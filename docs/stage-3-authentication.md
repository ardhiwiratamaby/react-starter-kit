# Stage 3: Authentication System Adaptation

## Stage Overview

This stage adapts the Better Auth system from the React Starter Kit to work within our Docker environment and extends it with features specific to the pronunciation assistant, including multi-tenant support, role-based access control, and email verification.

## Observable Outcomes

- ✅ Better Auth configured for Docker networking
- ✅ User registration and login flows working
- ✅ OAuth providers integrated (Google, GitHub)
- ✅ Email verification system operational
- ✅ Role-based access control implemented
- ✅ Session management with Redis
- ✅ Password reset functionality
- ✅ Admin authentication and permissions

## Technical Requirements

### Authentication Features
- Email/password authentication
- OAuth provider integration (Google, GitHub)
- Email verification for new accounts
- Password reset via email
- Multi-factor authentication (optional)
- Session management with Redis
- JWT token handling
- Role-based access control (USER/ADMIN)

### Security Requirements
- Secure session storage
- CSRF protection
- Rate limiting on auth endpoints
- Password strength validation
- Secure token generation
- Session expiration handling

## Implementation Details

### Step 1: Better Auth Configuration

#### 1.1 Authentication Setup
```typescript
// apps/api/src/lib/auth.ts
import { betterAuth } from "better-auth";
import { drizzleAdapter } from "better-auth/adapters/drizzle";
import { admin, openAPI } from "better-auth/plugins";
import { db } from "@repo/database";
import { sendEmail } from "./email";

export const auth = betterAuth({
  database: drizzleAdapter(db, {
    provider: "pg",
    schema: {
      users: {
        tableName: "users",
        id: "id",
        email: "email",
        name: "name",
        emailVerified: "emailVerified",
        role: "role",
        createdAt: "createdAt",
        updatedAt: "updatedAt",
      },
      sessions: {
        tableName: "user_sessions",
        id: "id",
        userId: "userId",
        token: "token",
        expiresAt: "expiresAt",
        ipAddress: "ipAddress",
        userAgent: "userAgent",
        createdAt: "createdAt",
        lastAccessed: "lastAccessed",
      }
    }
  }),

  emailAndPassword: {
    enabled: true,
    requireEmailVerification: true,
    minPasswordLength: 8,
    maxPasswordLength: 128,
    passwordHash: "bcrypt",
  },

  socialProviders: {
    google: {
      clientId: process.env.GOOGLE_CLIENT_ID!,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
      enabled: true,
    },
    github: {
      clientId: process.env.GITHUB_CLIENT_ID!,
      clientSecret: process.env.GITHUB_CLIENT_SECRET!,
      enabled: true,
    },
  },

  session: {
    expiresIn: 60 * 60 * 24 * 7, // 7 days
    updateAge: 60 * 60 * 24, // 1 day
    cookieCache: {
      enabled: true,
      maxAge: 5 * 60, // 5 minutes
    }
  },

  emailVerification: {
    sendOnSignUp: true,
    expiresIn: 60 * 60 * 24, // 24 hours
    sendVerificationEmail: async ({ user, url }) => {
      await sendEmail({
        to: user.email,
        subject: "Verify your Pronunciation Assistant account",
        template: "email-verification",
        props: {
          name: user.name,
          verificationUrl: url,
        },
      });
    },
  },

  passwordReset: {
    sendResetPassword: async ({ user, url }) => {
      await sendEmail({
        to: user.email,
        subject: "Reset your Pronunciation Assistant password",
        template: "password-reset",
        props: {
          name: user.name,
          resetUrl: url,
        },
      });
    },
    expiresIn: 60 * 60 * 1, // 1 hour
  },

  advanced: {
    generateId: false, // Use UUID from database
    crossSubDomainCookies: {
      enabled: false,
    },
    trustedOrigins: [
      "http://localhost:3000",
      "https://yourdomain.com",
    ],
  },

  plugins: [
    admin(),
    openAPI(),
  ],
});
```

