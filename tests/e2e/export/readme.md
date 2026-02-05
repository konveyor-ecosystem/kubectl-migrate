# Export Command E2E Tests

This directory contains end-to-end tests for the `kubectl migrate export` command.

## Test Scenarios

### 1. Basic Export Test
**Objective:** Verify that the export command successfully exports resources from a namespace

**Test Steps:**
1. Set up a test Kubernetes cluster with sample resources
2. Create a test namespace with sample deployments, services, and configmaps
3. Run `kubectl migrate export <namespace> --export-dir <temp-dir>`
4. Verify that:
   - Export directory is created
   - Resource YAML files are exported
   - All expected resource types are present
   - File contents are valid YAML

**Expected Result:** All resources from the namespace are exported to the specified directory

### 2. Export with Invalid Namespace
**Objective:** Verify proper error handling when namespace doesn't exist

**Test Steps:**
1. Run `kubectl migrate export non-existent-namespace --export-dir <temp-dir>`
2. Verify that:
   - Command returns an error
   - Error message is informative
   - No files are created

**Expected Result:** Command fails gracefully with appropriate error message

### 3. Export with Custom Kubeconfig
**Objective:** Verify export works with custom kubeconfig file

**Test Steps:**
1. Create a custom kubeconfig file
2. Run `kubectl migrate export <namespace> --kubeconfig <custom-config> --export-dir <temp-dir>`
3. Verify successful export using the specified kubeconfig

**Expected Result:** Resources are exported using the custom kubeconfig

## Test Data

- Sample deployments: nginx, redis
- Sample services: nginx-service, redis-service
- Sample configmaps: app-config

## Prerequisites

- Kind or Minikube cluster running
- Sample resources deployed (use `make resources-deploy`)