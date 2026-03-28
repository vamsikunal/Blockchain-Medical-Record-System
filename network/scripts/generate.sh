#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK_DIR="$(dirname "$SCRIPT_DIR")"
ARTIFACTS_DIR="$NETWORK_DIR/channel-artifacts"
CRYPTO_DIR="$NETWORK_DIR/crypto-config"

echo "=== Checking required binaries ==="

# Check for required Hyperledger Fabric binaries
command -v cryptogen >/dev/null || { echo "❌ cryptogen not found. Please install Hyperledger Fabric binaries."; exit 1; }
command -v configtxgen >/dev/null || { echo "❌ configtxgen not found. Please install Hyperledger Fabric binaries."; exit 1; }

echo "✅ All required binaries found"
echo ""

echo "=== Generating Crypto Material ==="

# Clean up existing crypto material
if [ -d "$CRYPTO_DIR" ]; then
    echo "Removing existing crypto-config directory..."
    rm -rf "$CRYPTO_DIR"
fi

# Generate crypto material using cryptogen
cd "$NETWORK_DIR"
cryptogen generate --config=crypto-config.yaml
echo "Crypto material generated successfully!"

echo ""
echo "=== Generating Channel Artifacts ==="

# Clean up existing artifacts
if [ -d "$ARTIFACTS_DIR" ]; then
    rm -rf "$ARTIFACTS_DIR"
fi
mkdir -p "$ARTIFACTS_DIR"

# Generate genesis block for the orderer
export FABRIC_CFG_PATH=$NETWORK_DIR
configtxgen -profile OrdererSolo -outputBlock "$ARTIFACTS_DIR/genesis.block"
echo "Genesis block created!"

# Generate channel transaction for medicalchannel
configtxgen -profile MedicalChannel -outputCreateChannelTx "$ARTIFACTS_DIR/medicalchannel.tx" -channelID medicalchannel
echo "Channel transaction created!"

# Generate anchor peer transactions for each org
configtxgen -profile MedicalChannel -outputAnchorPeersUpdate "$ARTIFACTS_DIR/HospitalMSPanchors.tx" -channelID medicalchannel -asOrg HospitalMSP
echo "HospitalMSP anchor peer transaction created!"

configtxgen -profile MedicalChannel -outputAnchorPeersUpdate "$ARTIFACTS_DIR/DoctorMSPanchors.tx" -channelID medicalchannel -asOrg DoctorMSP
echo "DoctorMSP anchor peer transaction created!"

configtxgen -profile MedicalChannel -outputAnchorPeersUpdate "$ARTIFACTS_DIR/PatientMSPanchors.tx" -channelID medicalchannel -asOrg PatientMSP
echo "PatientMSP anchor peer transaction created!"

echo ""
echo "=== All artifacts generated successfully! ==="
echo "Output directory: $ARTIFACTS_DIR"
ls -la "$ARTIFACTS_DIR"
