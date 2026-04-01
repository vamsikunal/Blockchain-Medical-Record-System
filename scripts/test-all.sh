#!/bin/bash
source "$(dirname "$0")/env.sh"

PASS=0; FAIL=0

run_test() {
  local label="$1"; local expected="$2"; local result="$3"
  if echo "$result" | grep -qi "$expected"; then
    echo "  PASS — $label"; ((PASS++))
  else
    echo "  FAIL — $label"; echo "     got: $result"; ((FAIL++))
  fi
}

echo "=== Test Suite: Medical Record Chaincode ==="
echo ""

echo "[1] Hospital creates patient record P001"
OUT=$(peer chaincode invoke -o $ORDERER -C $CHANNEL -n $CHAINCODE \
  --peerAddresses $PEER_HOSPITAL \
  -c '{"function":"CreatePatientRecord","Args":["P001","John Doe","35","Hypertension"]}' 2>&1)
run_test "Hospital creates P001" "status:200\|OK" "$OUT"
echo "$OUT" >> logs/invoke/create-record.log

echo "[2] Doctor updates without consent"
OUT=$(peer chaincode invoke -o $ORDERER -C $CHANNEL -n $CHAINCODE \
  --peerAddresses $PEER_DOCTOR \
  -c '{"function":"UpdateMedicalRecord","Args":["P001","Blood pressure stable"]}' 2>&1)
run_test "Doctor rejected without consent" "consent\|unauthorized" "$OUT"
echo "$OUT" >> logs/invoke/update-record.log

echo "[3] Patient grants consent to Doctor D001"
OUT=$(peer chaincode invoke -o $ORDERER -C $CHANNEL -n $CHAINCODE \
  --peerAddresses $PEER_PATIENT \
  -c '{"function":"GiveConsent","Args":["P001","D001"]}' 2>&1)
run_test "Patient grants consent" "status:200\|OK" "$OUT"
echo "$OUT" >> logs/invoke/give-consent.log

echo "[4] Doctor updates after consent"
OUT=$(peer chaincode invoke -o $ORDERER -C $CHANNEL -n $CHAINCODE \
  --peerAddresses $PEER_DOCTOR \
  -c '{"function":"UpdateMedicalRecord","Args":["P001","Blood pressure stable"]}' 2>&1)
run_test "Doctor update with consent" "status:200\|OK" "$OUT"
echo "$OUT" >> logs/invoke/update-record.log

echo "[5] Patient queries full record"
OUT=$(peer chaincode query -C $CHANNEL -n $CHAINCODE \
  -c '{"function":"GetPatientRecord","Args":["P001"]}' 2>&1)
run_test "Patient retrieves record" "P001" "$OUT"
echo "$OUT" >> logs/query/get-record.log

echo "[6] Doctor attempts to create record (unauthorized)"
OUT=$(peer chaincode invoke -o $ORDERER -C $CHANNEL -n $CHAINCODE \
  --peerAddresses $PEER_DOCTOR \
  -c '{"function":"CreatePatientRecord","Args":["P002","Jane","28","Migraine"]}' 2>&1)
run_test "Unauthorized create rejected" "unauthorized\|HospitalMSP" "$OUT"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
