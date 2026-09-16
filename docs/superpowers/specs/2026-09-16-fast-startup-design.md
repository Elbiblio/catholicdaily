# Fast startup design

## Goal

Render the Catholic Daily home experience within two seconds on a representative physical Android device, measured from an Android cold launch to the first Flutter frame and to usable home content. The app must never delay, lose, or duplicate daily saint and feast notifications because of this optimization.

## Evidence

`main()` currently awaits Firebase initialization, WorkManager registration, theme preferences, IP-based region discovery (with a four-second timeout), local-notification initialization, schedule reconciliation, and repair handoff before `runApp()`.

The home screen then waits for navigation persistence before beginning its reading load. A fresh session also resolves readings through local catalog and Bible assets. No Android device is presently connected, so a physical-device timing baseline cannot be captured in this workspace.

## Chosen architecture

### First-frame lane

`main()` performs only Flutter binding setup, synchronous FCM background-handler registration, system-chrome configuration, and `runApp()`. The app starts with the system theme and standard style, then applies persisted visual preferences when they are available. Notification tap handlers are installed before notification plugin initialization so launch payloads remain buffered and are resolved after navigation is ready.

The home screen begins its visual and reading work without waiting for navigation persistence. Persisting the active tab and checking the review prompt stay after usable reading content is available.

### Startup maintenance lane

After the first Flutter frame, a single coalesced startup task performs Firebase initialization, WorkManager registration, notification-plugin initialization, preference loading, reminder auto-setup/rescheduling, durable repair enqueueing, and foreground FCM listener setup. Failures remain isolated and logged; the task is retained by its Future rather than being abandoned.

On first launch, region selection uses the device locale immediately. It does not block on an IP request. A user-selected region remains authoritative. This keeps regional readings and reminder schedules deterministic without a network dependency on launch.

### Notification guarantee

Notification delivery remains owned by platform mechanisms rather than foreground startup:

- Android boot, package-replace, clock, timezone, and exact-alarm-capability receivers retain their existing repair behavior.
- WorkManager continues periodic and one-off coverage repair.
- Existing scheduled local alarms remain armed while post-frame reconciliation runs.
- FCM background delivery remains registered synchronously before app startup work; foreground and opened-message listeners initialize after the first frame.
- If a notification starts the app, its payload is buffered until the plugin and navigator are ready, then resolved normally.

## Explicit non-goals

This change does not weaken notification coverage, reduce reminder horizon, hide a slow boot behind an indefinite splash screen, change a user’s reminder choices, or replace the offline readings pipeline. Release shrinker changes are excluded until an APK and physical-device profile demonstrates a material benefit without plugin regressions.

## Measurement and regression protection

The implementation will add unit/widget seams that prove the first-frame lane does not await maintenance work and that delayed notification/Firebase work cannot prevent the app root from rendering. Automated tests will retain the first-run locale decision and the notification-tap buffer behavior.

On a connected physical Android device, the final check will capture repeatable cold-launch timings in profile or release mode. The acceptance threshold is under two seconds for first Flutter frame and usable home UI on the target device; absent a connected device, code-level gates and Android release build validation are reported separately rather than presented as measured device performance.
