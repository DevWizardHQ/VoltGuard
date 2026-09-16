# Changelog

All notable changes to VoltGuard are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- The signed appcast never reached the published site. The release workflow
  commits it with `GITHUB_TOKEN`, and GitHub raises no push event for commits
  made with that token, so the Pages workflow never ran and the live feed kept
  serving the previous build. Pages now also deploys on the release workflow
  completing.
- The notification permission prompt appeared on first launch even when no
  enabled rule used the notification channel. It is now raised only when a
  rule can actually post one, and when a rule later starts using it.

### Changed

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

[Unreleased]: https://github.com/DevWizardHQ/VoltGuard/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/DevWizardHQ/VoltGuard/releases/tag/v0.1.0
