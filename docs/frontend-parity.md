# Web frontend parity and release evidence

The static DOM frontend preserves the existing `/api/v1` service and the server's SQLite training data. Native Flutter sources remain in the repository. The browser replica is IndexedDB; it bootstraps from the authoritative server dataset.

| Area | Automated evidence | Release/device review |
| --- | --- | --- |
| Today, Log, Meso and import/generation direct URLs | Production-browser route checks, real Dart API | Compare information hierarchy and navigation with the native screens |
| Offline sets and reconnect | Browser offline save, page and full browser-process restart, stable queued IDs, exactly-once server count | Terminate iOS Home Screen app with a pending set; reopen offline and reconnect |
| Concurrent tabs / lost acknowledgements | Browser shared IndexedDB queue, two tabs, accepted response loss/retry, real conflict review/discard | Two physical devices, conflict resolution and pending export |
| Progression arcs | 96 checked-in fixtures from native `applyExerciseProgression`, including short blocks and consecutive deloads | Inspect multi-set arc preview and apply behavior |
| Rep calculator | 108 Epley/Brzycki boundary fixtures | Keyboard entry, stepping and sheet presentation |
| Program editing, swaps, targets and deloads | Dart command tests; browser label/target-forward/progression persistence | Exercise/day reorder, duplicate exercises, all swap scopes, target-forward overwrite confirmation |
| Mesocycle lifecycle | Browser create/rename/duplicate/activate/delete plus Dart command tests | Length and current-week changes |
| AI jobs and import review | Server job tests; fixed AI output through browser review and real import command with acknowledgement loss | GPU generation, CSV import, advisory fixes, day/exercise review edits, saved-job resume and cancellation |
| Backups and restore | Server backup tests; browser download/inspect/restore and retained pending export | Recovery snapshot on deployment |
| Accessibility | Automated WCAG A/AA audits across five screens in both themes; keyboard dialog dismissal | VoiceOver labels, focus return, zoom, touch targets and contrast in both themes |
| Service worker updates | Same `/sw.js` URL, explicit activation, asset-cache isolation | Install previous release, update online, keep pending operations, apply explicitly, reopen offline |
| Startup and local save | Five Chromium 10 Mbps / 50 ms runs against 4,635 sets, 100 browser-side local saves, artifact sizes | Physical iPhone cold/cached runs and p95 saved-set feedback |

Run `npm run test:browser` from `frontend/` after `npm run build` with Dart available. Results and screenshots are stored under `frontend/test-results/`; CI uploads these separately from the static site. Build size estimates appear in `frontend/build/build-metrics.json`. Test artifacts are generated and ignored by Git.

No automated Chromium check establishes physical iOS behavior, actual GPU inference speed, or a Flutter performance baseline. Do not describe acceptance targets as measured results without retaining the corresponding run output.

## Final automated verification

The production build passed all 19 Chromium browser checks. Firefox 159 passed 17 checks; the Chromium CDP performance test and Chromium persistent-profile restart fixture are explicitly skipped there. Both engines exercised the real Dart API, offline queues, concurrent tabs, acknowledgement loss, conflict resolution, backup restore, program editing and storage failure handling. The full five-run history performance suite passed separately.

Dart server tests and shared calculation fixtures passed. The compiled Dart AOT bundle also started against disposable data and served both `/api/v1/health` and the production `/today` route with HTTP 200, then shut down cleanly. This exercises the native server artifact without claiming a Docker image build.

Screenshots and reports are available under `frontend/test-results/chromium`, `frontend/test-results/firefox`, `frontend/playwright-report/chromium` and `frontend/playwright-report/firefox`. Populated desktop Today and mobile Log screenshots were inspected directly.

## Recorded performance

The production build was measured with Node 24.22.3, Dart 3.14.0, Playwright 1.65.1 and Chromium 159 on the local Linux workstation. Each of five fresh browser contexts loaded the same disposable dataset: 104 weeks, 309 historical sessions and 4,635 logged sets. No CPU throttling was applied. Network emulation used 10 Mbps and 50 ms latency.

| Measurement | Median | p95 | Target |
| --- | ---: | ---: | ---: |
| Cold page readiness | 2,834 ms | 2,860 ms | <5,000 ms |
| Cached reload readiness | 518 ms | 532 ms | <2,000 ms |
| Durable local-save feedback, 100 saves | 28.23 ms | 38.76 ms | <100 ms |

Readiness requires a visible main heading and synchronized training state. Local-save timing runs inside the browser from the click event to the saved-row DOM update, after the durable queue transaction completes. Offline mode is applied to the same CDP session as network throttling and verified with a failed health fetch, zero successful command responses and an unchanged server set count. p95 uses nearest rank; for five startup samples it is the largest sample. These are local emulation results, not physical iPhone measurements.

The measured static artifact totals 801,651 bytes (about 802 kB), including fonts, icons and license files. Its JavaScript totals 214,315 bytes raw / 76,333 bytes estimated gzip; CSS totals 21,585 / 5,384 bytes. Full-font WOFF2 assets total 495,472 bytes, preserving the original fonts while reducing their original 1,427,392-byte TTF payload by 65.3%. Estimated compression of all artifacts totals 615,520 bytes gzip or 601,605 bytes Brotli.

Actual measured static responses used identity encoding. Dart's `autoCompress` applies to chunked responses; Shelf's static file responses include a content length. The gzip/Brotli figures above are build estimates rather than deployed transfer claims. A proxy can enable compression later. Startup targets passed with the actual identity responses. The initial history snapshot was approximately 1.44 MB before compression.

The checked-in [performance evidence](frontend-performance.json) preserves the summary, dataset, toolchain and limits. Raw run JSON files, the summary, offline screenshots and the optional CPU profile are generated under `frontend/test-results/`; the five-run summary is `frontend/test-results/performance/performance-summary.json`.

## Remaining environment checks

WebKit 27.2 was downloaded, but launch was blocked by missing local runtime libraries: libicu74, libxml2, libavif16, libharfbuzz-icu0, libmanette-0.2-0 and libhyphen0. CI installs browser dependencies on Ubuntu and is configured to run Chromium, Firefox and WebKit separately. The local Docker and Flutter executables are unavailable, so container and native Flutter checks were not run here. The Node frontend build and the real Dart server were exercised directly.

Physical iOS Safari/Home Screen behavior, GPU inference and a Flutter startup/memory baseline remain unmeasured. Automated accessibility checks do not replace VoiceOver and device review. No live deployment was performed.
