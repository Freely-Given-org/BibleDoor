# Bible Door format support

Implementation references:

- [App specification](https://Freely-Given.org/Software/BibleDoor/BDAppSpecs.html)
- [Data specification](https://Freely-Given.org/Software/BibleDoor/BDDataSpecs.html)
- Local BibleOrgSys `BibleWriter._toBibleDoorText` implementation and real exports.

## Supported now

| Data | Behaviour |
| --- | --- |
| `BDHeader.json` | Format 1; name and abbreviation required; unknown fields retained |
| `BDBookNames.1.json` | Original order, local names, arbitrary three-character BOS codes |
| `BDDivisionNames.1.json` | Optional division labels |
| `BDChecksums.1.json` | Optional MD5 integrity checks; relative paths or basenames |
| `ByBook.1.BDTXT/BBB.1.bd.txt` + `.idx` | Preferred; sections sliced using Unicode code points as the Python exporter does |
| `ByBook.1.JSON/BBB.1.json` | Fallback when text/index endpoints are absent |
| Introductions and end matters | Available from the book/section picker, including FRT and appendix books |
| Paragraphs and poetry | Continuous paragraph reading; indented poetry/list lines |
| Inline styles | Added/italic/emphasised/book/quoted text, bold and marked words of Jesus |
| `\\w` word metadata | Display word text; suppress attributes |
| Footnotes and cross references | Preserve note content; accessible in section notes |
| References | Local book name/abbreviation/BOS code plus chapter and optional verse; verse ranges accepted at start |
| Packages | ZIP with metadata and BDTXT pairs/ByBook JSON; one optional enclosing folder |

The source does not depend on a fixed 66-book canon. The local WEBBE export test
parsed 83 books, including its additional books and front matter. Real Titus text
and JSON fixtures verify all 46 verse markers. Missing verse references resolve
to the containing or nearest preceding section; no missing text is invented.

## Current limits

- UI language is English. Book names come from the translation. RTL direction is
  inferred from section text, but broad Hebrew/Arabic device validation remains.
- Linked panes navigate by the same book/chapter/verse and scroll proportionally.
  There is no versification mapping or exact word/verse scroll alignment between
  translations of different lengths. Unlink to read independent passages.
- A pasted verse jumps to its paragraph. The header and restored reading location
  track the first visible paragraph's verse, not the exact line within it.
- Cross-reference navigation recognises references using the loaded Bible's own
  names/codes; unrecognised abbreviations open the passage picker for manual selection.
- Notes remain readable even when their internal styling is not recognised.
  Unknown inline USFM markers are stripped while their text is retained. This is
  not a complete USFM/ESFM renderer; complex tables and embedded figures are not rendered.
- Maps, linked glossary entries, external media, compressed HTML, per-chapter JSON,
  `.bz2` bulk packages, lexicon/morphology lookup, alternate divine-name wording,
  cloud sync and cloud notes are future work. Some were explicitly later milestones
  in the original specification.
- Downloads run while the app is active. Stopping finishes the current book. OS
  suspension may stop an unfinished request; completed books remain available and
  downloading again resumes by skipping cached books. No background service is used.
- Imports are local copies: they never silently use the original owner's key to
  fetch additional books. Ask for a fuller package if a book is missing.
- The filesystem cache is private to this app on Android. Sharing uses explicit
  export/import, in line with scoped storage. Export includes downloaded books only.
- ZIP input is limited to 32 MB compressed, 160 MB declared expanded, 1,000 entries,
  and 32 MB per file. Symlinks, traversal, duplicates and checksum/CRC failures are rejected.
- Key links provide access, not encryption or authentication. A recipient can copy
  unencrypted data. The app does not present key codes as a confidentiality guarantee.

## Validation tools

`flutter test` covers parser/reference handling, offline cache, failing installs,
sharing rules, unsafe imports, state restoration, and phone/tablet widgets.
`tool/check_exports.dart` validates a complete local export.
`tool/smoke_download.dart` performs an explicit HTTPS public-key download.
`integration_test/smoke_test.dart` exercises the app with Android's real local storage.
