export default async function handler(req, res) {
  const backendUrl = process.env.BACKEND_URL || "http://backend:8000";

  if (req.method === "GET") {
    // List sessions
    try {
      const response = await fetch(`${backendUrl}/sessions`);
      const data = await response.json();
      res.status(response.status).json(data);
    } catch (error) {
      console.error("Failed to fetch sessions:", error);
      res.status(500).json({ error: "Failed to fetch sessions" });
    }
  } else if (req.method === "POST") {
    // Create new session
    try {
      const response = await fetch(`${backendUrl}/sessions`, {
        method: "POST",
      });
      const data = await response.json();
      res.status(response.status).json(data);
    } catch (error) {
      console.error("Failed to create session:", error);
      res.status(500).json({ error: "Failed to create session" });
    }
  } else {
    res.status(405).json({ error: "Method not allowed" });
  }
}

