# Changelog

All notable changes to this project will be documented in this file. The
format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Commit messages follow [Conventional Commits 1.0.0](https://www.conventionalcommits.org/).

## [Unreleased]

## [0.1.0] - 2026-05-08

### Added
- `FlowRouter` — typed navigation stack with `push`/`pop`/`popTo`/`replaceStack`.
- `present` / `presentForResult` with `sheet` and `fullScreen` styles.
- `async` result delivery via `presentForResult` with task cancellation support.
- `FlowView` SwiftUI host wrapping `NavigationStack`, `.sheet`, `.fullScreenCover`.
- `Route` protocol — `Hashable + Codable + Sendable`.
- `NavigationLogger` protocol with `NoopNavigationLogger` default.
- `DeeplinkParsing`, `DeeplinkHandling`, `DeeplinkBuffer`.
- Push debouncing via `ContinuousClock`.
- 26 tests covering edge cases, cancellation, and logging.
- DocC catalog with Getting Started, Tabs, Deeplinks, Auth, Testing articles.
