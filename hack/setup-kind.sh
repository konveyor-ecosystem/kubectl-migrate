#!/bin/bash

set -e

# Source the utility script
source "$(dirname "$0")/utils.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== kind Setup Script ===${NC}"

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

# --- Part 1: Ensure kubectl is installed ---
install_kubectl

# --- Part 2: Install kind ---
SKIP_INSTALL=false

# Check if kind is already installed
if command -v kind &> /dev/null; then
    CURRENT_VERSION=$(kind version 2>/dev/null || echo "unknown")
    echo -e "${YELLOW}kind is already installed: $CURRENT_VERSION${NC}"
    read -p "Do you want to reinstall? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Using existing kind installation${NC}"
        SKIP_INSTALL=true
    fi
fi

# Install kind
if [[ "$SKIP_INSTALL" != "true" ]]; then
    echo -e "${GREEN}Installing kind...${NC}"

    KIND_VERSION="v0.31.0"

    case $OS in
        linux|darwin)
            DOWNLOAD_URL="https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-${OS}-${ARCH}"
            curl -Lo ./kind "$DOWNLOAD_URL"
            chmod +x ./kind
            sudo mv ./kind /usr/local/bin/kind
            ;;
        *)
            echo -e "${RED}Unsupported OS: $OS${NC}"
            exit 1
            ;;
    esac

    echo -e "${GREEN}kind installed successfully!${NC}"
    kind version
fi

# --- Part 3: Runtime Detection & Fedora/Podman Fixes ---
CONTAINER_RUNTIME=""
if command -v podman &> /dev/null; then
    echo -e "${YELLOW}Detected Podman${NC}"
    CONTAINER_RUNTIME="podman"

    # Platform-specific podman setup
    if [[ "$OS" == "darwin" ]]; then
        # macOS - use podman machine
        echo -e "${YELLOW}Setting up Podman for macOS...${NC}"
        
        # Find running podman machine using structured output
        RUNNING_MACHINE=$(podman machine list --format '{{.Name}} {{.Running}}' 2>/dev/null | grep ' true$' | awk '{print $1}' | sed 's/\*$//' | head -n1)
        
        if [[ -z "$RUNNING_MACHINE" ]]; then
            echo -e "${YELLOW}No running podman machine detected${NC}"
            
            # Get the first available machine name (default or first in list)
            MACHINE_NAME=$(podman machine list --format '{{.Name}}' 2>/dev/null | sed 's/\*$//' | head -n1)
            
            if [[ -n "$MACHINE_NAME" ]]; then
                echo -e "${YELLOW}Starting existing podman machine: $MACHINE_NAME${NC}"
                podman machine start "$MACHINE_NAME"
                RUNNING_MACHINE="$MACHINE_NAME"
            else
                echo -e "${YELLOW}Initializing new podman machine...${NC}"
                podman machine init
                MACHINE_NAME=$(podman machine list --format '{{.Name}}' 2>/dev/null | sed 's/\*$//' | head -n1)
                podman machine start "$MACHINE_NAME"
                RUNNING_MACHINE="$MACHINE_NAME"
            fi
        else
            echo -e "${GREEN}Found running podman machine: $RUNNING_MACHINE${NC}"
        fi
        
        # Get the socket path from the specific running machine
        if [[ -n "$RUNNING_MACHINE" ]]; then
            PODMAN_SOCK=$(podman machine inspect "$RUNNING_MACHINE" --format '{{.ConnectionInfo.PodmanSocket.Path}}' 2>/dev/null)
            
            if [[ -n "$PODMAN_SOCK" ]] && [[ -S "$PODMAN_SOCK" ]]; then
                export DOCKER_HOST="unix://$PODMAN_SOCK"
                echo -e "${GREEN}Using Podman socket from $RUNNING_MACHINE: $DOCKER_HOST${NC}"
            else
                echo -e "${YELLOW}Warning: Could not get socket path from machine, podman may still work via default connection${NC}"
            fi
        fi
        
    elif [[ "$OS" == "linux" ]]; then
        # Fedora/Linux specific: kind needs the experimental provider flag for Podman
        export KIND_EXPERIMENTAL_PROVIDER=podman

        # Linux - verify podman is working first
        if ! podman info &> /dev/null; then
            echo -e "${RED}Error: Podman is installed but not working correctly${NC}"
            exit 1
        fi
        
        # Set up systemd socket
        if ! systemctl --user is-active --quiet podman.socket; then
            echo -e "${YELLOW}Starting podman socket for kind...${NC}"
            systemctl --user start podman.socket
            systemctl --user enable podman.socket
        fi
        
        export DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock
        echo -e "${GREEN}Using Podman socket: $DOCKER_HOST${NC}"
    fi

    # Final verify podman is working (after machine start or socket setup)
    if ! podman info &> /dev/null; then
        echo -e "${RED}Error: Podman is active but not responding correctly${NC}"
        exit 1
    fi

    # Create docker symlink if it doesn't exist (some tools expect 'docker' command)
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Creating docker symlink to podman...${NC}"
        sudo ln -sf $(which podman) /usr/local/bin/docker 2>/dev/null || true
    fi

