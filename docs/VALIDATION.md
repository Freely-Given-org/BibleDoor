# Validation record

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
