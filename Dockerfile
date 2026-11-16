FROM node:24.22.3-bookworm-slim@sha256:dc26ae92c9fb15cf6b1d63e20f0944b2efe0f115b20e00be48fb23fceb061c54 AS build
ARG GIT_SHA=unknown
ENV GIT_SHA=$GIT_SHA
WORKDIR /source/frontend
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci
COPY frontend ./
RUN npm run check && npm test && npm run build

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
COPY --from=build --chown=65532:65532 /source/frontend/build/ ./web/
COPY --chown=65532:65532 LICENSE assets/fonts/*-OFL.txt ./web/licenses/
USER 65532:65532
ENV DATA_DIR=/data WEB_ROOT=/app/web PORT=8080 TZ=Europe/London
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s CMD curl -fsS http://127.0.0.1:8080/api/v1/health || exit 1
CMD ["/app/bin/server"]
