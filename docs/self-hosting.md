# Self-hosting Strength Guru

The SvelteKit static web app and Dart API share one origin. The browser renders semantic HTML. Training data lives in SQLite on the server; the browser keeps an IndexedDB replica and a durable queue for offline set logging. Program editing and AI require connectivity. There is one private training profile and no application login: restrict access with your existing VPN/proxy.

## Start

Requirements: Linux x86-64 and Docker Engine with Compose. The default setup runs workout tracking with AI disabled.

```sh
cp .env.example .env
# Edit APP_ORIGIN to match your private HTTPS URL, without a trailing slash.
docker compose up --pull always -d
docker compose logs -f app
```

Forward your private HTTPS origin to `http://127.0.0.1:8080`. Only this loopback port is published; inference has no published port. If your proxy is itself containerized, connect it to the app's Docker network and forward to `app:8080`. Keep that network private. Retain the same hostname: browser data and its offline queue are scoped to the origin.

The proxy must preserve the app's security and cache headers. Keep `/api/v1` and the web frontend on the same origin. The Dart static handler serves `index.html` for extensionless app routes, while missing compiled assets and unknown `/api/` URLs remain 404. Disable buffering/compression for `/api/v1/jobs/*/events`; allow at least a 10-minute stream timeout. Allow backup uploads up to 64 MiB. Terminate trusted HTTPS even on the VPN: service workers and persistent browser features require a secure origin.

On iPhone, open the private HTTPS URL in Safari and use **Share → Add to Home Screen**. Open it online once and allow the application cache to finish installing before relying on offline startup. The first visit requires the server. Later launches render cached data immediately and synchronize in the background. iOS may remove website data; the server remains the durable copy of synchronized records.

## Import and backup

Export a SQLite backup from a legacy native app that supports schema v8. In the web app's About sheet choose Restore, select the file, review the program/session/set counts, then confirm. Schema v8 is supported. Older backups must first be opened and re-exported with a legacy version that supports schema v8.

Restore preserves training IDs, set targets, ordering and history, discards obsolete AI settings, and saves a recovery snapshot in `/data/backups` before replacing data. It changes the dataset generation. Other devices with pending edits retain those edits for export rather than applying them to the restored database.

Backup synchronizes the current browser first and refuses to export while it has pending edits. A server backup contains synchronized records; unsynchronized edits on other devices remain on those devices. Use the sync status strip to export pending changes as JSON, retry syncing, or resolve conflicts. “Keep my edit” explicitly overwrites a conflicting current version; “Use server version” discards that local operation after confirmation. Deleted references and dataset replacements may require exporting and discarding the retained operation.

Copy recovery snapshots off the server periodically. Stop the app before copying the entire training volume manually, or use the application backup endpoint for a consistent live snapshot. Do not copy only an active SQLite file while ignoring its WAL.

## AI and GPU checks

To enable AI, install an NVIDIA driver and configure NVIDIA Container Toolkit for Docker. The inference configuration targets an RTX 2070 with 8 GB VRAM.

```sh
docker compose -f compose.yaml -f compose.inference.yaml up --pull always -d
docker compose -f compose.yaml -f compose.inference.yaml logs -f app inference model-download
```

The first AI startup downloads the pinned 2.54 GB GGUF model and verifies its SHA-256. Interrupted downloads resume. The app starts while the model loads.

To return to app-only mode, run `docker compose up --pull always -d --remove-orphans`. This removes the inference and model-download containers and retains the named training and model volumes. Queued AI jobs wait until inference is enabled and ready.

The bundled model is `gemma-4-E2B-it-Q3_K_M.gguf`, an 8,192-token context, one inference slot and GPU layer offload. No model weights or inference tokens are downloaded to the phone. Generation, CSV interpretation and advisory fixes run as persistent jobs. Reopen jobs and completed results through **Sync → AI jobs and saved results** after navigating away or reopening Safari. Cancellation closes the active inference connection. Completed stages are checkpointed so server restart can resume work.

```sh
nvidia-smi
docker compose -f compose.yaml -f compose.inference.yaml logs inference
curl -fsS http://127.0.0.1:8080/api/v1/health
```

Check the inference logs for CUDA device selection and GPU layer allocation, and monitor VRAM during a full program generation. Record prompt processing speed, generated tokens/second and total job duration on the actual RTX 2070; timings are not assumed from the model's file size. If another application occupies VRAM, free it before starting inference.

The runtime image/model revisions and checksum are pinned in the Dockerfile, Compose file and downloader. Update them together only after rerunning import/generation and memory checks. The API's inference URL/model are deployment configuration, not browser settings.

## Updates and rollback

```sh
docker compose up --pull always -d
```

For a GPU-enabled deployment, use the two-file startup command above for updates.

Browser updates wait until explicitly applied through the sync panel; finish syncing before reloading. The API uses `/api/v1`. Back up before deploying schema changes. For rollback, set `APP_IMAGE=macksmacks/strength-guru:sha-<full-commit-sha>` in `.env`, rerun the startup command for your setup, and restore the matching pre-upgrade backup. Keep the original native backup until you have verified the imported records.