#### 1.2 Docker Environment Configuration
```typescript
// apps/api/src/lib/auth-config.ts
import { auth } from "./auth";

export const authConfig = {
  baseURL: process.env.BETTER_AUTH_URL || "http://localhost:4000",
  secret: process.env.BETTER_AUTH_SECRET!,
  trustedOrigins: [
    process.env.FRONTEND_URL || "http://localhost:3000",
  ],
  cookies: {
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    httpOnly: true,
    maxAge: 60 * 60 * 24 * 7, // 7 days
  },
  session: {
    store: "redis", // Use Redis for session storage
    redis: {
      host: process.env.REDIS_HOST || "localhost",
      port: parseInt(process.env.REDIS_PORT || "6379"),
      password: process.env.REDIS_PASSWORD,
      db: 0,
    },
  },
};
```

### Step 2: tRPC Authentication Integration

#### 2.1 Auth Middleware
```typescript
// apps/api/src/middleware/auth.ts
import { auth } from "../lib/auth";
import { TRPCError } from "@trpc/server";
import { Context } from "../trpc";

export const enforceAuth = async (ctx: Context) => {
  const session = await auth.api.getSession({
    headers: ctx.req.headers(),
  });

  if (!session) {
    throw new TRPCError({
      code: "UNAUTHORIZED",
      message: "You must be logged in to access this resource",
    });
  }

  return {
    user: session.user,
    session: session.session,
  };
};

export const enforceAdmin = async (ctx: Context) => {
  const authData = await enforceAuth(ctx);

  if (authData.user.role !== "ADMIN") {
    throw new TRPCError({
      code: "FORBIDDEN",
      message: "Admin access required",
    });
  }

  return authData;
};

export const optionalAuth = async (ctx: Context) => {
  try {
    const session = await auth.api.getSession({
      headers: ctx.req.headers(),
    });
    return session || null;
  } catch {
    return null;
  }
};
```

#### 2.2 Authenticated Procedures
```typescript
// apps/api/src/router/auth.ts
import { router, publicProcedure, protectedProcedure } from "./trpc";
import { z } from "zod";
import { TRPCError } from "@trpc/server";
import { auth } from "../lib/auth";
import { enforceAuth, enforceAdmin } from "../middleware/auth";

export const authRouter = router({
  // Get current user
  me: publicProcedure.query(async ({ ctx }) => {
    const session = await auth.api.getSession({
      headers: ctx.req.headers(),
    });
    return session;
  }),

  // Sign up with email/password
  signUp: publicProcedure
    .input(z.object({
      email: z.string().email(),
      password: z.string().min(8),
      name: z.string().min(2),
    }))
    .mutation(async ({ input }) => {
      try {
        const user = await auth.api.signUpEmail({
          body: input,
        });
        return { success: true, user };
      } catch (error) {
        throw new TRPCError({
          code: "BAD_REQUEST",
          message: error instanceof Error ? error.message : "Sign up failed",
        });
      }
    }),

  // Sign in with email/password
  signIn: publicProcedure
    .input(z.object({
      email: z.string().email(),
      password: z.string(),
    }))
    .mutation(async ({ input, ctx }) => {
      try {
        const session = await auth.api.signInEmail({
          body: input,
          headers: ctx.req.headers(),
        });
        return { success: true, session };
      } catch (error) {
        throw new TRPCError({
          code: "UNAUTHORIZED",
          message: "Invalid email or password",
        });
      }
    }),

  // Sign out
  signOut: protectedProcedure.mutation(async ({ ctx }) => {
    await auth.api.signOut({
      headers: ctx.req.headers(),
    });
    return { success: true };
  }),

  // Admin only: Get all users
  getAllUsers: protectedProcedure
    .use(enforceAdmin)
    .input(z.object({
      page: z.number().min(1).default(1),
      limit: z.number().min(1).max(100).default(20),
      search: z.string().optional(),
    }))
    .query(async ({ input }) => {
      // Implementation for getting paginated users
      return {
        users: [],
        total: 0,
        page: input.page,
        limit: input.limit,
      };
    }),

  // Admin only: Update user role
  updateUserRole: protectedProcedure
    .use(enforceAdmin)
    .input(z.object({
      userId: z.string().uuid(),
      role: z.enum(["USER", "ADMIN"]),
    }))
    .mutation(async ({ input }) => {
      // Implementation for updating user role
      return { success: true };
    }),
});
```

