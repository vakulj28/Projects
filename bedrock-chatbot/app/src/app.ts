import { Hono } from "hono";
import { stream } from "hono/streaming";
import { requireAccessCode } from "./auth";
import { streamChat } from "./bedrock";

const MAX_QUESTION_LEN = 2000;

export const app = new Hono();

// Health check — Web Function endpoints and CloudFront can hit this.
app.get("/", (c) => c.json({ status: "ok" }));

app.post("/api/chat", requireAccessCode, async (c) => {
  let body: unknown;
  try {
    body = await c.req.json();
  } catch {
    return c.json({ error: "invalid JSON body" }, 400);
  }

  const question = (body as { question?: unknown }).question;
  if (typeof question !== "string" || question.trim().length === 0) {
    return c.json({ error: "question is required" }, 400);
  }
  if (question.length > MAX_QUESTION_LEN) {
    return c.json({ error: `question too long (max ${MAX_QUESTION_LEN})` }, 400);
  }

  c.header("Content-Type", "text/plain; charset=utf-8");
  c.header("X-Content-Type-Options", "nosniff");

  return stream(c, async (s) => {
    try {
      for await (const chunk of streamChat(question)) {
        await s.write(chunk);
      }
    } catch (err) {
      console.error("bedrock stream error", err);
      await s.write("\n[error generating response]");
    }
  });
});
