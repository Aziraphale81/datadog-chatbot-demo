export default async function handler(req, res) {
  if (req.method !== "POST") {
    res.setHeader("Allow", ["POST"]);
    return res.status(405).json({ error: "Method not allowed" });
  }

  const { scenario } = req.body || {};

  const backendBase = process.env.BACKEND_URL || "http://backend:8000";

  try {
    const resp = await fetch(`${backendBase}/chaos/scenario`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ scenario }),
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
    console.error("API route /api/chaos/scenario failed", err);
    return res
      .status(500)
      .json({ error: "Unable to reach backend from frontend" });
  }
}

