#!/bin/bash

set -e

# Source the utility script
source "$(dirname "$0")/utils.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Minikube Setup Script ===${NC}"

# Ensure kubectl installed
install_kubectl

SKIP_INSTALL=false

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case $ARCH in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64|arm64)
        ARCH="arm64"
        ;;
    *)
        echo -e "${RED}Unsupported architecture: $ARCH${NC}"
        exit 1
        ;;
esac

echo -e "${YELLOW}Detected OS: $OS, Architecture: $ARCH${NC}"

# Check if minikube is already installed
if command -v minikube &> /dev/null; then
    CURRENT_VERSION=$(minikube version --short 2>/dev/null || echo "unknown")
    echo -e "${YELLOW}Minikube is already installed: $CURRENT_VERSION${NC}"
    read -p "Do you want to reinstall? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Using existing minikube installation${NC}"
        SKIP_INSTALL=true
    fi
fi

# Install minikube
if [[ "$SKIP_INSTALL" != "true" ]]; then
    echo -e "${GREEN}Installing minikube...${NC}"

    MINIKUBE_VERSION="latest"

    case $OS in
        linux)
            DOWNLOAD_URL="https://storage.googleapis.com/minikube/releases/latest/minikube-${OS}-${ARCH}"
            curl -LO "$DOWNLOAD_URL"
            sudo install minikube-${OS}-${ARCH} /usr/local/bin/minikube
            rm minikube-${OS}-${ARCH}
            ;;
        darwin)
            DOWNLOAD_URL="https://storage.googleapis.com/minikube/releases/latest/minikube-${OS}-${ARCH}"
            curl -LO "$DOWNLOAD_URL"
            sudo install minikube-${OS}-${ARCH} /usr/local/bin/minikube
            rm minikube-${OS}-${ARCH}
            ;;
        *)
            echo -e "${RED}Unsupported OS: $OS${NC}"
            exit 1
            ;;
    esac

    echo -e "${GREEN}Minikube installed successfully!${NC}"
    minikube version
fi

# Check if a minikube cluster is already running
if minikube status &> /dev/null; then
    echo -e "${YELLOW}A minikube cluster is already running${NC}"
    minikube status
    read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Deleting existing cluster...${NC}"
        minikube delete
    else
        echo -e "${GREEN}Using existing cluster${NC}"
        exit 0
    fi
fi

# Start minikube cluster
echo -e "${GREEN}Starting minikube cluster...${NC}"

# Select driver based on OS
case $OS in
    linux)
        DRIVER="kvm2"
        ;;
    darwin)
        DRIVER="docker"  # or hyperkit if available
        ;;
    *)
        echo -e "${RED}Error: Unsupported operating system '$OS'. Cannot determine Minikube driver.${NC}"
        exit 1
        ;;
esac
echo -e "${YELLOW}Using driver: $DRIVER${NC}"

# Check if libvirt is installed (required for kvm2)
if [[ "$OS" == "linux" ]]; then
    if ! command -v virsh &> /dev/null; then
        echo -e "${YELLOW}Warning: libvirt (virsh) not found. KVM2 driver requires libvirt.${NC}"
        echo -e "${YELLOW}Install it with: sudo dnf install libvirt libvirt-daemon-kvm qemu-kvm${NC}"
        echo -e "${YELLOW}Or on Ubuntu/Debian: sudo apt-get install libvirt-daemon-system libvirt-clients qemu-kvm${NC}"
    fi

    # Check if user is in libvirt group
    if ! groups | grep -q libvirt; then
        echo -e "${YELLOW}Warning: Current user is not in 'libvirt' group.${NC}"
        echo -e "${YELLOW}Add yourself with: sudo usermod -aG libvirt \$USER && newgrp libvirt${NC}"
    fi
fi

minikube start --driver="$DRIVER"

# Verify cluster is running
echo -e "${GREEN}Verifying cluster status...${NC}"
minikube status

# Configure kubectl context
echo -e "${GREEN}Configuring kubectl context...${NC}"
kubectl config use-context minikube

echo -e "${GREEN}=== Setup Complete! ===${NC}"
echo -e "Cluster info:"
kubectl cluster-info
echo ""
echo -e "${GREEN}You can now use kubectl to interact with your cluster${NC}"
echo -e "Useful commands:"
echo -e "  ${YELLOW}minikube status${NC}     - Check cluster status"
echo -e "  ${YELLOW}minikube stop${NC}       - Stop the cluster"
echo -e "  ${YELLOW}minikube delete${NC}     - Delete the cluster"
echo -e "  ${YELLOW}minikube dashboard${NC}  - Open Kubernetes dashboard"
