# NotifyGlow-Rootless

App-colored notification animations for a rootless jailbreak. Package: `com.rshad.notifyglow`, version `1.0.2`.

## 1.0.2 runtime fixes

Targets the reported iPhone XS Max / iOS 17.5.1 failure; still requires physical-device validation.

- Attach the overlay to a connected main-display UIWindowScene and explicitly size/layout its root view before creating animation paths.
- Secure window context and lock-screen-capable root controller, without stealing key status or touches.
- Preview bypasses private lock/Focus/notification/low-power gates and now returns SpringBoard success/failure/timeout feedback.
- Runtime diagnostics reports injected runtime version and dispatcher/banner hook availability. A created window is not proof of visible rendering.
- Add the single-argument banner destination selector and bounded retries for notification classes loaded after the constructor.
- Guard delayed rendering exceptions, allow absent timestamps for newly posted requests and only deduplicate successfully created overlays.
- Use Darwin display state when the backlight selector is unavailable; fix optional icon opacity after the animation ends.

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

Unlocked effects follow accepted system banner posts. The dispatcher-only locked path retains Focus/notification eligibility checks and fails closed when unavailable. Accepted banner posts rely on iOS routing instead of querying Focus again. These private selectors and window visibility must be validated on the device. Explicit Preview is independent of these gates. Locking/unlocking without a new notification does not trigger an effect.

The notch effect is a stylized top-center capsule, not an exact model-specific notch contour. Gradient colors, automatic game/video detection, an installed-app picker and a standalone app are not part of this build.

## Build / install

The GitHub Actions workflow builds a DEB and SHA256SUMS (`NotifyGlow-Rootless-1.0.2`). Update from Sileo and restart SpringBoard when prompted. Then open Settings > NotifyGlow > Preview animation. If it is invisible, use Runtime diagnostics and capture the response. No response means injection/IPC requires investigation; Sileo alone does not inject tweaks.

For local builds, install Theos and its patched iPhoneOS 16.5 SDK, then run `make clean package FINALPACKAGE=1`. Tests: `cc -std=c11 tests/logic.c -lm -o /tmp/ng-logic && /tmp/ng-logic`; metadata: `python3 scripts/validate.py`.

Sileo source: https://rshad97.github.io/FreeFall-Rootless/

## Required device checks before a stable release

1. Preview all three styles and random; change duration, width, color and icon. Confirm settings apply without a respring.
2. Send a real notification while unlocked, locked with screen on, and locked with screen off. Confirm one effect per event.
3. Verify Focus, silent delivery, Low Power Mode, Reduce Motion, per-app disable and global disable.
4. Send a burst of notifications, rotate the device, lock during an effect, and use the keyboard. Check no overlay remains and touches keep working.
5. Test alongside existing notification tweaks. Confirm memory returns to baseline and no idle animation/wake activity.

Expected logs: `[NotifyGlow] loaded 1.0.2`, `hooks mask=...`, `render style=... scene=... bounds=...`, or explicit renderer failure/exception. Mask bits: 1 dispatcher, 2 historical banner, 4 single-argument banner. Do not collect notification contents for debugging.

## Implementation references

- https://theos.dev/docs/rootless
- https://developer.apple.com/documentation/uikit/uiwindow/init(windowscene:)
- https://github.com/NSExceptional/FLEXing/blob/master/Tweak.xm (secure context / lock-screen presentation)
- https://github.com/xybp888/iOS-Header/blob/master/14.5/PrivateFrameworks/SpringBoard.framework/SBNotificationBannerDestination.h (historical selector reference; availability checked at runtime)
- https://github.com/udevsharold/battsafepro/blob/master/SpringBoard-Private.h (notification/lock-screen selector references)
- https://github.com/rdunlocked18/iOS-10-Springboard-Heads/blob/master/SBBacklightController.h (historical backlight selector reference, not proof of modern compatibility)
