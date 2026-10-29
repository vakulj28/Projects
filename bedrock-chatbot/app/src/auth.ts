import { createMiddleware } from "hono/factory";
import { createHash, timingSafeEqual } from "node:crypto";
import { getConfig } from "./config";

function safeEqual(a: string, b: string): boolean {
  // Hash to a fixed length first, so timingSafeEqual never throws on
  // length mismatch and we don't leak the expected length.
  const ha = createHash("sha256").update(a).digest();
  const hb = createHash("sha256").update(b).digest();
  return timingSafeEqual(ha, hb);
}

export const requireAccessCode = createMiddleware(async (c, next) => {
  const provided = c.req.header("x-access-code") ?? "";
  const { accessCode } = await getConfig();
  if (!safeEqual(provided, accessCode)) {
    return c.json({ error: "unauthorized" }, 401);
  }
  await next();
});
