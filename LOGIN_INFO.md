# 🔐 Pronunciation Assistant - Login Information

## 🚀 Development Login Credentials

### Primary Development Account

- **Email**: `dev@example.com`
- **Password**: `asdf1234`
- **Name**: Development User
- **Status**: ✅ Created with Better Auth registration, working perfectly
- **Authentication**: ✅ Password login fully functional

### How to Login

1. **Open browser**: http://localhost:5173/login
2. **Select authentication mode**:
   - Click **"Password"** button (default mode)
   - Or click **"Email Code"** for OTP
3. **Enter credentials**:
   - Email: `dev@example.com`
   - Password: `asdf1234`
4. **Click "Sign in with password"** → You're in! 🎉

### 🎉 **Login Form Now Supports Both Modes**

- ✅ **Password Login**: Use email + password
- 📧 **Email OTP**: Use email + 6-digit code
- 🔄 **Easy Toggle**: Switch between modes with buttons

## 🔧 Authentication Methods Available

### 1. ✅ **Password Login** (Recommended for Development)

- Use the development account credentials above
- Fastest and most reliable for testing
- No email setup required

### 2. 📧 **Email OTP Login**

- Enter any email address
- Receive 6-digit code via email
- Requires Resend API key setup
- **Setup**: Run `./setup-dev-login.sh`

### 3. 🎭 **Anonymous Mode**

- Try the app without authentication
- Limited functionality
- Perfect for quick testing

### 4. 🔗 **Google OAuth** (Optional)

- Requires Google OAuth setup
- See `.env` file for configuration

## 🛠️ Technical Setup Details

### Database Schema

Better Auth tables created in PostgreSQL:

- `user` - User accounts with profile info
- `identity` - OAuth provider accounts & passwords
- `session` - Active user sessions
- `verification` - Email verification tokens

### Password Security

- Password: `asdf1234`
- Hash format: HMAC-SHA256 with salt (salt:hash)
- Algorithm: Custom Better Auth compatible hashing
- Database: PostgreSQL with proper schema

## 🎯 Testing Scenarios

### 1. Basic Login Testing

```bash
# Navigate to login page
http://localhost:5173/login

# Use credentials:
Email: dev@example.com
Password: asdf1234
```

### 2. Session Management Testing

- Login and refresh page
- Close browser and reopen
- Check session persistence
- Test logout functionality

### 3. Protected Route Testing

- Access protected pages without login
- Verify redirect to login
- Test automatic authentication after login

## 🔄 Additional Development Users

You can create more test users with the same password:

```sql
-- Example: Create additional test users
INSERT INTO "user" (id, name, email, email_verified, is_anonymous, created_at, updated_at)
VALUES (uuid_generate_v4(), 'Test User 2', 'test2@pronounce.app', true, false, now(), now());

INSERT INTO identity (id, account_id, provider_id, user_id, password, created_at, updated_at)
SELECT uuid_generate_v4(), id::text, 'credential', id, '$2b$10$jAWWwRuVgQu4Vr.L6BuD6egPkifLXf9F6ck4eXVm1VQljRusVWn82', now(), now()
FROM "user" WHERE email = 'test2@pronounce.app';
```

## 🚨 Important Notes

### Security

- These credentials are **development only**
- Password `asdf` is simple for easy testing
- **Never use these credentials in production**
- Bcrypt hash ensures secure storage

### Database

- Better Auth schema created in `pronunciation_assistant` database
- PostgreSQL running on port 5432
- UUID v4 used for primary keys
- Foreign key constraints enforced

### Environment

- Development mode: `NODE_ENV=development`
- API endpoint: http://localhost:4000
- Frontend: http://localhost:5173
- Better Auth URL: http://localhost:4000

## 🛠️ Troubleshooting

### Login Issues

```bash
# Check services are running
./manage.sh status

# Check backend API
curl http://localhost:4000/

# Check database connection
docker exec pronounciation-assistant-claudecode_postgres_1 psql -U postgres -d pronunciation_assistant -c "SELECT COUNT(*) FROM \"user\";"
```

### Common Problems

**"Invalid credentials" error:**

- Verify email: `dev@example.com`
- Verify password: `asdf1234` (case-sensitive)
- Check database tables exist

**"User not found" error:**

- Check if user was created in database
- Verify email spelling matches exactly

**Backend not responding:**

- Check if services are running: `./manage.sh status`
- Restart services: `./manage.sh restart`
- Check logs: `./manage.sh logs`

## 📚 Related Documentation

- [Quick Login Setup Guide](./QUICK_LOGIN_GUIDE.md)
- [Service Management](./SERVICE_MANAGEMENT.md)
- [Development Setup](./README.md)

## 🎉 Ready for Development!

Your pronunciation assistant now has full authentication capabilities ready for development and testing. Use the `dev@example.com` / `asdf1234` credentials to explore all features of the application.

---

**💡 Pro Tip**: The development user has email verification already completed, so you can skip any email verification steps during login testing.
