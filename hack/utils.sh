#!/bin/bash
set -euo pipefail

# Function to install kubectl if missing
install_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo -e "\033[0;32m=== Installing kubectl ===\033[0m"
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
        ARCH=$(uname -m)
        case $ARCH in
            x86_64) ARCH="amd64" ;;
            aarch64|arm64) ARCH="arm64" ;;
            *) echo "Unsupported architecture: $ARCH"; return 1 ;;
        esac

        K8S_VERSION=$(curl -fL -s https://dl.k8s.io/release/stable.txt) || { echo "Failed to fetch stable kubectl version"; return 1; }
        curl -fLO "https://dl.k8s.io/release/${K8S_VERSION}/bin/${OS}/${ARCH}/kubectl" || { echo "Failed to download kubectl ${K8S_VERSION}"; return 1; }
        chmod +x ./kubectl
        sudo mv ./kubectl /usr/local/bin/kubectl
        echo -e "\033[0;32mkubectl installed successfully!\033[0m"
    fi
}
