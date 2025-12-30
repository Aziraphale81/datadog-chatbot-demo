import { useState, useEffect, useRef } from "react";
import ReactMarkdown from "react-markdown";
import Sidebar from "../components/Sidebar";

export default function Home() {
  // Session management
  const [sessions, setSessions] = useState([]);
  const [currentSessionId, setCurrentSessionId] = useState(null);
  const [messages, setMessages] = useState([]);
  const [sidebarOpen, setSidebarOpen] = useState(false);
  
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
    
    try {
      const res = await fetch(`/api/chat`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ 
          prompt,
          session_id: currentSessionId 
        }),
      });
      
      if (!res.ok) {
        throw new Error(`Request failed: ${res.status}`);
      }
      
      const data = await res.json();
      console.log("Received response:", data);
      
      // Update or set current session
      const newSessionId = data.session_id;
      const isFirstMessage = messages.length === 0; // Check BEFORE updating state
      if (!currentSessionId) {
        setCurrentSessionId(newSessionId);
      }
      
      // Add message to local state
      const newMessage = {
        id: data.message_id,
        session_id: newSessionId,
        prompt: prompt,
        reply: data.reply,
        created_at: new Date().toISOString(),
      };
      console.log("Adding message to state:", newMessage);
      setMessages(prevMessages => {
        console.log("Previous messages:", prevMessages);
        const newState = [...prevMessages, newMessage];
        console.log("New messages state:", newState);
        return newState;
      });
      
      // Clear prompt
      setPrompt("");
      
      // Reload sessions list
      await loadSessions();
      
      // Generate title if this is the first message
      if (isFirstMessage) {
        setTimeout(() => generateTitle(newSessionId), 1000);
      }
      
    } catch (err) {
      console.error("Chat error", err);
      setError("Something went wrong. Check backend or OpenAI key.");
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
        isOpen={sidebarOpen}
        onToggle={() => setSidebarOpen(!sidebarOpen)}
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


