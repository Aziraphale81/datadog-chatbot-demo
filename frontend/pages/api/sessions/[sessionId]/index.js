export default async function handler(req, res) {
  const { sessionId } = req.query;
  const backendUrl = process.env.BACKEND_URL || "http://backend:8000";

  if (req.method === "DELETE") {
    try {
      const response = await fetch(`${backendUrl}/sessions/${sessionId}`, {
        method: "DELETE",
      });
      const data = await response.json();
      res.status(response.status).json(data);
    } catch (error) {
      console.error("Failed to delete session:", error);
      res.status(500).json({ error: "Failed to delete session" });
    }
  } else {
    res.status(405).json({ error: "Method not allowed" });
  }
}

