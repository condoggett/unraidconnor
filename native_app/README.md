# Connor Homelab mobile app

The native Flutter app for Android and iPhone. It signs in with the existing
Supabase account, displays only the services assigned to the signed-in person,
shows Unraid availability, and opens protected Homelab services.

## Open it in Android Studio

1. Open **Android Studio**.
2. Choose **Open** and select this `native_app` folder.
3. Wait for the Gradle sync at the bottom to finish.
4. Connect an Android phone with USB debugging enabled, or start an emulator.
5. Select that device from the top bar and press the green **Run** triangle.

For a shareable test APK, run the following in the Android Studio terminal:

```powershell
C:\Flutter\flutter\bin\flutter.bat build apk --debug
```

The output is `build\app\outputs\flutter-apk\app-debug.apk`. The `build`
folder is generated and deliberately excluded from Git. Use a release signing
key before distributing the app beyond personal testing.

## Release roadmap

- **1.2** — Seerr is first for assigned family accounts.
- **1.3** — per-user themes, dashboards, favourite services, and layout.