### Step 3: Email Service Integration

#### 3.1 Email Configuration
```typescript
// apps/api/src/lib/email.ts
import React from "react";
import { render } from "@react-email/render";
import { Resend } from "resend";

const resend = new Resend(process.env.RESEND_API_KEY);

interface EmailProps {
  to: string | string[];
  subject: string;
  template: string;
  props?: Record<string, any>;
}

export const sendEmail = async ({ to, subject, template, props }: EmailProps) => {
  try {
    let emailHtml: string;

    switch (template) {
      case "email-verification":
        emailHtml = render(<EmailVerificationEmail {...props} />);
        break;
      case "password-reset":
        emailHtml = render(<PasswordResetEmail {...props} />);
        break;
      case "welcome":
        emailHtml = render(<WelcomeEmail {...props} />);
        break;
      default:
        throw new Error(`Unknown email template: ${template}`);
    }

    const { data, error } = await resend.emails.send({
      from: process.env.FROM_EMAIL || "onboarding@pronunciation-assistant.com",
      to: Array.isArray(to) ? to : [to],
      subject,
      html: emailHtml,
    });

    if (error) {
      console.error("Email send error:", error);
      throw error;
    }

    return data;
  } catch (error) {
    console.error("Failed to send email:", error);
    throw error;
  }
};
```

#### 3.2 Email Templates
```typescript
// apps/api/src/email-templates/index.tsx
import React from "react";

// Email Verification Template
export const EmailVerificationEmail: React.FC<{
  name: string;
  verificationUrl: string;
}> = ({ name, verificationUrl }) => (
  <div style={{ fontFamily: "Arial, sans-serif", maxWidth: "600px", margin: "0 auto" }}>
    <h2>Welcome to Pronunciation Assistant, {name}!</h2>
    <p>Thank you for signing up. To get started, please verify your email address by clicking the button below:</p>
    <div style={{ textAlign: "center", margin: "30px 0" }}>
      <a
        href={verificationUrl}
        style={{
          backgroundColor: "#007bff",
          color: "white",
          padding: "12px 24px",
          textDecoration: "none",
          borderRadius: "6px",
          display: "inline-block",
        }}
      >
        Verify Email Address
      </a>
    </div>
    <p>This link will expire in 24 hours. If you didn't create an account, you can safely ignore this email.</p>
    <p>Best regards,<br />The Pronunciation Assistant Team</p>
  </div>
);

// Password Reset Template
export const PasswordResetEmail: React.FC<{
  name: string;
  resetUrl: string;
}> = ({ name, resetUrl }) => (
  <div style={{ fontFamily: "Arial, sans-serif", maxWidth: "600px", margin: "0 auto" }}>
    <h2>Password Reset Request</h2>
    <p>Hi {name},</p>
    <p>We received a request to reset your password for your Pronunciation Assistant account. Click the button below to reset it:</p>
    <div style={{ textAlign: "center", margin: "30px 0" }}>
      <a
        href={resetUrl}
        style={{
          backgroundColor: "#dc3545",
          color: "white",
          padding: "12px 24px",
          textDecoration: "none",
          borderRadius: "6px",
          display: "inline-block",
        }}
      >
        Reset Password
      </a>
    </div>
    <p>This link will expire in 1 hour. If you didn't request a password reset, you can safely ignore this email.</p>
    <p>Best regards,<br />The Pronunciation Assistant Team</p>
  </div>
);

// Welcome Email Template
export const WelcomeEmail: React.FC<{
  name: string;
  loginUrl: string;
}> = ({ name, loginUrl }) => (
  <div style={{ fontFamily: "Arial, sans-serif", maxWidth: "600px", margin: "0 auto" }}>
    <h2>Welcome to Pronunciation Assistant! 🎉</h2>
    <p>Hi {name},</p>
    <p>Your email has been successfully verified! You're now ready to start improving your English pronunciation with our AI-powered assistant.</p>
    <h3>What you can do:</h3>
    <ul>
      <li>Upload documents and generate conversation scripts</li>
      <li>Practice pronunciation with interactive conversations</li>
      <li>Get instant AI feedback on your speaking</li>
      <li>Track your progress over time</li>
    </ul>
    <div style={{ textAlign: "center", margin: "30px 0" }}>
      <a
        href={loginUrl}
        style={{
          backgroundColor: "#28a745",
          color: "white",
          padding: "12px 24px",
          textDecoration: "none",
          borderRadius: "6px",
          display: "inline-block",
        }}
      >
        Get Started
      </a>
    </div>
    <p>If you have any questions, feel free to contact our support team.</p>
    <p>Best regards,<br />The Pronunciation Assistant Team</p>
  </div>
);
```

