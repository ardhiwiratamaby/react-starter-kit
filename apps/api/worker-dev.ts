/**
 * Development worker for local testing without Hyperdrive.
 * Uses direct database connection instead of Cloudflare Workers bindings.
 */

import { Hono } from "hono";
import app from "./lib/app.js";
import { createAuth } from "./lib/auth.js";
import type { AppContext } from "./lib/context.js";
import { createDb } from "./lib/db.js";
import type { Env } from "./lib/env.js";

// Create a Hono app for development
const worker = new Hono<{
  Variables: AppContext["Variables"];
}>();

// Initialize shared context for all requests
worker.use("*", async (c, next) => {
  // Initialize database using direct connection for development
  const db = createDb(
    process.env.DATABASE_URL ||
      "postgresql://postgres:password@localhost:5432/pronunciation_assistant",
  );
  const dbDirect = db; // Use same connection for dev

  // Create environment for auth
  const env: Env = {
    APP_NAME: process.env.APP_NAME || "Pronunciation Assistant",
    APP_ORIGIN: process.env.APP_ORIGIN || "http://localhost:5173",
    BETTER_AUTH_SECRET: process.env.BETTER_AUTH_SECRET || "dev-secret-key",
    GOOGLE_CLIENT_ID: process.env.GOOGLE_CLIENT_ID || "",
    GOOGLE_CLIENT_SECRET: process.env.GOOGLE_CLIENT_SECRET || "",
    RESEND_API_KEY: process.env.RESEND_API_KEY || "",
    RESEND_EMAIL_FROM: process.env.RESEND_EMAIL_FROM || "",
    OPENAI_API_KEY: process.env.OPENAI_API_KEY || "",
  };

  // Initialize auth
  const auth = createAuth(db, env);

  // Set context variables
  c.set("db", db);
  c.set("dbDirect", dbDirect);
  c.set("auth", auth);

  await next();
});

// Add CORS headers
worker.use("*", async (c, next) => {
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

// Mount the core API app
worker.route("/", app);

export default worker;
