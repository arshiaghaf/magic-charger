# Native controls and welcome direction

This draft makes Magic Charger a compact utility with progressive disclosure. Accessories is the everyday surface; Notifications and General hold deliberate configuration. Native segmented navigation switches to a popup at compact widths. Command-1, Command-2 and Command-3 select sections. Controls and accessory cards retain their identities across refreshes.

Accessory cards prioritize the device, charge state and exact percentage. A decorative battery track provides a second visual cue without duplicating the accessible reading. Semantic colors follow system appearance, and charging is also stated in text. Stale or invalid values cannot acquire charging emphasis. No animations or additional polling timers are introduced.

The two-step welcome explains conditional menu-bar visibility, reopening the app and local privacy before offering optional notification permission. Continue, Back, Skip and closing the tour never request permission. Existing installations migrate quietly. General provides a Welcome Tour button to replay the introduction. Login registration remains an independent explicit choice.

## Validation

The combined implementation passed 87 local tests (two opt-in performance tests skipped), including navigation, compact enlarged-text layout, state preservation, permission isolation and existing charging/session regressions. The native app bundle built successfully with the installed compatible Xcode via `sh build-app.sh`.

App-owned offscreen renders were inspected in light and dark appearance using an isolated helper with explicitly simulated readings and notification readiness. No fixtures are linked into the live application. This is design evidence, not screen capture or real-device validation.

Live VoiceOver, physical charging transitions, actual notification banners, Intel builds and macOS 14 runtime appearance remain unverified. No new performance measurement is claimed. This proposal preserves the deployment target and adds no dependency.
