// Datadog Feature Flags (OpenFeature) + stable visitor identity for experiments.
//
// Why a visitor identity: experiments randomize on the subject (targetingKey) and
// join metrics on the RUM user id. A single hard-coded user would always land in
// the same variant, so each browser gets its own stable id instead.
//
// Demo override: open the app with ?as=<name> (for example ?as=captain) to become
// a named visitor. The name is remembered in localStorage until ?as=reset.
import { createContext, useContext, useEffect, useState } from "react";
import { OpenFeature } from "@openfeature/web-sdk";
import { DatadogProvider, withTimeout } from "@datadog/openfeature-browser";
import { datadogRum } from "@datadog/browser-rum";

const STORAGE_KEY = "chat_demo_visitor_id";

// Flag keys use underscores: RUM flag tracking rejects hyphens and dots.
export const FLAGS = {
  suggestedPrompts: "chat_suggested_prompts",
};

function randomId() {
  if (typeof crypto !== "undefined" && crypto.randomUUID) {
    return `visitor-${crypto.randomUUID().slice(0, 8)}`;
  }
  return `visitor-${Math.random().toString(36).slice(2, 10)}`;
}

function safeGet(key) {
  try {
    return window.localStorage.getItem(key);
  } catch (_) {
    return null;
  }
}

function safeSet(key, value) {
  try {
    if (value === null) window.localStorage.removeItem(key);
    else window.localStorage.setItem(key, value);
  } catch (_) {}
}

export function resolveVisitor() {
  const params = new URLSearchParams(window.location.search);
  const override = params.get("as");
  if (override === "reset") {
    safeSet(STORAGE_KEY, null);
  } else if (override) {
    const named = `visitor-${override.toLowerCase().replace(/[^a-z0-9_]/g, "")}`;
    safeSet(STORAGE_KEY, named);
    return named;
  }
  let id = safeGet(STORAGE_KEY);
  if (!id) {
    id = randomId();
    safeSet(STORAGE_KEY, id);
  }
  return id;
}

export async function initFlags({ visitorId, applicationId, clientToken, site, env, service, version }) {
  const provider = new DatadogProvider({
    applicationId,
    clientToken,
    site,
    env,
    service,
    version,
    enableExposureLogging: true,
    enableRumFeatureFlagTracking: true,
    flagConfigurationFetch: withTimeout(globalThis.fetch, 5_000),
  });
  await OpenFeature.setProviderAndWait(provider, {
    targetingKey: visitorId,
    user_id: visitorId,
    app: "chatbot-demo",
  });
}

// Evaluate a boolean flag and record it on RUM explicitly. The provider also does
// this automatically; the explicit call keeps it working across SDK versions.
export function evaluateBoolean(key, defaultValue = false) {
  const details = OpenFeature.getClient().getBooleanDetails(key, defaultValue);
  datadogRum.addFeatureFlagEvaluation(key, details.value);
  return details;
}

export const FlagsContext = createContext({ ready: false, visitorId: null });

export function useBooleanFlag(key, defaultValue = false) {
  const { ready } = useContext(FlagsContext);
  const [details, setDetails] = useState({ value: defaultValue, variant: "default" });

  useEffect(() => {
    if (!ready) return undefined;
    const update = () => setDetails(evaluateBoolean(key, defaultValue));
    update();
    // Pick up targeting changes made in the Datadog UI without a page reload.
    const client = OpenFeature.getClient();
    client.addHandler("PROVIDER_CONFIGURATION_CHANGED", update);
    return () => client.removeHandler("PROVIDER_CONFIGURATION_CHANGED", update);
  }, [ready, key, defaultValue]);

  return details;
}

export function useVisitor() {
  return useContext(FlagsContext).visitorId;
}
