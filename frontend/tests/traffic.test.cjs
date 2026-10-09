const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../lib/traffic.js'), 'utf8');
const modulePromise = import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);

test('a live intensity change sends the selected level while keeping traffic enabled', async (t) => {
  const { updateTraffic } = await modulePromise;
  const fetch = t.mock.method(globalThis, 'fetch', async () => ({
    ok: true, json: async () => ({ enabled: true, level: 'heavy' }),
  }));
  assert.deepEqual(await updateTraffic(true, 'heavy'), { enabled: true, level: 'heavy' });
  const [url, options] = fetch.mock.calls[0].arguments;
  assert.equal(url, '/api/chaos/traffic');
  assert.equal(options.method, 'POST');
  assert.deepEqual(JSON.parse(options.body), { enabled: true, level: 'heavy' });
});

test('turning traffic off preserves the current intensity', async (t) => {
  const { updateTraffic } = await modulePromise;
  const fetch = t.mock.method(globalThis, 'fetch', async () => ({
    ok: true, json: async () => ({ enabled: false, level: 'medium' }),
  }));
  await updateTraffic(false, 'medium');
  assert.deepEqual(JSON.parse(fetch.mock.calls[0].arguments[1].body), {
    enabled: false, level: 'medium',
  });
});

test('HTTP errors reject the update instead of looking successful', async (t) => {
  const { updateTraffic } = await modulePromise;
  t.mock.method(globalThis, 'fetch', async () => ({
    ok: false, status: 502, json: async () => ({ error: 'Backend error' }),
  }));
  await assert.rejects(updateTraffic(true, 'heavy'), /Backend error/);
});

test('network errors reject the update', async (t) => {
  const { updateTraffic } = await modulePromise;
  t.mock.method(globalThis, 'fetch', async () => { throw new Error('Connection failed'); });
  await assert.rejects(updateTraffic(true, 'light'), /Connection failed/);
});
