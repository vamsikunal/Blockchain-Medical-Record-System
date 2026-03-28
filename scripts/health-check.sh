#!/bin/bash
source "$(dirname "$0")/env.sh"

echo "=== Network Health Check ==="
echo ""
echo "Testing chaincode responsiveness..."
OUT=$(peer chaincode query -C $CHANNEL -n $CHAINCODE \
  -c '{"function":"GetPatientRecord","Args":["HEALTH_CHECK"]}' 2>&1)

if echo "$OUT" | grep -q "does not exist"; then
    echo "Chaincode is responsive (record not found is expected)"
    exit 0
elif echo "$OUT" | grep -q "status:200"; then
    echo "Chaincode is responsive (test record found)"
    exit 0
else
    echo "Chaincode is not responding"
    echo "Error: $OUT"
    exit 1
fi