## Publishing to Docker Hub

Create the public `macksmacks/strength-guru` repository on Docker Hub. In GitHub Actions, set the repository variable `DOCKERHUB_USERNAME` and the repository secret `DOCKERHUB_TOKEN` to a Docker Hub access token with push permission. The **Web and API** workflow publishes after both checks pass on `main`. Run it manually on `main` to retry or publish a commit whose push did not trigger Actions.

## Development and verification

To build and run the app from the checked-out source, use the local image explicitly.

```sh
docker build -t strength-guru:local .
APP_IMAGE=strength-guru:local docker compose up --pull never -d
```


The production frontend lives in `frontend/`, using Node 24.22.3, Svelte 5, SvelteKit 3, TypeScript and the static adapter. Its `index.html` fallback is served by the existing Dart API process. No Node process runs in the production container.

```sh
cd frontend
npm ci
npm run check
npm test
npm run build
cd ../server
dart pub get --enforce-lockfile
dart run tool/browser_fixtures.dart --check
dart analyze
dart test
```

Use Dart 3.14.0 for server checks. `server/tool/browser_fixtures.dart` generates the checked-in browser calculation fixtures by invoking the shared Dart progression queries against an in-memory database and the existing rep calculation functions. Review and regenerate those fixtures deliberately when domain behavior changes.

For frontend development, start the API with disposable data and a matching `APP_ORIGIN`, then run `npm run dev` from `frontend/`. Vite proxies `/api` and `/guide` to port 18765. Production builds are served by Dart from `frontend/build`; `npm run preview` alone has no API.

### Automated browser checks

```sh
cd frontend
npx playwright install chromium
npm run build
npm run test:browser
npm run test:perf
# Optional other engines after installing their browsers/dependencies:
TEST_BROWSER=firefox npm run test:browser
TEST_BROWSER=webkit npm run test:browser
```

The Playwright runner starts the real Dart server on loopback port 18765 with a new temporary training directory and disabled inference. It refuses to reuse an existing server and deletes its temporary data on exit. It never connects to the deployed training profile. Set `DART_BIN` if Dart is outside `PATH`, `PLAYWRIGHT_BROWSERS_PATH` for an isolated browser cache, or `TEST_PORT` to use a different free port.

The suite covers direct route loads, semantic controls and accessibility, offline cache startup, queued logging across page closure/reload, reconnect deduplication, concurrent tabs, lost acknowledgements, origin rejection, missing-asset 404s and dialogs. Browser traces/screenshots are retained on failure. `npm run test:perf` seeds 103 weeks of history in a disposable dataset (4,635 sets), then repeats the performance scenario five times and writes a median/p95 summary under `test-results/performance/`. Performance checks emulate a mobile viewport at 10 Mbps and 50 ms latency, recording cold/cached readiness, actual DOM feedback time for 20 local saves, and raw/gzip/Brotli artifact sizes. Results are written to Playwright's test output with an offline screenshot. `frontend/build/build-metrics.json` also records build artifact sizes; compressed sizes are estimates, not a promise of the proxy's transfer encoding.

CI installs all three browser engines and their Ubuntu dependencies, then runs Chromium, Firefox and WebKit checks separately. It also runs frontend checks, shared calculation fixtures, accessibility/performance tests and Dart API checks, and uploads the static site and browser results. Deploy the private server with Docker Compose.

### Service worker and release checks

The built service worker remains at `/sw.js` with scope `/`, replacing the earlier Flutter worker at the same URL. App updates wait for explicit application in the sync panel; queued changes must be resolved first. Activation removes previous Strength Guru asset caches while leaving IndexedDB and OPFS untouched. The new browser replica uses a separate IndexedDB database, `strength-guru-replica`. This cutover assumes existing training data is already synchronized to the server; it does not import unsynchronized legacy Drift replicas. Keep the same public origin and export any legacy pending work before upgrading a browser that still contains it.

Retain `no-cache` for HTML, the worker and manifests. Content-hashed `/_app/immutable/` assets may use long-lived immutable caching. The worker excludes API and external guide routes from asset caching. First installation must finish online before offline startup can work.

Physical-device release checks remain necessary: iOS 18+ Safari and Home Screen mode, keyboard and safe areas, theme appearance, cached offline reload, full browser/app termination with an offline set, and reconnection without duplicate logging. Check scrolling and edit dialogs on a small device and a desktop. Record real RTX 2070 inference memory and generation timings separately; browser tests disable inference.

Acceptance targets: interactive Today screen within 5 seconds cold / 2 seconds cached at 10 Mbps and 50 ms RTT, with p95 local-save feedback below 100 ms. Chromium emulation measurements do not establish iPhone performance.

Measured local results and remaining release checks are recorded in [the frontend parity evidence](frontend-parity.md).
