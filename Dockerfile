# Production image (Heroku, and as is on Render, Fly.io, Cloud Run…).
#
#   docker build -t flasha . && docker run -p 8080:8080 flasha

FROM rust:1-slim-trixie AS build
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && rustup target add wasm32-unknown-unknown
WORKDIR /app
COPY . .
# The islands, compiled to WebAssembly, then bound with the wasm-bindgen version of
# Cargo.lock (a prebuilt binary, or compiled if it cannot be downloaded).
RUN cargo build --lib --target wasm32-unknown-unknown --profile wasm-release \
    && version=$(grep -A1 '^name = "wasm-bindgen"$' Cargo.lock | sed -n 's/^version = "\(.*\)"$/\1/p') \
    && (curl -sSfL "https://github.com/wasm-bindgen/wasm-bindgen/releases/download/${version}/wasm-bindgen-${version}-x86_64-unknown-linux-musl.tar.gz" \
            | tar -xz --strip-components=1 -C /usr/local/bin \
        || cargo install wasm-bindgen-cli --version "$version" --locked) \
    && wasm-bindgen --target web --no-typescript --remove-name-section --remove-producers-section --out-dir pkg \
        target/wasm32-unknown-unknown/wasm-release/flasha.wasm
# The server.
RUN cargo build --release --bin flasha && cp target/release/flasha /server

FROM debian:trixie-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/* && useradd --system --uid 10001 app
WORKDIR /app
COPY --from=build /server /usr/local/bin/server
COPY --from=build /app/pkg ./pkg
COPY public ./public
USER app
# Heroku sets PORT at startup; 8080 elsewhere.
ENV PORT=8080
EXPOSE 8080
CMD ["server"]
