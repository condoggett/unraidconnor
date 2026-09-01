# Connor Homelab - Family User Guide

Welcome to Connor Homelab. The website and mobile app are a private front door
to the family's services. You only see the services Connor has assigned to
your account. Your username and password are the only normal sign-in required
for the Homelab app and website.

## 1. Signing in

Open the Connor Homelab app, or visit `https://conhomelab.uk`. Enter the email
address and password that Connor created for you. Use **Forgot password** if
you cannot remember it. Never share an account: your account controls which
services and notifications belong to you.

The app can optionally ask for your fingerprint, face unlock, or phone PIN when
you return to it. This protects the already-signed-in app on your phone; it
does not send biometric information to Connor Homelab.

## 2. Home

The Home tab shows your assigned services, the Unraid health card, any planned
maintenance notice, and your recent Homelab activity. A green Unraid card means
the status bridge has responded. If the card says **Last known Unraid status**,
the app is showing the most recent private reading saved on your own phone
while the portal is temporarily unreachable.

Tap a service card to open it inside the app. Use the Services tab to search
everything you have access to. The Profile tab lets you choose a personal
theme, layout, icon and optional app lock.

## 3. Movies and shows (Seerr)

Open **Seerr** from Home or Services to request a film or series. Sign in to
Seerr with the separate Seerr account you were given; that account remembers
its session in the in-app service page. Requests and availability messages are
private to the matching person where Seerr can identify the requester.

The **Media** / **Now Available** view lists requests that have become
available for you. A request may take time to download and appear in Plex. If a
notification does not arrive, open the app's Activity tab; notification delivery
depends on Android notifications being allowed for Connor Homelab.

## 4. Photos, Home Assistant and other services

Immich, Home Assistant, Plex and other cards remain inside the Connor Homelab
app. Each service has its own session because it is a different application.
Do not clear the app's storage unless you are happy to sign in to those services
again. The app's Back button stays inside the service page; use the top Back
arrow to return to Connor Homelab.

Some services have their own accounts and permissions. A missing card means you
have not been granted access yet, rather than the app being broken. Ask Connor
to add the service to your Homelab account.

## 5. Notifications

Connor Homelab notifications can open the appropriate place: a Seerr request,
Home Assistant, Immich, update notes, or your notification history. Turn on
notifications in Android: **Settings → Apps → Connor Homelab → Notifications**.
Only sign in to notifications through the main app; do not paste notification
tokens or webhook addresses into a chat or public page.

## 6. Updating the Android app

From V3.4 onward the app automatically checks for a newer verified release each
time it opens. Nothing is shown when you are current. If an update is ready,
select **Download update**, wait for Android's installer, then approve the
install. Android may show an **Install anyway** confirmation because this is a
private family app, not a Play Store app. The app verifies the published SHA-256
hash before handing the APK to Android.

You can also open **Update Centre** or choose **Check for updates** manually.
If an update says it is unavailable, wait a few minutes: the GitHub release and
the website update manifest must both finish publishing.

## 7. App shortcuts

On recent Android phones, press and hold the Connor Homelab icon. You can open
Home Assistant, Seerr, Immich or Unraid directly. These shortcuts still use the
in-app page, so the normal navigation and saved sessions are retained.

## 8. Planned maintenance and problems

The maintenance banner explains planned restarts and automatically disappears
after its scheduled end. During unplanned problems, use **Diagnostics** in the
app: it separates account sign-in, the portal and the Unraid status bridge so
you can tell Connor what is unavailable.

For help, send Connor a screenshot of the error and say which service, device
and connection you were using. Do not send passwords, one-time codes, API keys
or screenshots containing them.

