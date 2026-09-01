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

## Full release guide: Android Studio → GitHub → Azure

This is the normal, repeatable process for publishing an update. The release
workflow signs the APK on GitHub, so do **not** add the signing key or its
passwords to Android Studio, the repository, or any document.

### 1. Open and change the app

Open this folder in Android Studio:

```text
C:\Users\conno\OneDrive\Documents\GitHub\unraidconnor\native_app
```

The main places to look are:

| File | What it controls |
| --- | --- |
| `lib/main.dart` | Sign-in, the main dashboard, update checking and app navigation. |
| `lib/notification_screens.dart` | Notification history, Now Available and release notes. |
| `lib/service_hubs.dart` | Home Assistant and Unraid in-app hub screens. |
| `lib/seerr_screen.dart` | The protected in-app browser used for Homelab services. |
| `lib/release3_screens.dart` | V3 profiles, maintenance centre, personal activity and Immich highlights. |
| `lib/app_lock.dart` | Optional Android fingerprint, face, or device-PIN app lock. |
| `pubspec.yaml` | App version and package dependencies. |
| `../supabase/release3-and-4.sql` | V3 data migration: personal settings, maintenance notices and user-safe profile updates. |

Run the app on your phone or emulator with the green **Run** button. Before
publishing, open Android Studio's Terminal and run:

```powershell
C:\Flutter\flutter\bin\flutter.bat analyze
```

Fix any errors shown before continuing.

### 2. Increase the version

In `pubspec.yaml`, increase both parts of the version. For example:

```yaml
version: 2.6.1+20
```

`2.6.1` is the version people see. `20` is Android's internal version code and
must be higher than every previous release. Never reuse a published version or
version code.

### 3. Commit and push with GitHub Desktop

Open GitHub Desktop and select the `unraidconnor` repository.

1. Review the changed files.
2. Enter a clear summary, such as `Add family theme choices`.
3. Click **Commit to main**.
4. Click **Push origin**.

Do not commit generated folders such as `native_app/build`, an APK, a signing
key, passwords, Supabase service-role keys, or notification secrets.

### 4. Build the signed release on GitHub

1. Open `https://github.com/condoggett/unraidconnor/actions`.
2. Choose **Build Android release**.
3. Click **Run workflow**, leave branch as `main`, then click **Run workflow**
   again.
4. Wait for the workflow to show a green tick.

The workflow builds and signs the APK using encrypted GitHub secrets, creates
the GitHub Release, calculates the APK SHA-256 security hash, and writes
`app-update.json`.

### 5. Azure deployment and phone update

The same workflow asks the Azure Static Web Apps workflow to deploy the new
`app-update.json` file. It waits for that deployment before sending the app
update notification, avoiding the old situation where a notification arrived
before the update was actually available.

On the phone, open **Connor Homelab** and choose **Check for updates**. The
app verifies that the downloaded APK is from the Connor Homelab GitHub release
and matches the published SHA-256 hash before Android shows the install prompt.

### Website-only changes

For a website-only change, edit the root `index.html` file, commit it in
GitHub Desktop and click **Push origin**. Azure Static Web Apps deploys site
changes automatically. No Android build is needed.

## V3 profile and maintenance database guide

V3 stores a person's theme, dashboard layout, profile icon and app-lock choice
in Supabase. It also stores maintenance notices. The migration has already been
run on the live project, so it must **not** be rerun unless the SQL file is
changed deliberately.

The source of truth is:

```text
supabase\release3-and-4.sql
```

If a future migration is needed:

1. Create a new, clearly named SQL file rather than editing a migration that is
   already live.
2. Review it carefully: it must enable RLS and grant each member access only to
   their own settings. Admin-only tables must use `public.is_admin()`.
3. Run it once in **Supabase → SQL Editor** while signed into project
   `yrvmanmrzxceqahopfec`.
4. Keep API keys, service-role keys, passwords and notification secrets out of
   the SQL file and Git history.
5. Test with both an ordinary family account and an admin account.

The `update_my_profile` RPC is intentionally limited to the signed-in person's
display name. Do not replace it with a broad profile update policy; that could
let a member change their role or another security-related column.

## Current scheduled publishing setup

Only one Windows Task Scheduler task is intentionally kept:

| Task | Purpose | How it runs |
| --- | --- | --- |
| `Connor Homelab Publish Release` | Publishes a completed local Android release when you intentionally run it. | Manual / on-demand only. |

The old repeating preparation and finaliser tasks were removed because GitHub
Actions now reliably builds, signs, publishes and deploys the update manifest
in one workflow. Do not recreate polling tasks; they can collide with a build
or leave a Git lock file behind.

## V3 feature map

- **My profile** — name, icon, personal theme, dashboard layout, and app lock.
- **Maintenance centre** — active family notices; admins can create a banner.
- **Latest for you** — personal activity cards on the home screen.
- **Now Available** — your available requested media, based on private
  notification history.
- **App lock** — uses Android's own biometric or device-PIN prompt; biometric
  data never leaves the phone.

Service webhooks and connector setup are intentionally deferred to **V3.5**.

### If a GitHub Actions release fails

Open the failed run in **Actions**, select the failed step, and copy its error
into Codex. Do not keep rerunning a failed workflow without changing the cause:
reruns can overwrite a release asset while keeping the same version number.
Fix the source, increase the version if the failed run got as far as publishing
anything, then commit, push and run a new release.

## Release roadmap

- **1.2** — Seerr is first for assigned family accounts.
- **1.3** — per-user themes, dashboards, favourite services, and layout.
