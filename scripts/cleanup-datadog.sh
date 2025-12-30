#!/bin/bash
set -e

echo "================================================"
echo "Datadog Resource Cleanup Script"
echo "================================================"
echo ""
echo "This script will delete all Datadog monitors, SLOs, security rules,"
echo "dashboards, and synthetic tests tagged with 'managed_by:terraform'"
echo "and 'team:chatbot' from your Datadog organization."
echo ""

# Check for required environment variables
if [ -z "$DD_API_KEY" ] || [ -z "$DD_APP_KEY" ]; then
    echo "❌ Error: DD_API_KEY and DD_APP_KEY environment variables must be set"
    echo ""
    echo "Get your keys from: https://app.datadoghq.com/organization-settings/api-keys"
    echo ""
    echo "Then set them:"
    echo "  export DD_API_KEY='your-api-key'"
    echo "  export DD_APP_KEY='your-app-key'"
    exit 1
fi

DD_SITE="${DD_SITE:-datadoghq.com}"
API_BASE="https://api.${DD_SITE}"

read -p "⚠️  This will DELETE resources from Datadog. Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "🔍 Finding resources to delete..."
echo ""

# Function to make API calls with proper headers
api_call() {
    local method=$1
    local endpoint=$2
    local extra_args="${3:-}"
    
    curl -s -X "$method" "${API_BASE}${endpoint}" \
        -H "DD-API-KEY: ${DD_API_KEY}" \
        -H "DD-APPLICATION-KEY: ${DD_APP_KEY}" \
        -H "Content-Type: application/json" \
        $extra_args
}

# Delete Monitors
echo "📊 Deleting monitors..."
MONITOR_IDS=$(api_call GET "/api/v1/monitor?tags=managed_by:terraform&tags=team:chatbot" | \
    grep -o '"id":[0-9]*' | cut -d':' -f2 || echo "")

if [ -n "$MONITOR_IDS" ]; then
    MONITOR_COUNT=$(echo "$MONITOR_IDS" | wc -l | tr -d ' ')
    echo "   Found $MONITOR_COUNT monitors to delete"
    
    while IFS= read -r monitor_id; do
        if [ -n "$monitor_id" ]; then
            echo "   Deleting monitor $monitor_id..."
            api_call DELETE "/api/v1/monitor/${monitor_id}" > /dev/null || echo "   ⚠️  Failed to delete monitor $monitor_id"
        fi
    done <<< "$MONITOR_IDS"
    echo "   ✅ Monitors deleted"
else
    echo "   No monitors found"
fi

echo ""

# Delete SLOs
echo "🎯 Deleting SLOs..."
SLO_IDS=$(api_call GET "/api/v1/slo?tags=managed_by:terraform&tags=team:chatbot" | \
    grep -o '"id":"[^"]*"' | cut -d'"' -f4 || echo "")

if [ -n "$SLO_IDS" ]; then
    SLO_COUNT=$(echo "$SLO_IDS" | wc -l | tr -d ' ')
    echo "   Found $SLO_COUNT SLOs to delete"
    
    while IFS= read -r slo_id; do
        if [ -n "$slo_id" ]; then
            echo "   Deleting SLO $slo_id..."
            api_call DELETE "/api/v1/slo/${slo_id}" > /dev/null || echo "   ⚠️  Failed to delete SLO $slo_id"
        fi
    done <<< "$SLO_IDS"
    echo "   ✅ SLOs deleted"
else
    echo "   No SLOs found"
fi

echo ""

# Delete Security Monitoring Rules
echo "🔒 Deleting security monitoring rules..."
# Note: Security rules API doesn't support tag filtering, so we'll list all and filter by name
RULE_IDS=$(api_call GET "/api/v2/security_monitoring/rules" | \
    grep -o '"id":"[^"]*"' | cut -d'"' -f4 | grep -E "demo|chatbot" || echo "")

if [ -n "$RULE_IDS" ]; then
    RULE_COUNT=$(echo "$RULE_IDS" | wc -l | tr -d ' ')
    echo "   Found $RULE_COUNT security rules to delete (matching 'demo' or 'chatbot')"
    
    while IFS= read -r rule_id; do
        if [ -n "$rule_id" ]; then
            echo "   Deleting security rule $rule_id..."
            api_call DELETE "/api/v2/security_monitoring/rules/${rule_id}" > /dev/null || echo "   ⚠️  Failed to delete rule $rule_id"
        fi
    done <<< "$RULE_IDS"
    echo "   ✅ Security rules deleted"
else
    echo "   No security rules found"
fi

echo ""

# Delete Synthetic Tests
echo "🧪 Deleting synthetic tests..."
SYNTHETIC_IDS=$(api_call GET "/api/v1/synthetics/tests?tags=managed_by:terraform&tags=team:chatbot" | \
    grep -o '"public_id":"[^"]*"' | cut -d'"' -f4 || echo "")

if [ -n "$SYNTHETIC_IDS" ]; then
    SYNTHETIC_COUNT=$(echo "$SYNTHETIC_IDS" | wc -l | tr -d ' ')
    echo "   Found $SYNTHETIC_COUNT synthetic tests to delete"
    
    while IFS= read -r test_id; do
        if [ -n "$test_id" ]; then
            echo "   Deleting synthetic test $test_id..."
            api_call DELETE "/api/v1/synthetics/tests/${test_id}" > /dev/null || echo "   ⚠️  Failed to delete test $test_id"
        fi
    done <<< "$SYNTHETIC_IDS"
    echo "   ✅ Synthetic tests deleted"
else
    echo "   No synthetic tests found"
fi

echo ""

# Note: Dashboards and Service Catalog entities are typically not deleted in teardown
# to preserve manual customizations, but can be added if needed

echo "================================================"
echo "✅ Datadog cleanup complete!"
echo "================================================"
echo ""
echo "💡 You can now run 'terraform apply' to recreate resources"
echo ""

