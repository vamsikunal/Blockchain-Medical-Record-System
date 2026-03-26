package main

import (
    "time"
    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type MedicalContract struct {
    contractapi.Contract
}

// PatientRecord is the top-level object stored on-chain per patient.
type PatientRecord struct {
    PatientID    string          `json:"patientId"`
    Name         string          `json:"name"`
    Age          int             `json:"age"`
    Diagnosis    string          `json:"diagnosis"`
    CreatedAt    string          `json:"createdAt"`
    Updates      []UpdateEntry   `json:"updates"`
    ConsentGiven map[string]bool `json:"consentGiven"`
}

// UpdateEntry represents one doctor's update appended to a record.
type UpdateEntry struct {
    DoctorID      string `json:"doctorId"`
    DoctorName    string `json:"doctorName,omitempty"`
    Data          string `json:"data"`
    Timestamp     string `json:"timestamp"`
    TransactionID string `json:"txId,omitempty"`
}

func getTimestamp() string {
    return time.Now().UTC().Format(time.RFC3339)
}
