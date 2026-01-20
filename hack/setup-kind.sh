#!/bin/bash

set -e

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

# Detect container runtime (Podman or Docker)
CONTAINER_RUNTIME=""
if command -v podman &> /dev/null; then
    echo -e "${YELLOW}Detected Podman${NC}"
    CONTAINER_RUNTIME="podman"

    # Check if podman is running
    if ! podman info &> /dev/null; then
        echo -e "${RED}Error: Podman is installed but not working correctly${NC}"
        exit 1
    fi

    # Platform-specific podman setup
    if [[ "$OS" == "darwin" ]]; then
        # macOS - use podman machine
        echo -e "${YELLOW}Setting up Podman for macOS...${NC}"
        
        # Check if podman machine exists and is running
        if ! podman machine list 2>/dev/null | grep -q "Currently running"; then
            echo -e "${YELLOW}No running podman machine detected${NC}"
            
            # Check if machine exists but is stopped
            if podman machine list 2>/dev/null | grep -q "podman-machine-default"; then
                echo -e "${YELLOW}Starting existing podman machine...${NC}"
                podman machine start
            else
                echo -e "${YELLOW}Initializing new podman machine...${NC}"
                podman machine init
                podman machine start
            fi
        fi
        
        # Get the correct socket path for macOS
        PODMAN_SOCK=$(podman machine inspect --format '{{.ConnectionInfo.PodmanSocket.Path}}' 2>/dev/null || echo "$HOME/.local/share/containers/podman/machine/qemu/podman.sock")
        if [[ -S "$PODMAN_SOCK" ]]; then
            export DOCKER_HOST="unix://$PODMAN_SOCK"
            echo -e "${GREEN}Using Podman socket: $DOCKER_HOST${NC}"
        fi
        
    elif [[ "$OS" == "linux" ]]; then
        # Linux - use systemd socket
    if ! systemctl --user is-active --quiet podman.socket; then
        echo -e "${YELLOW}Starting podman socket for kind...${NC}"
        systemctl --user start podman.socket
        systemctl --user enable podman.socket
    fi

    export DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock
        echo -e "${GREEN}Using Podman socket: $DOCKER_HOST${NC}"
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
        echo -e "${GREEN}Using existing cluster${NC}"
        kubectl config use-context "kind-${CLUSTER_NAME}"
        exit 0
    fi
fi

# Start kind cluster
echo -e "${GREEN}Creating kind cluster...${NC}"
kind create cluster --name "${CLUSTER_NAME}"

# Verify cluster is running
echo -e "${GREEN}Verifying cluster status...${NC}"
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
