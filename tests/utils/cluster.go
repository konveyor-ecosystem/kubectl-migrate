package utils

import (
    "fmt"
)

// ClusterType represents the type of Kubernetes cluster
type ClusterType string

const (
    ClusterTypeKind      ClusterType = "kind"
    ClusterTypeMinikube  ClusterType = "minikube"
    ClusterTypeOpenShift ClusterType = "openshift"
    ClusterTypeGeneric   ClusterType = "generic"
)

// Cluster represents a Kubernetes cluster with its context and type
type Cluster struct {
    Name        string
    Context     string
    Type        ClusterType
    IsOpenShift bool
}

// NewClusterWithContext creates a cluster with explicit context
func NewClusterWithContext(name, context string, clusterType ClusterType) *Cluster {
    cluster := &Cluster{
        Name:    name,
        Context: context,
        Type:    clusterType,
    }
    
    if clusterType == ClusterTypeOpenShift {
        cluster.IsOpenShift = true
    }
    
    return cluster
}

// RunKubectl runs a kubectl command against this cluster
func (c *Cluster) RunKubectl(args ...string) CommandResult {
    // Prepend --context flag to use this cluster
    fullArgs := append([]string{"--context", c.Context}, args...)
    return RunKubectl(fullArgs...)
}

// CheckConnectivity verifies we can connect to this cluster
func (c *Cluster) CheckConnectivity() error {
    result := c.RunKubectl("cluster-info")
    if !result.Success() {
        return fmt.Errorf("cannot connect to cluster %s (context: %s): %s", 
            c.Name, c.Context, result.Stderr)
    }
    return nil
}

// CreateNamespace creates a namespace in this cluster
func (c *Cluster) CreateNamespace(namespace string) error {
    result := c.RunKubectl("create", "namespace", namespace)
    if !result.Success() {
        if !contains(result.Stderr, "already exists") {
            return fmt.Errorf("failed to create namespace in %s: %s", c.Name, result.Stderr)
        }
    }
    return nil
}

// DeleteNamespace deletes a namespace from this cluster
func (c *Cluster) DeleteNamespace(namespace string) error {
    result := c.RunKubectl("delete", "namespace", namespace, "--ignore-not-found=true")
    if !result.Success() {
        return fmt.Errorf("failed to delete namespace from %s: %s", c.Name, result.Stderr)
    }
    return nil
}

// DeployApp deploys a simple test application to this cluster
func (c *Cluster) DeployApp(namespace, appName string) error {
    // Create deployment
    result := c.RunKubectl("create", "deployment", appName,
        "--image=nginx:latest",
        "-n", namespace)
    
    if !result.Success() {
        return fmt.Errorf("failed to create deployment in %s: %s", c.Name, result.Stderr)
    }
    
    // Create service
    result = c.RunKubectl("expose", "deployment", appName,
        "--port=80",
        "--target-port=80",
        "-n", namespace)
    
    if !result.Success() {
        return fmt.Errorf("failed to create service in %s: %s", c.Name, result.Stderr)
    }
    
    return nil
}

// GetPods gets pods from a namespace in this cluster
func (c *Cluster) GetPods(namespace string) CommandResult {
    return c.RunKubectl("get", "pods", "-n", namespace, "-o", "json")
}

// String returns a string representation of the cluster
func (c *Cluster) String() string {
    return fmt.Sprintf("%s (%s) - context: %s", c.Name, c.Type, c.Context)
}

// Helper function to check if a string contains a substring
func contains(s, substr string) bool {
    for i := 0; i <= len(s)-len(substr); i++ {
        if s[i:i+len(substr)] == substr {
            return true
        }
    }
    return false
}