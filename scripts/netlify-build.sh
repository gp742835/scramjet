#!/usr/bin/env bash
set -euo pipefail

# Netlify has rustup/cargo available, but Scramjet's rewriter needs
# a nightly Rust toolchain plus three command-line WASM tools.
echo "==> Installing Rust nightly toolchain"
rustup toolchain install nightly --profile minimal --component rust-src
rustup target add wasm32-unknown-unknown --toolchain nightly

echo "==> Installing Scramjet WASM build tools"
if ! command -v wasm-bindgen >/dev/null 2>&1 || [ "$(wasm-bindgen -V)" != "wasm-bindgen 0.2.105" ]; then
  cargo install wasm-bindgen-cli --version 0.2.105 --locked
fi

if ! command -v wasm-snip >/dev/null 2>&1; then
  cargo install --git https://github.com/r58playz/wasm-snip --locked
fi

# Binaryen's npm package ships the wasm-opt CLI. Install it into the
# temporary Netlify build environment and put its binaries on PATH.
if ! command -v wasm-opt >/dev/null 2>&1; then
  pnpm add --ignore-workspace-root-check --save-dev binaryen@131.0.0
fi
export PATH="$PWD/node_modules/.bin:$PATH"

command -v cargo
command -v wasm-bindgen
command -v wasm-snip
command -v wasm-opt
wasm-bindgen -V
wasm-opt --version

# Install the workspace before generating the WASM artifact.
echo "==> Installing workspace dependencies"
pnpm install --no-frozen-lockfile

# This MUST happen before Rspack because rspack.config.ts reads
# packages/core/dist/scramjet.wasm at config-load time.
echo "==> Building Scramjet rewriter WASM"
pnpm --filter @mercuryworkshop/scramjet run rewriter:build

echo "==> Building Scramjet core"
pnpm --filter @mercuryworkshop/scramjet run build

echo "==> Building Scramjet demo"
pnpm --filter @mercuryworkshop/scramjet-demo run build

echo "==> Netlify build complete"
