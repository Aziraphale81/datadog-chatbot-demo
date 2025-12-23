import { useEffect } from "react";
import { datadogRum } from "@datadog/browser-rum";
import { datadogLogs } from "@datadog/browser-logs";
import "../styles/globals.css";

const ddClientToken = process.env.NEXT_PUBLIC_DD_CLIENT_TOKEN;
const ddAppId = process.env.NEXT_PUBLIC_DD_APP_ID;
const ddSite = process.env.NEXT_PUBLIC_DD_SITE || "datadoghq.com";
const ddService = process.env.NEXT_PUBLIC_DD_SERVICE || "chat-frontend";
const ddEnv = process.env.NEXT_PUBLIC_DD_ENV || "dev";
const ddVersion = process.env.NEXT_PUBLIC_DD_VERSION || "1.0.0";

function MyApp({ Component, pageProps }) {
  useEffect(() => {
    if (!ddClientToken || !ddAppId) {
      console.warn("Datadog RUM not initialized: missing client token or app id");
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
      trackBfcacheViews: true,
      trackResources: true,
      trackLongTasks: true,
      trackInteractions: true,
      defaultPrivacyLevel: "mask-user-input",
      allowedTracingUrls: [
        { match: (url) => url.startsWith(window.location.origin), propagatorTypes: ["datadog"] }
      ],
    });

    datadogRum.setUser({
      id: "demo-user-123",
      name: "Demo User",
      email: "demo@example.com",
    });

    datadogRum.startSessionReplayRecording();

    datadogLogs.init({
      clientToken: ddClientToken,
      site: ddSite,
      forwardErrorsToLogs: true,
      sampleRate: 100,
      service: ddService,
      env: ddEnv,
    });
  }, []);

  return <Component {...pageProps} />;
}

export default MyApp;


