#!/bin/bash
source "$(dirname "$0")/../env.sh"
peer chaincode invoke \
  -o $ORDERER \
  -C $CHANNEL \
  -n $CHAINCODE \
  --peerAddresses $PEER_DOCTOR \
  -c "{\"function\":\"UpdateMedicalRecord\",\"Args\":[\"$1\",\"$2\"]}"
# Usage: ./updateRecord.sh <patientId> <updateData>
# Must be called with DoctorMSP peer context
