# Contributing to Drift

Thanks for your interest. Drift is a small library — most contributions
land quickly if they follow the conventions below.

## Development

```bash
git clone https://github.com/chomaev-shamil/Drift.git
cd Drift
swift build
swift test
```

The package targets Swift 6 in strict concurrency mode. New code must
compile clean — no `@unchecked Sendable` in production sources, no
existential-any warnings, no force-unwraps without justification.

## Tests

Every public behaviour change needs a test. Drift uses Swift Testing
(`import Testing`, `@Test`). Keep tests fast and `@MainActor`-isolated
where the API requires it.

Coverage targets:

- new public API → unit test in `Tests/DriftTests/`
- bug fix → regression test that reproduces the bug, then the fix

Run the full suite before opening a PR:

```bash
swift test
```

## Commit messages

Drift follows [Conventional Commits 1.0.0](https://www.conventionalcommits.org/).

Format:

```
<type>(<optional scope>): <subject>

<optional body>

<optional footer>
```

### Types

| Type       | Use for                                                  | Version bump |
| ---------- | -------------------------------------------------------- | ------------ |
| `feat`     | New public API or capability                             | minor        |
| `fix`      | Bug fix in existing behaviour                            | patch        |
| `perf`     | Performance improvement, no API change                   | patch        |
| `refactor` | Code restructure, no behaviour change                    | none         |
| `docs`     | Documentation only (README, DocC, AGENTS.md, comments)   | none         |
| `test`     | Adding or fixing tests                                   | none         |
| `build`    | Package.swift, swift settings, dependencies              | none         |
| `ci`       | GitHub Actions, workflows                                | none         |
| `chore`    | Maintenance that does not fit elsewhere                  | none         |

A `!` after the type or a `BREAKING CHANGE:` footer marks a major bump.

### Examples

```
feat: add popTo(_:) to FlowRouter
fix: resolve pending result when sheet swipes down
docs: document task cancellation in presentForResult
refactor(router)!: rename presented to presentation

BREAKING CHANGE: FlowRouter.presented is now FlowRouter.presentation.
```

### Subject rules

- Imperative mood: "add", "fix", "remove" — not "added" or "adds".
- Lowercase first letter.
- No trailing period.
- Under 72 characters.

## Pull requests

- One concern per PR. Mixed PRs (feature + refactor + docs) get split.
- Update `CHANGELOG.md` under the `[Unreleased]` section.
- All CI checks must pass before review.
- Squash-merge is the default; the squashed message must follow Conventional Commits.

## Releases

Maintainer-only. Release flow:

1. Move `[Unreleased]` entries in `CHANGELOG.md` under a new version heading.
2. Commit: `chore(release): X.Y.Z`.
3. Tag: `git tag X.Y.Z && git push --tags`.
4. Draft release notes on GitHub from the tag.

## Code of conduct

Be kind. Disagree on the merits, not the person. Sensitive reports can
go directly to the maintainer at sham.chom77@gmail.com.
