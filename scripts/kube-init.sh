#!/bin/bash
set -eo pipefail

# Validate environment variables
required_vars=(K3S_SERVER_IP)
for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        echo "ERROR: Missing required environment variable $var" >&2
        exit 1
    fi
done

# Ensure .kube directory exists
mkdir -p /home/backenduser/.kube

# Ensure the writable config exists before copying
WRITABLE_CONFIG="/home/backenduser/.kube/config-writable"
if [ ! -f "$WRITABLE_CONFIG" ]; then
    cp ${KUBECONFIG:-/home/backenduser/.kube/config} ${WRITABLE_CONFIG}
fi

# Safely update the kubeconfig to point to the K3s server's IP
echo "Updating kubeconfig with K3s server IP..."
sed "s|server: https://127.0.0.1:6443|server: https://${K3S_SERVER_IP}:6443|g" "$WRITABLE_CONFIG" > /tmp/config-new

# Ensure no conflicting process is using the file before moving
sync && sleep 1
cp /tmp/config-new /home/backenduser/.kube/config-writable && rm -f /tmp/config-new
#if [ -f "/home/backenduser/.kube/config-writable" ]; then
#    echo "Deleting existing config-writable..."
#    rm -f /home/backenduser/.kube/config-writable
#fi
#cp ${KUBECONFIG:-/home/backenduser/.kube/config} /home/backenduser/.kube/config-writable



# Set the KUBECONFIG environment variable to the writable copy
export KUBECONFIG=${WRITABLE_CONFIG}

# Verify cluster access
echo "Testing cluster access..."
if ! kubectl cluster-info --request-timeout=30s; then
    echo "Failed to connect to Kubernetes cluster" >&2
    echo "Debugging information:"
    kubectl version --client
    kubectl config view
    exit 1
fi

echo "K3s cluster configuration complete."
exec "$@"

