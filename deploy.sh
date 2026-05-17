#!/usr/bin/env bash
# Build the Flutter web release and push it to the Raspberry Pi.
# Usage: ./deploy.sh           (build + sync)
#        ./deploy.sh --no-build (sync only — useful if build is already fresh)
#        ./deploy.sh --watch    (rebuild + sync on every change in lib/ assets/)

set -euo pipefail

REMOTE="berke@100.108.235.10"
REMOTE_DIR="tutorsim-web"
PORT=8088
SERVICE="tutorsim.service"

# Public URL the site is served at. The Flutter app uses this for both the
# backend base URL (same-origin path-routed /oauth + /api) and the 42 OAuth
# redirect_uri. If you ever change the hostname, change it here.
PUBLIC_URL="https://tutorsim.berkekbgz.dev"

here() { cd "$(dirname "$0")"; }

build() {
  echo "==> flutter build web --release  (backend=${PUBLIC_URL})"
  flutter build web --release \
    --dart-define=FT_BACKEND_URL="${PUBLIC_URL}" \
    --dart-define=FT_REDIRECT_URI="${PUBLIC_URL}/"
}

sync_backend() {
  echo "==> rsync proxy.dart to ${REMOTE}:tutorsim-backend/"
  rsync -avz bin/forty_two_oauth_proxy.dart \
    "${REMOTE}:tutorsim-backend/proxy.dart"
  ssh "${REMOTE}" "systemctl --user restart tutorsim-backend.service"
}

sync() {
  echo "==> rsync to ${REMOTE}:${REMOTE_DIR}/"
  rsync -avz --delete --human-readable \
    build/web/ "${REMOTE}:${REMOTE_DIR}/"
}

restart() {
  # Static files — server doesn't need to restart. Kept for symmetry / future use.
  ssh "${REMOTE}" "systemctl --user is-active ${SERVICE} >/dev/null || systemctl --user restart ${SERVICE}"
}

ip_hint() {
  echo
  echo "Open: http://100.108.235.10:${PORT}/"
  echo "      (or whatever the Pi's LAN IP is on your network)"
}

watch() {
  command -v inotifywait >/dev/null || { echo "Install inotify-tools: sudo dnf install inotify-tools"; exit 1; }
  build && sync && restart && ip_hint
  echo "==> watching lib/ assets/ web/ pubspec.yaml for changes (Ctrl-C to stop)"
  while inotifywait -qq -r -e modify,create,delete,move \
      lib assets web pubspec.yaml 2>/dev/null; do
    echo "==> change detected, rebuilding…"
    if build && sync; then
      echo "==> deployed @ $(date +%H:%M:%S)"
    else
      echo "!! build/sync failed, will retry on next change"
    fi
  done
}

main() {
  here
  case "${1:-}" in
    --no-build) sync; restart; ip_hint ;;
    --watch)    watch ;;
    --backend)  sync_backend ;;
    "")         build; sync; sync_backend; restart; ip_hint ;;
    *)          echo "Unknown arg: $1"; exit 2 ;;
  esac
}

main "$@"