### Step 4: Frontend Authentication Integration

#### 4.1 Auth Context Setup
```typescript
// apps/app/src/contexts/AuthContext.tsx
import React, { createContext, useContext, useEffect, useState } from "react";
import { createClient } from "@trpc/client";
import { authRouter } from "@repo/api/src/router/auth";

interface AuthContextType {
  user: any | null;
  loading: boolean;
  signIn: (email: string, password: string) => Promise<void>;
  signUp: (email: string, password: string, name: string) => Promise<void>;
  signOut: () => Promise<void>;
  refreshUser: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<any | null>(null);
  const [loading, setLoading] = useState(true);

  const trpc = createClient({
    links: [
      // Your tRPC links configuration
    ],
  });

  const refreshUser = async () => {
    try {
      const session = await trpc.auth.me.query();
      setUser(session?.user || null);
    } catch (error) {
      setUser(null);
    } finally {
      setLoading(false);
    }
  };

  const signIn = async (email: string, password: string) => {
    await trpc.auth.signIn.mutate({ email, password });
    await refreshUser();
  };

  const signUp = async (email: string, password: string, name: string) => {
    await trpc.auth.signUp.mutate({ email, password, name });
    // Note: User will need to verify email before signing in
  };

  const signOut = async () => {
    await trpc.auth.signOut.mutate();
    setUser(null);
  };

  useEffect(() => {
    refreshUser();
  }, []);

  return (
    <AuthContext.Provider value={{
      user,
      loading,
      signIn,
      signUp,
      signOut,
      refreshUser,
    }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
};
```

#### 4.2 Auth Components
```typescript
// apps/app/src/components/auth/LoginForm.tsx
import React, { useState } from "react";
import { useAuth } from "../../contexts/AuthContext";
import { Button } from "@repo/ui/components/button";
import { Input } from "@repo/ui/components/input";
import { Card, CardContent, CardHeader, CardTitle } from "@repo/ui/components/card";

export const LoginForm: React.FC = () => {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const { signIn } = useAuth();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError("");

    try {
      await signIn(email, password);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Login failed");
    } finally {
      setLoading(false);
    }
  };

  return (
    <Card className="w-full max-w-md">
      <CardHeader>
        <CardTitle>Sign In</CardTitle>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <Input
              type="email"
              placeholder="Email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
          </div>
          <div>
            <Input
              type="password"
              placeholder="Password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
          </div>
          {error && (
            <div className="text-red-600 text-sm">{error}</div>
          )}
          <Button type="submit" className="w-full" disabled={loading}>
            {loading ? "Signing in..." : "Sign In"}
          </Button>
        </form>

        <div className="mt-6 space-y-2">
          <div className="text-center text-sm text-gray-600">
            Or continue with
          </div>
          <div className="space-y-2">
            <Button variant="outline" className="w-full">
              Sign in with Google
            </Button>
            <Button variant="outline" className="w-full">
              Sign in with GitHub
            </Button>
          </div>
        </div>
      </CardContent>
    </Card>
  );
};
```

