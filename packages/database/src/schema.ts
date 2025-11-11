import { pgTable, serial, varchar, timestamp, jsonb, integer, text, boolean, decimal } from 'drizzle-orm/pg-core';

// Basic user schema (will be extended in Stage 2)
export const users = pgTable('users', {
  id: serial('id').primaryKey(),
  email: varchar('email', { length: 255 }).notNull().unique(),
  name: varchar('name', { length: 255 }).notNull(),
  role: varchar('role', { length: 50 }).default('USER'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

// Basic session storage
export const sessions = pgTable('sessions', {
  id: varchar('id', { length: 255 }).primaryKey(),
  userId: integer('user_id').references(() => users.id),
  expiresAt: timestamp('expires_at').notNull(),
  data: jsonb('data'),
});

// Additional tables will be added in Stage 2
// TODO: Add documents, conversations, audioRecordings, etc.