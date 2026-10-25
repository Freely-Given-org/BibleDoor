# Bible Door

A Flutter Bible reader from [Freely-Given.org](https://Freely-Given.org), built for
Android phones and tablets, Linux desktops, and Windows desktops. A publisher's key
opens a Bible exported by Bible Drop Box. Downloaded books work offline.

The app intentionally ships without a translation. On first launch, enter a key,
import a Bible Door ZIP, or choose a public Bible in the Library. `webbe-123-456`
and `asv-123-456` are public example keys.

## Implemented

- Key downloads over HTTPS; atomic local storage and optional publisher MD5 checks.
- Recommended format-1 BDTXT text/index pairs, with legacy ByBook JSON fallback.
- Unicode-aware indexes, ordered/localised book names, sections, introductions,
  poetry, verse bridges, missing references, footnotes, and cross-reference notes.
- Book/chapter/section navigation, pasted references, recent books and back history.
- Two reading panes, linked references/proportional scrolling or independent passages.
- Search across downloaded books, bookmarks, section copy and text selection.
- On-demand downloads, cancellable whole-Bible downloads, and transactional updates
  of already-downloaded books. Updates preserve the previous copy on failure.
- ZIP import and publisher-permitted export through Android's share sheet or the
  desktop save dialog. No broad storage permission is requested.
- Persistent reading locations and settings; serif/sans, text size, verse markers,
  optional red letters, dark/light/system appearance, basic RTL text direction.
- Privacy/help/About screens, contributor list, custom launcher icon, release signing
  configuration, automated checks and test fixtures.

Open **Settings → About Bible Door** for the installed app version and build,
links to Freely-Given.org and OET.Bible, and app information. **Privacy** is the
last item in Settings. Manage installed Bibles in **Library**: each Bible's menu
contains **About this Bible** (offline count, export date, source, headings and
sharing permissions) and **Remove from device** (with confirmation). The
**Find free Bibles** link opens the Bible Drop Box demos; each individual Bible
page has its Bible Door key near the bottom.

## Run and check

Tested toolchain: Flutter 3.47.7 / Dart 3.13.5, Android SDK 36, NDK 28.2.
Android minimum API is 24; compile/target API is 36. Java 21 is suitable for CI;
this workstation also builds with Android Studio's bundled Java 25.

```sh
flutter pub get
flutter analyze
flutter test
flutter run
# Or on Linux:
flutter run -d linux
```

`pubspec.lock` is committed for reproducibility. Do not commit signing credentials.
The optional `BIBLEDOOR_DATA_DIR` Dart define redirects storage only in debug mode.

## Install on this Ubuntu desktop

Build once, then install for your own user (no `sudo` needed):

```sh
cd /srv/FreelyGiven/BibleDoor
flutter build linux --release
python3 tool/install_linux.py
```

Find **Bible Door** in the application menu. The installer copies the complete
bundle to `~/.local/opt/bibledoor` and creates a menu launcher. Run it again after
rebuilding to update. Your downloaded Bibles and preferences are stored separately.
To try the build without installing, run
`/srv/FreelyGiven/BibleDoor/build/linux/x64/release/bundle/bibledoor`.

The Linux bundle contains the executable and its `lib` and `data` directories;
keep them together if moving it manually. This build targets this workstation's
Ubuntu version and architecture; redistribution to older distributions needs a
compatible build environment and dependency checks.

## Android release

```sh
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`.
Without `android/key.properties`, this is an **unsigned review bundle**, not an
upload-ready Play release. With the private upload key configured as described in
[the release guide](docs/RELEASE.md), the same command produces a signed bundle.
The release configuration never uses a debug key.

## Architecture and data

`lib/models` holds data types. `lib/data` handles parsing, references, downloads,
validation, local caching and packages. `AppController` coordinates reader state;
`lib/ui` contains the Flutter screens. Bible files remain unencrypted and retain
their original export structure under application support storage. Android's
sandbox prevents different apps from reading one another's private directories;
ZIP import/export is the explicit sharing route.

See [format support and deliberate limits](docs/FORMAT_SUPPORT.md),
[privacy text for publication](docs/privacy.html), and [store listing draft](docs/STORE_LISTING.md).

## Extra checks

```sh
# Real local data; pass an export directory:
dart run tool/check_exports.dart /path/to/BOS_BibleDoor_Export
# Explicit network check using public data and temporary storage:
dart run tool/smoke_download.dart webbe-123-456
# Render layout previews (Linux fonts used by this tool):
flutter test tool/render_previews.dart
# Android emulator/device smoke test:
flutter test integration_test/smoke_test.dart -d DEVICE_ID
```

The app uses the website's green/olive palette with an uncluttered reading surface.
Preview renders live in `docs/screenshots`; capture device screenshots for the
final store listing. The icon source is `assets/branding/bibledoor.svg`.

## History and licence

Bible Door began as CustomBible in 2013, with Flutter experiments in 2018 and
updated application/data specifications in 2022–2023. This is a fresh Flutter
implementation informed by those specifications and actual BibleOrgSys exports.
The earlier checkouts and website specifications were left untouched.

New application code: MIT. Noto Serif: SIL OFL 1.1. Bible translations keep their
own licences. See [LICENSE](LICENSE), [NOTICE](NOTICE), and [CONTRIBUTORS.md](CONTRIBUTORS.md).
