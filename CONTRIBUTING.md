# Contributing to VoltGuard

Thanks for helping. VoltGuard aims to be a small, dependable macOS utility, so
changes are judged on whether they keep it small and dependable.

## Getting set up

```bash
git clone https://github.com/DevWizardHQ/VoltGuard.git
cd VoltGuard
make test
make run
```

You need macOS 14+ and Xcode 15.4+. The Command Line Tools alone cannot build
`VoltGuardUI`, because SwiftUI's `@State` macro plugin ships inside Xcode. Use
`make test-core` to run the non-UI tests without Xcode.

There is no `.xcodeproj` in the repository. Open the folder in Xcode and it
reads `Package.swift` directly.

## Where code goes

| Target | Put it here when it is… |
|---|---|
| `VoltGuardCore` | a decision: thresholds, latches, schedules, statistics, message rendering |
| `VoltGuardStore` | persistence: settings, SQLite, migrations, export |
| `VoltGuardPlatform` | a system API: IOKit, notifications, sound, speech, login item, Sparkle |
| `VoltGuardUI` | SwiftUI views and view models |

**`VoltGuardCore` must never import a system framework beyond Foundation, and
must never perform I/O.** That constraint is what keeps the alerting logic
testable in milliseconds. A pull request that breaks it will be asked to move
the code into `VoltGuardPlatform` behind a protocol.

## How the code fits together

### Targets

```
voltguard (executable) — composition root only
    │
VoltGuardUI ──► VoltGuardStore ──► VoltGuardCore
    │                 │                  ▲
    └──► VoltGuardPlatform ───────────────┘
```

| Target | Imports |
|---|---|
| `VoltGuardCore` | Foundation only |
| `VoltGuardStore` | Foundation, SQLite3, Core |
| `VoltGuardPlatform` | AppKit, IOKit, UserNotifications, AVFoundation, ServiceManagement, OSLog, Sparkle, Core, Store |
| `VoltGuardUI` | SwiftUI, Swift Charts, Core, Store, Platform |

Core performs no I/O and imports no system framework. Everything it needs from
the outside arrives through four protocols in `Monitoring/Ports.swift`:
`PowerSourceReader`, `HistoryRecording`, `AlertDelivering`, `VoltGuardClock`.

### Monitoring state machine

```
                  ┌──────────────┐
                  │ noBatteryMac │   desktop Mac; timer stops entirely
                  └──────────────┘
                         ▲
              first read finds no present battery
                         │
  start ──► active ◄───────────────► pausedByUser
              ▲  │
              │  ├──────────────────► outsideSchedule
              │  ├──────────────────► systemAsleep
              │  └──────────────────► degraded
              │                            │
              └────────────────────────────┘
                   recovery on next successful read
```

Only `active` evaluates rules. `degraded` backs off from 30s to a 5-minute cap
and never exits the loop.

### Tick pipeline

```
read snapshot
   ├─ no battery ──────────► noBatteryMac, stop
   │
resolve state (paused / asleep / scheduled)
   ├─ not active ──────────► refresh the status item, return
   │
record a sample if the level, charging state, or power source changed,
or maxSampleGap elapsed
   │
evaluate rules (at most once per interval, unless the power source or
charging state flipped, which forces it)
   │
yield AlertEvents into an AsyncStream and return — never await presentation
```

That last line is the answer to the alert-loop hazard: a modal dialog cannot
stall the engine, because the engine never waits for one.

### Alert latch

```
        level crosses the threshold AND all conditions match
clear ─────────────────────────────────────────────────────► armed
  ▲                                                            │
  └─── level crosses back past (threshold ∓ releaseMargin) ─────┘
```

A low rule at 20% with a 3% margin arms at ≤20 and clears at ≥23. The margin
exists because re-entry legitimately re-alerts; without it a battery oscillating
19/20/19/20 would alert repeatedly. Every re-arm increments a generation
counter, which feeds the deduplication key.

Comparisons are `<=` and `>=`. A reading exactly at the threshold fires.

### Deduplication

```swift
AlertEventKey(ruleID:generation:powerSessionID:)
```

`powerSessionID` is regenerated whenever the power source changes. The
dispatcher remembers the last delivered key per channel, so one evaluation
produces at most one event and one event at most one delivery per channel.

### Restart and wake

Latches persist in `UserDefaults`. The first tick after launch or wake runs in
reconciling mode: a still-true condition re-arms silently instead of firing.
That kills "alerts on every restart" without going quiet on a Mac that woke at
8%.

### Storage

```
~/Library/Application Support/VoltGuard/history.sqlite   samples, sessions, alerts
~/Library/Preferences/com.devwizardhq.voltguard.plist    settings and latches
~/Library/Logs/VoltGuard/voltguard.log                   rotating, 1 MB × 3
```

SQLite in WAL mode behind one actor. Migrations are an ordered array keyed off
`PRAGMA user_version`. No write batching: samples originate only from evaluation
ticks and genuine state changes, so the rate is a handful of rows per hour, and
buffering would trade microseconds for losing recent history on a crash.

Charging/discharging durations clamp each inter-sample gap to `maxSampleGap ×
1.5`, otherwise a laptop asleep for three days registers three days of
discharging.

### Concurrency

