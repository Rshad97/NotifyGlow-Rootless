# NotifyGlow-Rootless

App-colored notification animations for a rootless jailbreak. Package: `com.rshad.notifyglow`, version `1.0.1`.

## Included

- Edge tracing, notch pulse, inward soft wave, and random selection.
- Color sampled from the application icon, with a blue fallback for monochrome icons; global and per-app hex overrides.
- Independent lock-screen/unlocked toggles, duration, width, intensity, optional app icon, per-app disable/style/color rules, and a Preview button.
- Touch-through overlay that never becomes key; automatic cleanup, bounded color cache, duplicate suppression and rate limiting.
- Low Power Mode pause and Reduce Motion fade. No message text is read or logged.
- Opt-in experimental screen wake; default lets iOS handle screen wake.
- PreferenceLoader settings and Sileo `Needs: respring` metadata.

## Status and compatibility

Initial implementation, **not yet verified on a physical iPhone**. A successful CI build verifies compilation and packaging, not SpringBoard runtime compatibility. Deployment target is iOS 15+, arm64/arm64e rootless; this is not a claim that every later iOS version or jailbreak is supported.

Unlocked effects follow the system banner destination. Lock-screen effects use capability-checked private selectors: `NCNotificationDispatcher`, `NCNotificationOptions.canTurnOnDisplay`, `SBLockScreenManager`, `SBBacklightController` and `DNDStateService`. Lock-screen effects fail closed if Focus state or eligibility cannot be established. Focus mode blocks lock effects even for notifications otherwise allowed through Focus. These selectors and window visibility must be validated on the target device. Runtime incompatibility can mean Preview works but real notifications do not.

The notch effect is a stylized top-center capsule, not an exact model-specific notch contour. Gradient colors, automatic game/video detection, an installed-app picker and a standalone app are not part of this build.

## Build / install

The GitHub Actions workflow builds a DEB and SHA256SUMS. Download the `NotifyGlow-Rootless-1.0.0` artifact from a successful run, extract it, open the DEB with Sileo and restart SpringBoard when prompted. Then open Settings > NotifyGlow > Preview animation.

For local builds, install Theos and its patched iPhoneOS 16.5 SDK, then run `make clean package FINALPACKAGE=1`. Tests: `cc -std=c11 tests/logic.c -lm -o /tmp/ng-logic && /tmp/ng-logic`; metadata: `python3 scripts/validate.py`.

This GitHub source repository is not yet an APT/Sileo source URL. No unsigned package index is advertised, and no unrelated repository is changed.

## Required device checks before a stable release

1. Preview all three styles and random; change duration, width, color and icon. Confirm settings apply without a respring.
2. Send a real notification while unlocked, locked with screen on, and locked with screen off. Confirm one effect per event.
3. Verify Focus, silent delivery, Low Power Mode, Reduce Motion, per-app disable and global disable.
4. Send a burst of notifications, rotate the device, lock during an effect, and use the keyboard. Check no overlay remains and touches keep working.
5. Test alongside existing notification tweaks. Confirm memory returns to baseline and no idle animation/wake activity.

Expected logs: `[NotifyGlow] loaded 1.0.0`, `render style=... bundle=...`; capability failures report `notification dispatcher unavailable`, `banner hook unavailable`, or `lock skipped: Focus active or unavailable`. Do not collect notification contents for debugging.

## Implementation references

- https://theos.dev/docs/rootless
- https://github.com/udevsharold/battsafepro/blob/master/SpringBoard-Private.h (notification/lock-screen selector references)
- https://github.com/rdunlocked18/iOS-10-Springboard-Heads/blob/master/SBBacklightController.h (historical backlight selector reference, not proof of modern compatibility)
