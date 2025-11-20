#!/bin/bash

# Development Login Setup Script for Pronunciation Assistant
# This script helps you get a free Resend API key and test the login functionality

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo -e "${BLUE}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║           Development Login Setup Assistant                ║
║              Pronunciation Assistant                       ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

log_info "This script will help you set up email-based login for development."

# Check if services are running
log_info "Checking if required services are running..."
if ! curl -s http://localhost:4000/health > /dev/null; then
    log_error "Backend API (port 4000) is not running. Please start services first:"
    echo "  ./manage.sh start"
    exit 1
fi

if ! curl -s http://localhost:5173/ > /dev/null; then
    log_error "Frontend app (port 5173) is not running. Please start services first:"
    echo "  ./manage.sh start"
    exit 1
fi

log_success "✅ Services are running!"

echo
log_info "🔧 Setting up Email OTP Authentication..."

# Check if Resend API key is configured
if [[ "${RESEND_API_KEY:-}" == "re_your-test-key-here" ]]; then
    echo
    log_warning "⚠️  You need to set up a Resend API key for email OTP login."
    echo
    log_info "📧 Getting a FREE Resend API key:"
    echo "  1. Go to: https://resend.com/signup"
    echo "  2. Create a free account"
    echo "  3. Navigate to: https://resend.com/api-keys"
    echo "  4. Click 'Create API Key'"
    echo "  5. Copy the API key (starts with 're_')"
    echo
    log_info "📝 Once you have the API key, update your .env file:"
    echo "  RESEND_API_KEY=re_your_actual_api_key_here"
    echo "  RESEND_EMAIL_FROM=onboarding@resend.dev"
    echo

    read -p "Enter your Resend API key (or press Enter to skip): " api_key

    if [[ -n "$api_key" && "$api_key" != "re_your-test-key-here" ]]; then
        # Update the .env file with the actual API key
        sed -i "s/RESEND_API_KEY=re_your-test-key-here/RESEND_API_KEY=$api_key/" .env
        log_success "✅ Resend API key updated in .env file"
        echo
        log_info "🔄 Restarting services to apply changes..."
        ./manage.sh dev stop > /dev/null 2>&1
        sleep 2
        ./manage.sh dev start > /dev/null 2>&1 &
        sleep 10
        log_success "✅ Services restarted with new configuration"
    else
        log_warning "⚠️  Skipping API key setup. Email OTP will not work without a valid key."
        echo
    fi
else
    log_success "✅ Resend API key is already configured"
fi

echo
log_info "🧪 Testing Login Setup..."

# Check if the application is responding
if curl -s http://localhost:5173/login > /dev/null; then
    log_success "✅ Login page is accessible"
else
    log_warning "⚠️  Login page might not be ready yet"
fi

echo
log_info "🎯 How to Test Your Login:"
echo
echo "1. 🌐 Open your browser and go to:"
echo "   ${BLUE}http://localhost:5173/login${NC}"
echo
echo "2. 📧 Enter any email address (it doesn't have to be real for testing)"
echo
echo "3. 📱 Check your email for a 6-digit OTP code"
echo
echo "4. 🔢 Enter the OTP code to complete login"
echo

if [[ "${RESEND_API_KEY:-}" != "re_your-test-key-here" ]]; then
    log_success "✅ Email OTP is ready to use!"
    echo
    echo "📱 Quick Test Email Addresses:"
    echo "   • test@example.com"
    echo "   • dev@localhost.dev"
    echo "   • yourname@test.com"
    echo
    echo "💡 The system will send OTP to any email you enter."
else
    log_warning "⚠️  Email OTP requires a valid Resend API key to work."
    echo
    echo "📋 Your Options:"
    echo "   1. Get a free Resend API key (recommended)"
    echo "   2. Set up Google OAuth (more complex setup)"
    echo "   3. Use anonymous mode (limited functionality)"
    echo
fi

echo
log_info "🔧 Additional Development Features:"
echo "  • Session management: Automatic refresh on reconnect"
echo "  • Protected routes: Auto-redirect to /login"
echo "  • Multiple auth methods: Email, Google, Passkeys"
echo

log_info "🌐 Access URLs:"
echo "  • Frontend: http://localhost:5173/"
echo "  • Login: http://localhost:5173/login"
echo "  • API: http://localhost:4000/"
echo "  • Status: ./manage.sh status"
echo

if [[ "${RESEND_API_KEY:-}" != "re_your-test-key-here" ]]; then
    log_success "🎉 Development login setup complete! Try logging in now!"
else
    log_info "📝 Next Steps:"
    echo "  1. Get a Resend API key from https://resend.com"
    echo "  2. Run this script again: ./setup-dev-login.sh"
    echo "  3. Or manually update the .env file and restart services"
fi

echo
log_info "📚 Documentation:"
echo "  • Service Management: ./SERVICE_MANAGEMENT.md"
echo "  • Service Status: ./manage.sh status"
echo "  • Service Logs: ./manage.sh logs"
echo