### Step 5: Protected Routes and Admin Access

#### 5.1 Route Protection
```typescript
// apps/app/src/components/auth/ProtectedRoute.tsx
import React from "react";
import { useAuth } from "../../contexts/AuthContext";
import { Loader2 } from "lucide-react";

interface ProtectedRouteProps {
  children: React.ReactNode;
  adminOnly?: boolean;
}

export const ProtectedRoute: React.FC<ProtectedRouteProps> = ({
  children,
  adminOnly = false
}) => {
  const { user, loading } = useAuth();

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <Loader2 className="h-8 w-8 animate-spin" />
      </div>
    );
  }

  if (!user) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-center">
          <h1 className="text-2xl font-bold mb-4">Authentication Required</h1>
          <p className="text-gray-600 mb-4">Please sign in to access this page.</p>
          {/* Redirect to login or show login form */}
        </div>
      </div>
    );
  }

  if (adminOnly && user.role !== "ADMIN") {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-center">
          <h1 className="text-2xl font-bold mb-4">Access Denied</h1>
          <p className="text-gray-600">You don't have permission to access this page.</p>
        </div>
      </div>
    );
  }

  return <>{children}</>;
};
```

#### 5.2 Admin Dashboard Integration
```typescript
// apps/app/src/pages/admin/Dashboard.tsx
import React from "react";
import { ProtectedRoute } from "../../components/auth/ProtectedRoute";
import { AdminLayout } from "../../components/admin/AdminLayout";

export const AdminDashboard: React.FC = () => {
  return (
    <ProtectedRoute adminOnly>
      <AdminLayout>
        <div className="p-6">
          <h1 className="text-3xl font-bold mb-6">Admin Dashboard</h1>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
            <div className="bg-white p-6 rounded-lg shadow">
              <h3 className="text-lg font-semibold mb-2">Total Users</h3>
              <p className="text-3xl font-bold text-blue-600">1,234</p>
            </div>
            <div className="bg-white p-6 rounded-lg shadow">
              <h3 className="text-lg font-semibold mb-2">Active Sessions</h3>
              <p className="text-3xl font-bold text-green-600">456</p>
            </div>
            <div className="bg-white p-6 rounded-lg shadow">
              <h3 className="text-lg font-semibold mb-2">Documents Uploaded</h3>
              <p className="text-3xl font-bold text-purple-600">7,890</p>
            </div>
            <div className="bg-white p-6 rounded-lg shadow">
              <h3 className="text-lg font-semibold mb-2">Conversations</h3>
              <p className="text-3xl font-bold text-orange-600">12,345</p>
            </div>
          </div>

          {/* Admin content here */}
        </div>
      </AdminLayout>
    </ProtectedRoute>
  );
};
```

## Testing Strategy

### Authentication Tests
```typescript
// apps/api/src/__tests__/auth.test.ts
import { describe, it, expect, beforeEach } from "vitest";
import { auth } from "../lib/auth";

describe("Authentication", () => {
  beforeEach(async () => {
    // Clean up test data
  });

  it("should sign up a new user", async () => {
    const result = await auth.api.signUpEmail({
      body: {
        email: "test@example.com",
        password: "password123",
        name: "Test User",
      },
    });

    expect(result.user).toBeDefined();
    expect(result.user.email).toBe("test@example.com");
  });

  it("should sign in with valid credentials", async () => {
    // First sign up
    await auth.api.signUpEmail({
      body: {
        email: "test@example.com",
        password: "password123",
        name: "Test User",
      },
    });

    // Then sign in
    const session = await auth.api.signInEmail({
      body: {
        email: "test@example.com",
        password: "password123",
      },
    });

    expect(session.user).toBeDefined();
    expect(session.session).toBeDefined();
  });

  it("should reject invalid credentials", async () => {
    await expect(auth.api.signInEmail({
      body: {
        email: "test@example.com",
        password: "wrongpassword",
      },
    })).rejects.toThrow();
  });
});
```

