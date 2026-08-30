# Connor Homelab Android app

This Capacitor wrapper uses the live portal, so Supabase sessions and Cloudflare-protected links work the same way as in the browser.

## Build a self-signed APK

Install Android Studio (including the Android SDK and JDK), then from this folder run:

```text
npm install
npx cap add android
npm run sync
npm run open
```

In Android Studio choose **Build → Generate App Bundles or APKs → Generate APKs**. A debug APK is self-signed and can be installed directly on your phone. For a release APK, create an Android signing key in Android Studio and back it up securely.

The app points at `https://conhomelab.uk`, so portal updates do not require rebuilding the APK.
