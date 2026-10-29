import {
  BedrockRuntimeClient,
  ConverseStreamCommand,
} from "@aws-sdk/client-bedrock-runtime";
import { getConfig } from "./config";

let client: BedrockRuntimeClient | undefined;

export async function* streamChat(question: string): AsyncGenerator<string> {
  const { region, modelId, maxTokens } = await getConfig();
  client ??= new BedrockRuntimeClient({ region });

  const command = new ConverseStreamCommand({
    modelId,
    system: [{ text: "You are a concise, helpful assistant. Answer briefly." }],
    messages: [{ role: "user", content: [{ text: question }] }],
    inferenceConfig: { maxTokens },
  });

  const response = await client.send(command);
  if (!response.stream) return;

  for await (const event of response.stream) {
    const delta = event.contentBlockDelta?.delta?.text;
    if (delta) yield delta;
  }
}
