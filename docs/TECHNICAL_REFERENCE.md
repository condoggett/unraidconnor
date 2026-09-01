# Connor Homelab - Technical Reference

This is the maintained engineering guide for the Connor Homelab website, API,
Supabase data, Unraid status bridge, Flutter app and release pipeline. It is
written so a future change can be made safely without rediscovering the setup.
Secrets are deliberately named but never recorded here.

## 1. System map

`conhomelab.uk` is the public static portal. Azure Static Web Apps deploys the
repository's root website and Azure Functions in `api/`. The native Flutter app
in `native_app/` uses Supabase for account data and its private dashboard. It
also reads the portal's `/api/status` endpoint for Unraid health. GitHub Actions
builds, signs and releases Android APKs, updates `app-update.json`, asks Azure
to publish it, then notifies app users.

## 2. Repository map

| Location | Responsibility |
| --- | --- |
| `index.html`, `manifest.json`, `sw.js` | Website/PWA shell. |
| `api/src/functions/status.js` | Azure endpoint that protects and relays Unraid status. |
| `status-bridge/` | Small Docker service running on Unraid port 9100. |
| `supabase/` | Schema and deliberately versioned SQL migrations. |
| `native_app/lib/` | Flutter application source. |
| `.github/workflows/android-release.yml` | Signed Android release, manifest, deployment and notification pipeline. |
| `docs/` | Maintained operator, connector and user documentation. |

## 3. Trust boundaries

The public internet reaches the portal, not Unraid directly. Cloudflare protects
the domain/tunnel layer; Azure serves the portal/API; Supabase authenticates the
family app; Unraid remains on `192.168.0.22`. Never expose the bridge's `9100`
port to the internet. The status token, Supabase service-role key, Android
signing material and notification webhook secret must only be stored in their
approved secret stores.

## 4. Identity and permissions

Supabase Auth is the primary Connor Homelab sign-in. `profiles` identifies the
member and role; `user_app_access` determines ordinary-user service cards;
admins see the full permitted management set. Row-level security is mandatory:
a member must only read or update their own preferences, profile details,
devices and notification records. Do not replace the limited `update_my_profile`
RPC with a broad profiles update policy.

## 5. Website operation

Edit root web files for a website-only change. In GitHub Desktop: review,
commit to `main`, then **Push origin**. Azure Static Web Apps deploys it. Test
`https://conhomelab.uk` and `https://conhomelab.uk/api/status` after deployment.
Do not add API tokens to JavaScript, HTML, committed configuration, browser
local storage, or a GitHub issue.

## 6. Flutter application entry point

`native_app/lib/main.dart` owns Flutter startup, Firebase notifications,
Supabase initialization, the authentication gate, dashboard data, secure APK
checks, notification routing and app-link routing. It is intentionally the
central coordinator. Keep service-specific widgets in their own files instead
of turning `main.dart` into a service implementation file.

## 7. Screen source map

| File | Main responsibility |
| --- | --- |
| `main.dart` | Session, dashboard, status cache, release update flow. |
| `notification_screens.dart` | History, Now Available and release notes. |
| `navigation_screens.dart` | Services catalogue and family welcome guide. |
| `service_hubs.dart` | Home Assistant and Unraid hub views. |
| `seerr_screen.dart` | In-app authenticated web service shell. |
| `release3_screens.dart` | Profile, maintenance, diagnostics and Immich cards. |
| `app_lock.dart` | Local biometric/device-PIN lock. |

## 8. Service sessions and in-app browsing

`HomelabWebAppScreen` is the embedded browser wrapper. It is used so browser
back navigation remains within the app and normal web cookies can persist. Each
service is still responsible for its own account session. Never try to copy a
password from Supabase into Seerr, Immich or Home Assistant: that would weaken
security and is not a supported single-sign-on design.

## 9. Android app links and shortcuts

Android static shortcuts are declared in
`native_app/android/app/src/main/res/xml/shortcuts.xml`; the manifest accepts
`conhomelab://service/<name>`. Flutter's `app_links` package translates those
links into the same internal routes used by notifications. Add a new shortcut
only when its service URL is stable, it is assigned through the app, and there
is a safe `_openNotificationRoute` destination for it.

## 10. Offline status cache

On a successful `/api/status` response, the app stores the status plus a UTC
timestamp in `shared_preferences`, scoped to the signed-in user ID. If the live
portal check fails, that snapshot is labelled **Last known Unraid status**. It
is not a claim that Unraid is currently online. Do not cache passwords, tokens,
or private service page content in this store.

## 11. Update manifest and validation

`app-update.json` contains the visible version, monotonically increasing
`versionCode`, GitHub download URL, SHA-256 hash and release notes. The app
uses a cache-busting URL, allows only the expected GitHub release path over
HTTPS, and compares the downloaded APK's SHA-256 before asking Android to
install. Never relax the host/path/hash checks merely to fix a failed update.

