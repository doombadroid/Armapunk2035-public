#!/usr/bin/env bash
# Deploy the portal to the .96 box (PORTAL_SPEC.md § Deploy kit).
#   website/deploy/push-96.sh            # rsync + npm ci + build + restart armapunk-portal + smoke
#   website/deploy/push-96.sh --no-build # rsync only (static/public changes, no restart)
# Source of truth is this repo; the box never runs git. .env.local on the box is NOT touched
# (it is excluded from the rsync, like node_modules and .next). Neither is uploads/: ticket evidence,
# wiki and poll images are written to <cwd>/uploads at runtime (src/lib/actions.ts, served by
# src/app/api/images/*), cwd is $DEST (armapunk-portal.service), and website/ has no uploads/ -- so
# without the exclude every --delete mirror wiped every player attachment.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"     # website/
BOX="${PORTAL_BOX:-timb@10.1.24.96}"
SSH="ssh -i $HOME/.ssh/id_lb -o BatchMode=yes"
DEST="${PORTAL_DEST:-/home/timb/armapunk-portal}"
PORT="${PORTAL_PORT:-3011}"
BUILD=1; [ "${1:-}" = "--no-build" ] && BUILD=0

if [ -n "$(git -C "$HERE" status --porcelain --untracked-files=no -- .)" ]; then
    echo "push-96: website/ has uncommitted changes -- commit first (the box must be reproducible from a commit)"; exit 1
fi
echo "push-96: mirroring website/ -> $BOX:$DEST"
rsync -az --delete --info=stats1 -e "$SSH" \
    --exclude node_modules --exclude .next --exclude '.env*' --exclude next-env.d.ts --exclude /uploads \
    "$HERE/" "$BOX:$DEST/"
$SSH "$BOX" "printf '%s\n' '$(git -C "$HERE" rev-parse HEAD)' > $DEST/DEPLOYED_COMMIT"
[ "$BUILD" = 1 ] || { echo "push-96: mirrored only"; exit 0; }

$SSH "$BOX" 'bash -s' <<REMOTE
set -euo pipefail
export XDG_RUNTIME_DIR=/run/user/\$(id -u)
cd "$DEST"
[ -f .env.local ] || { echo "push-96: $DEST/.env.local missing on the box"; exit 1; }
echo "push-96: npm ci"; npm ci --no-audit --no-fund 2>&1 | tail -1
echo "push-96: build"; npm run build 2>&1 | tail -3
systemctl --user restart armapunk-portal
for i in \$(seq 1 40); do curl -sf -o /dev/null "http://127.0.0.1:$PORT/" && break; sleep 1; done
echo "push-96: smoke"
# Public: / and /login render (200). Everything else is Steam-gated and must redirect to /login (307).
fail=0
for p in / /login; do
    code=\$(curl -s -o /dev/null -w '%{http_code}' -H 'Host: armapunk.com' "http://127.0.0.1:$PORT\$p")
    printf '  %-20s %s (want 200)\n' "\$p" "\$code"; [ "\$code" = 200 ] || fail=1
done
for p in /players /leaderboard /gameserver/gangs /bounties /wiki /server; do
    out=\$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' -H 'Host: armapunk.com' "http://127.0.0.1:$PORT\$p")
    printf '  %-20s %s (want 307 -> /login)\n' "\$p" "\$out"; case "\$out" in "307 "*"/login") ;; *) fail=1 ;; esac
done
# Owner-session render of every gated route: mint the site's own session JWT with its secret (jose from
# node_modules) so server components hit the real database. A 500 here is a query the schema rejects.
JWT=\$(node -e '
  const {SignJWT}=require("jose"); const fs=require("fs");
  const env=Object.fromEntries(fs.readFileSync(".env.local","utf8").split("\\n").filter(l=>/^[A-Z_]+=/.test(l)).map(l=>[l.slice(0,l.indexOf("=")), l.slice(l.indexOf("=")+1)]));
  new SignJWT({uid: env.OWNER_STEAMID, name:"smoke-owner", adminLevel:5, copLevel:7, medicLevel:5, isOwner:true})
    .setProtectedHeader({alg:"HS256"}).setIssuedAt().setExpirationTime("10m")
    .sign(new TextEncoder().encode(env.SESSION_SECRET)).then(t=>process.stdout.write(t));')
OWNER=\$(grep '^OWNER_STEAMID=' .env.local | cut -d= -f2-)
for p in /players /leaderboard /gameserver/gangs /gang-territories /governor /bounties /bans /changelogs /homes-for-sale /logs /maxsec /maxsec/apply /server /support-tickets /support-tickets/new /trauma-team /trauma-team/apply /voting /vpn-whitelist /whitelist /wiki /pixel /api/pixel/state "/player-detail?playerid=\$OWNER"; do
    code=\$(curl -s -o /dev/null -w '%{http_code}' -H 'Host: armapunk.com' -H "Cookie: lb_session=\$JWT" "http://127.0.0.1:$PORT\$p")
    printf '  owner %-34s %s\n' "\$p" "\$code"; [ "\$code" = 200 ] || fail=1
done
# Armapunk Pixel is owner-only (PIXEL_SPEC.md § Access): a signed-in NON-owner must get 404 on the page and
# the API, and the action route must validate its body (400) without touching the owner's save.
OTHER=\$(node -e '
  const {SignJWT}=require("jose"); const fs=require("fs");
  const env=Object.fromEntries(fs.readFileSync(".env.local","utf8").split("\\n").filter(l=>/^[A-Z_]+=/.test(l)).map(l=>[l.slice(0,l.indexOf("=")), l.slice(l.indexOf("=")+1)]));
  new SignJWT({uid: "76561190000000002", name:"smoke-other", adminLevel:0, copLevel:0, medicLevel:0, isOwner:false})
    .setProtectedHeader({alg:"HS256"}).setIssuedAt().setExpirationTime("10m")
    .sign(new TextEncoder().encode(env.SESSION_SECRET)).then(t=>process.stdout.write(t));')
for p in /pixel /api/pixel/state; do
    code=\$(curl -s -o /dev/null -w '%{http_code}' -H 'Host: armapunk.com' -H "Cookie: lb_session=\$OTHER" "http://127.0.0.1:$PORT\$p")
    printf '  other %-34s %s (want 404)\n' "\$p" "\$code"; [ "\$code" = 404 ] || fail=1
done
code=\$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' -d '{"type":"nope"}' -H 'Host: armapunk.com' -H "Cookie: lb_session=\$JWT" "http://127.0.0.1:$PORT/api/pixel/action")
printf '  owner %-34s %s (want 400)\n' "POST /api/pixel/action {nope}" "\$code"; [ "\$code" = 400 ] || fail=1
[ "\$fail" = 0 ] || { echo "push-96: SMOKE FAILED"; journalctl --user -u armapunk-portal -n 300 --no-pager -o cat | grep -E "error: |does not exist|syntax error" | sort | uniq -c | sort -rn | head -8; exit 1; }
echo "push-96: live on :$PORT (\$(cut -c1-8 DEPLOYED_COMMIT))"
REMOTE
