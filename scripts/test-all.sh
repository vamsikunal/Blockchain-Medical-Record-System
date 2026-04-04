#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"

# ── Counters ──────────────────────────────────────────────────────────────────
PASS=0; FAIL=0; SKIP=0

# ── Log setup ─────────────────────────────────────────────────────────────────
LOG_DIR="logs/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$LOG_DIR"
SUMMARY_LOG="$LOG_DIR/summary.log"

log() { echo "$*" | tee -a "$SUMMARY_LOG"; }

# ── Helpers ───────────────────────────────────────────────────────────────────

# invoke: retries up to 3 times with backoff, waits for block commit
invoke() {
  local org="$1"; shift
  local fn="$1";  shift
  local args="$1"; shift
  local logfile="$LOG_DIR/${fn}.log"

  setGlobals "$org"

  local peer_flags="--peerAddresses $PEER_HOSPITAL --tlsRootCertFiles $HOSPITAL_CA \
                  --peerAddresses $PEER_DOCTOR   --tlsRootCertFiles $DOCTOR_CA \
                  --peerAddresses $PEER_PATIENT  --tlsRootCertFiles $PATIENT_CA"


  local attempt out
  for attempt in 1 2 3; do
    out=$(peer chaincode invoke \
      -o "$ORDERER" --ordererTLSHostnameOverride orderer.example.com \
      -C "$CHANNEL" -n "$CHAINCODE" \
      --tls --cafile "$ORDERER_CA" \
      --waitForEvent \
      $peer_flags \
      -c "{\"function\":\"${fn}\",\"Args\":${args}}" 2>&1) && break
    log "  [retry $attempt/3] $fn failed, retrying in ${attempt}s..."
    sleep "$attempt"
  done

  echo "$out" >> "$logfile"
  echo "$out"
}

# query: single attempt, no orderer needed
query() {
  local org="$1"; shift
  local fn="$1";  shift
  local args="$1"; shift
  local logfile="$LOG_DIR/${fn}.log"

  setGlobals "$org"

  local peer_flags=""
  case "$org" in
    Hospital) peer_flags="--peerAddresses $PEER_HOSPITAL --tlsRootCertFiles $HOSPITAL_CA" ;;
    Doctor)   peer_flags="--peerAddresses $PEER_DOCTOR   --tlsRootCertFiles $DOCTOR_CA"   ;;
    Patient)  peer_flags="--peerAddresses $PEER_PATIENT  --tlsRootCertFiles $PATIENT_CA"  ;;
  esac

  local out
  out=$(peer chaincode query \
    -C "$CHANNEL" -n "$CHAINCODE" \
    --tls --cafile "$ORDERER_CA" \
    $peer_flags \
    -c "{\"function\":\"${fn}\",\"Args\":${args}}" 2>&1)

  echo "$out" >> "$logfile"
  echo "$out"
}

# assert_success: checks for known Fabric success signals
assert_success() {
  local label="$1"; local out="$2"
  if echo "$out" | grep -qiE "Chaincode invoke successful|status:200|\"status\":200"; then
    log "  PASS — $label"
    PASS=$((PASS + 1))
  else
    log "  FAIL — $label"
    log "         expected: success"
    log "         got:      $(echo "$out" | tail -3)"
    FAIL=$((FAIL + 1))
  fi
}

# assert_failure: checks that the output contains an expected rejection keyword
assert_failure() {
  local label="$1"; local keyword="$2"; local out="$3"
  if echo "$out" | grep -qiE "$keyword"; then
    log "  PASS — $label"
    PASS=$((PASS + 1))
  else
    log "  FAIL — $label (expected rejection matching '$keyword')"
    log "         got: $(echo "$out" | tail -3)"
    FAIL=$((FAIL + 1))
  fi
}

# assert_contains: checks that a query result contains an expected value
assert_contains() {
  local label="$1"; local expected="$2"; local out="$3"
  if echo "$out" | grep -q "$expected"; then
    log "  PASS — $label"
    PASS=$((PASS + 1))
  else
    log "  FAIL — $label"
    log "         expected to contain: $expected"
    log "         got: $out"
    FAIL=$((FAIL + 1))
  fi
}

# ── Test suite ────────────────────────────────────────────────────────────────
PID="P$(date +%s)$RANDOM"
PID2="P2$(date +%s)$RANDOM"

log "=== Test Suite: Medical Record Chaincode ==="
log "    Logs: $LOG_DIR"
log ""

log "[1] Hospital creates patient record ${PID}"
OUT=$(invoke Hospital CreatePatientRecord "[\"${PID}\",\"John Doe\",\"35\",\"Hypertension\"]")
assert_success "Hospital creates ${PID}" "$OUT"

log "[2] Doctor attempts update without consent"
OUT=$(invoke Doctor UpdateMedicalRecord "[\"${PID}\",\"Blood pressure stable\"]")
assert_failure "Doctor rejected without consent" "consent|unauthorized|Error|failed" "$OUT"

log "[3] Patient grants consent to Doctor Admin"
OUT=$(invoke Patient GiveConsent "[\"${PID}\",\"eDUwOTo6Q049QWRtaW5AZG9jdG9yLmNvbSxPVT1hZG1pbixMPVNhbiBGcmFuY2lzY28sU1Q9Q2FsaWZvcm5pYSxDPVVTOjpDTj1jYS5kb2N0b3IuY29tLE89ZG9jdG9yLmNvbSxMPVNhbiBGcmFuY2lzY28sU1Q9Q2FsaWZvcm5pYSxDPVVT\"]")
assert_success "Patient grants consent" "$OUT"

log "[4] Doctor updates after consent"
OUT=$(invoke Doctor UpdateMedicalRecord "[\"${PID}\",\"Blood pressure stable\"]")
assert_success "Doctor update with consent" "$OUT"

log "[5] Patient queries full record"
OUT=$(query Patient GetPatientRecord "[\"${PID}\"]")
assert_contains "Patient retrieves own record" "${PID}" "$OUT"
assert_contains "Record contains diagnosis"    "Hypertension" "$OUT"
assert_contains "Record contains doctor note"  "Blood pressure stable" "$OUT"

log "[6] Doctor attempts to create record (unauthorized)"
OUT=$(invoke Doctor CreatePatientRecord "[\"${PID2}\",\"Jane\",\"28\",\"Migraine\"]")
assert_failure "Unauthorized create rejected" "unauthorized|HospitalMSP|Error|failed" "$OUT"

# ── Results ───────────────────────────────────────────────────────────────────
log ""
log "=== Results: $PASS passed, $FAIL failed, $SKIP skipped ==="
log "    Full logs: $LOG_DIR"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi