# Alternative onboarding: Quiet Current

An independent native onboarding direction for comparison. This branch adds a guided setup to the existing utility; it is not a selected or merged product direction.

Open [the visual comparison](comparison.html), or inspect the native-view renders directly:

| Screen | Artifact |
| --- | --- |
| Welcome and product expectations | [Light](01-welcome-light.png) |
| Four saved alert choices and optional permission | [Light](02-reminders-light.png) |
| Completion, accessory discovery, and finding controls again | [Light](03-ready-light.png) |
| Authorized notification state | [Dark](04-reminders-dark.png) |
| Blocked notification state | [Light](05-permission-denied.png) |
| Smaller 720 × 520 window | [Compact](06-compact.png) |

These PNGs are direct renders of the actual native views, using isolated test settings and an empty accessory list. They contain no user telemetry. Authorization in the dark and blocked variants is a rendering fixture, not a record of a permission change. Runtime SF Symbols are used inside the interface, including Apple's accessory glyphs; they are not separately distributed icon assets.

## Design direction

- A stable progress rail explains where you are and allows returning to previous steps.
- A restrained material sidebar, generous typography, and runtime accessory symbols keep the setup familiar on macOS.
- The notification step separates four independent alert preferences from macOS authorization. A clear optional action explains the system prompt before it appears.
- Completion remains useful without permission or a connected accessory. It explains background monitoring, the disappearing menu-bar item, and how to reopen controls.
- The window is resizable. Content scrolls on smaller displays while navigation and Quit remain visible. VoiceOver labels describe each switch, the current step, and headings. Navigation directs accessibility focus to the new heading.

This direction suits a deliberate first-run introduction. Its tradeoff is a larger, three-step window. The everyday controls remain the existing native controls rather than an additional redesign.

## Run the alternative

From this checkout:

```sh
sh scripts/run-onboarding-alternative.sh
```

This builds with the existing `sh build-app.sh` workflow, then creates and opens a separate local comparison app under `build/`. The alternative uses bundle ID `co.arshia.magiccharger.alternative.quietcurrent`, so preferences, permission, and session history are separate from the standard app. It does not install the app, enable Launch at Login, or change the global developer selection. Earlier preview bundles are preserved rather than overwritten.

On first launch, setup opens automatically. Closing the window keeps monitoring; reopening the running app returns to the unfinished step. After completing setup, reopening goes to controls. **Show Setup…** in controls replays the walkthrough without clearing completion or saved choices. An interrupted process restart begins unfinished setup at Welcome; only the completion bit is persisted.

The four switches immediately save through the existing alert-preference service. Changes synchronize between setup and controls. **Allow Notifications…** is the only setup action that requests macOS permission. Existing authorization opens Notification Settings instead. No permission is required to continue. Setup never sends a test alert, fabricates a device, or changes charging-session deduplication.

For a normal production-identity build, the documented command is unchanged:

```sh
sh build-app.sh
```

Avoid running multiple comparison or standard app instances at once when testing real automatic alerts. Quit the previous instance from its own window before opening another.

## Validation

Local validation used the installed Xcode toolchain with Swift 6.4 on ARM64 macOS 27.3. The supported deployment target remains macOS 14; no dependencies were added.

- `sh build-app.sh`: passed.
- `swift test --configuration release`: 89 tests, 3 opt-in skips, 0 failures. The skips are the comparison renderer and two pre-existing performance samples. The debug suite also passed before the final window-lifecycle test was added.
- `CONFIGURATION=release sh build-app.sh` and the repository's shared release-bundle validator: passed (ARM64, version/build, unchanged license, signature integrity).
- Opt-in `OnboardingRenderingTests`: passed; exported the six images above, visually inspected in light, dark, and compact states.
- Actual isolated-app UI: verified Welcome → Reminders → Ready → Controls, continuing without requesting permission, a switch saving into the existing controls, restoring that choice, replaying setup, and Quit. Native accessibility inspection exposed the correct heading, step, switch values, and actions. The live window was visually inspected separately from the fixture renders.
- Notification permission was not requested or accepted; no test notification was sent; Launch at Login was left off. No real charging crossing, notification banner, or performance measurement was performed for this concept.

Reproduce tests and renders:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  MAGIC_CHARGER_RENDER_CONCEPT="$PWD/docs/concepts/quiet-current" \
  swift test --filter OnboardingRenderingTests
```

Remaining validation: live VoiceOver navigation and announcements, Increased Contrast/Reduce Transparency, real authorization prompt/error recovery, macOS 14 runtime, Intel, and real charging notifications. The existing hardware validation limits in the main README still apply.
