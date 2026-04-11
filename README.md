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

2. **Install Prerequisites (Optional)**
   ```bash
   bash install.sh
   sudo apt install docker-compose
   source ~/.bashrc
   ```
   **Note:** Log out and log back in for docker group changes to take effect.

3. **Wipe existing data and generate crypto material**
   ```bash
   cd network
   docker-compose down -v --remove-orphans
   bash scripts/generate.sh
   ```

4. **Start the network**
   ```bash
   bash scripts/start-network.sh
   ```

   This will:
   - Start all Docker containers (3 peers, 3 CouchDB instances, 1 orderer, 3 CAs, CLI)
   - Create channel `medicalchannel`
   - Join all 3 peers to the channel

5. **Deploy the Chaincode (CCaaS)**
   ```bash
   cd ../scripts
   bash deploy-chaincode.sh
   ```

   This script automatically:
   - Packages `connection.json` and installs it on peers
   - Builds the Go chaincode as an external Docker container (`medicalrecord-ccaas`)
   - Approves and Commits the chaincode on the channel
   - Initializes the ledger

6. **Run the Test Suite**
   Verify the medical record functions (create, read, doctor consent loops) across the 3 independent peers:

   ```bash
   bash test-all.sh
   ```

---

## Network Architecture

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
│   ├── deploy-chaincode.sh     # **NEW** CCaaS automated deployment
│   ├── test-all.sh             # Integration test suite
│   ├── env.sh                  # MSP and environment variables
│   ├── invoke/                 # Chaincode invoke scripts
│   └── query/                  # Chaincode query scripts
├── README.md
```