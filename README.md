# PEWPEW · Neon Outpost

An Android-first, offline 3D shooter prototype. Move through an original arena,
fight waves of drones, and survive a two-minute training round. Built with Godot
4.6.3's C++ engine; gameplay is GDScript. There is no custom C++ module yet.

## Play on Android

The cloud build is `build/pewpew-debug.apk` (debug-signed, ARM64 + ARMv7).
Transfer it to your phone, allow installation from that source, install, and tap
**Deploy**. This is a development APK, not a Google Play release.

- Left thumb: floating movement stick. Right side: drag to look.
- Hold **Fire** to shoot. **Aim** toggles zoom. **Reload** refills the magazine.
- Bots use line-of-sight attacks; solid cover blocks both sides' shots.
- Clearing a wave restores 25 health and starts the next wave after 2.5 seconds.
- Pause freezes gameplay; leaving the app also pauses it.
- Smooth: 75% render resolution, no shadows or MSAA. High: full render resolution,
  directional shadows and 2× MSAA. The selection persists locally.

The APK declares Android 7.0/API 24 minimum, targets API 36, and requires OpenGL
ES 3.0. Those are installation requirements, **not a measured performance floor**.
The frame cap is 60 FPS; actual FPS, thermal behavior, touchscreen behavior and
device compatibility require physical-device testing.

## Develop

Open `project.godot` in Godot **4.6.3 stable** and run the main scene. No plugins,
paid assets, accounts, backend, or secrets are needed. Desktop controls are WASD,
mouse look, left-click fire, right-click aim, R reload and Esc pause.

In this cloud environment:

```sh
cd /workspace/pewpew
python3 tools/setup_cloud.py  # repeatable SDK/exporter setup; first download can be large
bash tools/godot.sh --headless --editor --import --quit
bash tools/godot.sh --headless -- --smoke-test
bash tools/export_android.sh
```

`tools/godot.sh` keeps editor caches, settings and Android user directories under
`/workspace/tooling`. Set `GODOT_BIN` to use a different Godot executable.
This task already has an isolated checkout; do not create another Git worktree.

For a fresh machine, install Godot 4.6.3 and its matching official export
templates. Install Android SDK platform-tools, build-tools 36.0.0 and Android 36
using Android Studio, or run `python3 tools/setup_android.py /path/to/android-sdk`.
The helper downloads from Google's official HTTPS repository and verifies each
archive against the manifest checksum. Review Android's SDK license terms before
using the SDK. Configure the SDK, Java, and debug keystore paths in Godot's Editor
Settings → Export → Android. The cloud uses Java 21 for standard APK export;
custom Gradle builds are not enabled or validated.

Do not use the development keystore for a production release. Production signing
keys belong outside the repository in a secure build pipeline.

## Validation

The headless smoke test checks deployment, raycast damage, fire-rate limiting,
elimination, wall occlusion, reload timing, pause/resume, independent multitouch
movement/fire/look, touch release, graphics modes, defeat, restart and survival.
Failures return a nonzero exit status. It is gameplay integration coverage, not
an Android hardware test. A rendered menu and arena were also checked on the
cloud's software OpenGL renderer; that renderer cannot establish phone FPS.

`build/` contains ignored local outputs. Rebuild the APK after gameplay edits.
For an attached device, use `adb install -r build/pewpew-debug.apk` and inspect
`adb logcat` for startup errors.

## Current scope and next milestones

This is a first-person training prototype with one rifle, procedural placeholder
geometry, a generated firing sound, and simple bots. It is not a production
battle royale. No multiplayer, third-person animation, second weapon, accounts,
matchmaking, anti-cheat, monetization, or store release is implemented.

1. Test on named low/mid/high Android devices, including 20-minute thermal runs,
   interruptions, screen cutouts, aspect ratios, and three-finger controls.
2. Add character animation, weapon assets, audio controls, a second weapon, and
   navigation-aware bots. Confirm first-person versus third-person direction.
3. Build authoritative 4–8-player deathmatch and validate latency/server cost.
4. Add progression, crash reporting, release signing and store compliance before
   considering larger battle royale matches.
