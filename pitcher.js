import { ChatGroq } from "@langchain/groq";
import WebSocket from "ws";
import "dotenv/config.js";

async function run() {
  const llm = new ChatGroq({
    model: "llama-3.1-8b-instant",
    temperature: 0.7,
  });

  const prompt = `You are an enthusiastic SaaS salesperson. Deliver a 90-second pitch
for our penetration-testing platform "Vuln Voyager". Limit each sentence to ≤25 words.`;

  const reply = await llm.call([{ role: "user", content: prompt }]);
  const sentences = reply.text
    .split(/\. |\n/) // crude sentence split
    .map((s) => s.trim())
    .filter(Boolean);

  const ws = new WebSocket("ws://localhost:4000");
  await new Promise((res) => ws.once("open", res));

  for (const line of sentences) {
    ws.send(line);
    await new Promise((res) => setTimeout(res, 350)); // short gap
  }
  ws.close();
}
run().catch(console.error);
