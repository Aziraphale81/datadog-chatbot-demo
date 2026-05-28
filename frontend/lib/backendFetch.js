/**
 * Fetch backend with retries to tolerate brief unavailability (e.g. during restarts).
 * Retries on connection failure (ECONNREFUSED, fetch failed) and 5xx, up to maxRetries times.
 */
const DEFAULT_MAX_RETRIES = 3;
const RETRY_DELAY_MS = 1000;

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export async function fetchWithRetry(url, options = {}, maxRetries = DEFAULT_MAX_RETRIES) {
  let lastError;
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const response = await fetch(url, options);
      if (response.status >= 500 && attempt < maxRetries) {
        await sleep(RETRY_DELAY_MS);
        continue;
      }
      return response;
    } catch (err) {
      lastError = err;
      const isConnectionError =
        err.cause?.code === "ECONNREFUSED" ||
        err.message?.includes("fetch failed") ||
        err.message?.includes("ECONNREFUSED");
      if (isConnectionError && attempt < maxRetries) {
        await sleep(RETRY_DELAY_MS);
        continue;
      }
      throw err;
    }
  }
  throw lastError;
}
