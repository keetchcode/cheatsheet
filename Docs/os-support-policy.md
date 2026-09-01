# OS Support Policy and iOS 27 Plan

How CheatSheet decides which OS versions it runs on, which SDK it ships against,
and how a new major iOS release gets adopted without destabilising the version
that is on the App Store.

## Current support matrix

| Platform      | Minimum (deployment target) | Built against (SDK) | Toolchain | Test runtime |
| ------------- | --------------------------- | ------------------- | --------- | ------------ |
| iOS / iPadOS  | 26.0                        | 26.x                | Xcode 26  | iOS 26.5+    |
| macOS         | 26.0                        | 26.x                | Xcode 26  | macOS 26+    |

## Two versions that are easy to confuse

These are independent knobs, and conflating them is the most common way a small
app either sheds users or gets rejected at upload.

- **Deployment target** — the oldest OS that can install the app. Raising it
  removes users. It is a product decision, never a housekeeping one.
- **SDK** — what the code is compiled against. Apple periodically raises the
  minimum SDK it will accept for submission, and it never accepts a beta SDK.
  Raising the SDK removes nobody.

The floor may never exceed the SDK: `xcodebuild` refuses to build when the
deployment target is later than the SDK it is given. A floor *below* the SDK is
the normal, supported case.

## Why the floor is iOS 26 / macOS 26

Set 2026-09-01. Every OS-conditional path in the app was a Liquid Glass gate —
`GlassEffectContainer`, `glassEffect(_:in:)`, and the `.glass` /
`.glassProminent` button styles, all introduced in 26.0. With the floor at 26.0
those gates are unconditionally true, so they were removed:
`CheatSheetApp/Sources/LiquidGlassGroup.swift` and
`CheatSheetApp/Sources/ViewModifiers.swift` now call the Liquid Glass API
directly, and the two platform arms collapsed into one `#if os(macOS) || os(iOS)`
branch. There are no `#available` or `@available` checks left in the codebase.

**26.0, not a point release.** Nothing in the app requires a 26.x point release,
so a 26.1–26.5 floor would delete exactly the same code while supporting fewer
devices. Pick the lowest floor that makes the code you actually want to delete
unreachable.

Raise the floor again only when a specific feature the app needs demands it and
the gated fallback has become a maintenance burden — not merely because a newer
OS exists. The previous floor (iOS 18 / macOS 15) was retired because it had
stopped being a real configuration: every gate behind it was a fallback nobody
was shipping against, and no iOS 18 simulator remained to test it on.

## Tests run on iOS 26.5 or newer

`Scripts/resolve-ios-simulator.sh` picks the newest available simulator **at or
above a floor**, defaulting to 26.5 and overridable with
`CHEATSHEET_MIN_IOS_RUNTIME`. Below the floor it fails with a per-runtime
breakdown rather than substituting an older runtime — a green suite that ran
against an unsupported configuration certifies nothing.

There is a ceiling as well as a floor: runtimes from a newer major than the
active simulator SDK are excluded. `simctl` keeps listing a beta OS runtime as
available after you switch back to the release Xcode, and "newest wins" would
otherwise send every shipping test run onto the beta OS. Because the ceiling
comes from the toolchain, an iOS 27 branch needs no special case — selecting
Xcode 27 raises it automatically.

It matches device family on `deviceTypeIdentifier`, not the display name: a
simulator can be renamed to anything and still be an iPhone, and name matching
silently hid four real iPhone simulators on this machine.

## Never submit from a beta toolchain

A machine that carries an Xcode beta will silently build against the beta SDK,
and the rejection only surfaces at upload. `Scripts/verify-build-sdk.sh` asserts
the active toolchain matches the SDK major this branch ships against.

```sh
Scripts/verify-build-sdk.sh          # hard fail on mismatch — run before archiving
Scripts/verify-build-sdk.sh --warn   # warn only — used by Scripts/verify-macos.sh
```

The expected major is a branch-level contract, defaulting to `26` and overridable:

```sh
CHEATSHEET_EXPECTED_SDK_MAJOR=27 Scripts/verify-build-sdk.sh
```

Both CI jobs run the hard-fail form immediately after selecting Xcode, so the
pin is asserted rather than assumed. Local verification warns instead of failing,
because developing against a beta is fine — archiving against one is not.

`Scripts/verify-project-config.sh` separately asserts the deployment floors in
`project.yml`, so a regression to an older target fails CI instead of shipping.

## iOS 27 readiness: measured, not assumed

Measured 2026-08-31 on Xcode 27.0 beta (build 27A5252f), iOS 27.0 SDK:

- **The app compiles clean against the iOS 27 SDK.** `CheatSheetiOS` built
  against `iPhoneSimulator27.0.sdk`: 91 Swift compile actions, **0 warnings,
  0 deprecations**. (Measured while the floor was still 18.0; the floor has
  since risen to 26.0, which only removes code.)
