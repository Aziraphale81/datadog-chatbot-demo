#!/bin/bash
set -e

# Security Features Testing Script
# This script helps test all security features in the demo

FRONTEND_URL="${FRONTEND_URL:-http://localhost:30080}"
API_URL="$FRONTEND_URL/api/chat"

echo "🔒 Security Features Testing Script"
echo "===================================="
echo ""
echo "Frontend URL: $FRONTEND_URL"
echo "API URL: $API_URL"
echo ""

# Check if app is accessible by sending a test request
echo "Checking app accessibility..."
TEST_RESPONSE=$(curl -s -X POST "$API_URL" \
    -H "Content-Type: application/json" \
    -d '{"prompt": "test"}' 2>&1)

if [ $? -ne 0 ] || [ -z "$TEST_RESPONSE" ]; then
    echo "❌ Error: App not accessible at $FRONTEND_URL"
    echo "   Make sure the app is deployed and running:"
    echo "   kubectl get pods -n chat-demo"
    echo ""
    echo "   If pods are running, check the frontend service:"
    echo "   kubectl get svc frontend -n chat-demo"
    exit 1
fi

echo "✅ App is accessible"
echo ""

# Function to test ASM
test_asm() {
    echo "📍 Testing Application Security Management (ASM)"
    echo "------------------------------------------------"
    echo ""
    
    echo "1️⃣  SQL Injection Test"
    echo "Sending SQL injection payload..."
    curl -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -d '{"prompt": "Hello'\'' OR '\''1'\''='\''1"}' \
        -s | jq -r '.reply // "Error"' | head -c 100
    echo ""
    echo "✅ Attack sent. Check ASM: https://app.datadoghq.com/security/appsec"
    echo ""
    
    echo "2️⃣  XSS Test"
    echo "Sending XSS payload..."
    curl -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -d '{"prompt": "<script>alert(1)</script>"}' \
        -s | jq -r '.reply // "Error"' | head -c 100
    echo ""
    echo "✅ Attack sent. Check ASM Security Signals."
    echo ""
    
    echo "3️⃣  Command Injection Test"
    echo "Sending command injection payload..."
    curl -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -d '{"prompt": "test; rm -rf /"}' \
        -s | jq -r '.reply // "Error"' | head -c 100
    echo ""
    echo "✅ Attack sent. Check ASM for command injection detection."
    echo ""
}

# Function to test SIEM
test_siem() {
    echo "📍 Testing Cloud SIEM Detection Rules"
    echo "--------------------------------------"
    echo ""
    
    echo "1️⃣  High Error Rate Detection"
    echo "Generating 60 errors in quick succession..."
    for i in {1..60}; do
        curl -s -f "$FRONTEND_URL/nonexistent-endpoint" > /dev/null 2>&1 || true
        if [ $((i % 10)) -eq 0 ]; then
            echo -n "."
        fi
    done
    echo ""
    echo "✅ Generated 60 errors. SIEM should trigger 'High Rate of API Errors' rule."
    echo "   Check: https://app.datadoghq.com/security?query=service%3Achat-backend"
    echo ""
    
    echo "2️⃣  OpenAI Abuse Detection"
    echo "Sending 50 rapid chat requests (simulating abuse)..."
    for i in {1..50}; do
        curl -X POST "$API_URL" \
            -H "Content-Type: application/json" \
            -d '{"prompt": "Hi"}' \
            -s > /dev/null 2>&1 || true
        if [ $((i % 10)) -eq 0 ]; then
            echo -n "."
        fi
    done
    echo ""
    echo "✅ Generated 50 requests. SIEM may trigger 'Unusual OpenAI Usage' if threshold met."
    echo "   Check: https://app.datadoghq.com/security"
    echo ""
}

# Function to check CSM
test_csm() {
    echo "📍 Checking Cloud Security Management (CSM)"
    echo "--------------------------------------------"
    echo ""
    
    echo "CSM monitors runtime security, misconfigurations, and container vulnerabilities."
    echo ""
    echo "✅ View CSM Findings:"
    echo "   - Threats: https://app.datadoghq.com/security/csm/threats"
    echo "   - Misconfigurations: https://app.datadoghq.com/security/csm/misconfigurations"
    echo "   - Container Images: https://app.datadoghq.com/security/csm/container-images"
    echo ""
    
    echo "Expected findings:"
    echo "  • Container vulnerabilities (CVEs in base images)"
    echo "  • K8s misconfigurations (containers running as root, missing limits)"
    echo "  • Runtime process monitoring active"
    echo ""
}

# Function to verify Code Security
verify_code_security() {
    echo "📍 Code Security Status"
    echo "-----------------------"
    echo ""
    echo "⚠️  Code Security requires GitHub integration (one-time setup)."
    echo ""
    echo "Setup steps:"
    echo "  1. Go to: https://app.datadoghq.com/security/code-security/setup"
    echo "  2. Click 'Connect a Repository'"
    echo "  3. Authorize Datadog GitHub App"
    echo "  4. Select this repository"
    echo "  5. Enable Code Security"
    echo ""
    echo "After setup, Code Security will scan for:"
    echo "  • Vulnerable dependencies (requirements.txt, package.json)"
    echo "  • Code-level vulnerabilities (SQL injection, XSS risks)"
    echo "  • Secrets accidentally committed"
    echo "  • Code quality issues"
    echo ""
    echo "View results: https://app.datadoghq.com/security/code-security/vulnerabilities"
    echo ""
}

# Main menu
echo "Select tests to run:"
echo ""
echo "  1) Test ASM (Application Security Management)"
echo "  2) Test Cloud SIEM (Detection Rules)"
echo "  3) Check CSM (Cloud Security Management)"
echo "  4) Verify Code Security Setup"
echo "  5) Run ALL tests"
echo "  6) Exit"
echo ""
read -p "Enter choice [1-6]: " choice

case $choice in
    1)
        test_asm
        ;;
    2)
        test_siem
        ;;
    3)
        test_csm
        ;;
    4)
        verify_code_security
        ;;
    5)
        echo "🚀 Running all security tests..."
        echo ""
        test_asm
        echo ""
        test_siem
        echo ""
        test_csm
        echo ""
        verify_code_security
        ;;
    6)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

echo ""
echo "🎉 Security Testing Complete!"
echo ""
echo "📊 View All Security Findings:"
echo "   • Security Signals Explorer: https://app.datadoghq.com/security"
echo "   • Application Security: https://app.datadoghq.com/security/appsec"
echo "   • Cloud SIEM: https://app.datadoghq.com/security/detection-rules"
echo "   • CSM: https://app.datadoghq.com/security/csm"
echo "   • Code Security: https://app.datadoghq.com/security/code-security"
echo ""
echo "📚 For more details, see: SECURITY_SETUP.md"
echo ""

