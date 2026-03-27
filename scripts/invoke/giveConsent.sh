#!/bin/bash
source "$(dirname "$0")/../env.sh"
peer chaincode invoke \
  -o $ORDERER \
  -C $CHANNEL \
  -n $CHAINCODE \
  --peerAddresses $PEER_PATIENT \
  -c "{\"function\":\"GiveConsent\",\"Args\":[\"$1\",\"$2\"]}"
# Usage: ./giveConsent.sh <patientId> <doctorId>
# Must be called with PatientMSP peer context
