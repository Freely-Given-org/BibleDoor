# Release guide

Bible Door is prepared as `org.freelygiven.bibledoor`, version `1.0.2+3`.
Confirm this is the intended new Play application ID before the first upload;
updating an existing listing would require its existing ID and signing arrangement.
Nothing in this repository creates a Play listing or publishes a release.

## Build and sign

1. Use Flutter 3.47.7 stable, Android platform 36, and the SDK/NDK selected by the
   project. Run `flutter doctor -v`, `flutter pub get`, `flutter analyze`, and
   `flutter test`.
2. Use the existing Freely-Given upload key for this release. Its certificate is
   2048-bit RSA with SHA256withRSA and expires on 31 March 2114. The original
   keystore remains outside the repository. For a different deployment, create
   and securely back up your own upload key, or use the existing upload key
   for the intended listing. Example (prompts for passwords; do not put them in shell history):

   ```sh
   keytool -genkeypair -v -keystore /secure/path/bibledoor-upload.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

3. Run `python3 tool/configure_signing.py /secure/path/to/keystore --alias key`.
   It prompts for the password without echoing it and creates a mode-0600,
   Git-ignored `android/key.properties`. Add `--different-key-password` if needed.
   Alternatively use `android/key.properties.example`. Never pass passwords in
   command-line arguments, workflow files, or committed configuration.
4. Run `flutter build appbundle --release`. Output:
   `build/app/outputs/bundle/release/app-release.aab`.
5. Check the bundle with `jarsigner -verify -verbose -certs PATH_TO_AAB` and ensure
   it uses the intended upload certificate. If `key.properties` was absent, the
   bundle is deliberately **unsigned** and cannot be submitted as a signed release.
6. Enrol in Play App Signing when configuring the Play application. For later
   updates, increase the build number after `+` in `pubspec.yaml`.

References: [Flutter Android release](https://docs.flutter.dev/deployment/android),
[Android app signing](https://developer.android.com/studio/publish/app-signing).

## Play requirements and owner-supplied information

Checked against official documentation on 26 October 2026:

- Compile/target API is **36**, satisfying the current phone/tablet target API
  requirement. Recheck the requirement at submission time.
  [Target API policy](https://support.google.com/googleplay/android-developer/answer/11926878)
- Verify **16 KB memory-page support** for the final signed bundle in Play Console
  and on a suitable Android test image. The build uses modern Flutter and NDK 28.2;
  check every native library again after dependency upgrades.
  [Android 16 KB guidance](https://developer.android.com/guide/practices/page-sizes)
- Publish `docs/privacy.html` at a stable, public HTTPS URL, set the real privacy
  contact, and provide that URL in Play Console. Review the server's actual log
  practices, retention and third-party hosting before finalising the policy and
  Data safety declaration. Do not infer “no data collected” only from the absence
  of analytics: key downloads necessarily contact the server with an IP address.
- Supply the actual developer contact details, target audience, content rating,
  app-access instructions, country availability and any account verification
  requested by Play Console. App has no ads, login or purchases.
- For reviewer access, give the public key `webbe-123-456` and explain that the
  Library's World English Bible option downloads it without an account.
- Use the listing draft, the 512×512 icon, and a 1024×500 feature graphic under
  `assets/branding`. Capture final screenshots from the signed app on phones and
  tablets. The widget renders under `docs/screenshots` are layout-review previews.
  [Store asset guidance](https://support.google.com/googleplay/android-developer/answer/9866151)
- Complete the testing track requirements attached to the developer account.
  New personal accounts may require 12 continuously opted-in testers for 14 days
  before applying for production access.
  [Testing policy](https://support.google.com/googleplay/android-developer/answer/14151465)

## Dependency note

`share_plus` is pinned to 12.0.2, which builds and passed the Android emulator
smoke test with this toolchain. Version 13.3.1 failed Kotlin compilation with an
unresolved `SharePlusPendingIntent`; it was not retained. Flutter emits a future
built-in-Kotlin migration warning for 12.0.2. Re-evaluate the pin when upgrading
Flutter/AGP, and retest Android file sharing before release.

`package_info_plus` uses the compatible 9.0.1 series to display the installed app
version on Android and Linux. Its 10.2.2 release requires a newer `win32` major
version than the sharing dependency permits. The same future built-in Kotlin
migration warning applies to this package; update the two dependencies together
when their Android build compatibility is resolved.

## Device acceptance checks before production

Test the signed build on at least one physical phone and tablet:

- First launch, key entry (including a bad key), successful public download.
- Airplane-mode restart, reading downloaded content, and a clear error for an
  uncached book; resume after connectivity returns.
- Background/resume during a download; cancel and restart whole-Bible downloads.
- Book/chapter/section navigation, merged/missing verses, back history, bookmarks,
  notes, search and selection/copy; verify representative non-English translations.
- Two panes in portrait/landscape, tablet layout, system dark mode, large text,
  TalkBack, RTL text, and any chosen translation's special layout.
- The Android file chooser and share sheet with a permitted ZIP; restricted Bibles
  must not offer export. Imported incomplete packages must report missing books.
- An updated translation with both a successful download and an interrupted one.
- Play pre-launch report, crash/ANR findings, signing, target API, page-size checks,
  and current content-policy review.

Keep upload credentials and the developer-account declarations outside source
control. The source/build work is complete independently of these owner steps.

## Desktop builds

On this workstation the Android SDK is `/mnt/SSDs/Android_SDK/`. This is a local
tool setting and is deliberately excluded from source control.

Linux: run `flutter build linux --release`, then `python3 tool/package_linux.py`.
The complete redistributable bundle is written to
`build/releases/Bible-Door-1.0.2-linux-x64.tar.gz`. Run
`python3 tool/install_linux.py` to update the user-local application menu install.

Windows requires a Windows host with Visual Studio C++ tools. The **Build and
check Bible Door** GitHub Actions workflow runs a native integration test, builds
the release, and packages all Flutter/plugin DLLs, data, and the application-local
Visual C++ runtime into `Bible-Door-1.0.2-windows-x64.zip`. Download the
`bible-door-windows-x64` workflow artifact. On Windows, the equivalent commands are
`flutter build windows --release` and `./tool/package_windows.ps1`.
The ZIP is a portable desktop app, not a Microsoft Store submission; Windows
Authenticode signing needs a separate code-signing certificate. No Android
signing credentials are sent to GitHub Actions. Its Android bundle is explicitly
an unsigned build check; the Play upload bundle is signed locally.

See [Flutter Windows distribution](https://docs.flutter.dev/platform-integration/windows/building).
