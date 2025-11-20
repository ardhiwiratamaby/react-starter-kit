# Quick Login Setup Guide

## 🚀 **Get Logged In - 2 Easy Steps**

### **Step 1: Get Email Service Setup**

```bash
# Run the setup assistant
./setup-dev-login.sh
```

Or manually:

1. **Get a FREE Resend API key**: https://resend.com/signup
2. **Add to your `.env`**:
   ```bash
   RESEND_API_KEY=re_your_actual_api_key
   RESEND_EMAIL_FROM=onboarding@resend.dev
   ```
3. **Restart services**: `./manage.sh dev restart`

### **Step 2: Login to Your App**

1. **Open**: http://localhost:5173/login
2. **Enter any email** (test@example.com works)
3. **Check email** for 6-digit code
4. **Enter code** → You're in! 🎉

## 📧 **Why Email OTP?**

- ✅ **Free** with Resend (100 emails/day)
- ✅ **No OAuth setup needed**
- ✅ **Works with any email address**
- ✅ **Perfect for development**

## 🔧 **Alternative Login Methods**

### **Google OAuth** (Advanced)

1. Go to: https://console.developers.google.com/
2. Create new project
3. Enable Google+ API
4. Create OAuth 2.0 credentials
5. Add to `.env`:
   ```bash
   GOOGLE_CLIENT_ID=your-client-id
   GOOGLE_CLIENT_SECRET=your-client-secret
   ```

### **Anonymous Mode** (Limited)

The app also supports anonymous access for testing without email.

## 🎯 **Access Your App**

- **🌐 Frontend**: http://localhost:5173/
- **🔐 Login**: http://localhost:5173/login
- **📊 API**: http://localhost:4000/
- **📈 Status**: `./manage.sh status`

## 🛠️ **Troubleshooting**

**Email not arriving?**

```bash
# Check if API key is set
grep RESEND_API_KEY .env

# Check service logs
./manage.sh logs
```

**Services not running?**

```bash
# Start all services
./manage.sh start

# Check status
./manage.sh status
```

**Login page not working?**

```bash
# Check if frontend is on correct port
curl http://localhost:5173/login
```

## 🔐 **Authentication Features**

- **Session Management**: Auto-refresh on reconnect
- **Protected Routes**: Auto-redirect to login
- **Multiple Providers**: Email, Google, Passkeys
- **Security**: CSRF protection, secure cookies

---

**💡 Pro Tip**: For development, Email OTP is fastest and most reliable. Get your free Resend key and you'll be logged in minutes!
