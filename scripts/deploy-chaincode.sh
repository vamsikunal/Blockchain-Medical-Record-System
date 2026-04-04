#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK_DIR="$(cd "$SCRIPT_DIR/../network" && pwd)"
CHAINCODE_DIR="$(cd "$SCRIPT_DIR/../chaincode/medical-record" && pwd)"

source "$SCRIPT_DIR/env.sh"

export FABRIC_CFG_PATH="/home/$USER/fabric-samples/config"
export CC_NAME=${CHAINCODE:-medicalrecord}
export CC_VERSION="1.0"
export CC_SEQUENCE=1
export CC_PKG="medicalrecord.tar.gz"

echo "=== Deploying Chaincode ==="

setGlobals() {
  local ORG=$1
  if [ "$ORG" = "Hospital" ]; then
    export CORE_PEER_LOCALMSPID="HospitalMSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$HOSPITAL_CA
    export CORE_PEER_MSPCONFIGPATH=${NETWORK_DIR}/crypto-config/peerOrganizations/hospital.com/users/Admin@hospital.com/msp
    export CORE_PEER_ADDRESS=localhost:7051
  elif [ "$ORG" = "Doctor" ]; then
    export CORE_PEER_LOCALMSPID="DoctorMSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$DOCTOR_CA
    export CORE_PEER_MSPCONFIGPATH=${NETWORK_DIR}/crypto-config/peerOrganizations/doctor.com/users/Admin@doctor.com/msp
    export CORE_PEER_ADDRESS=localhost:8051
  elif [ "$ORG" = "Patient" ]; then
    export CORE_PEER_LOCALMSPID="PatientMSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PATIENT_CA
    export CORE_PEER_MSPCONFIGPATH=${NETWORK_DIR}/crypto-config/peerOrganizations/patient.com/users/Admin@patient.com/msp
    export CORE_PEER_ADDRESS=localhost:9051
  else
    echo "Unknown Org: $ORG"
    exit 1
  fi
}

# ── Step 1: Build the CCaaS package ──────────────────────────────────────────
echo "1. Packaging chaincode (CCaaS format)..."
cd "$SCRIPT_DIR"

cat > connection.json <<EOF
{
  "address": "medicalrecord-ccaas:9999",
  "dial_timeout": "10s",
  "tls_required": false
}
EOF

cat > metadata.json <<EOF
{
  "type": "ccaas",
  "label": "${CC_NAME}_${CC_VERSION}"
}
EOF

tar cfz code.tar.gz connection.json
tar cfz ${CC_PKG} code.tar.gz metadata.json
rm connection.json metadata.json code.tar.gz

# ── Step 2: Install on ALL peers ─────────────────────────────────────────────
echo "2. Installing chaincode on all peers..."
for ORG in Hospital Doctor Patient; do
  setGlobals $ORG
  echo "  Installing on $ORG (${CORE_PEER_ADDRESS})..."
  peer lifecycle chaincode install ${CC_PKG}
done

# ── Step 3: Get PACKAGE_ID ───────────────────────────────────────────────────
echo "3. Querying installed chaincode..."
setGlobals Hospital
peer lifecycle chaincode queryinstalled > log.txt
PACKAGE_ID=$(sed -n "/${CC_NAME}_${CC_VERSION}/{s/^Package ID: //; s/, Label:.*$//; p;}" log.txt | tail -n 1)
echo "  PackageID: ${PACKAGE_ID}"

if [ -z "$PACKAGE_ID" ]; then
  echo "ERROR: Could not determine PACKAGE_ID" >&2
  exit 1
fi

# ── Step 3.5: Start CCaaS container ──────────────────────────────────────────
echo "3.5. Starting CCaaS container..."
docker build -t medicalrecord-ccaas ${CHAINCODE_DIR}
docker rm -f medicalrecord-ccaas 2>/dev/null || true
docker run -d --name medicalrecord-ccaas \
  --network fabric_network \
  -e CHAINCODE_SERVER_ADDRESS=0.0.0.0:9999 \
  -e CHAINCODE_ID=${PACKAGE_ID} \
  -e CORE_CHAINCODE_ID_NAME=${PACKAGE_ID} \
  medicalrecord-ccaas
echo "  Waiting for CCaaS server to start..."
sleep 5

# ── Step 4: Approve for ALL orgs ─────────────────────────────────────────────
echo "4. Approving for all organizations..."
for ORG in Hospital Doctor Patient; do
  setGlobals $ORG
  echo "  Approving for $ORG..."
  peer lifecycle chaincode approveformyorg \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile $ORDERER_CA \
    --channelID $CHANNEL \
    --name $CC_NAME \
    --version $CC_VERSION \
    --package-id ${PACKAGE_ID} \
    --sequence $CC_SEQUENCE
done

# ── Step 5: Verify all orgs have approved ────────────────────────────────────
echo "5. Checking commit readiness..."
setGlobals Hospital
peer lifecycle chaincode checkcommitreadiness \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile $ORDERER_CA \
  --channelID $CHANNEL \
  --name $CC_NAME \
  --version $CC_VERSION \
  --sequence $CC_SEQUENCE \
  --output json

# ── Step 6: Commit ───────────────────────────────────────────────────────────
echo "6. Committing chaincode definition..."
setGlobals Hospital
peer lifecycle chaincode commit \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile $ORDERER_CA \
  --channelID $CHANNEL \
  --name $CC_NAME \
  --version $CC_VERSION \
  --sequence $CC_SEQUENCE \
  --peerAddresses localhost:7051 --tlsRootCertFiles $HOSPITAL_CA \
  --peerAddresses localhost:8051 --tlsRootCertFiles $DOCTOR_CA \
  --peerAddresses localhost:9051 --tlsRootCertFiles $PATIENT_CA

# ── Step 7: Invoke InitLedger ─────────────────────────────────────────────────
echo "7. Initializing chaincode (if required)..."
sleep 5
peer chaincode invoke \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile $ORDERER_CA \
  -C $CHANNEL -n $CC_NAME \
  --peerAddresses localhost:7051 --tlsRootCertFiles $HOSPITAL_CA \
  --peerAddresses localhost:8051 --tlsRootCertFiles $DOCTOR_CA \
  --peerAddresses localhost:9051 --tlsRootCertFiles $PATIENT_CA \
  -c '{"function":"InitLedger","Args":[]}' \
  || echo "InitLedger not found or failed, ignoring."

echo "=== Chaincode Deployment Complete ==="