#!/usr/bin/env bun

/**
 * Simple development server for the API using Bun.
 */

import { serve } from "bun";
import worker from "./worker-dev.js";

// Load environment variables from root directory
import { config } from "dotenv";

// Load .env from project root
config({ path: "../../.env" });

const port = 4000;

console.log(`🚀 Development API server starting on port ${port}`);
console.log(`📡 API available at: http://localhost:${port}`);
console.log(`🔐 Auth endpoints at: http://localhost:${port}/api/auth`);

// Start server
const server = serve({
  fetch: worker.fetch,
  port: port,
});

console.log(`✅ Development API server started successfully!`);
console.log(`📊 Using direct database connection (no Hyperdrive)`);

// Handle graceful shutdown
process.on("SIGINT", () => {
  console.log("\n🔄 Shutting down development server...");
  server.stop();
  console.log("✅ Server stopped gracefully");
  process.exit(0);
});
