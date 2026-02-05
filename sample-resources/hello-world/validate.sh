#!/bin/bash

# Script to validate Apache Hello World service
# Starts port-forward, checks HTTP status and HTML content for "Hello World!"

set -e

# Local forward port mapping
PORT="${PORT:-18080}"
URL="http://127.0.0.1:${PORT}/"
TIMEOUT="${TIMEOUT:-10}"

echo "# Validating Apache Hello World service"
echo "# Using kubectl context: $(kubectl config current-context)"
echo ""

# Check if deployment exists and is ready
echo "Checking deployment status..."
if ! kubectl get deployment apache-hello &>/dev/null; then
    echo "✗ FAILED: Deployment 'apache-hello' not found"
    exit 1
fi

# Wait for deployment to be ready
echo "Waiting for deployment 'apache-hello' to be ready..."
if ! kubectl wait --for=condition=available --timeout=60s deployment/apache-hello; then
    echo "✗ FAILED: Deployment 'apache-hello' did not become ready within 60 seconds"
    kubectl get deployment apache-hello
    kubectl get pods -l app=apache-hello
    exit 1
fi
echo "✓ PASSED: Deployment 'apache-hello' is ready"

# Check if service exists
echo "Checking service presence..."
if ! kubectl get service apache-hello-service &>/dev/null; then
    echo "✗ FAILED: Service 'apache-hello-service' not found"
    exit 1
fi
echo "✓ PASSED: Service 'apache-hello-service' exists"

# Start port-forward in background
echo "Starting port-forward on port ${PORT}..."
kubectl port-forward svc/apache-hello-service ${PORT}:80 &
PF_PID=$!

# Cleanup function to kill port-forward on exit
cleanup() {
    echo ""
    echo "Stopping port-forward (PID: $PF_PID)..."
    kill $PF_PID 2>/dev/null || true
}
trap cleanup EXIT

# Wait for port-forward to be ready
echo "Waiting for port-forward to be ready..."
sleep 3

# Perform curl request and capture HTTP status and response body
echo "Performing HTTP request to ${URL}..."
HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" --max-time "$TIMEOUT" "$URL" 2>&1)

# Extract HTTP status code (last line)
HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tail -n 1)

# Extract response body (everything except last line)
RESPONSE_BODY=$(echo "$HTTP_RESPONSE" | sed '$d')

echo "HTTP Status: $HTTP_STATUS"

# Check HTTP status
if [ "$HTTP_STATUS" != "200" ]; then
    echo "✗ FAILED: Expected HTTP status 200, got $HTTP_STATUS"
    exit 1
fi

echo "✓ PASSED: HTTP status is 200"

# Track validation failures
VALIDATION_FAILED=0

# Check for "Hello World!" in HTML content
if echo "$RESPONSE_BODY" | grep -q "Hello World!"; then
    echo "✓ PASSED: Found 'Hello World!' in HTML content"
else
    echo "✗ FAILED: Could not find 'Hello World!' in HTML content"
    VALIDATION_FAILED=1
fi

# Check for "Apache HTTPD" in HTML content
if echo "$RESPONSE_BODY" | grep -q "Apache HTTPD"; then
    echo "✓ PASSED: Found 'Apache HTTPD' in HTML content"
else
    echo "✗ FAILED: Could not find 'Apache HTTPD' in HTML content"
    VALIDATION_FAILED=1
fi

# Final result
echo ""
if [ "$VALIDATION_FAILED" -eq 0 ]; then
    echo "✓ All validation checks passed!"
    exit 0
else
    echo "✗ Some validation checks failed"
    echo ""
    echo "Response preview (first 500 chars):"
    echo "$RESPONSE_BODY" | head -c 500
    echo ""
    exit 1
fi
