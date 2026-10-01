# macOS panel performance

## Regression

Repeatedly cycle All -> Text -> Image -> Files -> Regex -> each pinboard -> All.
Testing All -> Text alone is insufficient: a pinboard can select a record thousands
of positions into All. Carrying that selection into another tab made
`ScrollViewReader.scrollTo` materialize a large part of the lazy list.

Tab changes now start at the first item and replace the tab's scroll scope.
Refreshes within the same filter preserve item selection. Type-filter snapshots
are prepared outside the input path; searches and compound filters use immutable
snapshots with stale-result guards.

Escape immediately orders the panel out before transient cleanup. An empty
focused search field no longer consumes Escape just to lose focus. Nonempty
search, preview, multi-selection, and pinboard exit keep their existing behavior.

## Verification

On September 14, 2026, the local Developer ID build `1.10.0 (4)` was tested against
the real history (5,277 records at the final check):

- 64 targeted Tab events, eight full cycles, verified using the selected filter's
  accessibility label. Returning to All/Text no longer produced the earlier
  multi-second stalls.
- Six open/Escape cycles, each verified to close with one Escape.
- macOS universal archive and iOS Release build passed.
- Thirteen focused macOS tests passed.
- The installed build was notarized and its stapled ticket validated.

The live probe waited 120 ms between key dispatch and accessibility reads.
Those numbers include automation/IPC overhead and are not frame latency.
The first Files transition still showed a cold icon-load cost; warmed cycles did
not reproduce the earlier multi-second behavior.

## Repeatable fixture benchmark

Run:

```sh
bash scripts/benchmark-macos-panel.sh
PASTE_BENCHMARK_COUNT=50000 bash scripts/benchmark-macos-panel.sh
```

The benchmark uses a separate bundle identifier and generated content. Clipboard
monitoring, the real store, and CloudKit synchronization are not started.
It cycles through all filters, including a sparse pinboard of old records, and
prints filter, layout-submit, and hide measurements. It is not enabled in normal
release builds. Screenshots contain fixtures only and are written under `/tmp`.

Run regression tests:

```sh
LLVM_PROFILE_FILE=/tmp/paste-tests-%p.profraw xcodebuild test \
  -project Paste.xcodeproj -scheme Paste -configuration Debug \
  -destination 'platform=macOS' -only-testing:PasteTests \
  CODE_SIGNING_ALLOWED=NO
```

Do not replace an App Store review build or move a published Git tag merely to
install a local performance fix. The September 14 review submissions and GitHub
`v1.10.0` assets remain separate from this local build.
