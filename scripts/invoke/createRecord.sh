#!/bin/bash
source "$(dirname "$0")/../env.sh"
peer chaincode invoke \
  -o $ORDERER \
  -C $CHANNEL \
  -n $CHAINCODE \
  --peerAddresses $PEER_HOSPITAL \
  -c "{\"function\":\"CreatePatientRecord\",\"Args\":[\"$1\",\"$2\",\"$3\",\"$4\"]}"
# Usage: ./createRecord.sh <patientId> <name> <age> <diagnosis>
# Must be called with HospitalMSP peer context