### Integration Tests
```bash
# Test authentication flow
docker-compose -f docker-compose.dev.yml exec api bun run test:auth

# Test email sending
docker-compose -f docker-compose.dev.yml exec api bun run test:email

# Test session management
docker-compose -f docker-compose.dev.yml exec api bun run test:sessions
```

## Security Considerations

### Rate Limiting
```typescript
// apps/api/src/middleware/rateLimit.ts
import rateLimit from "express-rate-limit";

export const authRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: {
    error: "Too many requests from this IP, please try again later.",
  },
});

export const passwordRateLimit = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 5, // Limit each IP to 5 password reset requests per hour
  message: {
    error: "Too many password reset attempts, please try again later.",
  },
});
```

### Password Strength Validation
```typescript
// apps/api/src/lib/password-validation.ts
export const validatePassword = (password: string): { valid: boolean; errors: string[] } => {
  const errors: string[] = [];

  if (password.length < 8) {
    errors.push("Password must be at least 8 characters long");
  }

  if (password.length > 128) {
    errors.push("Password must be less than 128 characters long");
  }

  if (!/[A-Z]/.test(password)) {
    errors.push("Password must contain at least one uppercase letter");
  }

  if (!/[a-z]/.test(password)) {
    errors.push("Password must contain at least one lowercase letter");
  }

  if (!/[0-9]/.test(password)) {
    errors.push("Password must contain at least one number");
  }

  if (!/[^A-Za-z0-9]/.test(password)) {
    errors.push("Password must contain at least one special character");
  }

  return {
    valid: errors.length === 0,
    errors,
  };
};
```

## Estimated Timeline: 1 Week

### Day 1-2: Basic Authentication Setup
- Configure Better Auth for Docker environment
- Set up email/password authentication
- Integrate with tRPC router

### Day 3-4: OAuth and Email System
- Implement Google and GitHub OAuth
- Set up email verification system
- Create password reset functionality

### Day 5: Advanced Features and Testing
- Implement role-based access control
- Set up admin authentication
- Test all authentication flows
- Document authentication API

## Success Criteria

- [ ] Users can sign up with email/password
- [ ] Email verification works correctly
- [ ] Users can sign in with valid credentials
- [ ] OAuth providers (Google, GitHub) work
- [ ] Password reset functionality operational
- [ ] Session management with Redis working
- [ ] Role-based access control enforced
- [ ] Admin authentication and permissions working
- [ ] Rate limiting on auth endpoints
- [ ] Email templates render correctly
- [ ] Protected routes enforce authentication
- [ ] All authentication flows tested

## Troubleshooting

### Common Issues
1. **Docker networking** - Ensure auth service can reach other containers
2. **Environment variables** - Check all required auth env vars are set
3. **Email service** - Verify Resend API key and configuration
4. **Redis connection** - Ensure Redis is accessible for session storage
5. **CORS issues** - Configure trusted origins properly

### Debug Commands
```bash
# Check auth service logs
docker-compose -f docker-compose.dev.yml logs -f api

# Test Redis connection
docker-compose -f docker-compose.dev.yml exec redis redis-cli ping

# Test email service
curl -X POST http://localhost:4000/auth/test-email

# Check session storage
docker-compose -f docker-compose.dev.yml exec redis keys "*"
```

This comprehensive authentication system provides secure user management with modern features while integrating seamlessly with the React Starter Kit foundation and Docker environment.