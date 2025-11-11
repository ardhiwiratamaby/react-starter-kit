# apps/api/Dockerfile - Pronunciation Assistant Backend API
FROM oven/bun:1-alpine AS base

# Install dumb-init and jq for proper signal handling and JSON processing
RUN apk add --no-cache dumb-init jq

# Set environment variables
ENV NODE_ENV=production

WORKDIR /app
COPY package*.json ./
RUN bun install --frozen-lockfile

COPY . .

FROM base AS development
EXPOSE 4000
CMD ["bun", "run", "dev"]

FROM base AS production
RUN bun run build
EXPOSE 4000
CMD ["bun", "run", "start"]
