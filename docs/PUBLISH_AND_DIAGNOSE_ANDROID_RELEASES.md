# Publish and Diagnose Android Releases

This is the exact Connor Homelab process for turning a tested app change into a
safe phone update. GitHub Actions, not the PC, signs and publishes family APKs.
Do not put the keystore, passwords, Supabase secrets or notification secrets in
Android Studio, GitHub Desktop or the repository.

## Before you begin

Open the repository in GitHub Desktop and open this folder in Android Studio:

```text
C:\Users\conno\OneDrive\Documents\GitHub\unraidconnor\native_app
```

Test the change on your phone if possible. In Android Studio Terminal run:

```powershell
C:\Flutter\flutter\bin\flutter.bat pub get
C:\Flutter\flutter\bin\flutter.bat analyze
```

New errors caused by your change must be fixed. Existing `info` suggestions are
not normally release blockers, but do not ignore an error just because there
are also harmless-looking package update messages.

## 1. Change the version

Open `native_app/pubspec.yaml` and find the single `version:` line. Change both
parts. For example, after `3.4.1+29` use:

```yaml
version: 3.5.0+30
```

`3.5.0` is what people see. `30` is Android's internal version code and must
always increase. Android will not install an APK with the same/lower code over
the current app, even if the visible version name is different.

Also add a short item at the top of `ReleaseNotesScreen` in
`native_app/lib/notification_screens.dart`. Write ordinary-language notes for
the family, not development notes.

## 2. Commit with GitHub Desktop

1. Return to GitHub Desktop and select **unraidconnor**.
2. Check the changed file list. It should contain source, documentation and
   `pubspec.lock` where dependencies changed.
3. Do **not** include `native_app/build`, downloaded APK files, `.jks` keystore
   files, `.temp`, passwords, API keys, SQL editor exports or local logs.
4. Enter a clear summary, for example `Add V3.5 dashboard cards`.
5. Click **Commit to main**, then **Push origin**.

If Desktop says a lock file exists, close any other Git terminal or GitHub
Desktop operation first. Only then remove the exact `.git/index.lock` inside
this repository. Never delete a broad folder or use reset/checkout commands to
solve a lock.

## 3. Start the signed build

1. Open `https://github.com/condoggett/unraidconnor/actions`.
2. Select **Build Android release**.
3. Click **Run workflow**.
4. Leave branch as `main`, then click the green **Run workflow** button.
5. Open the new run and wait for every step to finish green.

The pipeline: checks out code, restores the encrypted signing key, builds the
release APK, calculates SHA-256, commits `app-update.json`, publishes the
GitHub Release, deploys the manifest through Azure, sends the update
notification, and saves the APK artifact.

## 4. Verify the release

Do not test until **Deploy and verify the update manifest** is green. Then:

1. Open Connor Homelab on the phone, or reopen it for the automatic check.
2. Confirm the V3.5 release notes/update dialog appear.
3. Choose **Download update**.
4. Wait for the security check and Android's installer confirmation.
5. After installation, open the app and confirm the version in Update Centre.

## 5. Diagnose failures

| Symptom | Likely cause | Safe response |
| --- | --- | --- |
| `storeFile` / keystore error | Missing or malformed GitHub signing secret. | Check encrypted secret names/values; never commit a keystore. |
| Android resource linking error | Invalid XML/resource reference. | Read the exact filename/line in the Actions log; correct source, then make a new version. |
| Flutter/Dart error | App source or package API mismatch. | Open the referenced file/line in Android Studio, run `flutter analyze`, fix and retest. |
| `pub get` package issue | Dependency constraint/cache issue. | Run `flutter pub get`; use the compatible package version, do not edit cache contents. |
| Git lock file | GitHub Desktop/another Git process still active. | Close the active operation, then remove only the confirmed `index.lock`. |
| Phone says update unavailable / 404 | Azure has not deployed the new manifest yet. | Wait for the Azure verification step; check the GitHub release asset and `app-update.json`. |
| Security check failed | APK hash or trusted release URL does not match. | Stop and inspect workflow output. Never disable hash validation. |
| App not installed | Version code too low or different signing key. | Increase build code; confirm GitHub uses the established signing secrets. |
| Notification did not arrive | Final workflow notification step/Android permission issue. | Check Actions final step, then Android notification permission and device registration. |

## 6. What to send when asking for help

Send the Actions run link and the full failed step text. Include the app version
you tried to publish and whether an APK/GitHub release was already created.
For phone problems, include a screenshot of the exact message and the installed
version. Never include passwords, keys, one-time codes, Authorization headers
or the contents of secret files.

## 7. Recovery rules

Never rerun a failed build blindly if it reached manifest or GitHub Release
publication. First confirm whether `vX.Y.Z` exists under GitHub Releases. If it
does, fix the source, increase the version and code, commit, push and start a
new run. This prevents an old manifest/asset from being mistaken for the new
build.

## 8. Website-only changes

For a change to the portal only, edit root web files, commit and push through
GitHub Desktop. Azure deploys automatically. Do not run the Android release
workflow unless the Flutter app has changed or you intentionally want a new APK.

