# Strength Guru

A private strength tracker focused on RIR-based progression, offline workout logging and server GPU inference.

## Stack
- **Web frontend:** SvelteKit 3 / Svelte 5 / TypeScript (static, semantic DOM)
- **Native app:** Flutter
- **Database:** Drift/SQLite on server; IndexedDB replica and durable offline queue in browser
- **State:** Svelte stores on web; Riverpod in native app
- **Server:** Dart Shelf, durable AI jobs, incremental synchronization
- **Deployment:** Docker Compose, NVIDIA CUDA inference, existing VPN + HTTPS proxy

## Self-hosted mobile web app

See [self-hosting instructions](docs/self-hosting.md) for Compose setup, native backup migration, offline use and GPU checks. No iOS sideloading is required.

```sh
cp .env.example .env
# Set your private HTTPS APP_ORIGIN in .env
docker compose up --build -d
```

## Development checks

Web checks use Node 24.22.3; API checks use Dart 3.14.0:

```sh
cd frontend
npm ci
npm run check
npm test
npm run build
cd ../server
dart pub get --enforce-lockfile
dart test
```

Native regression checks remain `flutter pub get --enforce-lockfile` and `flutter test` from the repository root with the pinned Flutter toolchain.

Build the full app with Docker Compose so the web client and API share one origin. CI checks the static frontend, three browser engines and the Dart API; native regression checks remain a separate job. See [parity and measured performance](docs/frontend-parity.md) for release evidence and remaining device checks.
