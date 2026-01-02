import { useState, useEffect } from 'react';
import styles from './ChaosPanel.module.css';

export default function ChaosPanel({ isOpen, onClose }) {
  const [trafficEnabled, setTrafficEnabled] = useState(false);
  const [trafficLevel, setTrafficLevel] = useState('light');
  const [activeScenarios, setActiveScenarios] = useState([]);
  const [status, setStatus] = useState({});

  useEffect(() => {
    if (isOpen) {
      fetchStatus();
      const interval = setInterval(fetchStatus, 3000);
      return () => clearInterval(interval);
    }
  }, [isOpen]);

  const fetchStatus = async () => {
    try {
      const response = await fetch('/api/chaos/status');
      const data = await response.json();
      setStatus(data);
      setTrafficEnabled(data.trafficEnabled || false);
      setActiveScenarios(data.activeScenarios || []);
    } catch (error) {
      console.error('Failed to fetch chaos status:', error);
    }
  };

  const toggleTraffic = async () => {
    try {
      const response = await fetch('/api/chaos/traffic', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          enabled: !trafficEnabled,
          level: trafficLevel 
        })
      });
      const data = await response.json();
      setTrafficEnabled(data.enabled);
    } catch (error) {
      console.error('Failed to toggle traffic:', error);
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
                  onChange={toggleTraffic}
                />
                <span className={styles.slider}></span>
                <span className={styles.label}>
                  {trafficEnabled ? 'Traffic ON' : 'Traffic OFF'}
                </span>
              </label>
            </div>

            {trafficEnabled && (
              <div className={styles.trafficControls}>
                <label>Intensity:</label>
                <select 
                  value={trafficLevel} 
                  onChange={(e) => setTrafficLevel(e.target.value)}
                  className={styles.select}
                >
                  <option value="light">Light (5 req/min)</option>
                  <option value="medium">Medium (20 req/min)</option>
                  <option value="heavy">Heavy (60 req/min)</option>
                </select>
                
                {status.trafficStats && (
                  <div className={styles.stats}>
                    <div>Requests sent: {status.trafficStats.total}</div>
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

