# Validation record

## Publishing preparation — 26 October 2026, version 1.0.2+3

Application source: commit `15db8c3` (follow-up documentation and screenshots do
not change the application binary). Android ID: `org.freelygiven.bibledoor`;
visible name: **Bible Door**. Original data folder names are preserved.

- Static analysis and formatting checks pass. All 23 app tests and the preview
  check pass. Library tests cover the demo link, all Bible metadata, and
  cancelling/confirming removal; Settings tests verify Privacy follows About
  and About no longer contains a Bible list.
- Native integration checks pass on Android 16 / API 36 and Linux. The signed
  release APK was installed, used to download WEBBE, updated with the final APK,
  and reopened with Wi-Fi and mobile data disabled; the saved Titus text loaded.
- Android AAB and APK built locally with the existing Freely-Given key. SHA-256
  certificate fingerprint:
  `7D:46:F0:39:67:D8:C0:72:87:98:7D:67:7D:03:62:E5:5E:34:9A:D4:69:83:32:81:28:49:21:07:4D:8C:45:06`.
  The keystore remains outside the repository and local credentials are ignored.
- Google bundletool 1.18.3 validates the final AAB. `jarsigner` verifies its
  signature; `apksigner` verifies the APK with the same certificate. The APK is
  labelled Bible Door, version 1.0.2 / code 3, minimum API 24, target API 36.
- All six 64-bit AAB libraries have ELF LOAD alignment of at least 16 KB, and the
  APK passes `zipalign -c -P 16 4`. Runtime verification on 16 KB hardware and
  Play pre-launch testing remain release-owner checks.
- Linux release built on Ubuntu 26.04 x86-64, packaged with libraries, data,
  licence notices and instructions. The user installation was updated; binary,
  app-library and version metadata hashes match the release bundle.
- Five unedited signed-app phone captures are under `docs/store-screenshots`;
  layout previews were also refreshed with Bible Door branding.

The Windows native check initially exposed platform-specific directory handling.
Folder detection now uses the platform-aware path library; ZIP export names
always use `/`. Repository tests also check restored keys and portable ZIP paths.
The Windows workflow runs the full test suite and the native integration check
before making its portable release ZIP. See the final workflow run at
[GitHub Actions](https://github.com/Freely-Given-org/BibleDoor/actions/runs/40247601780).
Both jobs passed: the clean Android build and the Windows build. Windows passed
all 23 app tests, its native integration check (including version display), the
release build, and packaging with the required Visual C++ runtime DLLs.

The Windows executable is built from `15db8c3`; the locally delivered ZIP also
contains the final corrected Bible Door notice text. Release files are kept in
the ignored `build/releases/` directory, with checksums in
`docs/releases/1.0.2-SHA256SUMS.txt`. Binaries and signing credentials are not
committed. Documentation-only follow-up commits do not require recompilation.

No Play Console release or GitHub release was published. Hosting the privacy
policy, completing developer/contact/Data safety/content-rating declarations,
account testing requirements, and physical-device accessibility checks remain
with the release owner. See [RELEASE.md](RELEASE.md).

## About page update — 25 October 2026, version 1.0.1+2

- `flutter analyze`: no issues.
- `flutter test test tool/render_previews.dart`: all 23 checks passed (22 app
  tests and the preview-rendering check).
- Added checks for navigating from Settings to About, reading the platform
  version/build, the empty library, both external website links and browser
  failure, Bible metadata, and cancelling/confirming removal while preserving
  other Bibles' bookmarks. The removal check uses a narrow screen, dark theme,
  and enlarged text.
- Phone and tablet About page renders inspected in `docs/screenshots/`.
- Linux release rebuilt; generated version metadata is 1.0.1, build 2. The
  existing user installation was updated using `tool/install_linux.py`.
- Android unsigned release bundle rebuilt successfully with the version-info
  dependency. Native emulator checks below describe the initial release; they
  were not repeated for this About page update.

## Initial app validation

Run on 24 October 2026 using Flutter 3.47.7 / Dart 3.13.5, Android SDK 36,
NDK 28.2, AGP 9.1.0 and the installed Android Studio JDK.

| Check | Result |
| --- | --- |
| `flutter analyze` | No issues |
| `flutter test` | 19 tests passed |
| `flutter test integration_test/smoke_test.dart -d emulator-5554` | Passed on an Android 16 / API 36 emulator |
| `flutter test tool/render_previews.dart` | Passed; phone, tablet, light/dark previews inspected |
| Local complete WEBBE export | 83 books / 1,479 sections parsed |
| Real `webbe-123-456` HTTPS download | Metadata and Titus downloaded, validated and parsed |
| `flutter build apk --debug` | Passed; normal-app APK installed and launched on the emulator |
| `flutter build appbundle --release` | Passed; unsigned review AAB, approximately 54.5 MB |
| `python3 tool/check_bundle.py ...app-release.aab` | All six 64-bit native libraries have LOAD alignment of at least 16 KB; bundle unsigned |

The Android integration check covers native temporary storage, ZIP import,
offline reading, section navigation, bookmarks, text search, dark mode,
export generation and restoring saved state. It does not interact with external
share destinations or a real SD-card provider.

The update tests verify that a checksum failure preserves the old Bible and that
a valid refresh replaces the cached text. Comparison tests verify reference
navigation from either pane and independent navigation after unlinking.

The image previews are real Flutter widget renders using the same screens as the
app. They are not captures from a physical device. Android emulator integration
uses a small synthetic fixture; real Bible text is checked separately through
unit tests, the whole-export tool and the live public-key download.

Remaining release checks: physical-device/TalkBack testing, final signed-bundle
verification, 16 KB runtime validation and the Play pre-launch report. See
[RELEASE.md](RELEASE.md). The sharing dependency pin and its future migration
warning are documented there.
