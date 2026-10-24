# Colpad Android Starter ⚡

Flutter Android starter with a modern dark UI and GitHub Actions APK builds.

## Features
- Flutter stable
- Android target SDK 36 (Android 16)
- Minimum Android SDK 24
- Automatic APK build on pushes to `main`
- Manual build from GitHub Actions
- APK uploaded as a downloadable artifact

## Build APK
1. Open **Actions**.
2. Select **Build Android APK**.
3. Click **Run workflow** or push a commit to `main`.
4. After a successful run, download `colpad-android-apk` from Artifacts.

The workflow generates Android platform files with Flutter on a GitHub-hosted runner. No local Android SDK is required.

## Compatibility and release notes
- Target SDK 36 is configured for Android 16-era compatibility.
- Minimum SDK 24 means Android 7.0 or newer, subject to device compatibility.
- Test the APK on real devices before distribution.
- Configure and protect a release signing key before publishing to an app store.

Crafted by Colpad ⚡
