export default async function handler(req, res) {
  if (req.method !== "POST") {
    res.setHeader("Allow", ["POST"]);
    return res.status(405).json({ error: "Method not allowed" });
  }

  const { prompt } = req.body || {};
  if (!prompt || typeof prompt !== "string" || !prompt.trim()) {
    return res.status(400).json({ error: "Prompt is required" });
  }

  const backendBase =
    process.env.BACKEND_INTERNAL_BASE ||
    "http://backend.chat-demo.svc.cluster.local:8000";

  // Forward Datadog trace headers for distributed tracing
  const traceHeaders = {};
  const ddHeaders = [
    "x-datadog-trace-id",
    "x-datadog-parent-id",
    "x-datadog-sampling-priority",
    "x-datadog-origin",
  ];
  ddHeaders.forEach((header) => {
    if (req.headers[header]) {
      traceHeaders[header] = req.headers[header];
    }
  });

  try {
    const resp = await fetch(`${backendBase}/chat`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...traceHeaders,
      },
      body: JSON.stringify({ prompt }),
    });

    if (!resp.ok) {
      const text = await resp.text();
      return res
        .status(502)
        .json({ error: "Backend error", status: resp.status, body: text });
    }

    const data = await resp.json();
    return res.status(200).json(data);
  } catch (err) {
    console.error("API route /api/chat failed", err);
    return res
      .status(500)
      .json({ error: "Unable to reach backend from frontend" });
  }
}


