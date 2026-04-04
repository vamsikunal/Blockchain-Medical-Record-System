#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK_DIR="$(dirname "$SCRIPT_DIR")"
ARTIFACTS_DIR="$NETWORK_DIR/channel-artifacts"

# FABRIC_CFG_PATH for peer CLI needs core.yaml (fabric-samples/config has it)
PEER_CFG_PATH="/home/$USER/fabric-samples/config"

echo "=== Medical Record Network Startup ==="
echo ""

# ---------------------------------------------------------------------------
# Step 1: Generate crypto material and channel artifacts
# ---------------------------------------------------------------------------
echo "[1/4] Checking crypto material and channel artifacts..."
if [ ! -f "$ARTIFACTS_DIR/medicalchannel.block" ]; then
    echo "Artifacts not found — generating..."
    bash "$SCRIPT_DIR/generate.sh"
else
    echo "Artifacts already exist, skipping generation."
fi
echo ""

# ---------------------------------------------------------------------------
# Step 2: Start all Docker containers
# ---------------------------------------------------------------------------
echo "[2/4] Starting Docker containers..."
cd "$NETWORK_DIR"
docker-compose up -d
echo "Waiting for containers to initialize (30 seconds)..."
sleep 30
echo ""

# ---------------------------------------------------------------------------
# Common TLS/MSP paths (host filesystem)
# ---------------------------------------------------------------------------
ORDERER_TLS_CA="$NETWORK_DIR/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt"
ORDERER_ADMIN_TLS_CERT="$NETWORK_DIR/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt"
ORDERER_ADMIN_TLS_KEY="$NETWORK_DIR/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key"

HOSPITAL_TLS_CA="$NETWORK_DIR/crypto-config/peerOrganizations/hospital.com/peers/peer0.hospital.com/tls/ca.crt"
DOCTOR_TLS_CA="$NETWORK_DIR/crypto-config/peerOrganizations/doctor.com/peers/peer0.doctor.com/tls/ca.crt"
PATIENT_TLS_CA="$NETWORK_DIR/crypto-config/peerOrganizations/patient.com/peers/peer0.patient.com/tls/ca.crt"

HOSPITAL_ADMIN_MSP="$NETWORK_DIR/crypto-config/peerOrganizations/hospital.com/users/Admin@hospital.com/msp"
DOCTOR_ADMIN_MSP="$NETWORK_DIR/crypto-config/peerOrganizations/doctor.com/users/Admin@doctor.com/msp"
PATIENT_ADMIN_MSP="$NETWORK_DIR/crypto-config/peerOrganizations/patient.com/users/Admin@patient.com/msp"

# ---------------------------------------------------------------------------
# Step 3: Create channel via osnadmin (channel participation API — requires etcdraft)
# ---------------------------------------------------------------------------
echo "[3/4] Creating channel 'medicalchannel' via osnadmin..."
osnadmin channel join \
  --channelID medicalchannel \
  --config-block "$ARTIFACTS_DIR/medicalchannel.block" \
  -o localhost:7053 \
  --ca-file "$ORDERER_TLS_CA" \
  --client-cert "$ORDERER_ADMIN_TLS_CERT" \
  --client-key "$ORDERER_ADMIN_TLS_KEY"
echo "Channel created!"
echo ""

# ---------------------------------------------------------------------------
# Step 4: Join all peers to the channel
# ---------------------------------------------------------------------------
echo "[4/4] Joining peers to channel..."

# Hospital peer
echo "  Joining peer0.hospital.com..."
FABRIC_CFG_PATH="$PEER_CFG_PATH" \
CORE_PEER_TLS_ENABLED=true \
CORE_PEER_TLS_ROOTCERT_FILE="$HOSPITAL_TLS_CA" \
CORE_PEER_LOCALMSPID=HospitalMSP \
CORE_PEER_MSPCONFIGPATH="$HOSPITAL_ADMIN_MSP" \
CORE_PEER_ADDRESS=localhost:7051 \
  peer channel join -b "$ARTIFACTS_DIR/medicalchannel.block" --tls --cafile "$ORDERER_TLS_CA"
echo "  peer0.hospital.com joined."

# Doctor peer
echo "  Joining peer0.doctor.com..."
FABRIC_CFG_PATH="$PEER_CFG_PATH" \
CORE_PEER_TLS_ENABLED=true \
CORE_PEER_TLS_ROOTCERT_FILE="$DOCTOR_TLS_CA" \
CORE_PEER_LOCALMSPID=DoctorMSP \
CORE_PEER_MSPCONFIGPATH="$DOCTOR_ADMIN_MSP" \
CORE_PEER_ADDRESS=localhost:8051 \
  peer channel join -b "$ARTIFACTS_DIR/medicalchannel.block" --tls --cafile "$ORDERER_TLS_CA"
echo "  peer0.doctor.com joined."

# Patient peer
echo "  Joining peer0.patient.com..."
FABRIC_CFG_PATH="$PEER_CFG_PATH" \
CORE_PEER_TLS_ENABLED=true \
CORE_PEER_TLS_ROOTCERT_FILE="$PATIENT_TLS_CA" \
CORE_PEER_LOCALMSPID=PatientMSP \
CORE_PEER_MSPCONFIGPATH="$PATIENT_ADMIN_MSP" \
CORE_PEER_ADDRESS=localhost:9051 \
  peer channel join -b "$ARTIFACTS_DIR/medicalchannel.block" --tls --cafile "$ORDERER_TLS_CA"
echo "  peer0.patient.com joined."

echo ""
echo "=== Network is up ==="
echo "All 3 peers (Hospital, Doctor, Patient) joined 'medicalchannel'."
echo ""
echo "Verify with:"
echo "  FABRIC_CFG_PATH=$PEER_CFG_PATH \\"
echo "  CORE_PEER_TLS_ENABLED=true CORE_PEER_TLS_ROOTCERT_FILE=$HOSPITAL_TLS_CA \\"
echo "  CORE_PEER_LOCALMSPID=HospitalMSP CORE_PEER_MSPCONFIGPATH=$HOSPITAL_ADMIN_MSP \\"
echo "  CORE_PEER_ADDRESS=localhost:7051 \\"
echo "  peer channel list"
