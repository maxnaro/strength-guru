#!/bin/sh
set -eu
model=/models/gemma-4-E2B-it-Q3_K_M.gguf
checksum=086e2f5ba85057f8f19712e3160a644728f74f323c9feeac4cd73fab11b43085
url=https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/0314792d7f1f7e229411f620751375812bb9faf2/gemma-4-E2B-it-Q3_K_M.gguf
if [ -f "$model" ] && printf '%s  %s\n' "$checksum" "$model" | sha256sum -c -; then
  exit 0
fi
curl --fail --location --retry 5 --continue-at - "$url" --output "$model.part"
if ! printf '%s  %s\n' "$checksum" "$model.part" | sha256sum -c -; then
  rm -f "$model.part"
  exit 1
fi
mv "$model.part" "$model"
chmod 644 "$model"
