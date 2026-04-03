#!/bin/bash
source "$(dirname "$0")/env.sh"

PASS=0; FAIL=0

# Create log directories if they don't exist
mkdir -p logs/invoke logs/query

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
setGlobals Hospital
OUT=$(peer chaincode invoke \
  -o $ORDERER --ordererTLSHostnameOverride orderer.example.com \
  -C $CHANNEL -n $CHAINCODE \
  --tls --cafile $ORDERER_CA \
  --peerAddresses $PEER_HOSPITAL --tlsRootCertFiles $HOSPITAL_CA \
  -c '{"function":"CreatePatientRecord","Args":["P001","John Doe","35","Hypertension"]}' 2>&1)
run_test "Hospital creates P001" "status:200\|Chaincode invoke successful\|OK" "$OUT"
echo "$OUT" >> logs/invoke/create-record.log
sleep 3

echo "[2] Doctor updates without consent"
setGlobals Doctor
OUT=$(peer chaincode invoke \
  -o $ORDERER --ordererTLSHostnameOverride orderer.example.com \
  -C $CHANNEL -n $CHAINCODE \
  --tls --cafile $ORDERER_CA \
  --peerAddresses $PEER_DOCTOR --tlsRootCertFiles $DOCTOR_CA \
  -c '{"function":"UpdateMedicalRecord","Args":["P001","Blood pressure stable"]}' 2>&1)
run_test "Doctor rejected without consent" "consent\|unauthorized\|Error\|failed" "$OUT"
echo "$OUT" >> logs/invoke/update-record.log
sleep 2

echo "[3] Patient grants consent to Doctor D001"
setGlobals Patient
OUT=$(peer chaincode invoke \
  -o $ORDERER --ordererTLSHostnameOverride orderer.example.com \
  -C $CHANNEL -n $CHAINCODE \
  --tls --cafile $ORDERER_CA \
  --peerAddresses $PEER_PATIENT --tlsRootCertFiles $PATIENT_CA \
  -c '{"function":"GiveConsent","Args":["P001","D001"]}' 2>&1)
run_test "Patient grants consent" "status:200\|Chaincode invoke successful\|OK" "$OUT"
echo "$OUT" >> logs/invoke/give-consent.log
sleep 3

echo "[4] Doctor updates after consent"
setGlobals Doctor
OUT=$(peer chaincode invoke \
  -o $ORDERER --ordererTLSHostnameOverride orderer.example.com \
  -C $CHANNEL -n $CHAINCODE \
  --tls --cafile $ORDERER_CA \
  --peerAddresses $PEER_DOCTOR --tlsRootCertFiles $DOCTOR_CA \
  -c '{"function":"UpdateMedicalRecord","Args":["P001","Blood pressure stable"]}' 2>&1)
run_test "Doctor update with consent" "status:200\|Chaincode invoke successful\|OK" "$OUT"
echo "$OUT" >> logs/invoke/update-record.log
sleep 3

echo "[5] Patient queries full record"
setGlobals Patient
OUT=$(peer chaincode query \
  -C $CHANNEL -n $CHAINCODE \
  --tls --cafile $ORDERER_CA \
  --peerAddresses $PEER_PATIENT --tlsRootCertFiles $PATIENT_CA \
  -c '{"function":"GetPatientRecord","Args":["P001"]}' 2>&1)
run_test "Patient retrieves record" "P001" "$OUT"
echo "$OUT" >> logs/query/get-record.log

echo "[6] Doctor attempts to create record (unauthorized)"
setGlobals Doctor
OUT=$(peer chaincode invoke \
  -o $ORDERER --ordererTLSHostnameOverride orderer.example.com \
  -C $CHANNEL -n $CHAINCODE \
  --tls --cafile $ORDERER_CA \
  --peerAddresses $PEER_DOCTOR --tlsRootCertFiles $DOCTOR_CA \
  -c '{"function":"CreatePatientRecord","Args":["P002","Jane","28","Migraine"]}' 2>&1)
run_test "Unauthorized create rejected" "unauthorized\|HospitalMSP\|Error\|failed" "$OUT"
echo "$OUT" >> logs/invoke/create-record.log

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
