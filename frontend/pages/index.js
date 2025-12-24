import { useState } from "react";
import ReactMarkdown from "react-markdown";

export default function Home() {
  const [prompt, setPrompt] = useState("");
  const [reply, setReply] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!prompt.trim() || loading) return;
    setLoading(true);
    setError("");
    setReply("");
    try {
      const res = await fetch(`/api/chat`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ prompt }),
      });
      if (!res.ok) {
        throw new Error(`Request failed: ${res.status}`);
      }
      const data = await res.json();
      setReply(data.reply);
    } catch (err) {
      console.error("Chat error", err);
      setError("Something went wrong. Check backend or OpenAI key.");
    } finally {
      setLoading(false);
    }
  };

  const handleKeyDown = (e) => {
    // Submit on Enter (without Shift), allow Shift+Enter for new lines
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSubmit(e);
    }
  };

  return (
    <main className="container">
      <h1>AI Chatbot (FastAPI + Next.js)</h1>
      <p>Datadog RUM/APM/Logs/DBM demo</p>
      <form onSubmit={handleSubmit}>
        <textarea
          rows={4}
          value={prompt}
          onChange={(e) => setPrompt(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder="Ask anything... (Enter to send, Shift+Enter for new line)"
          required
        />
        <button type="submit" disabled={loading}>
          {loading ? "Thinking..." : "Send"}
        </button>
      </form>
      {reply && (
        <div className="card">
          <h3>Reply</h3>
          <div className="markdown-content">
            <ReactMarkdown>{reply}</ReactMarkdown>
          </div>
        </div>
      )}
      {error && <p className="error">{error}</p>}
    </main>
  );
}


