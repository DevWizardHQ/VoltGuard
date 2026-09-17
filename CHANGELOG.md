# Changelog

All notable changes to VoltGuard are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- The charging bolt was invisible in the menu bar. It was painted in the same
  ink as the charge fill and separated only by a hairline gap, which vanished
  at menu bar size. Where the fill covers it the bolt is now a hole punched
  clean through; where the level is too low for the fill to reach it, the
  bolt is painted instead.

### Changed

- The menu bar icon is a monochrome template image, like every other item in
  the menu bar. macOS tints it to match the bar in both appearances and while
  the menu is open, instead of it sitting there as the one coloured icon.
  Level still reads from the fill height. The application icon keeps its
  colours.

### Fixed

- The charging bolt disappeared whenever the battery was too low for the
  charge fill to reach it, because the bolt was only ever drawn as a knockout
  of that fill. It is now drawn beneath the fill and knocked back out of it,
  so a charger attached at 20% shows the bolt.
- The voice list was read once at launch, so a voice downloaded in System
  Settings did not appear until VoltGuard was restarted. It is re-read
  whenever the app becomes active.
- Corrected the voice defaults. VoltGuard claimed to default to Apple's Siri
  voice; macOS does not vend Siri voices to third-party apps, so that
  preference never matched and the app silently used the system default.
  Automatic now means the highest-quality voice the app can actually use —
  Premium, then Enhanced — and the UI says so.
- The voice picker still read "System Default" and listed bare voice names.
  It now labels the automatic option with the voice it resolves to, shows
  each voice's quality, and offers a Download More Voices button that opens
  System Settings ▸ Accessibility ▸ Read & Speak.

## [0.1.2] - 2026-09-17

### Added

- A new icon: a battery inside a guard shield, drawn from
  `Resources/Assets/battery-shield-icon.svg`. One renderer produces both the
  application icon and the menu bar glyph, so they cannot drift apart.
- The menu bar icon now reports state directly: the cell fills to the real
  battery level and is tinted green, amber or red by how much is left, the
  bolt appears only while a charger is attached, and the shield disappears
  while monitoring is paused.
- Voice alerts gained a tone control alongside rate and volume, and every
  alert rule has a Listen button that speaks that rule's own message, filled
  in with the current battery level.
- The voice now defaults to Apple's natural Siri voice — "Voice 4" — when it
  is installed, falling back to the best remaining voice and then to the
  system default. Settings shows which voice Automatic resolves to, and the
  picker labels each voice with its quality.

### Changed

- New default rules and wording: Critical at 15%, Low at 25%, Charging Warning
  at 80%, and Full at 100%. Each message names the live battery level, for
  example "Battery is 15% please connect your device to a power source
  immediately to avoid shutdown."
- The installer background follows the new palette.
- The site's logo and favicon are `site/mark.svg`, generated from the same
  geometry as the application icon, so the two cannot diverge. It carries its
  own colours and reads on light and dark backgrounds alike.

## [0.1.1] - 2026-09-16

### Fixed

- An open window was unreachable. VoltGuard runs as an accessory app, so it
  has no Dock icon and no ⌘-Tab entry, and once Settings or the history window
  was behind something there was no way back to it. The app is now a regular
  app for exactly as long as a window is on screen, and returns to accessory
  when the last one closes.
- Opening a window did not focus it. Activation ran before the window was
  created, so it arrived un-keyed behind whatever was in front; Settings did
  not activate the app at all. Activation now happens after the window exists,
  and the new window is made key.
- First-run setup never appeared: `hasCompletedOnboarding` was written but
  never read, so the welcome flow could not open. It is presented on first
  launch.

- The Settings ▸ Alerts tab was broken: `HSplitView` collapsed the rule list
  to its intrinsic height inside a fixed-size window, so it floated in the
  middle of the tab with rows clipped. It is now a proper sidebar that fills
  the window.
- The history window's tabs left a band of empty space above their controls,
  because a `VStack` centres itself when given extra height. Content is pinned
  to the top, the range picker sits in a header strip at its natural width
  rather than stretched edge to edge, and Charging Sessions gained the same
  range control as the other tabs.
- The menu reported "Notifications Are Disabled" forever: the permission was
  read once at launch, so turning notifications on in System Settings had no
  effect until VoltGuard was restarted. It is now re-read whenever the app
  becomes active, and it distinguishes "not yet asked" from "turned off" from
  "no notification centre available", which is what happens when the app is
  run from the disk image instead of Applications.

- The signed appcast never reached the published site. The release workflow
  commits it with `GITHUB_TOKEN`, and GitHub raises no push event for commits
  made with that token, so the Pages workflow never ran and the live feed kept
  serving the previous build. Pages now also deploys on the release workflow
  completing.
- The notification permission prompt appeared on first launch even when no
  enabled rule used the notification channel. It is now raised only when a
  rule can actually post one, and when a rule later starts using it.

### Changed

- Removed the keyboard shortcuts from the menu bar. VoltGuard is an accessory
  app and is never the frontmost application, so they never fired; showing
  them promised something that did not work.

- Documentation said Xcode 15.4 was enough to build. The package declares
  swift-tools-version 6.0, so it needs Xcode 16.

## [0.1.0] - 2026-09-16

First release. Signed with the DevWizardHQ stable identity and **not
notarized**, so on first launch macOS asks you to allow it through
System Settings ▸ Privacy & Security ▸ Open Anyway.

### Added

- Monitoring engine over IOKit `IOPowerSources`, event driven with a coalescing
  interval timer, so plugging in registers immediately while rule evaluation
  still honours the configured interval.
- Alert rules as a list rather than a fixed low/high pair: each has a
  threshold, direction, power condition, channels, repeat policy and release
  margin, and can be added, renamed, retuned or deleted.
- Latching with a release margin and a rule/generation/power-session
  deduplication key, so a battery hovering on a threshold cannot spam alerts.
- Notification, sound, voice and dialog channels, chosen per rule. Sound rides
  on the notification when both are enabled, so one alert makes one sound.
- Menu bar status item with pause/resume, Check Now, an alerts toggle, and an
  icon that changes shape rather than only colour.
- Settings across eight tabs, each control with Reset to Default.
- Monitoring schedules, including windows that cross midnight.
- SQLite history, charging sessions, statistics, charts, an alert log, and
  CSV/JSON/TXT export with configurable retention.
- First-launch onboarding, launch at login through `SMAppService`, and
  sleep/wake handling that does not replay dismissed alerts.
- Structured logging with rotation, and a diagnostic report the user reads
  before anything leaves the machine.
- Sparkle 2 updates with an EdDSA-signed appcast and stable/beta channels.
- `voltguard-selftest`, a headless binary that exercises the real IOKit,
  SQLite and alerting stack and exits non-zero on failure.
- Universal binary packaging, a designed DMG, inside-out code signing,
  optional notarization, and CI that builds, tests and launches the signed app
  before anything can be published.
- A documentation site published to GitHub Pages alongside the appcast.

[Unreleased]: https://github.com/DevWizardHQ/VoltGuard/compare/v0.1.2...HEAD
[0.1.2]: https://github.com/DevWizardHQ/VoltGuard/releases/tag/v0.1.2
[0.1.1]: https://github.com/DevWizardHQ/VoltGuard/releases/tag/v0.1.1
[0.1.0]: https://github.com/DevWizardHQ/VoltGuard/releases/tag/v0.1.0
