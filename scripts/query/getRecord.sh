#!/bin/bash
source "$(dirname "$0")/../env.sh"
peer chaincode query \
  -C $CHANNEL \
  -n $CHAINCODE \
  -c "{\"function\":\"GetPatientRecord\",\"Args\":[\"$1\"]}"
# Usage: ./getRecord.sh <patientId>
# Must be called with PatientMSP peer context
