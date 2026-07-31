#!/bin/sh
# Fetch whisper.cpp (with ggml submodule) — required for the native build.
# Run once:  sh scripts/fetch_whisper_cpp.sh
set -e
cd "$(dirname "$0")/.."
mkdir -p third_party
if [ ! -d third_party/whisper.cpp/.git ]; then
  git clone --depth 1 --recurse-submodules https://github.com/ggerganov/whisper.cpp third_party/whisper.cpp
else
  echo "whisper.cpp already present"
fi
echo "Done. Build: cd example && flutter build apk --debug"
