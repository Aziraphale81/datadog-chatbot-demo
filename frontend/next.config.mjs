/** @type {import('next').NextConfig} */
const nextConfig = {
  output: "standalone",
  reactStrictMode: true,
  // Emit source maps for production JS so Datadog RUM Error Tracking can unminify stack traces.
  // Maps are uploaded at build time via datadog-ci; they are not served to browsers.
  productionBrowserSourceMaps: true,
  experimental: {
    instrumentationHook: true,
  },
};

export default nextConfig;


