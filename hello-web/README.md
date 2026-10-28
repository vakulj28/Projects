# hello-web

`hello-web` is an AWS Lambda Web Function, a Node.js HTTP server that
AWS Lambda runs behind an HTTPS endpoint. This project was scaffolded with
`aws lambda-web deploy`.

## Why Lambda Web Functions

- Deploy a standard Node.js application that listens on a port without
  Lambda-specific adapters, wrappers, or handler changes.
- Each execution environment can serve concurrent requests.
- Lambda scales the Web Function with traffic, including to zero when idle.
- Deploy across multiple AWS Regions behind one endpoint. Lambda routes each
  request to the Region with the lowest latency for the caller.
- Stream responses as your application produces them.

## Run locally

```bash
npm start
```

Open [http://localhost:3000](http://localhost:3000) in a browser, or run:

```bash
curl http://localhost:3000
```

To change the response, edit `server.ts` and restart.

## Deploy

```bash
npm run deploy
# or
aws lambda-web deploy --name hello-web --code .
```

Run `aws lambda-web deploy help` for all deployment options.

The command uploads the source code, deploys a revision, updates the endpoint,
and prints the endpoint URL.

## How it works

`server.ts` is a Node.js HTTP server that listens on port 3000.
There is no handler to export and no adapter to install. AWS Lambda starts it
and forwards HTTPS requests to it. Frameworks such as Express, Fastify, Hono,
and Next.js use the same HTTP server model.

Each deployment uploads the directory as a new revision and updates the
endpoint. The first deployment creates the Web Function and endpoint and can
create an execution role and deployment bucket.

## Set up an AI coding agent

To configure Claude Code, Cursor, Kiro, Codex, or another AI coding agent with
the AWS MCP Server and AWS skills, run:

```bash
aws configure agent-toolkit --region us-east-1
```

This command requires AWS CLI version 2.35.9 or later.
The Agent Toolkit API is available only in `us-east-1`.

## Learn more

- [Lambda Web Functions](https://docs.aws.amazon.com/lambda/latest/dg/web-functions.html)
  for concepts, endpoints, scaling, and monitoring
- [`AGENTS.md`](./AGENTS.md)
  for context for AI coding agents
- [Agent setup guide](https://docs.aws.amazon.com/lambda/latest/dg/agent-setup-guide.html)
  for per-agent setup steps and Lambda skills
