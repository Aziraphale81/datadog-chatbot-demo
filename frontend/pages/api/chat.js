export default async function handler(req, res) {
  if (req.method !== "POST") {
    res.setHeader("Allow", ["POST"]);
    return res.status(405).json({ error: "Method not allowed" });
  }

  const { prompt, session_id } = req.body || {};
  if (!prompt || typeof prompt !== "string" || !prompt.trim()) {
    return res.status(400).json({ error: "Prompt is required" });
  }

  const backendBase = process.env.BACKEND_URL || "http://backend:8000";

  const traceHeaders = {};
  ["x-datadog-trace-id", "x-datadog-parent-id", "x-datadog-sampling-priority", "x-datadog-origin"].forEach(
    (h) => { if (req.headers[h]) traceHeaders[h] = req.headers[h]; }
  );

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 50000);

  try {
    const { fetchWithRetry } = await import("../../lib/backendFetch");
    const resp = await fetchWithRetry(`${backendBase}/chat`, {
      method: "POST",
      signal: controller.signal,
      headers: { "Content-Type": "application/json", ...traceHeaders },
      body: JSON.stringify({ prompt, session_id }),
    });
    clearTimeout(timeoutId);

    if (!resp.ok) {
      const text = await resp.text();
      let detail = text;
      try {
        const j = JSON.parse(text);
        detail = j.detail || j.body || j.error || text;
      } catch (_) {}
      return res.status(resp.status === 404 ? 404 : 502).json({ error: "Backend error", body: detail });
    }

    // Backend is streaming SSE — pipe it through
    res.setHeader("Content-Type", "text/event-stream");
    res.setHeader("Cache-Control", "no-cache");
    res.setHeader("Connection", "keep-alive");
    res.setHeader("X-Accel-Buffering", "no");

    const reader = resp.body.getReader();
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      res.write(value);
      if (typeof res.flush === "function") res.flush();
    }
    res.end();
  } catch (err) {
    clearTimeout(timeoutId);
    console.error("API route /api/chat failed", err);
    const isTimeout = err.name === "AbortError" || err.message?.includes("aborted");
    if (!res.headersSent) {
      return res.status(isTimeout ? 504 : 500).json({
        error: isTimeout ? "Request timed out" : "Unable to reach backend",
        detail: err.message,
      });
    }
    // Headers already sent (mid-stream error) — send SSE error event
    try {
      res.write(`data: ${JSON.stringify({ type: "error", message: isTimeout ? "Request timed out" : "Connection lost" })}\n\n`);
      res.end();
    } catch (_) {}
  }
}
