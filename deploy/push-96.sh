#!/usr/bin/env bash
# Push the working tree to the live box and repack+restart there. THIS IS THE LIVE DEPLOY PATH.
#
#   deploy/push-96.sh                # mirror + reload + patch note
#   deploy/push-96.sh --map          # also replace live map content from the dev DB (D7)
#   deploy/push-96.sh --no-reload    # mirror only (no repack, no restart, no note)
#   deploy/push-96.sh --no-notes     # deploy, but post nothing to Discord
#
# Refuses a dirty tree: live must be reproducible from a commit, and the commit range is what the
# patch note is built from. The 22:00-09:00 freeze is enforced unless deploy/LIVE_IS_DEV exists
# (see that file) or FORCE_DEPLOY=1.
set -euo pipefail
SRC=/home/timb/Armapunk2035; HOST=timb@10.1.24.96; SSH="ssh -i /home/timb/.ssh/id_lb -o BatchMode=yes"
DO_MAP=0; DO_RELOAD=1; DO_NOTES=1
for a in "$@"; do case "$a" in
  --map) DO_MAP=1 ;;
  --no-reload) DO_RELOAD=0; DO_NOTES=0 ;;
  --no-notes) DO_NOTES=0 ;;
  *) echo "push-96: unknown argument '$a'"; exit 2 ;;
esac; done
cd "$SRC"

if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  echo "push-96: working tree has uncommitted tracked changes -- commit first"; exit 1
fi
if [ -f "$SRC/deploy/LIVE_IS_DEV" ]; then
  echo "push-96: LIVE_IS_DEV -- .96 is the dev server, freeze not enforced"
else
  H=$(date +%H)
  if { [ "$H" -ge 22 ] || [ "$H" -lt 9 ]; } && [ "${FORCE_DEPLOY:-0}" != 1 ]; then
    echo "push-96: 22:00-09:00 freeze (FORCE_DEPLOY=1 to override)"; exit 1
  fi
fi

# What is live RIGHT NOW, straight from the box: the commit range prev..HEAD is the patch note.
PREV=$($SSH $HOST 'cat ~/Armapunk2035/DEPLOYED_COMMIT 2>/dev/null' || true)
HEAD_SHA=$(git rev-parse HEAD)

rsync -az --delete --info=stats1 -e "$SSH" \
  --exclude='.git/' --exclude='.claude/' --exclude='scratchpad/' --exclude='textures_png/' --exclude='website/node_modules/' --exclude='website/.next/' \
  --exclude='radio/dist/@Armapunk2035/addons/' --exclude='loonybot/venv/' --exclude='__pycache__/' \
  --exclude='deploy/postgres/.env' --exclude='deploy/secrets.env' --exclude='*.biprivatekey' --exclude='DEPLOYED_COMMIT' \
  "$SRC/" "$HOST:Armapunk2035/" | tail -n 5

[ "$DO_MAP" = 1 ] && bash "$SRC/deploy/live/map-push-live.sh"
[ "$DO_RELOAD" = 1 ] || exit 0

$SSH $HOST 'bash -s' <<'REMOTE'
export XDG_RUNTIME_DIR=/run/user/$(id -u)
bash /home/timb/Armapunk2035/deploy/live/reload-live.sh
REMOTE

# Only now: the box's DEPLOYED_COMMIT is what is RUNNING there, and the next deploy's patch note is
# built from that commit onward. Writing it during the mirror (as this did until 2026-09-08) made a
# --no-reload mirror claim a build the box was not running, and silently dropped those commits from
# the next note's range.
$SSH $HOST "printf '%s\\n' '$HEAD_SHA' > ~/Armapunk2035/DEPLOYED_COMMIT"
echo "$HEAD_SHA" > DEPLOYED_COMMIT

[ "$DO_NOTES" = 1 ] || exit 0
BUILD=$($SSH $HOST 'cat ~/arma3server_live/.build 2>/dev/null' || echo "")
[ -n "$BUILD" ] && BUILD=$(printf 'b%04d' "$BUILD")
# build_patchnote.py exits 1 when nothing player-facing changed -- that is a normal, silent no-post.
if NOTE=$(python3 "$SRC/deploy/live/build_patchnote.py" "$PREV" "$HEAD_SHA" "$BUILD"); then
  printf '%s' "$NOTE" | $SSH $HOST 'python3 /home/timb/Armapunk2035/deploy/live/post_patchnote.py'
else
  echo "push-96: no player-facing changes in ${PREV:0:8}..${HEAD_SHA:0:8} -- no patch note posted"
fi
