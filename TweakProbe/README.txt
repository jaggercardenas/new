QuickWheelProbe - LiveContainer diagnostic tweak

This is a custom standalone iPhone ARM64 dynamic library built for LiveContainer.
What it should do:
  - Show a black and green "TWEAK ACTIVE" panel inside QuickWheel
  - Show approximate FPS and battery level
  - Drag the panel around; tap to switch compact/full
  - No network access, jailbreak, private APIs or JIT needed.

Install:
1. Extract QuickWheelProbe.dylib from ZIP.
2. In LiveContainer > Tweaks, tap + > New Folder. Name it QWTest.
3. Open QWTest and import QuickWheelProbe.dylib (keep it separate from FPSOverlay).
4. In LiveContainer > Apps, long-press QuickWheel > Settings.
5. Set Tweak Folder to QWTest (not FPS).
6. Verify "Don't Inject TweakLoader" is OFF, and keep Launch with JIT OFF.
7. Return to Tweaks, tap Sign if available; LiveContainer can also sign automatically.
8. Close and relaunch QuickWheel from LiveContainer.

If the green "TWEAK ACTIVE" panel appears, injection is working!
It should appear on top of any QuickWheel screen, including the launcher.
FPS counts CADisplayLink refresh callbacks; it is not a benchmark of camera or GPU output.

If it doesn't show:
- Check the chosen folder and confirm the tweak's switch is enabled.
- Tap Sign under Tweaks; relaunch from LiveContainer (not the iPhone Home Screen).
- Check LiveContainer Settings > JIT-less signing/diagnostics, if available.
- Keep the older FPSOverlay disabled while isolating the issue.
- Tell ChatGPT whether QuickWheel opens, crashes, or opens without the panel.
- Try a force re-sign of QuickWheel if needed.

Source:
https://github.com/jaggercardenas/new/blob/main/TweakProbe/QuickWheelProbe.m

This only operates INSIDE LiveContainer-hosted apps, not systemwide.
It cannot remap the Camera Control button outside QuickWheel.
Device behavior and injection not yet verified.
