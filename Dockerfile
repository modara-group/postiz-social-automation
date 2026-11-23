
# ============================================
# Postiz Social Automation - Production
# Node 22.23.4 / pnpm 10.6.1
# ============================================

# Stage 1: Build
FROM node:22.23.4-bookworm-slim AS builder

WORKDIR /app

ENV PNPM_HOME=/pnpm \
    PATH=/pnpm:$PATH \
    CI=true \
    NEXT_TELEMETRY_DISABLED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    openssl \
    python3 \
    make \
    g++ \
    git \
    bash \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g pnpm@10.6.1

COPY . .

RUN pnpm install --frozen-lockfile

# Next.js build-time configuration
ARG NEXT_PUBLIC_BACKEND_URL
ARG NEXT_PUBLIC_UPLOAD_STATIC_DIRECTORY
ARG STORAGE_PROVIDER=local

ENV NEXT_PUBLIC_BACKEND_URL=${NEXT_PUBLIC_BACKEND_URL} \
    NEXT_PUBLIC_UPLOAD_STATIC_DIRECTORY=${NEXT_PUBLIC_UPLOAD_STATIC_DIRECTORY} \
    STORAGE_PROVIDER=${STORAGE_PROVIDER}

RUN NODE_OPTIONS="--max-old-space-size=6144" \
    pnpm run build


# Stage 2: Production
FROM node:22.23.4-bookworm-slim AS production

WORKDIR /app

ENV NODE_ENV=production \
    PNPM_HOME=/pnpm \
    PATH=/pnpm:$PATH \
    NEXT_TELEMETRY_DISABLED=1 \
    TZ=UTC

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    openssl \
    tini \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g pnpm@10.6.1

COPY --from=builder /app /app

# dotenv-cli expects a file.
# Actual configuration comes from Compose env_file.
RUN touch /app/.env

EXPOSE 3000 4200 3002

ENTRYPOINT ["/usr/bin/tini", "--"]

CMD ["pnpm", "--filter", "./apps/backend", "start"]
