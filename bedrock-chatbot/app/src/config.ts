import {
  SecretsManagerClient,
  GetSecretValueCommand,
} from "@aws-sdk/client-secrets-manager";

export interface Config {
  region: string;
  modelId: string;
  maxTokens: number;
  accessCode: string;
}

let cached: Config | undefined;

async function resolveAccessCode(region: string): Promise<string> {
  // Local dev: use the env var and skip Secrets Manager entirely.
  if (process.env.APP_ACCESS_CODE) {
    return process.env.APP_ACCESS_CODE;
  }
  // Deployed: read it from Secrets Manager (name/ARN in SECRET_ID).
  const secretId = process.env.SECRET_ID;
  if (!secretId) {
    throw new Error("Set APP_ACCESS_CODE (local) or SECRET_ID (deployed)");
  }
  const client = new SecretsManagerClient({ region });
  const res = await client.send(new GetSecretValueCommand({ SecretId: secretId }));
  if (!res.SecretString) {
    throw new Error("Secret has no string value");
  }
  // Stored as JSON: {"accessCode":"..."}
  return JSON.parse(res.SecretString).accessCode as string;
}

export async function getConfig(): Promise<Config> {
  if (cached) return cached;
  const region = process.env.AWS_REGION ?? "eu-west-1";
  cached = {
    region,
    modelId: process.env.MODEL_ID ?? "eu.amazon.nova-lite-v1:0",
    maxTokens: Number(process.env.MAX_TOKENS ?? 512),
    accessCode: await resolveAccessCode(region),
  };
  return cached;
}
