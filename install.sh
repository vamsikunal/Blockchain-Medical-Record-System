#!/bin/bash

# Root & User Check
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo: sudo ./setup_blockchain.sh"
  exit 1
fi

REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo ~$REAL_USER)

echo "Starting full blockchain environment setup for user: $REAL_USER"
echo "------------------------------------------------"

# Go Installation & Permanent PATH
if ! sudo -u $REAL_USER command -v go &> /dev/null; then
  echo "[1/5] Installing Go 1.21.6..."
  wget -q https://go.dev/dl/go1.21.6.linux-amd64.tar.gz
  rm -rf /usr/local/go
  tar -C /usr/local -xzf go1.21.6.linux-amd64.tar.gz
  rm go1.21.6.linux-amd64.tar.gz
  
  if ! grep -q "/usr/local/go/bin" "$USER_HOME/.bashrc"; then
    echo 'export PATH=$PATH:/usr/local/go/bin' >> "$USER_HOME/.bashrc"
  fi
else
  echo "[1/5] Go is already installed."
fi
# Temporarily export path for the rest of the script
export PATH=$PATH:/usr/local/go/bin

# Docker Installation
if ! command -v docker &> /dev/null; then
  echo "[2/5] Installing Docker..."
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
  rm get-docker.sh
else
  echo "[2/5] Docker is already installed."
fi

# Docker Compose & Non-Sudo Docker Group
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
  echo "[3/5] Installing Docker Compose..."
  apt-get update -qq
  apt-get install -y docker-compose-plugin docker-compose -qq
else
  echo "[3/5] Docker Compose is already installed."
fi

echo "Adding $REAL_USER to the docker group..."
usermod -aG docker $REAL_USER

# Hyperledger Fabric (Binaries + Samples) & Permanent PATH
echo "[4/5] Setting up Hyperledger Fabric..."
cd "$USER_HOME"
if [ ! -d "$USER_HOME/fabric-samples" ]; then
  echo "Downloading fabric-samples and binaries..."
  curl -sSLO https://raw.githubusercontent.com/hyperledger/fabric/main/scripts/install-fabric.sh
  chmod +x install-fabric.sh
  
  # Run as the real user so the folder is owned by you, not root
  sudo -u $REAL_USER ./install-fabric.sh binary samples
  
  if ! grep -q "$USER_HOME/fabric-samples/bin" "$USER_HOME/.bashrc"; then
    echo "export PATH=\$PATH:$USER_HOME/fabric-samples/bin" >> "$USER_HOME/.bashrc"
  fi
  
  rm install-fabric.sh
else
  echo "fabric-samples folder already exists in $USER_HOME."
fi

# Project Permissions & Executable Scripts
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[5/5] Updating project permissions for $PROJECT_DIR..."

if [ -d "$PROJECT_DIR" ]; then
  # Recursively change ownership of the entire project to your user
  chown -R $REAL_USER:$REAL_USER "$PROJECT_DIR"
  echo "Ownership updated."
  
  # Make the specific scripts executable
  if [ -f "$PROJECT_DIR/network/scripts/generate.sh" ]; then
    chmod +x "$PROJECT_DIR/network/scripts/generate.sh"
    echo "Made generate.sh executable."
  fi
  
  if [ -f "$PROJECT_DIR/network/scripts/start-network.sh" ]; then
    chmod +x "$PROJECT_DIR/network/scripts/start-network.sh"
    echo "Made start-network.sh executable."
  fi
else
  echo "WARNING: Project directory not found. Skipping folder permissions."
fi

echo "------------------------------------------------"
echo "ALL DONE!"
echo "IMPORTANT: To apply the new PATHs and Docker group permissions without restarting your computer, run:"
echo "source ~/.bashrc"
echo "log out and log back in to ensure all changes take effect, especially for Docker permissions."