## 12. Automatic update checks

Dashboard startup calls `_checkForUpdates(quiet: true)` once per dashboard
session. The manual button calls the same method without `quiet`. A current or
unreachable release does not show a launch message. A new signed release shows
the same normal update dialog. Keep this behaviour: launch checks should be
helpful without annoying users.

## 13. Versioning

Change `native_app/pubspec.yaml` before every Android release:

```yaml
version: 3.4.1+29
```

The first value is the user-visible semantic version. The number after `+` is
Android `versionCode` and must be higher than every published build. A failed
build that never published an APK can normally reuse the code; if it published
anything, increase it to avoid update ambiguity.

## 14. Local development and testing

Open `C:\Users\conno\OneDrive\Documents\GitHub\unraidconnor\native_app` in
Android Studio. Use the green Run button with a connected phone/emulator for a
debug build. Before committing run:

```powershell
C:\Flutter\flutter\bin\flutter.bat pub get
C:\Flutter\flutter\bin\flutter.bat analyze
C:\Flutter\flutter\bin\flutter.bat build apk --debug
```

Style-only `info` output should be recorded and cleaned when convenient; errors
or warnings caused by your change must be fixed before release.

## 15. Standard Android release process

1. Make and test a focused change.
2. Increase the version and update `ReleaseNotesScreen`.
3. Commit source in GitHub Desktop; never add `build/`, APKs, keystores or
   `.temp/` folders.
4. Push `main`.
5. In GitHub Actions run **Build Android release** on `main`.
6. Wait for all workflow steps: build, sign, manifest, GitHub release, Azure
   deploy/verify, notification.
7. Open the app and verify the manifest finds the new update.

## 16. GitHub Actions secret inventory

The workflow uses encrypted GitHub secrets for Android signing, the Supabase
notification endpoint/authorization, and any deployment credentials. Inspect
secret *names* in repository settings only; never print their values in a log.
If signing fails with `storeFile` or keystore errors, fix the secret setup, not
the app by committing a key file.

## 17. Release troubleshooting

If an update returns 404, wait for the Azure verification step, then inspect
the manifest URL and GitHub release asset. If Android says the app cannot be
installed, confirm `versionCode` is greater than the installed build and that
the APK was signed with the same key. If hash verification fails, stop: inspect
the release workflow, do not disable the verification code.

## 18. Supabase migrations

Use a new named SQL file for every schema change. Review RLS, signed-in user
ownership and admin checks before running it once in Supabase SQL Editor.
Commit the SQL source with the app change. Test with one admin and one ordinary
family account. Existing live migrations, including `release3-and-4.sql`, are
historical records and must not be casually rerun.

## 19. Notifications

The app registers its Firebase token in `user_devices`. Supabase notification
data and the `send-notification` edge function deliver targeted push messages.
Notification data includes category/service for routing, never a password. Seerr
maps requester email to a Homelab profile where possible; admin-only pending
events go to administrators. Later V3.5 connector work must preserve this
person-scoped model.

## 20. Unraid status bridge

The Docker bridge source is `status-bridge/server.js` and is persisted under
`/boot/config/plugins/unraid-status-bridge` on Unraid. It exposes protected
health/container data locally; Azure's status function relays only the safe
dashboard subset. Use `--restart unless-stopped` so the bridge returns after a
reboot. See `status-bridge/HEALTH_MONITOR.md` for the monitoring helper.

## 21. Home Assistant and maintenance

Home Assistant configuration lives in `home-assistant/homelab_notifications.yaml`.
Maintenance notices are database-backed. Administrators can schedule start and
end times; the app refreshes the banner every minute while open. Do not use a
Windows task just to hide a banner—time-window logic already does that.

## 22. Scheduled tasks

The only intentional Windows task is **Connor Homelab Publish Release**, run
on demand. Old repeaters were removed because they could collide with Git and
create lock files. GitHub Actions is now the authority for signing, publishing,
Azure deployment and notifications. If a lock appears, first ensure no GitHub
Desktop operation is running; remove only the exact repository lock after that
process has stopped.

## 23. Security checklist for every change

- No credentials or webhook secrets in commits, screenshots or documentation.
- No new public ports to Unraid.
- RLS and user identity reviewed for every new table/function.
- Update verification remains enabled.
- Ordinary user tested separately from admin.
- Service links use HTTPS and remain behind the existing access layer.

## 24. Documentation maintenance

Update `docs/USER_GUIDE.md` when an everyday user flow changes. Update this
reference when a file, release step, security boundary, database table or
operational process changes. Add a short release-note entry to the app at the
same time. V3.4.1 is the baseline documentation/comment release; future work
should extend it instead of starting another unlinked guide.

For the click-by-click APK workflow and failure table, see
[`PUBLISH_AND_DIAGNOSE_ANDROID_RELEASES.md`](PUBLISH_AND_DIAGNOSE_ANDROID_RELEASES.md).
