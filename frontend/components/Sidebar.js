import { useState, useRef } from 'react';
import styles from '../styles/Sidebar.module.css';

export default function Sidebar({ 
  sessions, 
  currentSessionId, 
  onSessionSelect, 
  onNewChat, 
  onDeleteSession,
  onDeleteAllSessions,
  isOpen,
  onToggle,
  onChaosToggle
}) {
  const [deletingId, setDeletingId] = useState(null);
  const [deletingAll, setDeletingAll] = useState(false);
  const clickCountRef = useRef(0);
  const clickTimeoutRef = useRef(null);

  const handleDelete = async (sessionId, e) => {
    e.stopPropagation();
    if (!confirm('Delete this conversation?')) return;
    
    setDeletingId(sessionId);
    await onDeleteSession(sessionId);
    setDeletingId(null);
  };

  const handleDeleteAll = async () => {
    if (sessions.length === 0) return;
    
    const count = sessions.length;
    if (!confirm(`Delete all ${count} conversation(s)? This cannot be undone.`)) return;
    
    setDeletingAll(true);
    try {
      await onDeleteAllSessions();
    } catch (err) {
      console.error('Failed to delete all sessions', err);
      alert('Failed to delete conversations. Please try again.');
    } finally {
      setDeletingAll(false);
    }
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

  const handleBrandingClick = () => {
    clickCountRef.current += 1;
    
    // Clear any existing timeout
    if (clickTimeoutRef.current) {
      clearTimeout(clickTimeoutRef.current);
    }
    
    // Triple-click detected!
    if (clickCountRef.current === 3) {
      clickCountRef.current = 0;
      if (onChaosToggle) {
        onChaosToggle();
      }
    } else {
      // Reset counter after 1 second
      clickTimeoutRef.current = setTimeout(() => {
        clickCountRef.current = 0;
      }, 1000);
    }
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
          {sessions.length > 0 && (
            <button 
              className={styles.deleteAllBtn} 
              onClick={handleDeleteAll}
              disabled={deletingAll}
              title="Delete all conversations"
            >
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <polyline points="3 6 5 6 21 6"></polyline>
                <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
                <line x1="10" y1="11" x2="10" y2="17"></line>
                <line x1="14" y1="11" x2="14" y2="17"></line>
              </svg>
              {deletingAll ? 'Deleting...' : 'Delete all'}
            </button>
          )}
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
          <div 
            className={styles.branding}
            onClick={handleBrandingClick}
            title="Triple-click for easter egg..."
          >
            Datadog Chatbot Demo
          </div>
        </div>
      </div>
    </>
  );
}

