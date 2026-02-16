FROM node:20-alpine AS build
WORKDIR /app

# Build args for Next.js NEXT_PUBLIC_* variables
ARG NEXT_PUBLIC_DD_CLIENT_TOKEN
ARG NEXT_PUBLIC_DD_APP_ID
ARG NEXT_PUBLIC_DD_SITE=datadoghq.com
ARG NEXT_PUBLIC_DD_SERVICE=chat-frontend
ARG NEXT_PUBLIC_DD_ENV=demo
ARG NEXT_PUBLIC_DD_VERSION=dev
ARG BACKEND_INTERNAL_BASE=http://backend.chat-demo.svc.cluster.local:8000

# Set as env vars for the build
ENV NEXT_PUBLIC_DD_CLIENT_TOKEN=$NEXT_PUBLIC_DD_CLIENT_TOKEN
ENV NEXT_PUBLIC_DD_APP_ID=$NEXT_PUBLIC_DD_APP_ID
ENV NEXT_PUBLIC_DD_SITE=$NEXT_PUBLIC_DD_SITE
ENV NEXT_PUBLIC_DD_SERVICE=$NEXT_PUBLIC_DD_SERVICE
ENV NEXT_PUBLIC_DD_ENV=$NEXT_PUBLIC_DD_ENV
ENV NEXT_PUBLIC_DD_VERSION=$NEXT_PUBLIC_DD_VERSION
ENV BACKEND_INTERNAL_BASE=$BACKEND_INTERNAL_BASE

COPY package.json package-lock.json* /app/
RUN npm install
COPY . /app
RUN npm run build

# Upload RUM source maps to Datadog when DD_API_KEY is provided (BuildKit secret).
# Secret is optional: no key => skip upload (no secrets leakage); with key => unminified Error Tracking.
RUN --mount=type=secret,id=DD_API_KEY,required=false \
  if [ -f /run/secrets/DD_API_KEY ]; then \
    export DATADOG_API_KEY=$(cat /run/secrets/DD_API_KEY) && \
    export DATADOG_SITE="${NEXT_PUBLIC_DD_SITE:-datadoghq.com}" && \
    npx datadog-ci sourcemaps upload .next/static \
      --service chat-frontend \
      --minified-path-prefix /_next/static \
      --release-version "${NEXT_PUBLIC_DD_VERSION:-dev}" \
      --disable-git && \
    echo "Source maps uploaded for version ${NEXT_PUBLIC_DD_VERSION:-dev}"; \
  else \
    echo "Skipping source map upload (DD_API_KEY not provided). RUM Error Tracking will show minified stack traces."; \
  fi

FROM node:20-alpine
WORKDIR /app
COPY --from=build /app ./
ENV NODE_ENV=production
ENV PORT=3000
EXPOSE 3000
CMD ["npm", "start"]


