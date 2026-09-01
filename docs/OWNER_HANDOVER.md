# Connor Homelab - Final Owner Handover

This is the final starting point for Connor (or a future maintainer). Read this
before changing access, deploying, moving a service or publishing an app.

## What you own

Connor Homelab is a private family service hub. It has four parts:

1. **Portal** - `https://conhomelab.uk`, deployed by Azure Static Web Apps.
2. **Identity/data** - Supabase project `yrvmanmrzxceqahopfec` for accounts,
   service access, preferences, notifications and maintenance notices.
3. **Homelab** - Unraid at `192.168.0.22`, including a protected status bridge.
4. **Mobile app** - Flutter source in `native_app/`, signed and released by
   GitHub Actions.

Cloudflare provides the public-domain/tunnel/access layer. Do not expose Unraid
Docker ports publicly just to make an app feature easier.

## Start-here files

| Need | File |
| --- | --- |
| App startup/dashboard/update logic | `native_app/lib/main.dart` |
| Family activity, media, release notes | `native_app/lib/notification_screens.dart` |
| Dashboard builder, admin access, help, maintenance | `native_app/lib/release3_screens.dart` |
| Home Assistant/Unraid native hubs | `native_app/lib/service_hubs.dart` |
| Service in-app browser | `native_app/lib/seerr_screen.dart` |
| App lock | `native_app/lib/app_lock.dart` |
| Android configuration/shortcuts | `native_app/android/app/src/main/` |
| Android release workflow | `.github/workflows/android-release.yml` |
| Database source/migrations | `supabase/` |

## What V3.7 delivers

- Personal dashboard themes, layouts, card styles, pins and hidden services.
- Saved drag-and-drop dashboard order per signed-in user on their device.
- Native Home Assistant/Unraid hubs, status cache and diagnostics.
- In-app Seerr/Immich/Home Assistant service navigation with normal web sessions.
- Family activity, Now Available, scheduled maintenance and Help & Privacy.
- Admin-only family service access manager using `user_app_access`.
- Optional device biometric/PIN app lock.
- Verified automatic APK update checks and Android home-screen shortcuts.

## Security rules that must not change casually

- Supabase RLS is the access authority. The app UI is not security by itself.
- Only admins can manage `user_app_access`; ordinary users read their own rows.
- Do not commit passwords, keys, webhook secrets, signing files or service-role
  tokens. `supabase/.temp/` is generated data and remains untracked.
- The updater must keep its HTTPS GitHub host/path allow-list and SHA-256 check.
- Do not turn a Cloudflare-protected local service into a public port.
- New database features need a new migration file, RLS review, admin test and
  ordinary-user test.

## Safe change sequence

1. Make one focused change in Android Studio/GitHub workspace.
2. Test with your account and, for access changes, an ordinary user account.
3. Increase `version:` in `native_app/pubspec.yaml`.
4. Add plain-language release notes.
5. Commit/push via GitHub Desktop.
6. Run **Build Android release** on GitHub Actions.
7. Wait for manifest deployment verification before testing the phone update.

The full click-by-click guide is
[`PUBLISH_AND_DIAGNOSE_ANDROID_RELEASES.md`](PUBLISH_AND_DIAGNOSE_ANDROID_RELEASES.md).

## Routine checks

- Open the portal and app monthly.
- Verify the Unraid status card and one normal family account.
- Keep Android/Flutter/Gradle dependencies reviewed, but do not upgrade every
  package merely because an update is available.
- Back up the Android signing key and GitHub secret values outside the repo.
- Keep Cloudflare, Azure, GitHub and Supabase account recovery methods current.

## If something breaks

1. Use the app's Connection diagnostics to identify sign-in, portal or bridge.
2. Check the newest GitHub Actions run for mobile-update failures.
3. Check Azure deployment for a portal/manifest issue.
4. Check Cloudflare tunnel/access before touching Unraid.
5. On Unraid, inspect the status bridge container logs; do not reboot blindly.
6. Preserve logs and screenshots, but redact secrets before sharing them.

## Documentation map

- `USER_GUIDE.md` - everyday family use.
- `TECHNICAL_REFERENCE.md` - architecture and engineering reference.
- `PUBLISH_AND_DIAGNOSE_ANDROID_RELEASES.md` - Android release process.
- `SEERR_NOTIFICATIONS.md` / `RELEASE_4_CONNECTORS.md` - deferred connector
  reference; webhooks are intentionally not part of the final baseline.

## Future work after handover

Do not begin with more automation. First keep the release/update workflow
healthy. The safe next enhancements are a real Android home-screen widget backed
by the status API, service-specific APIs with explicit user consent, or a
dedicated admin web console. Each requires a focused design/security review.

