<div align="center">

# VoltGuard

**Smart Battery Monitoring & Alerts for macOS**

_Stay charged. Stay informed._

[![CI](https://github.com/DevWizardHQ/VoltGuard/actions/workflows/ci.yml/badge.svg)](https://github.com/DevWizardHQ/VoltGuard/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black)](https://www.apple.com/macos/)

</div>

VoltGuard is a lightweight menu-bar utility that watches your Mac's battery and
tells you before it gets too low or stays too high. It is built by
[DevWizardHQ](https://github.com/DevWizardHQ), runs entirely on your machine,
and never uploads a thing.

---

## Features

- **Flexible alert rules.** Not a fixed low/high pair — define as many named
  thresholds as you want, each with its own level, direction, power condition,
  channels, message, and repeat interval.
- **Charging-aware.** A 20% battery only warns you when you are actually running
  on battery; an 80% warning only fires while plugged in.
- **Four alert channels.** Notification, sound, spoken voice, and dialog, chosen
  per rule and independently switchable.
- **No alert spam.** Alerts latch on entry, release only after the level clears
  the threshold by a margin, and repeat only as often as you configure.
- **Schedules.** Restrict monitoring to working hours, overnight windows, or any
  set of weekdays. Windows crossing midnight are handled correctly.
- **History and statistics.** Battery level over time, daily and weekly
  aggregates, charging-session log, and CSV / JSON / TXT export.
- **Near-zero idle cost.** IOKit event notifications instead of shelling out to
  `pmset` on a timer. No busy loops, no subprocesses on the hot path.
- **Accessible.** VoiceOver labels everywhere, full keyboard navigation, and
  icon shapes that never rely on color alone.
- **Private by construction.** The only network request VoltGuard ever makes is
  the update check.

**Documentation:** <https://devwizardhq.github.io/VoltGuard/>

## Installation

### Download

Grab the latest `VoltGuard.dmg` from
[Releases](https://github.com/DevWizardHQ/VoltGuard/releases), open it, and drag
VoltGuard to Applications.

### First launch

VoltGuard is code signed but **not yet notarized by Apple**, so Gatekeeper
blocks the first launch with:

> "VoltGuard.app" Not Opened — Apple could not verify "VoltGuard.app" is free of
> malware that may harm your Mac or compromise your privacy.

Nothing scanned VoltGuard and found anything. That message means Apple has not
seen this developer before. Notarization requires a paid Apple Developer
account; until DevWizardHQ has one, every release will show it.

**To open it anyway — macOS 15 Sequoia and later:**

1. Try to open VoltGuard once and dismiss the dialog with **Done**.
2. Open **System Settings → Privacy & Security**.
3. Scroll to Security. Next to *"VoltGuard" was blocked*, click **Open Anyway**.
4. Confirm with Touch ID or your password.

Right-click → Open no longer works; Apple removed that path in macOS 15.

**Or from the terminal:**

```bash
xattr -dr com.apple.quarantine /Applications/VoltGuard.app
```

**Or build it yourself**, which produces a locally signed copy with no warning:

```bash
git clone https://github.com/DevWizardHQ/VoltGuard.git
cd VoltGuard && make bundle && cp -R dist/VoltGuard.app /Applications/
```

### Build from source

```bash
git clone https://github.com/DevWizardHQ/VoltGuard.git
cd VoltGuard
make bundle
open dist/VoltGuard.app
```

## Requirements

- macOS 14.0 Sonoma or later
- Xcode 15.4 or later to build (the Command Line Tools alone are not enough —
  SwiftUI's `@State` macro plugin ships inside Xcode)

## Development

```bash
make help       # list every target
make build      # universal release binary
make test       # full test suite
make test-core  # non-UI tests; works without Xcode
make lint       # formatting check
make format     # apply formatting
make bundle     # assemble dist/VoltGuard.app
make run        # build a debug bundle and launch it
make dmg        # build the installer image
make release    # build, sign, notarize, appcast
```

Only one third-party dependency: [Sparkle 2](https://sparkle-project.org) for
updates. Everything else is an Apple system framework.

## Architecture

Five SwiftPM targets, dependencies pointing strictly downward:

| Target | Responsibility |
|---|---|
| `VoltGuardCore` | Domain model, threshold evaluation, alert latch machine, schedule math, statistics. **Foundation only — no system frameworks, no I/O.** |
| `VoltGuardStore` | `UserDefaults` settings, SQLite history, migrations, retention, export |
| `VoltGuardPlatform` | IOKit power source, notifications, sound, speech, dialogs, login item, logging, Sparkle |
| `VoltGuardUI` | `MenuBarExtra`, settings tabs, history window, onboarding |
| `voltguard` | Composition root |

Keeping Core free of system frameworks is what makes every alerting decision
testable in milliseconds without launching an app. See
[CONTRIBUTING.md](CONTRIBUTING.md) for the state machines and data flow.

## Configuration

Defaults on first launch:

| Setting | Default |
|---|---|
| Monitoring interval | 10 minutes |
| Low Warning | 20%, on battery |
| Critical Low | 10%, on battery |
| High Warning | 80%, plugged in |
| Critical High | 90%, disabled |
| Channels | Notification + Sound |
| Repeat | Every 10 minutes |
| Schedule | Always active |
| History retention | 30 days |
| Launch at login | On |

Everything is editable in Settings, and every control has **Reset to Default**.

## Troubleshooting

**No notifications.** Check System Settings → Notifications → VoltGuard. When
permission is denied, VoltGuard says so in its menu and keeps the other channels
working.

**Menu bar says "Unavailable".** The battery read failed. VoltGuard retries with
exponential backoff and recovers on its own; Advanced → Export Diagnostics shows
the underlying error.

**"No battery" on a laptop.** Only expected on desktop Macs. On a laptop this
means IOKit reported no present battery — export diagnostics and open an issue.

**Alerts fire too often.** Raise the rule's repeat interval, or its release
margin if the battery is hovering at the threshold.

**Nothing after waking.** By design: VoltGuard does not replay an alert you
already dismissed. A genuinely critical level after wake still alerts.

## Privacy

- No account, no analytics, no telemetry.
- Battery history stays in `~/Library/Application Support/VoltGuard/`.
- Diagnostics are shown to you for review and never submitted automatically.
- The only network request is the Sparkle update check.

## Contributing

Issues and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE) © DevWizardHQ