- `MonitoringEngine` and `AlertDispatcher` are actors.
- `HistoryStore` is an actor owning the only `sqlite3*` handle.
- `AppState` is `@MainActor @Observable`.
- Core and its tests build in Swift 6 language mode; Platform and UI are in
  Swift 5 mode pending a concurrency audit of the AppKit and Sparkle surfaces.

### Where things live

```
Package.swift            targets and the one dependency
Makefile                 every task: build, test, bundle, sign, dmg, release
README.md                what it is and how to install it
CONTRIBUTING.md          this file
CHANGELOG.md             released versions
Sources/                 VoltGuardCore, Store, Platform, UI, voltguard
Tests/                   one test target per source target
Resources/               Info.plist.in, entitlements, icon and installer art
Scripts/                 bundle, sign, dmg, notarize, appcast, art generators
site/                    the published documentation site and the appcast
.github/                 workflows and issue templates
docs/                    private notes, release process, credentials —
                         git-ignored
```

### Deliberate choices

**Not sandboxed.** Hardened Runtime is on, which notarization requires.
Sandboxing would break Sparkle's in-place self-replacement and force
user-selected file access for custom sounds and exports. Distribution is
Developer ID, not the Mac App Store.

**Sparkle rather than a hand-rolled updater.** An app updater is the most
security-sensitive component in a utility like this. Sparkle brings signature
verification, atomic install, channels, and critical updates; writing that again
would be strictly worse.

**No `.xcodeproj` in git.** `.pbxproj` merge conflicts are the main source of
friction for macOS open-source contributors. The cost is `Scripts/bundle.sh`.

**`MenuBarExtra` in `.menu` style.** A native menu is keyboard-navigable and
VoiceOver-correct for free. The countdown row is recomputed only while the menu
is open — a per-second timer animating text nobody is looking at would defeat
the idle-CPU target.

## Before opening a pull request

```bash
make format
make lint
make test
```

- New behavior comes with tests. Logic in Core is straightforward to test with
  `FakeClock` and `ScriptedPowerSource`; look at `Tests/VoltGuardCoreTests`.
- Keep third-party dependencies out. Sparkle is the only one, and it is there
  because a hand-rolled updater is a security liability.
- Match the surrounding style. Comments are rare here on purpose: name things
  well and extract functions instead.

## When the build complains about macro plugins

```
external macro implementation type 'TestingMacros.SuiteDeclarationMacro'
could not be found for macro 'Suite'
```

This happens intermittently with the Command Line Tools toolchain and is not a
problem with your change — CI, which uses Xcode, does not see it. Clearing both
caches usually gets a run through:

```bash
rm -rf .build .build-core ~/Library/Caches/org.swift.swiftpm
make test-core
```

If it keeps recurring, build with Xcode instead:
`sudo xcode-select -s /Applications/Xcode.app && make test`.

A variant naming `SwiftUIMacros.StateMacro` is a different thing entirely: that
plugin only ships inside Xcode, so the UI target cannot be built with the
Command Line Tools at all. Use `make test-core`, which excludes it.

## Commit messages

Conventional Commits:

```
feat: add per-rule release margin
fix: keep the latch armed across a backwards clock change
docs: document the appcast hosting decision
```

## Reporting bugs

Use **Settings → Advanced → Export Diagnostics**, read what it collected, and
paste it into the issue. It contains your VoltGuard version, macOS version, Mac
model, configuration, and recent log lines — nothing personal, but read it
before you post it.

## Reporting a security problem

Please **do not** open a public issue for a security problem. Use GitHub's
private vulnerability reporting:
<https://github.com/DevWizardHQ/VoltGuard/security/advisories/new>

Include what you found, how to reproduce it, and the VoltGuard and macOS
versions. We aim to acknowledge within 72 hours.

VoltGuard reads battery state and writes a local database. It has no server, no
account and no telemetry, so the one genuinely security-sensitive surface is
the update mechanism:

- **Updates are Sparkle 2.** Every archive carries an EdDSA signature verified
  against `SUPublicEDKey`, which is compiled into the shipped binary. An
  attacker who controls the appcast still cannot get an update installed.
- **The feed is HTTPS only**, served from a URL fixed at build time.
- **Releases are code signed** with a stable DevWizardHQ identity. They are
  **not currently notarized**, which is why Gatekeeper warns on first launch.
  That warning is not a malware finding.

In scope: the update path, local privilege issues, anything that lets another
process on the machine influence what VoltGuard executes. Out of scope: the
absence of sandboxing, which is deliberate and explained above, and anything
requiring an attacker who already has root.

## Code of conduct

Everyone taking part in this project — issues, pull requests, discussions — is
expected to help keep it a harassment-free experience, regardless of age, body
size, disability, ethnicity, sex characteristics, gender identity and
expression, experience, education, socio-economic status, nationality,
appearance, race, religion, or sexual identity and orientation.

That means: be respectful of differing views, give and accept feedback
gracefully, take responsibility when you get something wrong, and focus on what
is best for the project. It rules out sexualised language or attention,
trolling, insults, personal or political attacks, harassment in public or
private, and publishing anyone's private information.

Maintainers will remove, edit or reject contributions that break this, and may
ban anyone whose behaviour they judge harmful. Report a problem through a
GitHub issue, or privately to DevWizardHQ if that is not appropriate.

Adapted from the [Contributor Covenant](https://www.contributor-covenant.org)
version 2.1.
