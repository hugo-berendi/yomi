#!/usr/bin/env node

const input = JSON.parse(await new Promise((resolve, reject) => {
  let data = "";
  process.stdin.setEncoding("utf8");
  process.stdin.on("data", (chunk) => (data += chunk));
  process.stdin.on("end", () => resolve(data));
  process.stdin.on("error", reject);
}));

const { baseUrl, token, operation, input: payload = {} } = input;
if (typeof baseUrl !== "string" || typeof token !== "string" || typeof operation !== "string") {
  throw new Error("baseUrl, token, and operation are required on stdin");
}

const response = await fetch(new URL("/api/auth/websocket-ticket", baseUrl), {
  method: "POST",
  headers: { authorization: `Bearer ${token}` },
});
if (!response.ok) throw new Error(`websocket ticket request failed: ${response.status}`);
const ticket = (await response.json()).ticket;
if (typeof ticket !== "string") throw new Error("websocket ticket response did not contain a ticket");

const socket = new WebSocket(new URL(`/ws?orchestrationProtocol=2&wsTicket=${encodeURIComponent(ticket)}`, baseUrl.replace(/^http/, "ws")));
const result = await new Promise((resolve, reject) => {
  const requestId = "1";
  const timer = setTimeout(() => reject(new Error("RPC request timed out")), 30000);
  socket.addEventListener("open", () => {
    socket.send(JSON.stringify({
      _tag: "Request",
      id: requestId,
      tag: operation,
      payload,
      headers: [],
    }));
  });
  socket.addEventListener("message", (event) => {
    const message = JSON.parse(String(event.data));
    if (message.requestId !== requestId) return;
    if (input.firstChunk && message._tag === "Chunk" && message.values?.length) {
      clearTimeout(timer);
      resolve(message.values[0]);
      socket.close();
      return;
    }
    if (message._tag !== "Exit") return;
    clearTimeout(timer);
    if (message.exit?._tag === "Success") resolve(message.exit.value);
    else {
      const reasons = [];
      const visit = (value) => {
        if (!value || typeof value !== "object") return;
        for (const [key, child] of Object.entries(value)) {
          if ((key === "reason" || key === "_tag") && typeof child === "string" && /^[a-zA-Z_]+$/.test(child)) reasons.push(child);
          else if (typeof child === "object") visit(child);
        }
      };
      visit(message.exit);
      reject(new Error(`RPC request failed: ${reasons.join("/")}`));
    }
    socket.close();
  });
  socket.addEventListener("error", () => reject(new Error("WebSocket connection failed")));
});

process.stdout.write(JSON.stringify(result));
