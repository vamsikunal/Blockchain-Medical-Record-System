#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK_DIR="$(cd "$SCRIPT_DIR/../network" && pwd)"
CHAINCODE_DIR="$(cd "$SCRIPT_DIR/../chaincode/medical-record" && pwd)"

source "$SCRIPT_DIR/env.sh"

export FABRIC_CFG_PATH="/home/prasun/fabric-samples/config"
export CC_NAME=${CHAINCODE:-medicalrecord}
export CC_VERSION="1.0"
export CC_SEQUENCE=1
export CC_PKG="medicalrecord.tar.gz"

echo "=== Deploying Chaincode ==="

# Function to set env vars for a specific org
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
    echo "Unknown Org"
    exit 1
  fi
}

echo "1. Packaging chaincode (CCaaS format)..."
cd "$SCRIPT_DIR"
cat << EOF > connection.json
{
  "address": "medicalrecord-ccaas:9999",
  "dial_timeout": "10s",
  "tls_required": false
}
EOF
cat << EOF > metadata.json
{
  "type": "ccaas",
  "label": "${CC_NAME}_${CC_VERSION}"
}
EOF
tar cfz code.tar.gz connection.json
tar cfz ${CC_PKG} code.tar.gz metadata.json
rm connection.json metadata.json code.tar.gz

echo "2. Installing chaincode on all peers..."
for ORG in Hospital Doctor Patient; do
  setGlobals $ORG
  echo "Installing on $ORG..."
  peer lifecycle chaincode install ${CC_PKG}
done

echo "3. Querying installed chaincode..."
setGlobals Hospital
peer lifecycle chaincode queryinstalled > log.txt
PACKAGE_ID=$(sed -n "/${CC_NAME}_${CC_VERSION}/{s/^Package ID: //; s/, Label:.*$//; p;}" log.txt | tail -n 1)
echo "PackageID is ${PACKAGE_ID}"

echo "3.5 Starting CCaaS Chaincode Container..."
docker build -t medicalrecord-ccaas ${CHAINCODE_DIR}
docker rm -f medicalrecord-ccaas || true
docker run -d --name medicalrecord-ccaas \
  --network fabric_network \
  -e CHAINCODE_SERVER_ADDRESS=0.0.0.0:9999 \
  -e CHAINCODE_ID=${PACKAGE_ID} \
  -e CORE_CHAINCODE_ID_NAME=${PACKAGE_ID} \
  medicalrecord-ccaas
sleep 5

echo "4. Approving for organizations (skipped, already approved)..."
# for ORG in Hospital Doctor Patient; do
#   setGlobals $ORG
#   echo "Approving for $ORG..."
#   peer lifecycle chaincode approveformyorg -o localhost:7050 \
#     --ordererTLSHostnameOverride orderer.example.com --tls --cafile $ORDERER_CA \
#     --channelID $CHANNEL --name $CC_NAME --version $CC_VERSION \
#     --package-id ${PACKAGE_ID} --sequence $CC_SEQUENCE
# done

echo "5. Committing chaincode..."
setGlobals Hospital
peer lifecycle chaincode commit -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile $ORDERER_CA \
  --channelID $CHANNEL --name $CC_NAME \
  --peerAddresses localhost:7051 --tlsRootCertFiles $HOSPITAL_CA \
  --peerAddresses localhost:8051 --tlsRootCertFiles $DOCTOR_CA \
  --version $CC_VERSION --sequence $CC_SEQUENCE

echo "6. Initializing chaincode (if required)..."
sleep 5 # Wait for commit to propagate
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile $ORDERER_CA -C $CHANNEL -n $CC_NAME \
  --peerAddresses localhost:7051 --tlsRootCertFiles $HOSPITAL_CA \
  -c '{"function":"InitLedger","Args":[]}' || echo "InitLedger not found or failed, ignoring."

echo "=== Chaincode Deployment Complete ==="
