# Strength Guru

A private strength tracker focused on RIR-based progression, offline workout logging and server GPU inference.

## Stack
- **Framework:** Flutter
- **Database:** Drift (SQLite on server and in a browser worker)
- **State Management:** Riverpod
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

Use the pinned Flutter toolchain from the Dockerfile, or a compatible local SDK:

```sh
flutter pub get --enforce-lockfile
flutter test
cd server
dart pub get --enforce-lockfile
dart test
```

Build the full app with Docker Compose so the web client and API share one origin. The native platform directories are retained; web/container checks are now the default CI path.
