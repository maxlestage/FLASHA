#!/usr/bin/env bash
# Compile le serveur et le bundle WebAssembly, comme le Dockerfile. Lancé sur Heroku
# par RustConfig une fois que le buildpack emk/rust a installé Rust ; marche aussi à la
# main : ./heroku-build.sh. Le Procfile démarre ensuite target/release/flasha.
set -euo pipefail

# Facultatif : si des dépendances git deviennent privées, la variable de configuration
# REPOS_TOKEN (un jeton GitHub en lecture) permet à Cargo de les télécharger. Le jeton
# reste hors des URL.
if [ -z "${REPOS_TOKEN:-}" ] && [ -n "${ENV_DIR:-}" ] && [ -f "$ENV_DIR/REPOS_TOKEN" ]; then
  REPOS_TOKEN=$(<"$ENV_DIR/REPOS_TOKEN")
fi
if [ -n "${REPOS_TOKEN:-}" ]; then
  export REPOS_TOKEN CARGO_NET_GIT_FETCH_WITH_CLI=true GIT_CONFIG_COUNT=1 \
    GIT_CONFIG_KEY_0=credential.https://github.com.helper \
    GIT_CONFIG_VALUE_0='!f() { test "$1" = get && echo username=x-access-token && echo "password=$REPOS_TOKEN"; }; f'
fi

cd "$(dirname "$0")"
# Sur Heroku, Cargo compile dans le cache du buildpack (CARGO_TARGET_DIR).
target="${CARGO_TARGET_DIR:-target}"

echo "-----> Compilation du serveur (site + relais)"
cargo build --release --bin flasha
mkdir -p target/release
if [ "$target" != target ]; then
  cp "$target/release/flasha" target/release/
fi
echo "       target/release/flasha prêt"

echo "-----> Compilation du bundle WebAssembly (îlots et scène 2D)"
rustup target add wasm32-unknown-unknown
cargo build --lib --target wasm32-unknown-unknown --profile wasm-release

# wasm-bindgen à la version de Cargo.lock : binaire publié, sinon compilé.
version=$(grep -A1 '^name = "wasm-bindgen"$' Cargo.lock | sed -n 's/^version = "\(.*\)"$/\1/p')
bin="$target/wasm-bindgen-$version"
if [ ! -x "$bin/wasm-bindgen" ]; then
  mkdir -p "$bin"
  curl -sSfL "https://github.com/wasm-bindgen/wasm-bindgen/releases/download/${version}/wasm-bindgen-${version}-x86_64-unknown-linux-musl.tar.gz" \
    | tar -xz --strip-components=1 -C "$bin" \
    || cargo install wasm-bindgen-cli --version "$version" --locked --root "$bin" --bin wasm-bindgen
  [ -x "$bin/wasm-bindgen" ] || mv "$bin/bin/wasm-bindgen" "$bin/"
fi
"$bin/wasm-bindgen" --target web --no-typescript --remove-name-section --remove-producers-section \
  --out-dir pkg \
  "$target/wasm32-unknown-unknown/wasm-release/flasha.wasm"
echo "       bundle prêt dans pkg/"
