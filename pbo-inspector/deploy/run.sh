#!/usr/bin/env bash
# Launcher for the Arma 3 PBO Inspector (Next.js production server on :3005).
# Installed to a space-free path (/usr/local/bin) so OpenRC/supervise-daemon
# never has to parse a spaced path. Mirrors the looneybin-stats launcher.
cd /home/timb/loonybin-pbo || exit 1
export NODE_ENV=production

# Reuse the main site's Steam-login session: pull the shared HS256 secret from
# the website's (gitignored) env so the /pbo middleware can verify lb_session.
SITE_ENV="/home/timb/Documents/LooneyBin Altis Life/website/.env.local"
if [ -f "$SITE_ENV" ]; then
  export SESSION_SECRET="$(grep -E '^SESSION_SECRET=' "$SITE_ENV" | head -1 | cut -d= -f2- | tr -d '"' )"
fi

# Security boundary: only these dirs may be scanned. Drop .pbo files into pbos/.
export PBO_ALLOWED_ROOTS="/home/timb/loonybin-pbo/pbos"
export PBO_LOGIN_URL="https://www.projectloonybin.com/login"

exec /usr/bin/node node_modules/next/dist/bin/next start -p 3005
