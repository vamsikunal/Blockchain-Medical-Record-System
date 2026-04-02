#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK_DIR="$(dirname "$SCRIPT_DIR")"
ARTIFACTS_DIR="$NETWORK_DIR/channel-artifacts"
CRYPTO_DIR="$NETWORK_DIR/crypto-config"

# CLEANUP — stop containers, remove volumes, prune network, delete old files
echo "Cleaning up existing Docker resources"

# Stop and remove all containers, networks, and volumes defined in docker-compose.yaml
echo "Running docker-compose down -v to wipe existing state..."
if [ -f "$NETWORK_DIR/docker-compose.yaml" ]; then
    (cd "$NETWORK_DIR" && docker-compose down -v --remove-orphans 2>/dev/null) || true
fi

# Remove any leftover chaincode containers/images
echo "Removing dev-* chaincode containers/images..."
docker rm -f $(docker ps -aq --filter "name=dev-") 2>/dev/null || true
docker rmi -f $(docker images --filter "reference=dev-*" -q) 2>/dev/null || true

# Remove the fabric_network Docker network
echo "Removing fabric_network Docker network..."
docker network rm fabric_network 2>/dev/null && echo "  Removed network: fabric_network" || true

echo "Docker cleanup done."
echo ""

# Check for required Hyperledger Fabric binaries
echo "Checking required binaries"
command -v cryptogen  >/dev/null || { echo "cryptogen not found. Please install Hyperledger Fabric binaries."; exit 1; }
command -v configtxgen >/dev/null || { echo "configtxgen not found. Please install Hyperledger Fabric binaries."; exit 1; }
echo "All required binaries found."
echo ""

echo "Generating Crypto Material"

if [ -d "$CRYPTO_DIR" ]; then
    echo "Removing existing crypto-config directory..."
    rm -rf "$CRYPTO_DIR"
fi

cd "$NETWORK_DIR"
cryptogen generate --config=crypto-config.yaml
echo "Crypto material generated successfully!"
echo ""

echo "Generating Channel Artifacts"

if [ -d "$ARTIFACTS_DIR" ]; then
    echo "Removing existing channel-artifacts directory..."
    rm -rf "$ARTIFACTS_DIR"
fi
mkdir -p "$ARTIFACTS_DIR"

export FABRIC_CFG_PATH=$NETWORK_DIR
echo "FABRIC_CFG_PATH set to: $FABRIC_CFG_PATH"

configtxgen -profile MedicalChannel \
    -outputBlock "$ARTIFACTS_DIR/medicalchannel.block" \
    -channelID medicalchannel
echo "Channel genesis block created!"

echo ""
echo "All artifacts generated successfully!"
echo "Output directory: $ARTIFACTS_DIR"
ls -la "$ARTIFACTS_DIR"
