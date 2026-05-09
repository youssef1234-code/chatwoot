#!/usr/bin/env bash
# Cleanup script: deletes ALL contacts from a Chatwoot account via API.
# Usage: bash cleanup_contacts.sh
#
# Set these env vars or edit the defaults below:
CHATWOOT_URL="${CHATWOOT_API_URL:-http://localhost:3000}"
API_TOKEN="${CHATWOOT_API_TOKEN:-dyhQXHNgWr1451F1eSsreVfe}"
ACCOUNT_ID="${CHATWOOT_ACCOUNT_ID:-1}"

BASE="${CHATWOOT_URL}/api/v1/accounts/${ACCOUNT_ID}/contacts"

deleted=0
failed=0
page=1

echo "=== Chatwoot Contact Cleanup ==="
echo "Target: ${BASE}"
echo ""

while true; do
  # Fetch one page of contacts
  response=$(curl -s -H "api_access_token: ${API_TOKEN}" "${BASE}?page=${page}&per_page=100")

  # Extract contact IDs from the payload (works with jq)
  ids=$(echo "$response" | jq -r '.payload[]?.id // empty' 2>/dev/null)

  if [ -z "$ids" ]; then
    echo "No more contacts found (page ${page})."
    break
  fi

  for id in $ids; do
    status=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE -H "api_access_token: ${API_TOKEN}" "${BASE}/${id}")
    if [ "$status" = "200" ] || [ "$status" = "204" ]; then
      deleted=$((deleted + 1))
      echo "  Deleted contact #${id}"
    else
      failed=$((failed + 1))
      echo "  FAILED  contact #${id} (HTTP ${status})"
    fi
    # Small delay to avoid hammering the API
    sleep 0.05
  done

  # Always re-fetch page 1, since deletions shift the pages
  page=1
done

echo ""
echo "=== Done: ${deleted} deleted, ${failed} failed ==="
