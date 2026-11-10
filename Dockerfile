FROM ghcr.io/cirruslabs/flutter@sha256:46691e311715845de03a3ba4753a475476936805b29431b1f00f1816981033f8 AS build
WORKDIR /source
COPY pubspec.yaml pubspec.lock ./
COPY packages ./packages
COPY lib ./lib
COPY assets ./assets
COPY web ./web
COPY tool/prepare_web.py tool/verify_assets.py tool/asset-checksums.json ./tool/
RUN flutter pub get --enforce-lockfile \
 && python3 tool/verify_assets.py \
 && dart compile js -O4 web/drift_worker.dart -o web/drift_worker.dart.js \
 && flutter build web --wasm --no-web-resources-cdn --pwa-strategy=none \
 && python3 tool/prepare_web.py
FROM ghcr.io/cirruslabs/flutter@sha256:46691e311715845de03a3ba4753a475476936805b29431b1f00f1816981033f8 AS server-build
WORKDIR /source
COPY packages ./packages
COPY server ./server
WORKDIR /source/server
RUN dart pub get --enforce-lockfile \
 && dart build cli --target=bin/server.dart --output=build

FROM ubuntu@sha256:fe81560990fae86dc4743202b2cb4d3df98d0bcf949173cecef15ce1127ef852
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates curl tzdata \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /data /app && chown -R 65532:65532 /data /app
WORKDIR /app
COPY --from=server-build --chown=65532:65532 /source/server/build/bundle/ ./
COPY --from=build --chown=65532:65532 /source/build/web/ ./web/
COPY --chown=65532:65532 LICENSE assets/fonts/*-OFL.txt ./web/licenses/
USER 65532:65532
ENV DATA_DIR=/data WEB_ROOT=/app/web PORT=8080 TZ=Europe/London
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s CMD curl -fsS http://127.0.0.1:8080/api/v1/health || exit 1
CMD ["/app/bin/server"]
