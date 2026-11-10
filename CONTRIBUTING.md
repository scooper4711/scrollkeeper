# Contributing to Scrollkeeper

Thank you for helping with Scrollkeeper. It is a library manager for the user's Paizo purchases, on the Mac, the
iPad and the iPhone. It is part of the
[Tableside Toolkit](https://github.com/scooper4711/scrollkeeper#tableside-toolkit), free tools for Pathfinder and
Starfinder players and GMs, kept by one maintainer in spare time.

## Before you start

- Small fixes can go straight to a pull request.
- For anything bigger (a feature, a change in behavior, a new dependency), open or comment on an issue first, so we
  can agree on the design before you write the code.
- One change per pull request.

## Setting up

You need macOS 26 and Xcode 26 (Swift 6), as CI uses, and [SwiftLint](https://github.com/realm/SwiftLint)
(`brew install swiftlint`).

```sh
git clone https://github.com/scooper4711/scrollkeeper.git
cd scrollkeeper
make build
make test
```

Launch with `-ScrollkeeperDemo` (`open build/Scrollkeeper.app --args -ScrollkeeperDemo`) to try the app with made-up
titles, without a Paizo account. `make ipad-simulator` runs the iPad app and `make ipad-uitest` its interface tests.
Never commit credentials, cookies or anything from a real account, in code, tests or screenshots.

Other apps rely on Scrollkeeper's hand-off links (`scrollkeeper://`) and title lists, described in
`docs/specs/app-handoff/`. A change to them must keep working with the apps already released.

## Making a change

### Code

Match the code around your change, and:

- **Functions** do one thing: under 20 lines ideally, 50 at most, with two arguments or fewer (four or more become a
  parameter object). No Boolean flag arguments: write two functions.
- **Files** under 300 lines (500 at most); lines under 120 characters.
- **Complexity** under 5 where you can, never 15 or more. Say why next to any SwiftLint rule you silence.
- **Empty values over `nil`**: return an empty array or string, or an `Optional` the caller must handle.
- **Errors** say what was being done and what went wrong.
- **Names** are whole words, one word per concept. Public before private, callers before the functions they call,
  positive conditions (`isValid`, not `!isInvalid`).
- **Repetition**: factor code out the third time it appears, when the copies mean the same thing.
- **No unrelated reformatting**; leave the code you touch cleaner than you found it.
- **Doc comments** say what something is for and why it works as it does.
- **American English** everywhere, interface text and commit messages included.

`make lint` (SwiftLint, strict) must be clean.

### Tests

- New behavior gets tests; a bug fix gets a test that would have caught it.
- Test code meets the same standard, apart from length. Use the shared helpers and fixtures.
- `make coverage` fails below 80% of the lines or regions of `ScrollkeeperKit`. Code you add or change should be at
  80% or more too. SwiftUI views aren't measured, so keep logic in types that are.
- **Never commit with a failing test.** A failing test is a signal that something another feature relies on has
  changed: find out why, rather than skipping or loosening it.

### Specs

Features are described in `docs/specs/<feature>/`: `requirements.md` (numbered, such as R4.3) and `design.md`.
Update both in the same pull request as the behavior.

### Paizo's and others' material

The repository holds no Paizo text, art or PDFs, with two exceptions in the demo files: art Paizo shares under
its [Community Use Policy](https://paizo.com/licenses/communityuse) (the Community Use Package and paizo.com blog
art), and rules text Paizo publishes under the [ORC License](https://paizo.com/orclicense), such as Monster Core's
stat blocks, with the ORC notice and Paizo's attribution beside it. Don't commit any other Paizo material, nor
screenshots of it, nor other publishers' art (such as Rexard's packs) or fonts whose licenses don't allow it.

It works with the user's own purchases through their paizo.com account. Tests use made-up titles and a demo client,
with no real account data.

## Commits

- **Signed commits are welcome**
  ([SSH or GPG signing](https://docs.github.com/en/authentication/managing-commit-signature-verification)), but not
  required: `main` accepts only verified commits, so the maintainer re-signs unsigned ones before merging. You stay
  credited as the author.
- Each commit is one coherent step that builds and passes its tests.
- Start the message with a type (`feat`, `fix`, `refactor`, `docs`, `test`, `style`, `chore`, or `chore(ci)` for
  CI), then a capitalized summary of what changes for the user, with no period:
  `feat: Roll a group's initiative from one die`. The body says why.
- Leave `CHANGELOG.md` alone: it is written at release.

## Pull requests

1. Branch from `main` and keep up to date with it.
2. Run `make lint` and `make coverage` before you push; CI runs the same. CI on a first pull request from a fork
   waits for the maintainer's approval.
3. Say what changes, why, and how you checked it (tests, what you tried, on which devices). Link the issue, and add
   screenshots for interface changes.

Code written with AI tools is welcome: say so in the pull request, and submit only what you have read, understood
and tested.

## Issues

[Open an issue](https://github.com/scooper4711/scrollkeeper/issues) for a bug or an idea. For a bug, give the app's
version (About Scrollkeeper), the device and system version, and what you did, expected and got. Leave Paizo content
out of screenshots.

## License

Scrollkeeper is under the [MIT License](LICENSE); your contributions are too.
