#!/usr/bin/env bash
#
# Configure Bunny.net Edge Rules for redirect and security headers.
# Applies the same rules to both draft and production pull zones.
#
# Usage:
#   BUNNY_API_KEY=<key> BUNNY_PULL_ZONE_ID_DRAFT=<id> BUNNY_PULL_ZONE_ID_PROD=<id> ./scripts/bunny-edge-rules.sh
#
# To apply to a single zone:
#   BUNNY_API_KEY=<key> BUNNY_PULL_ZONE_ID_DRAFT=<id> ./scripts/bunny-edge-rules.sh
#
set -euo pipefail

API_BASE="https://api.bunny.net"

if [ -z "${BUNNY_API_KEY:-}" ]; then
  echo "Error: BUNNY_API_KEY is required" >&2
  exit 1
fi

ZONE_IDS=()
[ -n "${BUNNY_PULL_ZONE_ID_DRAFT:-}" ] && ZONE_IDS+=("$BUNNY_PULL_ZONE_ID_DRAFT")
[ -n "${BUNNY_PULL_ZONE_ID_PROD:-}" ] && ZONE_IDS+=("$BUNNY_PULL_ZONE_ID_PROD")

if [ ${#ZONE_IDS[@]} -eq 0 ]; then
  echo "Error: At least one of BUNNY_PULL_ZONE_ID_DRAFT or BUNNY_PULL_ZONE_ID_PROD is required" >&2
  exit 1
fi

FAILURES=0

add_edge_rule() {
  local zone_id="$1"
  local payload="$2"
  local description="$3"

  echo "  Adding rule: ${description}"
  response=$(curl -s -w "\n%{http_code}" -X POST \
    "${API_BASE}/pullzone/${zone_id}/edgerules/addOrUpdate" \
    -H "AccessKey: ${BUNNY_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$payload")

  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
    echo "    OK (${http_code})"
  else
    echo "    FAILED (${http_code}): ${body}" >&2
    FAILURES=$((FAILURES + 1))
  fi
}

# --- Rule definitions ---

# 1. Redirect /post/* → /blog/* (301)
RULE_REDIRECT='{
  "ActionType": 1,
  "ActionParameter1": "https://%{RequestHeaders.Host}/blog/%{Path.1-}",
  "ActionParameter2": "301",
  "Triggers": [{
    "Type": 0,
    "PatternMatches": ["*/post/*"],
    "PatternMatchingType": 0
  }],
  "TriggerMatchingType": 0,
  "Description": "Redirect /post/* to /blog/* (301)",
  "Enabled": true
}'

# 2. Security headers (X-Frame-Options, X-XSS-Protection, X-Content-Type-Options)
RULE_SECURITY_HEADERS='{
  "ActionType": 15,
  "ActionParameter1": "X-Frame-Options",
  "ActionParameter2": "SAMEORIGIN",
  "Triggers": [{
    "Type": 0,
    "PatternMatches": ["*"],
    "PatternMatchingType": 0
  }],
  "TriggerMatchingType": 0,
  "Description": "Security header: X-Frame-Options",
  "Enabled": true
}'

RULE_XSS='{
  "ActionType": 15,
  "ActionParameter1": "X-XSS-Protection",
  "ActionParameter2": "1; mode=block",
  "Triggers": [{
    "Type": 0,
    "PatternMatches": ["*"],
    "PatternMatchingType": 0
  }],
  "TriggerMatchingType": 0,
  "Description": "Security header: X-XSS-Protection",
  "Enabled": true
}'

RULE_CONTENT_TYPE='{
  "ActionType": 15,
  "ActionParameter1": "X-Content-Type-Options",
  "ActionParameter2": "nosniff",
  "Triggers": [{
    "Type": 0,
    "PatternMatches": ["*"],
    "PatternMatchingType": 0
  }],
  "TriggerMatchingType": 0,
  "Description": "Security header: X-Content-Type-Options",
  "Enabled": true
}'

# 3. Report-To header
RULE_REPORT_TO='{
  "ActionType": 15,
  "ActionParameter1": "Report-To",
  "ActionParameter2": "{\"group\":\"default\",\"max_age\":31536000,\"endpoints\":[{\"url\":\"https://alkemio.report-uri.com/a/d/g\"}],\"include_subdomains\":true}",
  "Triggers": [{
    "Type": 0,
    "PatternMatches": ["*"],
    "PatternMatchingType": 0
  }],
  "TriggerMatchingType": 0,
  "Description": "Security header: Report-To",
  "Enabled": true
}'

# 4. Content-Security-Policy
CSP="default-src 'self' https://cdn.jsdelivr.net https://cdnjs.cloudflare.com; style-src 'self' 'unsafe-hashes' 'unsafe-inline' https://*.alkemio.org https://*.alkemio.foundation https://cdn.jsdelivr.net https://cdnjs.cloudflare.com https://api.fontshare.com; script-src 'self' 'unsafe-hashes' 'unsafe-inline' 'unsafe-eval' https://cdn.segment.com https://unpkg.com https://cdn.jsdelivr.net; font-src 'self' https://cdnjs.cloudflare.com https://api.fontshare.com https://use.fontawesome.com data:; connect-src 'self' https://cdn.segment.com; img-src 'self' blob: data: https:; form-action 'self' https://formspark.io; base-uri 'self'; report-uri https://alkemio.report-uri.com/r/d/csp/enforce;"

RULE_CSP=$(cat <<ENDJSON
{
  "ActionType": 15,
  "ActionParameter1": "Content-Security-Policy",
  "ActionParameter2": "${CSP}",
  "Triggers": [{
    "Type": 0,
    "PatternMatches": ["*"],
    "PatternMatchingType": 0
  }],
  "TriggerMatchingType": 0,
  "Description": "Security header: Content-Security-Policy",
  "Enabled": true
}
ENDJSON
)

# --- Apply rules to each zone ---

for zone_id in "${ZONE_IDS[@]}"; do
  echo ""
  echo "Configuring Pull Zone: ${zone_id}"
  echo "================================"
  add_edge_rule "$zone_id" "$RULE_REDIRECT"         "Redirect /post/* → /blog/*"
  add_edge_rule "$zone_id" "$RULE_SECURITY_HEADERS"  "X-Frame-Options"
  add_edge_rule "$zone_id" "$RULE_XSS"               "X-XSS-Protection"
  add_edge_rule "$zone_id" "$RULE_CONTENT_TYPE"       "X-Content-Type-Options"
  add_edge_rule "$zone_id" "$RULE_REPORT_TO"          "Report-To"
  add_edge_rule "$zone_id" "$RULE_CSP"                "Content-Security-Policy"
  echo "Done."
done

echo ""
if [ "$FAILURES" -gt 0 ]; then
  echo "ERROR: ${FAILURES} rule(s) failed to apply. Check errors above." >&2
  exit 1
fi
echo "All rules applied. Verify in Bunny dashboard: CDN → Pull Zone → Edge Rules"
