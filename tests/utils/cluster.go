package utils

import (
    "fmt"
)

// Cluster represents a Kubernetes cluster with its context and type
type Cluster struct {
    Name        string
    Context     string
}

// NewClusterWithContext creates a cluster with explicit context
func NewClusterWithContext(name, context string) *Cluster {
    cluster := &Cluster{
        Name:    name,
        Context: context,
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

// GetPods gets pods from a namespace in this cluster
func (c *Cluster) GetPods(namespace string) CommandResult {
    return c.RunKubectl("get", "pods", "-n", namespace, "-o", "json")
}

// String returns a string representation of the cluster
func (c *Cluster) String() string {
    return fmt.Sprintf("%s - context: %s", c.Name, c.Context)
}