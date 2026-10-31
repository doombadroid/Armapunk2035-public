import { NextResponse, type NextRequest } from "next/server";
import { jwtVerify } from "jose";

// Reuse the main LooneyBin site's Steam-login session. The `lb_session` cookie
// is host-only on projectloonybin.com, so requests routed here (/pbo) carry it.
// We verify the HS256 signature with the shared SESSION_SECRET and bounce
// unauthenticated visitors to the site login. Fail-closed: any missing/invalid
// secret or token redirects.
const COOKIE = "lb_session";
const LOGIN_URL = process.env.PBO_LOGIN_URL ?? "https://www.projectloonybin.com/login";

function key(): Uint8Array {
  return new TextEncoder().encode(process.env.SESSION_SECRET ?? "");
}

export async function middleware(req: NextRequest) {
  const token = req.cookies.get(COOKIE)?.value;
  if (token && (process.env.SESSION_SECRET ?? "").length > 0) {
    try {
      await jwtVerify(token, key());
      return NextResponse.next();
    } catch {
      // fall through to redirect
    }
  }

  const res = NextResponse.redirect(LOGIN_URL);
  if (token) res.cookies.delete(COOKIE);
  return res;
}

// Gate every route (pages + /api/pbos) except Next internals and the favicon.
// The explicit "/" is required: the negative-lookahead pattern alone does not
// match the index route, which would leave the base /pbo page ungated.
export const config = {
  matcher: ["/", "/((?!_next/static|_next/image|favicon.ico).*)"],
};
