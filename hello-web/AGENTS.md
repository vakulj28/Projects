# AGENTS.md

Context for AI coding agents working on this AWS Lambda Web Function. For setup
and deployment, see [`README.md`](./README.md).

## Skills

The `aws-lambda-web-functions` skill covers this service in more depth than this
file. Load it before nontrivial changes, and prefer it to assumptions from
other Lambda function types. To check whether the skill is installed and add
it if needed, run:

```bash
aws agent-toolkit list-installed-skills
aws configure agent-toolkit --yes --region us-east-1
aws agent-toolkit add-skill \
    --skill-name aws-lambda-web-functions \
    --region us-east-1
```

`aws configure agent-toolkit --yes` configures detected AI coding agents with
the AWS MCP Server and default AWS skills. These commands require AWS CLI
version 2.35.9 or later.

The Agent Toolkit API is available only in `us-east-1`. Use
`--region us-east-1` unless that AWS Region is already configured.

## Project

`hello-web` is an AWS Lambda Web Function, a Node.js HTTP server that AWS
Lambda runs behind an HTTPS endpoint. Deploy it with `aws lambda-web deploy`.

Web Functions use their own API and HTTP server programming model. They are not
a setting on handler-based Lambda functions, which the documentation calls
Lambda Event Functions. This project has no exported handler, `event` or
`context` argument, Amazon API Gateway API, Lambda Function URL, or adapter
library. Read per-request context from the HTTP request headers. Lambda adds
`lambda-web-request-id` and `lambda-web-endpoint-name`. The `x-forwarded-for`
header contains the caller address.

Before you make structural changes, confirm the behavior in the linked
documentation or in the `aws-lambda-web-functions` skill.

Do not convert this project to an exported handler, and do not manage it with
AWS SAM, AWS CDK, or `aws lambda` commands. If the workspace also contains
Lambda Event Functions, confirm which function to change before editing.

## Runtime contract

- Serve HTTP on port 3000. Lambda sends every request there.
  `LOCAL_PORT` changes the port for local runs only. Do not set it
  with `--env`.
- Keep the `server.listen(...)` call or the framework equivalent, such as
  `app.listen(...)`. A server on another port can still report `Active`, but
  requests return HTTP 502 responses.
- Responses stream as the application writes them. Use `res.write(...)` or pipe
  a stream to the response, and end the response when complete. There is no
  `streamifyResponse` wrapper to add.

## Layout

- `server.ts`: The entry point and HTTP server. If you rename it, update `main`
  in `package.json`.
- `package.json`: ES module configuration and the `start` and `deploy` scripts.
- The runtime is `nodejs24.x` and runs this TypeScript directly. There is no
  build step. Node.js strips types instead of compiling them.
  Transpile TypeScript features that require code generation, such as
  enums, namespaces, and parameter properties, and point `main` to the output.

## Dependencies

- Web Functions use the `arm64` architecture. The architecture
  is not configurable. Dependencies with native binaries need an
  `arm64` version.
- After adding dependencies, consider bundling the application to keep the
  deployment package small. Uploading `node_modules` as-is also works without a
  build step.
- Keep secrets out of the source tree. Pass nonsecret configuration with
  `--env`.

## How `deploy` packages the code

These rules apply to `aws lambda-web deploy`, not to the service. Another
deployment path, such as uploading a `.zip` file to Amazon S3, determines its
own package contents.

- `deploy` packages the `--code` directory. It does not run `npm install`,
  bundle, or compile the application, so install dependencies first.
- Hidden files and directories are excluded by default, except for known
  framework build paths. Use `--include-hidden-files` when the application
  needs another hidden path. Exact excluded files, such as `.env` or `*.pem`,
  require `--force-include`. Excluded directories, such as `.ssh`, remain
  excluded.
- Symlinks are skipped instead of followed. With pnpm or a workspace, install
  a layout of real files by using `npm install` or pnpm with
  `node-linker=hoisted`.
- The runtime loads `index.js` by default and does not read `package.json`.
  For a different entry file, `deploy` adds an `index.js` wrapper that
  imports the file. To load the file directly without a wrapper, set
  `AWS_LAMBDA_NODEJS_ENTRYPOINT` with `--env`.
  Use a path relative to the package root. Do not use that environment variable
  with `--entry-point`.

## Creating resources

Creating a Web Function or endpoint requires confirmation. Use
`--create` to confirm without a prompt. In an interactive terminal,
pressing Enter at the prompt provides the same confirmation.

## Commands

```bash
npm start        # run locally on port 3000
npm run deploy   # deploy a new revision

aws lambda-web deploy help          # show all deploy options
aws lambda-web list-web-functions   # list Web Functions
```

The first invocation creates the `/aws/lambda/web/hello-web` log group. To follow its logs,
run:

```bash
aws logs tail /aws/lambda/web/hello-web --follow
```

Common deploys:

```bash
# Deploy the latest code
aws lambda-web deploy --name hello-web --code .

# Update an environment variable without uploading code
aws lambda-web deploy --name hello-web --env MY_SETTING=value

# Add a staging endpoint and reuse the deployed code
aws lambda-web deploy --name hello-web \
    --endpoint-name staging --create
```

## Learn more

- [Lambda Web Functions](https://docs.aws.amazon.com/lambda/latest/dg/web-functions.html)
  for concepts, runtimes, endpoints, scaling, and monitoring
