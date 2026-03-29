package main

import (
    "encoding/json"
    "fmt"
    "strconv"
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

func (c *MedicalContract) CreatePatientRecord(ctx contractapi.TransactionContextInterface,
    patientId, name, ageStr, diagnosis string) error {

    mspID, err := ctx.GetClientIdentity().GetMSPID()
    if err != nil {
        return fmt.Errorf("failed to get MSP ID: %v", err)
    }
    if mspID != "HospitalMSP" {
        return fmt.Errorf("unauthorized: only HospitalMSP can create records")
    }

    existing, err := ctx.GetStub().GetState(patientId)
    if err != nil {
        return fmt.Errorf("failed to retrieve patient record: %v", err)
    }
    if existing != nil {
        return fmt.Errorf("patient record %s already exists", patientId)
    }

    age, err := strconv.Atoi(ageStr)
    if err != nil {
        return fmt.Errorf("invalid age value: %v", err)
    }

    record := PatientRecord{
        PatientID:    patientId,
        Name:         name,
        Age:          age,
        Diagnosis:    diagnosis,
        CreatedAt:    getTimestamp(),
        Updates:      []UpdateEntry{},
        ConsentGiven: map[string]bool{},
    }

    recordBytes, err := json.Marshal(record)
    if err != nil {
        return fmt.Errorf("failed to marshal patient record: %v", err)
    }
    return ctx.GetStub().PutState(patientId, recordBytes)
}

func (c *MedicalContract) GiveConsent(ctx contractapi.TransactionContextInterface,
    patientId, doctorId string) error {

    mspID, err := ctx.GetClientIdentity().GetMSPID()
    if err != nil {
        return fmt.Errorf("failed to get MSP ID: %v", err)
    }
    if mspID != "PatientMSP" {
        return fmt.Errorf("unauthorized: only PatientMSP can grant consent")
    }

    recordBytes, err := ctx.GetStub().GetState(patientId)
    if err != nil {
        return fmt.Errorf("failed to retrieve patient record: %v", err)
    }
    if recordBytes == nil {
        return fmt.Errorf("patient record %s does not exist", patientId)
    }

    var record PatientRecord
    if err := json.Unmarshal(recordBytes, &record); err != nil {
        return fmt.Errorf("failed to unmarshal patient record: %v", err)
    }

    record.ConsentGiven[doctorId] = true

    updatedBytes, err := json.Marshal(record)
    if err != nil {
        return fmt.Errorf("failed to marshal patient record: %v", err)
    }
    return ctx.GetStub().PutState(patientId, updatedBytes)
}

func (c *MedicalContract) UpdateMedicalRecord(ctx contractapi.TransactionContextInterface,
    patientId, updateData string) error {

    mspID, err := ctx.GetClientIdentity().GetMSPID()
    if err != nil {
        return fmt.Errorf("failed to get MSP ID: %v", err)
    }
    if mspID != "DoctorMSP" {
        return fmt.Errorf("unauthorized: only DoctorMSP can update records")
    }

    doctorID, err := ctx.GetClientIdentity().GetID()
    if err != nil {
        return fmt.Errorf("failed to get caller identity: %v", err)
    }

    recordBytes, err := ctx.GetStub().GetState(patientId)
    if err != nil {
        return fmt.Errorf("failed to retrieve patient record: %v", err)
    }
    if recordBytes == nil {
        return fmt.Errorf("patient record %s does not exist", patientId)
    }

    var record PatientRecord
    if err := json.Unmarshal(recordBytes, &record); err != nil {
        return fmt.Errorf("failed to unmarshal patient record: %v", err)
    }

    if !record.ConsentGiven[doctorID] {
        return fmt.Errorf("unauthorized: doctor %s does not have consent from patient %s",
            doctorID, patientId)
    }

    entry := UpdateEntry{
        DoctorID:      doctorID,
        Data:          updateData,
        Timestamp:     getTimestamp(),
        TransactionID: ctx.GetStub().GetTxID(),
    }
    record.Updates = append(record.Updates, entry)

    updatedBytes, err := json.Marshal(record)
    if err != nil {
        return fmt.Errorf("failed to marshal patient record: %v", err)
    }
    return ctx.GetStub().PutState(patientId, updatedBytes)
}

func (c *MedicalContract) GetPatientRecord(ctx contractapi.TransactionContextInterface,
    patientId string) (string, error) {

    mspID, err := ctx.GetClientIdentity().GetMSPID()
    if err != nil {
        return "", fmt.Errorf("failed to get MSP ID: %v", err)
    }
    if mspID != "PatientMSP" {
        return "", fmt.Errorf("unauthorized: only PatientMSP can view records")
    }

    recordBytes, err := ctx.GetStub().GetState(patientId)
    if err != nil {
        return "", fmt.Errorf("failed to retrieve patient record: %v", err)
    }
    if recordBytes == nil {
        return "", fmt.Errorf("patient record %s does not exist", patientId)
    }
    return string(recordBytes), nil
}
