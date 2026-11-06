import { useEffect, useState } from "react";
import Head from "next/head";
import { datadogRum } from "@datadog/browser-rum";
import { datadogLogs } from "@datadog/browser-logs";
import { FlagsContext, initFlags, resolveVisitor } from "../lib/flags";
import "../styles/globals.css";

const ddClientToken = process.env.NEXT_PUBLIC_DD_CLIENT_TOKEN;
const ddAppId = process.env.NEXT_PUBLIC_DD_APP_ID;
const ddSite = process.env.NEXT_PUBLIC_DD_SITE || "datadoghq.com";
const ddService = process.env.NEXT_PUBLIC_DD_SERVICE || "chat-frontend";
const ddEnv = process.env.NEXT_PUBLIC_DD_ENV || "dev";
const ddVersion = process.env.NEXT_PUBLIC_DD_VERSION || "1.0.0";
// Feature Flags environment; defaults to the RUM env so exposures and RUM line up.
const ddFlagsEnv = process.env.NEXT_PUBLIC_DD_FLAGS_ENV || ddEnv;
// RUM remote configuration (SDK >= 7.13): settings enabled as overrides in
// Datadog win over the local values below. Optional; unset means local only.
const ddRumRemoteConfigId = process.env.NEXT_PUBLIC_DD_RUM_REMOTE_CONFIG_ID;

function MyApp({ Component, pageProps }) {
  const [flags, setFlags] = useState({ ready: false, visitorId: null });

  useEffect(() => {
    const visitorId = resolveVisitor();

    if (!ddClientToken || !ddAppId) {
      console.warn("Datadog RUM not initialized: missing client token or app id");
      setFlags({ ready: false, visitorId });
      return;
    }

    datadogRum.init({
      applicationId: ddAppId,
      clientToken: ddClientToken,
      site: ddSite,
      service: ddService,
      env: ddEnv,
      version: ddVersion,
      sessionSampleRate: 100,
      sessionReplaySampleRate: 100,
      trackResources: true,
      trackLongTasks: true,
      trackUserInteractions: true,
      defaultPrivacyLevel: "mask-user-input",
      allowedTracingUrls: [
        { match: (url) => url.startsWith(window.location.origin), propagatorTypes: ["datadog"] }
      ],
      ...(ddRumRemoteConfigId ? { remoteConfiguration: { id: ddRumRemoteConfigId } } : {}),
    });

    // The RUM user id must equal the flag targetingKey so experiment metrics
    // join to the right variant.
    datadogRum.setUser({
      id: visitorId,
      name: visitorId,
    });

    // Session Replay starts automatically for sampled sessions (no manual start),
    // so a remotely configured replay sample rate is respected.

    datadogLogs.init({
      clientToken: ddClientToken,
      site: ddSite,
      forwardErrorsToLogs: true,
      // v7: forwardErrorsToLogs no longer includes console.error; keep it.
      forwardConsoleLogs: ["error"],
      sessionSampleRate: 100,
      service: ddService,
      env: ddEnv,
    });

    initFlags({
      visitorId,
      applicationId: ddAppId,
      clientToken: ddClientToken,
      site: ddSite,
      env: ddFlagsEnv,
      service: ddService,
      version: ddVersion,
    })
      .catch((err) => console.warn("Feature flags unavailable, using defaults", err))
      .finally(() => setFlags({ ready: true, visitorId }));
  }, []);

  return (
    <>
      <Head>
        <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
        <link rel="alternate icon" href="/favicon.ico" />
      </Head>
      <FlagsContext.Provider value={flags}>
        <Component {...pageProps} />
      </FlagsContext.Provider>
    </>
  );
}

export default MyApp;


