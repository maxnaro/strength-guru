# Self-hosting Strength Guru

The web app and Dart API share one origin. Training data lives in SQLite on the server; the browser keeps a replica and a durable queue for offline set logging. Program editing and AI require connectivity. There is one private training profile and no application login: restrict access with your existing VPN/proxy.

## Start

Requirements: Linux x86-64, Docker Engine with Compose, an NVIDIA driver and NVIDIA Container Toolkit configured for Docker. The default inference configuration targets an RTX 2070 with 8 GB VRAM.

```sh
cp .env.example .env
# Edit APP_ORIGIN to match your private HTTPS URL, without a trailing slash.
docker compose up --build -d
docker compose logs -f app inference model-download
```

The first run downloads the pinned 2.54 GB GGUF model and checks its SHA-256. Downloads resume after interruption. The model and training data use separate named volumes. The application starts independently of inference readiness; AI failure does not stop logging.

Forward your private HTTPS origin to `http://127.0.0.1:8080`. Only this loopback port is published; inference has no published port. If your proxy is itself containerized, connect it to the app's Docker network and forward to `app:8080`. Keep that network private. Retain the same hostname: browser data and its offline queue are scoped to the origin.

The proxy must preserve the app's `Cross-Origin-Opener-Policy` and `Cross-Origin-Embedder-Policy` headers and serve `.wasm` with `application/wasm`. Disable buffering/compression for `/api/v1/jobs/*/events`; allow at least a 10-minute stream timeout. Allow backup uploads up to 64 MiB. Terminate trusted HTTPS even on the VPN: service workers and persistent browser features require a secure origin.

On iPhone, open the private HTTPS URL in Safari and use **Share → Add to Home Screen**. Open it online once and allow the application cache to finish installing before relying on offline startup. The first visit requires the server. Later launches render cached data immediately and synchronize in the background. iOS may remove website data; the server remains the durable copy of synchronized records.

## Import and backup

Export a SQLite backup from the current native app. In the web app's About sheet choose Restore, select the file, review the program/session/set counts, then confirm. Schema v8 is supported. Older backups must first be opened and re-exported with the current native version.

Restore preserves training IDs, set targets, ordering and history, discards obsolete AI settings, and saves a recovery snapshot in `/data/backups` before replacing data. It changes the dataset generation. Other devices with pending edits retain those edits for export rather than applying them to the restored database.

Backup synchronizes the current browser first and refuses to export while it has pending edits. A server backup contains synchronized records; unsynchronized edits on other devices remain on those devices. Use the sync status strip to export pending changes as JSON, retry syncing, or resolve conflicts. “Keep my edit” explicitly overwrites a conflicting current version; “Use server version” discards that local operation after confirmation. Deleted references and dataset replacements may require exporting and discarding the retained operation.

Copy recovery snapshots off the server periodically. Stop the app before copying the entire training volume manually, or use the application backup endpoint for a consistent live snapshot. Do not copy only an active SQLite file while ignoring its WAL.

## AI and GPU checks

The default is `gemma-4-E2B-it-Q3_K_M.gguf`, an 8,192-token context, one inference slot and GPU layer offload. No model weights or inference tokens are downloaded to the phone. Generation, CSV interpretation and advisory fixes run as persistent jobs. Reopen jobs and completed results through **Sync → AI jobs and saved results** after navigating away or reopening Safari. Cancellation closes the active inference connection. Completed stages are checkpointed so server restart can resume work.

```sh
nvidia-smi
docker compose logs inference
curl -fsS http://127.0.0.1:8080/api/v1/health
```

Check the inference logs for CUDA device selection and GPU layer allocation, and monitor VRAM during a full program generation. Record prompt processing speed, generated tokens/second and total job duration on the actual RTX 2070; timings are not assumed from the model's file size. If another application occupies VRAM, free it before starting inference.

The runtime image/model revisions and checksum are pinned in the Dockerfile, Compose file and downloader. Update them together only after rerunning import/generation and memory checks. The API's inference URL/model are deployment configuration, not browser settings.

## Updates and rollback

```sh
docker compose build
docker compose up -d
```

Browser updates wait until explicitly applied through the sync panel; finish syncing before reloading. The API uses `/api/v1`. Back up before deploying schema changes. For rollback, run the previous application image with its matching pre-upgrade backup. Keep the native app and its original backup until web parity is verified; it does not share live data with the server.

## Verification

The pinned Flutter image can run `flutter test`, the server's `dart test`, and the production build without a host SDK. CI performs these checks and uploads a web artifact; it does not publish a public site or deploy your server. Native IPA packaging is retained as a manual workflow.

Physical-device release checks remain necessary: iOS 18+ Safari and Home Screen mode, keyboard/safe-area behaviour, cached offline reload, suspension during AI generation, and an offline set that survives termination and later synchronizes. Target an interactive Today screen within 5 seconds cold / 2 seconds cached at 10 Mbps and 50 ms RTT, with p95 local-save feedback below 100 ms. These are acceptance targets, not measured claims.

### Automated browser smoke check

With a local app instance running on port 18765:

```sh
npm install --prefix /tmp/sg-browser-check playwright
PLAYWRIGHT_BROWSERS_PATH=/tmp/sg-browsers node /tmp/sg-browser-check/node_modules/playwright/cli.js install chromium
NODE_PATH=/tmp/sg-browser-check/node_modules PLAYWRIGHT_BROWSERS_PATH=/tmp/sg-browsers node tool/browser_smoke.cjs
```

The check verifies offline startup, an offline set across reload and reconnection, API origin checks and correct Wasm serving. It supplements the physical iPhone checks. Set `APP_ORIGIN` to test another local instance. Repeat with `FORCE_CANVASKIT=1` to exercise the JavaScript fallback; run these checks sequentially because each logs a set in the test profile.
