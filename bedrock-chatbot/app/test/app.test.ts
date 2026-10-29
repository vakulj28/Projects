import { describe, it, expect, vi } from "vitest";

vi.mock("../src/bedrock", () => ({
  streamChat: async function* () {
    yield "Hello";
    yield " world";
  },
}));

process.env.APP_ACCESS_CODE = "test-code";

const { app } = await import("../src/app");

const post = (body: unknown, code?: string) =>
  app.request("/api/chat", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...(code ? { "x-access-code": code } : {}),
    },
    body: JSON.stringify(body),
  });

describe("POST /api/chat", () => {
  it("rejects a missing access code", async () => {
    expect((await post({ question: "hi" })).status).toBe(401);
  });

  it("rejects a wrong access code", async () => {
    expect((await post({ question: "hi" }, "nope")).status).toBe(401);
  });

  it("rejects an empty question", async () => {
    expect((await post({ question: "" }, "test-code")).status).toBe(400);
  });

  it("streams an answer with a valid code", async () => {
    const res = await post({ question: "hi" }, "test-code");
    expect(res.status).toBe(200);
    expect(await res.text()).toBe("Hello world");
  });
});

describe("GET /", () => {
  it("returns ok", async () => {
    expect((await app.request("/")).status).toBe(200);
  });
});
