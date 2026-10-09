import { useState, useEffect, useRef } from 'react';
import styles from './ChaosPanel.module.css';
import { updateTraffic } from '../lib/traffic';

export default function ChaosPanel({ isOpen, onClose }) {
  const [trafficEnabled, setTrafficEnabled] = useState(false);
  const [trafficLevel, setTrafficLevel] = useState('light');
  const [activeScenarios, setActiveScenarios] = useState([]);
  const [status, setStatus] = useState({});
  const [trafficPending, setTrafficPending] = useState(false);
  const [trafficError, setTrafficError] = useState('');
  const trafficUpdating = useRef(false);
  const trafficRevision = useRef(0);

  useEffect(() => {
    if (isOpen) {
      fetchStatus();
      const interval = setInterval(fetchStatus, 3000);
      return () => clearInterval(interval);
    }
  }, [isOpen]);

  const fetchStatus = async () => {
    const revision = trafficRevision.current;
    const canUpdateTraffic = !trafficUpdating.current;
    try {
      const response = await fetch('/api/chaos/status');
      if (!response.ok) throw new Error('Unable to fetch chaos status');
      const data = await response.json();
      if (revision !== trafficRevision.current) return;
      setStatus(data);
      if (canUpdateTraffic && !trafficUpdating.current) {
        setTrafficEnabled(data.trafficEnabled || false);
        setTrafficLevel(data.trafficLevel || 'light');
      }
      setActiveScenarios(data.activeScenarios || []);
    } catch (error) {
      console.error('Failed to fetch chaos status:', error);
    }
  };

  const applyTraffic = async (enabled, level) => {
    if (trafficUpdating.current) return;
    trafficUpdating.current = true;
    trafficRevision.current += 1;
    setTrafficPending(true);
    setTrafficError('');
    try {
      const data = await updateTraffic(enabled, level);
      setTrafficEnabled(data.enabled);
      setTrafficLevel(data.level);
      await fetchStatus();
    } catch (error) {
      setTrafficError(error.message || 'Unable to update traffic');
    } finally {
      trafficUpdating.current = false;
      setTrafficPending(false);
    }
  };

  const triggerScenario = async (scenarioId) => {
    try {
      const response = await fetch('/api/chaos/scenario', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ scenario: scenarioId })
      });
      await response.json();
      fetchStatus();
    } catch (error) {
      console.error('Failed to trigger scenario:', error);
    }
  };

  const scenarios = [
    { 
      id: 'worker-crash', 
      name: 'Worker Crash', 
      desc: 'Scale worker to 0 replicas',
      severity: 'high'
    },
    { 
      id: 'db-slow', 
      name: 'Database Slowdown', 
      desc: 'Inject query delays',
      severity: 'medium'
    },
    { 
      id: 'memory-pressure', 
      name: 'Memory Pressure', 
      desc: 'Reduce backend memory limits',
      severity: 'high'
    },
    { 
      id: 'queue-backup', 
      name: 'Queue Backup', 
      desc: 'Pause message processing',
      severity: 'medium'
    },
    { 
      id: 'api-errors', 
      name: 'API Errors', 
      desc: 'Simulate OpenAI failures',
      severity: 'low'
    },
    { 
      id: 'network-latency', 
      name: 'Network Latency', 
      desc: 'Add 200ms+ delays',
      severity: 'medium'
    }
  ];

  if (!isOpen) return null;

  return (
    <div className={styles.overlay}>
      <div className={styles.panel}>
        <div className={styles.header}>
          <h2>🎮 Chaos Control Panel</h2>
          <button onClick={onClose} className={styles.closeBtn}>✕</button>
        </div>

        <div className={styles.content}>
          {/* Traffic Generation */}
          <section className={styles.section}>
            <h3>📊 Traffic Generation</h3>
            <div className={styles.control}>
              <label className={styles.toggle}>
                <input 
                  type="checkbox" 
                  checked={trafficEnabled}
                  onChange={() => applyTraffic(!trafficEnabled, trafficLevel)}
                  disabled={trafficPending}
                />
                <span className={styles.slider}></span>
                <span className={styles.label}>
                  {trafficEnabled ? 'Traffic ON' : 'Traffic OFF'}
                </span>
              </label>
            </div>
            {trafficError && <p role="alert">{trafficError}</p>}

            {trafficEnabled && (
              <div className={styles.trafficControls}>
                <label>Intensity:</label>
                <select 
                  value={trafficLevel} 
                  onChange={(e) => applyTraffic(true, e.target.value)}
                  disabled={trafficPending}
                  className={styles.select}
                >
                  <option value="light">Light (5 req/min)</option>
                  <option value="medium">Medium (20 req/min)</option>
                  <option value="heavy">Heavy (60 req/min)</option>
                </select>
                
                {status.trafficStats && (
                  <div className={styles.stats}>
                    <div>Requests sent: {status.trafficStats.total}</div>
                    <div>In flight: {status.trafficStats.inFlight || 0}</div>
                    <div>Completed: {status.trafficStats.completed || 0}</div>
                    <div>Failed: {status.trafficStats.failed || 0}</div>
                    <div>Skipped at capacity: {status.trafficStats.skipped || 0}</div>
                    <div>Success rate: {status.trafficStats.successRate}%</div>
                  </div>
                )}
              </div>
            )}
          </section>

          {/* Break-Fix Scenarios */}
          <section className={styles.section}>
            <h3>💥 Break-Fix Scenarios</h3>
            <div className={styles.scenarios}>
              {scenarios.map((scenario) => {
                const isActive = activeScenarios.includes(scenario.id);
                return (
                  <div key={scenario.id} className={styles.scenario}>
                    <div className={styles.scenarioHeader}>
                      <span className={`${styles.badge} ${styles[scenario.severity]}`}>
                        {scenario.severity}
                      </span>
                      <strong>{scenario.name}</strong>
                    </div>
                    <div className={styles.scenarioDesc}>{scenario.desc}</div>
                    <button
                      onClick={() => triggerScenario(scenario.id)}
                      className={`${styles.scenarioBtn} ${isActive ? styles.active : ''}`}
                      disabled={isActive}
                    >
                      {isActive ? '🔴 Active' : '▶️ Trigger'}
                    </button>
                  </div>
                );
              })}
            </div>
          </section>

          {/* System Status */}
          <section className={styles.section}>
            <h3>📡 System Status</h3>
            <div className={styles.statusGrid}>
              <div className={styles.statusItem}>
                <span className={styles.statusLabel}>Backend</span>
                <span className={`${styles.statusDot} ${status.backend === 'healthy' ? styles.green : styles.red}`}></span>
              </div>
              <div className={styles.statusItem}>
                <span className={styles.statusLabel}>Worker</span>
                <span className={`${styles.statusDot} ${status.worker === 'healthy' ? styles.green : styles.red}`}></span>
              </div>
              <div className={styles.statusItem}>
                <span className={styles.statusLabel}>Database</span>
                <span className={`${styles.statusDot} ${status.database === 'healthy' ? styles.green : styles.red}`}></span>
              </div>
              <div className={styles.statusItem}>
                <span className={styles.statusLabel}>RabbitMQ</span>
                <span className={`${styles.statusDot} ${status.rabbitmq === 'healthy' ? styles.green : styles.red}`}></span>
              </div>
            </div>
          </section>

          {/* Quick Actions */}
          <section className={styles.section}>
            <h3>🔧 Quick Actions</h3>
            <div className={styles.actions}>
              <button 
                onClick={() => triggerScenario('heal-all')}
                className={styles.actionBtn}
              >
                🩹 Heal All
              </button>
              <button 
                onClick={() => triggerScenario('restart-all')}
                className={styles.actionBtn}
              >
                🔄 Restart Services
              </button>
            </div>
          </section>
        </div>

        <div className={styles.footer}>
          <small>⚠️ Chaos mode active - For demo purposes only</small>
        </div>
      </div>
    </div>
  );
}