- **Every Liquid Glass API the app uses survives iOS 27**, with no deprecation
  or renaming: `GlassEffectContainer`, `glassEffect(_:in:)`, `Glass.tint(_:)`,
  `Glass.interactive(_:)`, `.glass`, `.glassProminent`.
- `GlassButtonStyle.init(_ glass:)` is marked `@available(iOS 26.1, *)` — an
  opt-in refinement the app does not currently need.

**Caveat:** this is a beta SDK and can change before release. The finding means
there is no known iOS 27 migration debt today; it is not a guarantee. Re-run the
trial build against each new beta and against the GM.

Reproduce the trial build:

```sh
xcodegen generate --spec project.yml
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild build \
  -project CheatSheet.xcodeproj -scheme CheatSheetiOS \
  -destination "id=$(Scripts/resolve-ios-simulator.sh)" \
  -derivedDataPath /tmp/CheatSheet-iOS27-DD CODE_SIGNING_ALLOWED=NO
```

## Branching

The iOS 26 line stays shippable at all times; iOS 27 work happens beside it.
This slots into the existing Git Flow model (see `CONTRIBUTING.md`) rather than
replacing it.

| Branch                     | Floor | SDK contract | Purpose                                      |
| -------------------------- | ----- | ------------ | -------------------------------------------- |
| `main`                     | 26.0  | 26           | Released. Always submittable.                |
| `develop`                  | 26.0  | 26           | Next release. Always submittable.            |
| `release/*`                | 26.0  | 26           | Stabilising a release cut from `develop`.    |
| `hotfix/*`                 | 26.0  | 26           | Urgent fix off `main`.                       |
| `feature/ios-27-readiness` | 26.0  | 27           | Long-lived OS adoption branch off `develop`. |

**Why a feature branch and not a permanent parallel branch.** A permanent
`ios-27` branch rots: it accumulates conflicts against every release, and the
merge back becomes a big-bang event exactly when time is shortest. Keeping it as
a long-lived but *thin* feature branch keeps the merge cheap.

Rules for the readiness branch:

- Keep it thin. Only the SDK contract, CI variant, and genuinely 27-gated
  adoption belong on it. Ordinary features go to `develop` as usual.
- Merge `develop` into it on a regular cadence (weekly, or after every merge to
  `develop`). Never let it drift.
- It may be red while a beta is broken. `develop` may never be red.

Note that adopting the iOS 27 **SDK** does not imply an iOS 27 **floor**. Those
are separate decisions, governed by the rule above.

## Phases

**Phase 0 — baseline (done, 2026-08-31).** iOS 26 SDK contract made explicit and
enforced in CI. iOS 27 trial build proves zero migration debt.

**Phase 1 — modern-only floor (done, 2026-09-01).** Floor raised to iOS 26.0 /
macOS 26.0, all availability gates removed, test-runtime floor set to iOS 26.5,
CI moved to the `macos-26` runner so the macOS job can host a macOS 26 app.

**Phase 2 — beta season (now until iOS 27 GM).** Create
`feature/ios-27-readiness` off `develop` when there is something to put on it.
On that branch set `CHEATSHEET_EXPECTED_SDK_MAJOR=27` and point the CI Xcode
selection at `Xcode_27*.app`. Re-run the trial build against each beta.
`develop` and `main` do not move.

**Phase 3 — iOS 27 released, Xcode 27 released.** Flip the SDK contract on
`develop`: `CHEATSHEET_EXPECTED_SDK_MAJOR` default `26` → `27`, CI Xcode
selection `26` → `27`, and update the support matrix above plus `README.md` and
`CONTRIBUTING.md`. Merge `feature/ios-27-readiness` into `develop`, cut a
`release/*`, run the full device sweep, tag into `main`. Leave the floor at 26.0
unless a needed feature forces it higher.

## Checklist for the day iOS 27 ships

1. Install the released Xcode 27; confirm `Scripts/verify-build-sdk.sh` passes
   with `CHEATSHEET_EXPECTED_SDK_MAJOR=27`.
2. Flip the SDK contract on `develop` (see Phase 3) and merge the readiness branch.
3. Regenerate the project and run the full suite: `Scripts/verify-macos.sh`,
   iOS unit tests, iOS UI tests.
4. Verify the widgets on an iOS 27 device — App Group sharing and timeline
   reloads are the parts most likely to regress across a major release.
5. Check Liquid Glass rendering on 27 against the 26 screenshots.
6. Confirm the app still installs on a simulator at the declared floor (iOS 26.0),
   not only on the newest runtime.
7. Bump the build number, archive, and confirm the archive's SDK before upload.
