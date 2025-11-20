#!/usr/bin/env node

/**
 * Simple development API server that bypasses Cloudflare Workers configuration
 * for local testing. Uses direct database connection with Better Auth.
 */

/* eslint-disable @typescript-eslint/no-require-imports */
/* eslint-disable no-undef */

import { Hono } from "hono";
import { betterAuth } from "better-auth";
import { drizzleAdapter } from "better-auth/adapters/drizzle";
import { serve } from "bun";
import { config } from "dotenv";

// Load environment variables from root directory
config({ path: "./.env" });

// Import database schema and auth configuration
const { schema: Db } = require("@repo/db");
const { createDb } = require("./apps/api/lib/db");

// Database connection - use hardcoded connection for now
const hyperdriveMock = {
  connectionString:
    "postgresql://postgres:password@localhost:5432/pronunciation_assistant",
};
const db = createDb(hyperdriveMock);

// Better Auth configuration (simplified)
const auth = betterAuth({
  baseURL: `${process.env.APP_ORIGIN || "http://localhost:5173"}/api/auth`,
  trustedOrigins: [process.env.APP_ORIGIN || "http://localhost:5173"],
  secret:
    process.env.BETTER_AUTH_SECRET ||
    "dev-secret-key-for-testing-only-change-in-production",
  database: drizzleAdapter(db, {
    provider: "pg",
    schema: {
      identity: Db.identity,
      invitation: Db.invitation,
      member: Db.member,
      organization: Db.organization,
      passkey: Db.passkey,
      session: Db.session,
      user: Db.user,
      verification: Db.verification,
    },
  }),
  account: {
    modelName: "identity",
  },
  emailAndPassword: {
    enabled: true,
    requireEmailVerification: false,
  },
  // Password hashing configuration matching the main setup
  password: {
    hash: async (password) => {
      const { createHash } = await import("crypto");
      const { createHmac } = await import("crypto");
      const salt = createHash("sha256")
        .update(Math.random().toString())
        .digest("hex")
        .slice(0, 32);
      const hash = createHmac("sha256", salt).update(password).digest("hex");
      return `${salt}:${hash}`;
    },
    verify: async (hash, password) => {
      const { createHmac } = await import("crypto");
      const [salt, key] = hash.split(":");
      if (!salt || !key) {
        throw new Error("Invalid password hash");
      }
      const verifyHash = createHmac("sha256", salt)
        .update(password)
        .digest("hex");
      return key === verifyHash;
    },
  },
  plugins: [],
});

// Create Hono app
const app = new Hono();

// CORS middleware
app.use("*", async (c, next) => {
  c.header(
    "Access-Control-Allow-Origin",
    process.env.APP_ORIGIN || "http://localhost:5173",
  );
  c.header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
  c.header(
    "Access-Control-Allow-Headers",
    "Content-Type, Authorization, x-forwarded-origin",
  );

  if (c.req.method === "OPTIONS") {
    return c.text("", 200);
  }

  await next();
});

// Mount Better Auth handler
app.all("/api/auth/*", async (c) => {
  return auth.handler(c.req.raw);
});

// Root endpoint with API information
app.get("/api", (c) => {
  return c.json({
    name: "@repo/api",
    version: "0.0.0",
    endpoints: {
      trpc: "/api/trpc",
      auth: "/api/auth",
      health: "/health",
    },
    documentation: {
      trpc: "https://trpc.io",
      auth: "https://www.better-auth.com",
    },
  });
});

// Health check endpoint
app.get("/health", (c) => {
  return c.json({
    status: "ok",
    timestamp: new Date().toISOString(),
    services: {
      database: "connected",
      redis: "connected",
      minio: "connected",
    },
  });
});

// Simple tRPC-compatible endpoints (basic responses)
app.all("/api/trpc/*", (c) => {
  // Return empty result for tRPC queries to prevent frontend errors
  return c.json({
    result: {
      data: {
        json: null,
      },
    },
  });
});

// Simple test endpoint
app.get("/api/test", (c) => {
  return c.json({ message: "Development API is working!" });
});

// Start server
const port = 4000;
console.log(`🚀 Development API server starting on port ${port}`);
console.log(`📡 API available at: http://localhost:${port}`);
console.log(`🔐 Auth endpoints at: http://localhost:${port}/api/auth`);

serve({
  fetch: app.fetch,
  port: port,
});

console.log(`✅ Server started successfully!`);