elif command -v docker &> /dev/null; then
    echo -e "${YELLOW}Detected Docker${NC}"
    CONTAINER_RUNTIME="docker"

    # Check if docker is running
    if ! docker info &> /dev/null; then
        echo -e "${RED}Error: Docker is installed but not running${NC}"
        
        if [[ "$OS" == "darwin" ]]; then
            echo -e "${YELLOW}Please start Docker Desktop and try again${NC}"
        else
            echo -e "${YELLOW}Please start Docker daemon and try again${NC}"
        fi
        exit 1
    fi
else
    echo -e "${RED}Error: Neither Podman nor Docker is installed${NC}"
    echo -e "${YELLOW}kind requires either Podman or Docker to run${NC}"
    echo ""
    
    if [[ "$OS" == "darwin" ]]; then
        echo -e "For macOS, install one of:"
        echo -e "  ${GREEN}Docker Desktop: https://docs.docker.com/desktop/install/mac-install/${NC}"
        echo -e "  ${GREEN}Podman: brew install podman${NC}"
    elif [[ "$OS" == "linux" ]]; then
        echo -e "For Linux, install Podman with:"
        echo -e "  ${GREEN}sudo dnf install -y podman${NC} (Fedora/RHEL)"
        echo -e "  ${GREEN}sudo apt install -y podman${NC} (Ubuntu/Debian)"
    fi
    echo ""
    echo -e "Or install Docker from: https://docs.docker.com/get-docker/"
    exit 1
fi

echo -e "${GREEN}Using container runtime: ${CONTAINER_RUNTIME}${NC}"

# Default cluster name
CLUSTER_NAME="kind"

# Check if a kind cluster already exists
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo -e "${YELLOW}A kind cluster named '${CLUSTER_NAME}' already exists${NC}"
    kind get clusters
    read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Deleting existing cluster...${NC}"
        kind delete cluster --name "${CLUSTER_NAME}"
    else
        echo -e "${GREEN}Using existing cluster. Re-syncing kubeconfig...${NC}"
        # Fedora Fix: Re-exporting config ensures the dynamic port is updated
        kind export kubeconfig --name "${CLUSTER_NAME}"
        kubectl config use-context "kind-${CLUSTER_NAME}"
        exit 0
    fi
fi

# Start kind cluster
echo -e "${GREEN}Creating kind cluster...${NC}"
kind create cluster --name "${CLUSTER_NAME}"

# Verify cluster is running
echo -e "${GREEN}Verifying cluster status...${NC}"
# Re-syncing config here is a safety measure for rootless Podman
kind export kubeconfig --name "${CLUSTER_NAME}"
kubectl cluster-info --context "kind-${CLUSTER_NAME}"

# Configure kubectl context
echo -e "${GREEN}Configuring kubectl context...${NC}"
kubectl config use-context "kind-${CLUSTER_NAME}"

echo -e "${GREEN}=== Setup Complete! ===${NC}"
echo -e "Cluster info:"
kubectl cluster-info
echo ""
echo -e "${GREEN}You can now use kubectl to interact with your cluster${NC}"
echo -e "Useful commands:"
echo -e "  ${YELLOW}kind get clusters${NC}           - List all kind clusters"
echo -e "  ${YELLOW}kubectl cluster-info${NC}        - Check cluster status"
echo -e "  ${YELLOW}kind delete cluster${NC}         - Delete the cluster"
echo -e "  ${YELLOW}kind load docker-image <img>${NC} - Load a Docker image into the cluster"
