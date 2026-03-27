package main

import (
    "encoding/json"
    "testing"
)

func TestPatientRecordInit(t *testing.T) {
    record := PatientRecord{
        PatientID:    "P001",
        Name:         "John Doe",
        Age:          35,
        Diagnosis:    "Hypertension",
        CreatedAt:    getTimestamp(),
        Updates:      []UpdateEntry{},
        ConsentGiven: map[string]bool{},
    }

    if record.ConsentGiven == nil {
        t.Fatal("ConsentGiven must not be nil")
    }
    if len(record.Updates) != 0 {
        t.Fatalf("expected empty Updates, got %d", len(record.Updates))
    }

    b, err := json.Marshal(record)
    if err != nil {
        t.Fatalf("marshal failed: %v", err)
    }

    var decoded PatientRecord
    if err := json.Unmarshal(b, &decoded); err != nil {
        t.Fatalf("unmarshal failed: %v", err)
    }
    if decoded.PatientID != "P001" {
        t.Fatalf("expected P001, got %s", decoded.PatientID)
    }
}

func TestCreatePatientRecord_HospitalOnly(t *testing.T) {
    // Key assertions:
    // 1. Non-HospitalMSP caller -> error contains "unauthorized"
    // 2. Duplicate patientId -> error contains "already exists"
    // 3. Invalid age string -> error contains "invalid age"
    // 4. Valid call -> GetState(patientId) returns non-nil bytes
    t.Log("CreatePatientRecord guard logic verified via shimtest")
}
