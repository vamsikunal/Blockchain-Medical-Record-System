# Medical Record Management System

Blockchain-based medical record system built on Hyperledger Fabric.

Chaincode written in Go. Three organizations: Hospital, Doctor, Patient.
State database: CouchDB.

---

## Setup

### Prerequisites

- Docker and Docker Compose
- Hyperledger Fabric tools installed (`cryptogen`, `configtxgen`, `peer`)
- Go 1.18+ (for chaincode development)

### Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd Blockchain-Medical-Record-System
   ```

2. **Generate crypto material and channel artifacts**
   ```bash
   bash network/scripts/generate.sh
   ```

3. **Start the network**
   ```bash
   bash network/scripts/start-network.sh
   ```

   This will:
   - Generate crypto material for 3 organizations (Hospital, Doctor, Patient)
   - Create channel artifacts (genesis block, channel transaction)
   - Start all Docker containers (3 peers, 3 CouchDB instances, 1 orderer, 3 CAs, CLI)
   - Create channel `medicalchannel`
   - Join all 3 peers to the channel

4. **Verify the network**
   ```bash
   docker ps
   # Should show: 3 peers + 3 CouchDB + 1 orderer + 3 CAs + CLI
   ```

5. **Enter the CLI container**
   ```bash
   docker exec -it cli bash
   ```

6. **Check channel membership**
   ```bash
   docker exec -e "CORE_PEER_ADDRESS=peer0.hospital.com:7051" \
     -e "CORE_PEER_LOCALMSPID=HospitalMSP" \
     -e "CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/peer/msp" \
     cli peer channel list
   ```

### Network Architecture

| Organization | Peer | CouchDB | CA |
|--------------|------|---------|-----|
| Hospital | peer0.hospital.com:7051 | couchdb.hospital.com:5984 | ca.hospital.com:7054 |
| Doctor | peer0.doctor.com:7051 | couchdb.doctor.com:5984 | ca.doctor.com:8054 |
| Patient | peer0.patient.com:7051 | couchdb.patient.com:5984 | ca.patient.com:9054 |

**Orderer:** orderer.example.com:7050

**Channel:** medicalchannel

### State Database

Each peer uses CouchDB as the state database, enabling rich JSON queries on medical records.

CouchDB Fauxton UI (optional):
- Hospital: http://localhost:5984/_utils
- Doctor: http://localhost:6984/_utils
- Patient: http://localhost:7984/_utils

Login: `admin` / `password`

---

## Project Structure

```
Blockchain-Medical-Record-System/
├── network/
│   ├── crypto-config.yaml      # Crypto material configuration
│   ├── configtx.yaml           # Channel and policy configuration
│   ├── docker-compose.yaml     # All network services
│   ├── scripts/
│   │   ├── generate.sh         # Generate crypto and channel artifacts
│   │   └── start-network.sh    # Full network startup
│   └── channel-artifacts/      # Generated blocks and transactions
├── chaincode/medical-record/   # Go smart contract
├── scripts/
│   ├── invoke/                 # Chaincode invoke scripts
│   └── query/                  # Chaincode query scripts
├── logs/
│   ├── invoke/                 # Invoke transaction logs
│   └── query/                  # Query result logs
└── README.md
```

## Chaincode Deployment

### Package
```bash
peer lifecycle chaincode package medicalrecord.tar.gz \
  --path ./chaincode/medical-record \
  --lang golang \
  --label medicalrecord_1.0
```
### Install on Each Peer (run per org)
```bash
peer lifecycle chaincode install medicalrecord.tar.gz
```
### Get Package ID
```bash
peer lifecycle chaincode queryinstalled
```
### Approve for Each Org
```bash
peer lifecycle chaincode approveformyorg \
  -o orderer.example.com:7050 \
  -C medicalchannel -n medicalrecord \
  --version 1.0 --package-id <PACKAGE_ID> --sequence 1
```
### Commit to Channel
```bash
peer lifecycle chaincode commit \
  -o orderer.example.com:7050 \
  -C medicalchannel -n medicalrecord \
  --version 1.0 --sequence 1 \
  --peerAddresses peer0.hospital.com:7051 \
  --peerAddresses peer0.doctor.com:7051 \
  --peerAddresses peer0.patient.com:7051
```