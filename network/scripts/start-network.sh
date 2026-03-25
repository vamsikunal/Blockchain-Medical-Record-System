#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK_DIR="$(dirname "$SCRIPT_DIR")"
ARTIFACTS_DIR="$NETWORK_DIR/channel-artifacts"

echo "=== Medical Record Network Startup ==="
echo ""

# Step 1: Generate crypto material and channel artifacts
echo "[1/4] Generating crypto material and channel artifacts..."
bash "$SCRIPT_DIR/generate.sh"
echo ""

# Step 2: Start all Docker containers
echo "[2/4] Starting Docker containers..."
cd "$NETWORK_DIR"
docker-compose up -d
echo "Waiting for containers to initialize (30 seconds)..."
sleep 30
echo ""

# Step 3: Create the channel
echo "[3/4] Creating channel 'medicalchannel'..."
docker exec -e "CORE_PEER_ADDRESS=peer0.hospital.com:7051" -e "CORE_PEER_LOCALMSPID=HospitalMSP" -e "CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/peer/msp" cli peer channel create -o orderer.example.com:7050 -c medicalchannel -f ./channel-artifacts/medicalchannel.tx --outputBlock ./channel-artifacts/medicalchannel.block
echo "Channel created!"
echo ""

# Step 4: Join all peers to the channel
echo "[4/4] Joining peers to channel..."

# Hospital peer
echo "Joining peer0.hospital.com to medicalchannel..."
docker exec -e "CORE_PEER_ADDRESS=peer0.hospital.com:7051" -e "CORE_PEER_LOCALMSPID=HospitalMSP" -e "CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/peer/msp" cli peer channel join -b ./channel-artifacts/medicalchannel.block

# Doctor peer
echo "Joining peer0.doctor.com to medicalchannel..."
docker exec -e "CORE_PEER_ADDRESS=peer0.doctor.com:7051" -e "CORE_PEER_LOCALMSPID=DoctorMSP" -e "CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/peer/msp" cli peer channel join -b ./channel-artifacts/medicalchannel.block

# Patient peer
echo "Joining peer0.patient.com to medicalchannel..."
docker exec -e "CORE_PEER_ADDRESS=peer0.patient.com:7051" -e "CORE_PEER_LOCALMSPID=PatientMSP" -e "CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/peer/msp" cli peer channel join -b ./channel-artifacts/medicalchannel.block

echo ""
echo "=== Network is up. ==="
echo ""
echo "All 3 peers (Hospital, Doctor, Patient) are joined to 'medicalchannel'"
echo ""
echo "To enter the CLI container:"
echo "  docker exec -it cli bash"
echo ""
echo "To check channel membership:"
echo "  docker exec -e \"CORE_PEER_ADDRESS=peer0.hospital.com:7051\" -e \"CORE_PEER_LOCALMSPID=HospitalMSP\" -e \"CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/peer/msp\" cli peer channel list"
