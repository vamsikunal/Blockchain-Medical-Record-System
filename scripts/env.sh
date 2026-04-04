export CHANNEL=medicalchannel
export CHAINCODE=medicalrecord
export ORDERER=localhost:7050
export PEER_HOSPITAL=localhost:7051
export PEER_DOCTOR=localhost:8051
export PEER_PATIENT=localhost:9051

# Fabric config path (required by peer binary)
export FABRIC_CFG_PATH=/home/$USER/fabric-samples/config

# Ensure TLS is enabled for test scripts
export CORE_PEER_TLS_ENABLED=true
export NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../network" && pwd)"
export ORDERER_CA=${NETWORK_DIR}/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
export HOSPITAL_CA=${NETWORK_DIR}/crypto-config/peerOrganizations/hospital.com/peers/peer0.hospital.com/tls/ca.crt
export DOCTOR_CA=${NETWORK_DIR}/crypto-config/peerOrganizations/doctor.com/peers/peer0.doctor.com/tls/ca.crt
export PATIENT_CA=${NETWORK_DIR}/crypto-config/peerOrganizations/patient.com/peers/peer0.patient.com/tls/ca.crt

# Set MSP environment for a specific org (Hospital | Doctor | Patient)
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
    echo "Unknown org: $ORG (use Hospital, Doctor, or Patient)"; return 1
  fi
}
