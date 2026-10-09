export async function updateTraffic(enabled, level) {
  const response = await fetch('/api/chaos/traffic', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ enabled, level }),
  });
  const data = await response.json();
  if (!response.ok) {
    throw new Error(data.error || `Traffic update failed (${response.status})`);
  }
  return data;
}
