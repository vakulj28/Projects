import { serve } from "@hono/node-server";
import { app } from "./app";

// Lambda Web Functions provide the listen address as "host:port" in
// AWS_LAMBDA_HTTP_ENDPOINT. Locally it's unset, so fall back to :3000.
const endpoint = process.env.AWS_LAMBDA_HTTP_ENDPOINT ?? "localhost:3000";
const [host, portStr] = endpoint.split(":");
const port = Number(portStr ?? 3000);

serve({ fetch: app.fetch, hostname: host, port }, (info) => {
  console.log(`listening on ${info.address}:${info.port}`);
});
