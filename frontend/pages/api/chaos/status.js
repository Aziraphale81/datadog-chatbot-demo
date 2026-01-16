export default async function handler(req, res) {
  if (req.method !== "GET") {
    res.setHeader("Allow", ["GET"]);
    return res.status(405).json({ error: "Method not allowed" });
  }

  const backendBase = process.env.BACKEND_URL || "http://backend:8000";

  try {
    const resp = await fetch(`${backendBase}/chaos/status`, {
      method: "GET",
      headers: {
        "Content-Type": "application/json",
      },
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
    console.error("API route /api/chaos/status failed", err);
    return res
      .status(500)
      .json({ error: "Unable to reach backend from frontend" });
  }
}








