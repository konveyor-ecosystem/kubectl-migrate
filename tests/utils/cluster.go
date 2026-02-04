package utils

import (
    "fmt"
)

// CheckKindCluster verifies if a kind cluster exists and is accessible
func CheckKindCluster(clusterName string) error {
    // Check if kind cluster exists
    result := RunCommand("kind", "get", "clusters")
    if !result.Success() {
        return fmt.Errorf("failed to get kind clusters: %v", result.Error)
    }
    
    // Check if our specific cluster is in the list
    // For now, we'll just check if kubectl can connect
    result = RunKubectl("cluster-info")
    if !result.Success() {
        return fmt.Errorf("cannot connect to cluster: %s", result.Stderr)
    }
    
    return nil
}

// CreateNamespace creates a Kubernetes namespace
func CreateNamespace(namespace string) error {
    result := RunKubectl("create", "namespace", namespace)
    if !result.Success() {
        // Check if namespace already exists
        if result.Stderr != "" && !contains(result.Stderr, "already exists") {
            return fmt.Errorf("failed to create namespace: %s", result.Stderr)
        }
    }
    return nil
}

// DeleteNamespace deletes a Kubernetes namespace
func DeleteNamespace(namespace string) error {
    result := RunKubectl("delete", "namespace", namespace, "--ignore-not-found=true")
    if !result.Success() {
        return fmt.Errorf("failed to delete namespace: %s", result.Stderr)
    }
    return nil
}

// DeployTestApp deploys a simple test application to a namespace
func DeployTestApp(namespace, appName string) error {
    // Create a simple nginx deployment
    result := RunKubectl("create", "deployment", appName,
        "--image=nginx:latest",
        "-n", namespace)
    
    if !result.Success() {
        return fmt.Errorf("failed to create deployment: %s", result.Stderr)
    }
    
    // Create a service for the deployment
    result = RunKubectl("expose", "deployment", appName,
        "--port=80",
        "--target-port=80",
        "-n", namespace)
    
    if !result.Success() {
        return fmt.Errorf("failed to create service: %s", result.Stderr)
    }
    
    return nil
}

// Helper function to check if a string contains a substring
func contains(s, substr string) bool {
    return len(s) >= len(substr) && (s == substr || len(s) > len(substr) && 
        (s[:len(substr)] == substr || s[len(s)-len(substr):] == substr || 
        findSubstring(s, substr)))
}

func findSubstring(s, substr string) bool {
    for i := 0; i <= len(s)-len(substr); i++ {
        if s[i:i+len(substr)] == substr {
            return true
        }
    }
    return false
}