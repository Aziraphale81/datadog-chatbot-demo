const required = ["NEXT_PUBLIC_DD_CLIENT_TOKEN", "NEXT_PUBLIC_DD_APP_ID"];
const missing = required.filter((name) => !process.env[name]?.trim());

if (missing.length) {
  console.error(
    `Frontend build aborted: missing ${missing.join(", ")}. ` +
      "Set rum-client-token and rum-app-id in the chat-demo/datadog-keys secret " +
      "and pass them as Docker build arguments. Next.js embeds RUM configuration " +
      "at build time; pod environment variables cannot enable RUM after a build."
  );
  process.exit(1);
}
