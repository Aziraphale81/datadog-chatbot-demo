import { useState } from 'react';
import styles from '../styles/Sidebar.module.css';

export default function Sidebar({ 
  sessions, 
  currentSessionId, 
  onSessionSelect, 
  onNewChat, 
  onDeleteSession,
  isOpen,
  onToggle 
}) {
  const [deletingId, setDeletingId] = useState(null);

  const handleDelete = async (sessionId, e) => {
    e.stopPropagation();
    if (!confirm('Delete this conversation?')) return;
    
    setDeletingId(sessionId);
    await onDeleteSession(sessionId);
    setDeletingId(null);
  };

  const formatDate = (dateString) => {
    const date = new Date(dateString);
    const now = new Date();
    const diffMs = now - date;
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);

    if (diffMins < 60) return `${diffMins}m ago`;
    if (diffHours < 24) return `${diffHours}h ago`;
    if (diffDays < 7) return `${diffDays}d ago`;
    return date.toLocaleDateString();
  };

  return (
    <>
      {/* Mobile overlay */}
      {isOpen && (
        <div className={styles.overlay} onClick={onToggle} />
      )}
      
      {/* Sidebar */}
      <div className={`${styles.sidebar} ${isOpen ? styles.open : ''}`}>
        <div className={styles.header}>
          <button className={styles.newChatBtn} onClick={onNewChat}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <line x1="12" y1="5" x2="12" y2="19"></line>
              <line x1="5" y1="12" x2="19" y2="12"></line>
            </svg>
            New chat
          </button>
        </div>

        <div className={styles.sessionList}>
          {sessions.length === 0 && (
            <div className={styles.emptyState}>
              No conversations yet
            </div>
          )}
          
          {sessions.map((session) => (
            <div
              key={session.id}
              className={`${styles.sessionItem} ${
                session.id === currentSessionId ? styles.active : ''
              } ${deletingId === session.id ? styles.deleting : ''}`}
              onClick={() => onSessionSelect(session.id)}
            >
              <div className={styles.sessionContent}>
                <div className={styles.sessionTitle}>
                  {session.title || 'New conversation'}
                </div>
                <div className={styles.sessionMeta}>
                  {formatDate(session.updated_at)} · {session.message_count} msg
                </div>
              </div>
              
              <button
                className={styles.deleteBtn}
                onClick={(e) => handleDelete(session.id, e)}
                disabled={deletingId === session.id}
                title="Delete conversation"
              >
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <polyline points="3 6 5 6 21 6"></polyline>
                  <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
                </svg>
              </button>
            </div>
          ))}
        </div>

        <div className={styles.footer}>
          <div className={styles.branding}>
            Datadog Chatbot Demo
          </div>
        </div>
      </div>
    </>
  );
}

