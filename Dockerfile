FROM node:23.3.0-slim AS deps

# Set up the build environment
WORKDIR /app

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    python3 python3-pip make g++ curl \
    libssl-dev zlib1g-dev libbz2-dev \
    libreadline-dev libsqlite3-dev wget \
    libncursesw5-dev xz-utils tk-dev \
    libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev \
    libpixman-1-0 libpixman-1-dev pkg-config \
    tar gzip && \
    npm install -g pnpm@9.15.1 node-gyp && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create dist directory and set permissions
RUN mkdir -p dist /app/.cache && chown -R node:node /app
USER node

# Set environment variables for embedding
ENV USE_OPENAI_EMBEDDING_TYPE=false
ENV USE_OLLAMA_EMBEDDING_TYPE=false
ENV OLLAMA_EMBEDDING_MODEL=mxbai-embed-large
ENV NODE_OPTIONS="--max-old-space-size=4096"
ENV TS_NODE_TRANSPILE_ONLY=true
ENV NODE_ENV="production"

# Copy package files with correct ownership
COPY --chown=node:node package.json pnpm-lock.yaml ./
RUN pnpm install --prod

FROM node:23.3.0-slim AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    python3 python3-pip make g++ curl \
    libcairo2-dev libpango1.0-dev pkg-config \
    libssl-dev zlib1g-dev libbz2-dev \
    libreadline-dev libsqlite3-dev wget \
    libncursesw5-dev xz-utils tk-dev \
    libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev \
    libpixman-1-0 libpixman-1-dev \
    tar gzip && \
    npm install -g pnpm@9.15.1 node-gyp && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set ownership and switch to node user
RUN mkdir -p dist /app/.cache && chown -R node:node /app
USER node

# Set environment variables for embedding
ENV USE_OPENAI_EMBEDDING_TYPE=false
ENV USE_OLLAMA_EMBEDDING_TYPE=false
ENV OLLAMA_EMBEDDING_MODEL=mxbai-embed-large
ENV NODE_OPTIONS="--max-old-space-size=4096"
ENV TS_NODE_TRANSPILE_ONLY=true
ENV NODE_ENV="production"

# Copy node_modules from deps stage
COPY --chown=node:node --from=deps /app/node_modules ./node_modules

# Copy source files with correct ownership
COPY --chown=node:node . .

# Build the application
RUN pnpm install && \
    pnpm build

FROM node:23.3.0-slim

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    python3 curl \
    libcairo2 libpango1.0-0 \
    libssl3 zlib1g libbz2-1.0 \
    libreadline8 libsqlite3-0 \
    libncursesw6 liblzma5 \
    libpixman-1-0 \
    tar gzip && \
    npm install -g pnpm@9.15.1 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set up the runtime environment
WORKDIR /app
RUN mkdir -p dist /app/.cache && chown -R node:node /app
USER node

# Set environment variables for embedding
ENV USE_OPENAI_EMBEDDING_TYPE=false
ENV USE_OLLAMA_EMBEDDING_TYPE=false
ENV OLLAMA_EMBEDDING_MODEL=mxbai-embed-large
ENV NODE_OPTIONS="--max-old-space-size=4096"
ENV NODE_ENV="production"
ENV PORT=3000
ENV TS_NODE_TRANSPILE_ONLY=true

# Copy files from builder with correct ownership
COPY --chown=node:node --from=builder /app/package.json ./
COPY --chown=node:node --from=builder /app/pnpm-lock.yaml ./
COPY --chown=node:node --from=builder /app/dist ./dist
COPY --chown=node:node --from=builder /app/src ./src
COPY --chown=node:node --from=builder /app/characters ./characters
COPY --chown=node:node --from=builder /app/node_modules ./node_modules
COPY --chown=node:node --from=builder /app/tsconfig.json ./
COPY --chown=node:node --from=builder /app/.cache ./.cache

# Install dependencies
RUN pnpm install

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=60s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

CMD ["pnpm", "start:railway"]
