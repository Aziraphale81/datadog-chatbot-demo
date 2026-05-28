import { useState, useEffect, useRef } from "react";
import ReactMarkdown from "react-markdown";
import Sidebar from "../components/Sidebar";
import ChaosPanel from "../components/ChaosPanel";

export default function Home() {
  // Session management
  const [sessions, setSessions] = useState([]);
  const [currentSessionId, setCurrentSessionId] = useState(null);
  const [messages, setMessages] = useState([]);
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [chaosPanelOpen, setChaosPanelOpen] = useState(false);
  
  // Chat state
  const [prompt, setPrompt] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  
  // Auto-scroll
  const messagesEndRef = useRef(null);

  // Load sessions on mount
  useEffect(() => {
    loadSessions();
  }, []);

  // Load messages when session changes
  useEffect(() => {
    if (currentSessionId) {
      loadMessages(currentSessionId);
    } else {
      setMessages([]);
    }
  }, [currentSessionId]);

  // Auto-scroll to bottom when messages change
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const loadSessions = async () => {
    try {
      const res = await fetch("/api/sessions");
      if (res.ok) {
        const data = await res.json();
        setSessions(data);
      }
    } catch (err) {
      console.error("Failed to load sessions", err);
    }
  };

  const loadMessages = async (sessionId) => {
    try {
      const res = await fetch(`/api/sessions/${sessionId}/messages`);
      if (res.ok) {
        const data = await res.json();
        setMessages(data);
      }
    } catch (err) {
      console.error("Failed to load messages", err);
    }
  };

  const handleNewChat = () => {
    setCurrentSessionId(null);
    setMessages([]);
    setPrompt("");
    setError("");
    setSidebarOpen(false);
  };

  const handleSessionSelect = (sessionId) => {
    setCurrentSessionId(sessionId);
    setPrompt("");
    setError("");
    setSidebarOpen(false);
  };

  const handleDeleteSession = async (sessionId) => {
    try {
      const res = await fetch(`/api/sessions/${sessionId}`, {
        method: "DELETE",
      });
      if (res.ok) {
        setSessions(sessions.filter((s) => s.id !== sessionId));
        if (currentSessionId === sessionId) {
          handleNewChat();
        }
      }
    } catch (err) {
      console.error("Failed to delete session", err);
    }
  };

  const handleDeleteAllSessions = async () => {
    try {
      const res = await fetch(`/api/sessions`, {
        method: "DELETE",
      });
      if (res.ok) {
        const data = await res.json();
        setSessions([]);
        handleNewChat();
        return data;
      }
    } catch (err) {
      console.error("Failed to delete all sessions", err);
      throw err;
    }
  };

  const generateTitle = async (sessionId) => {
    try {
      const res = await fetch(`/api/sessions/${sessionId}/generate-title`, {
        method: "POST",
      });
      if (res.ok) {
        const data = await res.json();
        // Update the session in the list
        setSessions(sessions.map((s) => 
          s.id === sessionId ? { ...s, title: data.title } : s
        ));
      }
    } catch (err) {
      console.error("Failed to generate title", err);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!prompt.trim() || loading) return;

    setLoading(true);
    setError("");

    const submittedPrompt = prompt;
    setPrompt("");

    const isFirstMessage = messages.length === 0;
    const placeholderId = `streaming-${Date.now()}`;

    // Add placeholder immediately
    const placeholder = {
      id: placeholderId,
      session_id: currentSessionId,
      prompt: submittedPrompt,
      reply: "",
      created_at: new Date().toISOString(),
    };
    setMessages((prev) => [...prev, placeholder]);

    try {
      const resp = await fetch("/api/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ prompt: submittedPrompt, session_id: currentSessionId }),
      });

      if (!resp.ok) {
        // JSON error (before SSE started)
        setMessages((prev) => prev.filter((m) => m.id !== placeholderId));
        let message = "Something went wrong.";
        try {
          const data = await resp.json();
          message = data.body ?? data.detail ?? data.error ?? message;
        } catch (_) {}
        throw new Error(typeof message === "string" ? message : JSON.stringify(message));
      }

      // Parse SSE stream
      const reader = resp.body.getReader();
      const decoder = new TextDecoder();
      let buffer = "";
      let finalSessionId = currentSessionId;

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const parts = buffer.split("\n\n");
        buffer = parts.pop(); // keep incomplete event

        for (const part of parts) {
          const line = part.trim();
          if (!line.startsWith("data: ")) continue;
          let event;
          try {
            event = JSON.parse(line.slice(6));
          } catch (_) {
            continue;
          }

          if (event.type === "chunk") {
            setMessages((prev) =>
              prev.map((m) =>
                m.id === placeholderId ? { ...m, reply: m.reply + event.content } : m
              )
            );
          } else if (event.type === "done") {
            finalSessionId = event.session_id;
            setMessages((prev) =>
              prev.map((m) =>
                m.id === placeholderId
                  ? { ...m, id: event.message_id, session_id: event.session_id, reply: event.reply }
                  : m
              )
            );
            if (!currentSessionId) {
              setCurrentSessionId(event.session_id);
            }
            await loadSessions();
            if (isFirstMessage) {
              setTimeout(() => generateTitle(event.session_id), 1000);
            }
          } else if (event.type === "error") {
            setMessages((prev) => prev.filter((m) => m.id !== placeholderId));
            throw new Error(event.message || "Worker error");
          }
        }
      }
    } catch (err) {
      console.error("Chat error", err);
      // Remove placeholder if still there
      setMessages((prev) => prev.filter((m) => m.id !== placeholderId));
      setError(err.message || "Something went wrong.");
    } finally {
      setLoading(false);
    }
  };

  const handleKeyDown = (e) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSubmit(e);
    }
  };

  return (
    <>
      <Sidebar
        sessions={sessions}
        currentSessionId={currentSessionId}
        onSessionSelect={handleSessionSelect}
        onNewChat={handleNewChat}
        onDeleteSession={handleDeleteSession}
        onDeleteAllSessions={handleDeleteAllSessions}
        isOpen={sidebarOpen}
        onToggle={() => setSidebarOpen(!sidebarOpen)}
        onChaosToggle={() => setChaosPanelOpen(!chaosPanelOpen)}
      />
      
      <ChaosPanel
        isOpen={chaosPanelOpen}
        onClose={() => setChaosPanelOpen(false)}
      />
      
      <main className="main-content">
        {/* Mobile menu button */}
        <button 
          className="menu-toggle"
          onClick={() => setSidebarOpen(!sidebarOpen)}
          aria-label="Toggle menu"
        >
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <line x1="3" y1="12" x2="21" y2="12"></line>
            <line x1="3" y1="6" x2="21" y2="6"></line>
            <line x1="3" y1="18" x2="21" y2="18"></line>
          </svg>
        </button>

        <div className="chat-container">
          {messages.length === 0 ? (
            <div className="welcome">
              <h1>AI Chatbot</h1>
              <p>FastAPI + Next.js + Datadog</p>
              <p className="subtitle">Start a conversation below</p>
            </div>
          ) : (
            <div className="messages">
              {messages.map((msg) => (
                <div key={msg.id} className="message-pair">
                  <div className="message user-message">
                    <div className="message-label">You</div>
                    <div className="message-content">{msg.prompt}</div>
                  </div>
                  <div className="message assistant-message">
                    <div className="message-label">Assistant</div>
                    <div className="message-content markdown-content">
                      <ReactMarkdown>{msg.reply}</ReactMarkdown>
                    </div>
                  </div>
                </div>
              ))}
              <div ref={messagesEndRef} />
            </div>
          )}

          <div className="input-area">
            {error && <p className="error">{error}</p>}
            <form onSubmit={handleSubmit}>
              <textarea
                rows={3}
                value={prompt}
                onChange={(e) => setPrompt(e.target.value)}
                onKeyDown={handleKeyDown}
                placeholder="Message ChatGPT... (Enter to send, Shift+Enter for new line)"
                disabled={loading}
              />
              <button type="submit" disabled={loading || !prompt.trim()}>
                {loading ? (
                  <svg className="spinner" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <circle cx="12" cy="12" r="10" opacity="0.25"></circle>
                    <path d="M12 2 A10 10 0 0 1 22 12" opacity="0.75"></path>
                  </svg>
                ) : (
                  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <line x1="22" y1="2" x2="11" y2="13"></line>
                    <polygon points="22 2 15 22 11 13 2 9 22 2"></polygon>
                  </svg>
                )}
              </button>
            </form>
          </div>
        </div>
      </main>
    </>
  );
}


