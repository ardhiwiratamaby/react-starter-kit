/* SPDX-FileCopyrightText: 2014-present Kriasoft */
/* SPDX-License-Identifier: MIT */

import { useLoginForm } from "@/hooks/use-login-form";
import { Button, Card, CardContent, Input, cn } from "@repo/ui";
import { Eye, EyeOff, Key, Mail } from "lucide-react";
import { useState } from "react";
import type { ComponentProps } from "react";
import { OtpVerification } from "./otp-verification";
import { PasskeyLogin } from "./passkey-login";
import { SocialLogin } from "./social-login";

interface AuthFormContentProps {
  onSuccess?: () => void;
  className?: string;
  isExternallyLoading?: boolean;
}

function AuthFormContent({
  onSuccess,
  className,
  isExternallyLoading,
}: AuthFormContentProps) {
  const [showPassword, setShowPassword] = useState(false);

  const {
    email,
    password,
    authMode,
    isDisabled,
    error,
    showOtpInput,
    setEmail,
    setPassword,
    setAuthMode,
    handleSuccess,
    handleError,
    sendOtp,
    signInWithPassword,
    resetOtpFlow,
  } = useLoginForm({
    onSuccess,
    isExternallyLoading,
  });

  return (
    <div className={cn("flex flex-col gap-6", className)}>
      <div className="flex flex-col items-center text-center">
        <h1 className="text-2xl font-bold">Welcome</h1>
        <p className="text-muted-foreground text-balance">
          Sign in or create your account
        </p>
      </div>

      {/* Error message */}
      {error && (
        <div className="rounded-md bg-destructive/10 p-3 text-sm text-destructive">
          {error}
        </div>
      )}

      {/* Passkey Login - Primary CTA for returning users with passkeys */}
      <PasskeyLogin
        onSuccess={handleSuccess}
        onError={handleError}
        isDisabled={isDisabled}
      />

      {/* Google OAuth - Works for both new and existing accounts */}
      <SocialLogin onError={handleError} isDisabled={isDisabled} />

      {/* Divider - Uses pseudo-element for line-through effect */}
      <div className="relative text-center text-sm after:absolute after:inset-0 after:top-1/2 after:z-0 after:flex after:items-center after:border-t after:border-border">
        <span className="relative z-10 bg-background px-2 text-muted-foreground">
          Or continue with email
        </span>
      </div>

      {/* Email Form - Password or OTP authentication flow */}
      {!showOtpInput ? (
        <form
          onSubmit={authMode === "password" ? signInWithPassword : sendOtp}
          className="grid gap-3"
        >
          <Input
            type="email"
            placeholder="your@email.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            disabled={isDisabled}
            autoComplete="email webauthn"
            required
          />

          {/* Password field - only shown in password mode */}
          {authMode === "password" && (
            <div className="relative">
              <Input
                type={showPassword ? "text" : "password"}
                placeholder="Password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                disabled={isDisabled}
                autoComplete="current-password"
                required
              />
              <Button
                type="button"
                variant="ghost"
                size="sm"
                className="absolute right-0 top-0 h-full px-3 py-2 hover:bg-transparent"
                onClick={() => setShowPassword(!showPassword)}
                disabled={isDisabled}
              >
                {showPassword ? (
                  <EyeOff className="h-4 w-4" />
                ) : (
                  <Eye className="h-4 w-4" />
                )}
              </Button>
            </div>
          )}

          {/* Auth mode toggle */}
          <div className="flex items-center gap-2 text-sm">
            <Button
              type="button"
              variant={authMode === "password" ? "default" : "ghost"}
              size="sm"
              onClick={() => setAuthMode("password")}
              disabled={isDisabled}
              className="flex-1"
            >
              <Key className="mr-2 h-4 w-4" />
              Password
            </Button>
            <Button
              type="button"
              variant={authMode === "otp" ? "default" : "ghost"}
              size="sm"
              onClick={() => setAuthMode("otp")}
              disabled={isDisabled}
              className="flex-1"
            >
              <Mail className="mr-2 h-4 w-4" />
              Email Code
            </Button>
          </div>

          {/* Submit button */}
          <Button
            type="submit"
            variant="secondary"
            className="w-full"
            disabled={
              isDisabled || !email || (authMode === "password" && !password)
            }
          >
            {authMode === "password" ? (
              <Key className="mr-2 h-4 w-4" />
            ) : (
              <Mail className="mr-2 h-4 w-4" />
            )}
            {authMode === "password"
              ? "Sign in with password"
              : "Send email code"}
          </Button>
        </form>
      ) : (
        <OtpVerification
          email={email}
          onSuccess={handleSuccess}
          onError={handleError}
          onCancel={resetOtpFlow}
          isDisabled={isDisabled}
        />
      )}
    </div>
  );
}

interface LoginFormProps extends ComponentProps<"div"> {
  variant?: "page" | "modal";
  showTerms?: boolean;
  onSuccess?: () => void;
  isLoading?: boolean;
}

export function LoginForm({
  className,
  variant = "page",
  showTerms,
  onSuccess,
  isLoading,
  ...props
}: LoginFormProps) {
  // Default: Show terms on full page, hide in modals (unless overridden)
  const shouldShowTerms = showTerms ?? variant === "page";

  if (variant === "modal") {
    return (
      <div className={cn("flex flex-col gap-4", className)} {...props}>
        <AuthFormContent
          onSuccess={onSuccess}
          isExternallyLoading={isLoading}
        />
        {shouldShowTerms && (
          <div className="text-center text-xs text-muted-foreground text-balance">
            By clicking continue, you agree to our{" "}
            <a
              href="/terms"
              className="underline underline-offset-4 hover:text-primary"
            >
              Terms of Service
            </a>{" "}
            and{" "}
            <a
              href="/privacy"
              className="underline underline-offset-4 hover:text-primary"
            >
              Privacy Policy
            </a>
            .
          </div>
        )}
      </div>
    );
  }

  // Default page variant with card layout
  return (
    <div className={cn("flex flex-col gap-6", className)} {...props}>
      <Card className="overflow-hidden p-0">
        <CardContent className="grid p-0 md:grid-cols-2">
          <div className="p-6 md:p-8">
            <AuthFormContent
              onSuccess={onSuccess}
              isExternallyLoading={isLoading}
            />
          </div>

          {/* Right panel - Hidden on mobile, provides visual balance on desktop */}
          <div className="relative hidden bg-muted md:block">
            <div className="absolute inset-0 bg-gradient-to-br from-primary/20 to-primary/10" />
          </div>
        </CardContent>
      </Card>

      {/* Terms Footer - Required for compliance, configurable via showTerms prop */}
      {shouldShowTerms && (
        <div className="text-center text-xs text-muted-foreground text-balance">
          By clicking continue, you agree to our{" "}
          <a
            href="/terms"
            className="underline underline-offset-4 hover:text-primary"
          >
            Terms of Service
          </a>{" "}
          and{" "}
          <a
            href="/privacy"
            className="underline underline-offset-4 hover:text-primary"
          >
            Privacy Policy
          </a>
          .
        </div>
      )}
    </div>
  );
}
