import http from "node:http";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createWidgetRuntime, createLinkRequest, getStatus, disconnectWidget, newWidgetId } from "./src/widget-runtime.js";
import { readJsonFile } from "./src/json-store.js";
import { getProjectRoot } from "./src/paths.js";
import { createSentryHooks } from "./src/sentry.js";

const publicDir = path.join(path.dirname(fileURLToPath(import.meta.url)), "public");
const serverVersion = "0.1.1";

function jsonResponse(response, status, body) {
  response.writeHead(status, { "content-type": "application/json; charset=utf-8" });
  response.end(JSON.stringify(body));
}

async function staticResponse(response, requestPath) {
  const relativePath = requestPath === "/" ? "index.html" : requestPath.slice(1);
  const filePath = path.join(publicDir, relativePath);
  if (!filePath.startsWith(publicDir)) {
    response.writeHead(403);
    response.end("Forbidden");
    return;
  }
  const data = await fs.readFile(filePath);
  const ext = path.extname(filePath);
  const type = ext === ".css" ? "text/css; charset=utf-8" : ext === ".js" ? "text/javascript; charset=utf-8" : "text/html; charset=utf-8";
  response.writeHead(200, { "content-type": type });
  response.end(data);
}

export async function startServer({ projectRoot = getProjectRoot(), port = 43821, linkId = newWidgetId("widget-web"), openBrowser = false } = {}) {
  const runtime = createWidgetRuntime({ projectRoot, linkId });
  const sentry = createSentryHooks();
  const server = http.createServer(async (request, response) => {
    try {
      const url = new URL(request.url, "http://127.0.0.1");
      if (request.method === "GET" && url.pathname === "/api/health") {
        jsonResponse(response, 200, { ok: true });
        return;
      }
      if (request.method === "GET" && url.pathname === "/api/guide") {
        jsonResponse(response, 200, await readJsonFile(runtime.paths.guidePath, { required: true }));
        return;
      }
      if (request.method === "GET" && url.pathname === "/api/status") {
        jsonResponse(response, 200, await getStatus(runtime));
        return;
      }
      if (request.method === "POST" && url.pathname === "/api/link-request") {
        jsonResponse(response, 200, await createLinkRequest(runtime));
        return;
      }
      if (request.method === "POST" && url.pathname === "/api/disconnect") {
        await disconnectWidget(runtime);
        jsonResponse(response, 200, { ok: true });
        return;
      }
      if (request.method === "GET") {
        await staticResponse(response, url.pathname);
        return;
      }
      jsonResponse(response, 404, { error: "Not found" });
    } catch (error) {
      sentry.captureException(error, { url: request.url, linkId: runtime.linkId });
      jsonResponse(response, 500, { error: "상태 파일을 읽을 수 없습니다" });
    }
  });

  await new Promise((resolve) => server.listen(port, "127.0.0.1", resolve));
  const address = server.address();
  const actualPort = typeof address === "object" && address ? address.port : port;
  if (openBrowser) {
    console.log(`Open http://127.0.0.1:${actualPort}`);
  }
  return {
    port: actualPort,
    version: serverVersion,
    runtime,
    close: () => new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()))
  };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const linkArgIndex = process.argv.indexOf("--link-id");
  const portArgIndex = process.argv.indexOf("--port");
  const linkId = linkArgIndex >= 0 ? process.argv[linkArgIndex + 1] : undefined;
  const port = portArgIndex >= 0 ? Number(process.argv[portArgIndex + 1]) : 43821;
  const server = await startServer({ linkId, port, openBrowser: true });
  console.log(`Superpowers web widget v${server.version} running at http://127.0.0.1:${server.port}`);
  console.log("After updating this repository, close this server window and start the web widget again.");
}
