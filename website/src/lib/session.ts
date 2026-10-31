import { cookies } from "next/headers";
import { SignJWT, jwtVerify } from "jose";

const COOKIE = "lb_session";
const MAX_AGE = 60 * 60 * 24 * 30; // 30 days

export interface Session {
  uid: string;
  name: string;
  adminLevel: number;
  copLevel: number;
  medicLevel: number;
  isOwner: boolean;
  avatar?: string | null;
}

function key(): Uint8Array {
  const s = process.env.SESSION_SECRET ?? "";
  if (!s) throw new Error("SESSION_SECRET not set");
  return new TextEncoder().encode(s);
}

export async function createSession(s: Session): Promise<void> {
  const token = await new SignJWT({ ...s })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime("30d")
    .sign(key());
  const jar = await cookies();
  jar.set(COOKIE, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: MAX_AGE,
  });
}

export async function getSession(): Promise<Session | null> {
  const jar = await cookies();
  const token = jar.get(COOKIE)?.value;
  if (!token) return null;
  try {
    const { payload } = await jwtVerify(token, key());
    return {
      uid: String(payload.uid),
      name: String(payload.name),
      adminLevel: Number(payload.adminLevel ?? 0),
      copLevel: Number(payload.copLevel ?? 0),
      medicLevel: Number(payload.medicLevel ?? 0),
      isOwner: Boolean(payload.isOwner),
      avatar: (payload.avatar as string | null | undefined) ?? null,
    };
  } catch {
    return null;
  }
}

export async function destroySession(): Promise<void> {
  const jar = await cookies();
  jar.delete(COOKIE);
}
