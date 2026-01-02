#!/bin/bash
set -e

echo "================================================"
echo "Datadog Resource Cleanup Script v2"
echo "================================================"
echo ""

# Check for required environment variables
if [ -z "$DD_API_KEY" ] || [ -z "$DD_APP_KEY" ]; then
    echo "❌ Error: DD_API_KEY and DD_APP_KEY environment variables must be set"
    exit 1
fi

DD_SITE="${DD_SITE:-datadoghq.com}"
API_BASE="https://api.${DD_SITE}"

read -p "⚠️  This will DELETE demo monitors, SLOs, and synthetic tests. Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "🔍 Finding resources to delete..."
echo ""

# Function to make API calls
api_get() {
    curl -s -X GET "${API_BASE}$1" \
        -H "DD-API-KEY: ${DD_API_KEY}" \
        -H "DD-APPLICATION-KEY: ${DD_APP_KEY}"
}

api_delete() {
    curl -s -X DELETE "${API_BASE}$1" \
        -H "DD-API-KEY: ${DD_API_KEY}" \
        -H "DD-APPLICATION-KEY: ${DD_APP_KEY}"
}

# Delete Monitors with [demo] prefix
echo "📊 Deleting monitors with [demo] prefix..."
MONITORS_JSON=$(api_get "/api/v1/monitor")
MONITOR_IDS=$(echo "$MONITORS_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for monitor in data:
    name = monitor.get('name', '')
    if '[demo]' in name.lower() or 'demo' in name.lower():
        print(monitor['id'])
" 2>/dev/null || echo "")

if [ -n "$MONITOR_IDS" ]; then
    echo "$MONITOR_IDS" | while read -r monitor_id; do
        if [ -n "$monitor_id" ]; then
            MONITOR_NAME=$(echo "$MONITORS_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for m in data:
    if m['id'] == $monitor_id:
        print(m['name'])
        break
" 2>/dev/null || echo "Monitor $monitor_id")
            echo "   Deleting: $MONITOR_NAME (ID: $monitor_id)"
            api_delete "/api/v1/monitor/${monitor_id}" > /dev/null
        fi
    done
    echo "   ✅ Monitors deleted"
else
    echo "   No monitors found"
fi

echo ""

# Delete SLOs with demo/chatbot tags
echo "🎯 Deleting SLOs..."
SLOS_JSON=$(api_get "/api/v1/slo")
SLO_IDS=$(echo "$SLOS_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if 'data' in data:
    for slo in data['data']:
        name = slo.get('name', '')
        if '[demo]' in name.lower() or 'demo' in name.lower() or 'chatbot' in name.lower():
            print(slo['id'])
" 2>/dev/null || echo "")

if [ -n "$SLO_IDS" ]; then
    echo "$SLO_IDS" | while read -r slo_id; do
        if [ -n "$slo_id" ]; then
            echo "   Deleting SLO: $slo_id"
            api_delete "/api/v1/slo/${slo_id}" > /dev/null
        fi
    done
    echo "   ✅ SLOs deleted"
else
    echo "   No SLOs found"
fi

echo ""

# Delete Synthetic Tests with [Synthetics] demo prefix
echo "🧪 Deleting synthetic tests..."
SYNTHETICS_JSON=$(api_get "/api/v1/synthetics/tests")
SYNTHETIC_IDS=$(echo "$SYNTHETICS_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if 'tests' in data:
    for test in data['tests']:
        name = test.get('name', '')
        if 'demo' in name.lower():
            print(test['public_id'])
" 2>/dev/null || echo "")

if [ -n "$SYNTHETIC_IDS" ]; then
    echo "$SYNTHETIC_IDS" | while read -r test_id; do
        if [ -n "$test_id" ]; then
            echo "   Deleting synthetic test: $test_id"
            api_delete "/api/v1/synthetics/tests/${test_id}" > /dev/null
        fi
    done
    echo "   ✅ Synthetic tests deleted"
else
    echo "   No synthetic tests found"
fi

echo ""

# Delete Security Rules
echo "🔒 Deleting security rules..."
RULES_JSON=$(api_get "/api/v2/security_monitoring/rules")
RULE_IDS=$(echo "$RULES_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if 'data' in data:
    for rule in data['data']:
        name = rule.get('name', '')
        if 'demo' in name.lower() or 'chatbot' in name.lower():
            print(rule['id'])
" 2>/dev/null || echo "")

if [ -n "$RULE_IDS" ]; then
    echo "$RULE_IDS" | while read -r rule_id; do
        if [ -n "$rule_id" ]; then
            echo "   Deleting security rule: $rule_id"
            api_delete "/api/v2/security_monitoring/rules/${rule_id}" > /dev/null
        fi
    done
    echo "   ✅ Security rules deleted"
else
    echo "   No security rules found"
fi

echo ""
echo "================================================"
echo "✅ Cleanup complete!"
echo "================================================"
echo ""
echo "💡 Wait 1-2 minutes, then run: cd terraform && terraform apply -auto-approve"
echo ""



