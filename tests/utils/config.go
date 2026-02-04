package utils

import (
    "fmt"
    "os"
    "path/filepath"
    "sync"
    
    "gopkg.in/yaml.v3"
)

// ClusterConfig holds configuration for a single cluster
type ClusterConfig struct {
    Name    string `yaml:"name"`
    Type    string `yaml:"type"`
    Context string `yaml:"context"`
}

// Config is the main configuration structure
type Config struct {
    Clusters struct {
        Source ClusterConfig `yaml:"source"`
        Target ClusterConfig `yaml:"target"`
    } `yaml:"clusters"`
}

var (
    // globalConfig holds the loaded configuration
    globalConfig *Config
    // configOnce ensures config is loaded only once
    configOnce sync.Once
    // configError stores any error from loading
    configError error
)

// GetConfig returns the global config, loading it automatically if needed
func GetConfig() (*Config, error) {
    configOnce.Do(func() {
        configPath := findConfigFile()
        globalConfig, configError = loadConfigFromPath(configPath)
    })
    
    return globalConfig, configError
}

// findConfigFile searches for config.yaml in common locations
func findConfigFile() string {
    possiblePaths := []string{
        "config.yaml",           // current directory
        "tests/config.yaml",     // from project root
        "../config.yaml",        // from tests subdirectory
        "../../config.yaml",     // from tests/e2e subdirectory
    }
    
    for _, path := range possiblePaths {
        if _, err := os.Stat(path); err == nil {
            absPath, _ := filepath.Abs(path)
            fmt.Printf("Found config file: %s\n", absPath)
            return path
        }
    }
    
    return "tests/config.yaml" // default fallback
}

// loadConfigFromPath loads configuration from a specific file path
func loadConfigFromPath(configPath string) (*Config, error) {
    data, err := os.ReadFile(configPath)
    if err != nil {
        return nil, fmt.Errorf("failed to read config file %s: %w", configPath, err)
    }
    
    config := &Config{}
    if err := yaml.Unmarshal(data, config); err != nil {
        return nil, fmt.Errorf("failed to parse config file: %w", err)
    }
    
    return config, nil
}

// LoadConfig manually loads configuration (for testing or special cases)
func LoadConfig(configPath string) (*Config, error) {
    return loadConfigFromPath(configPath)
}

// CreateSourceCluster creates a Cluster instance from source config
func (c *Config) CreateSourceCluster() (*Cluster, error) {
    clusterType := parseClusterType(c.Clusters.Source.Type)
    
    cluster := NewClusterWithContext(
        c.Clusters.Source.Name,
        c.Clusters.Source.Context,
        clusterType,
    )
    
    // Verify connectivity
    if err := cluster.CheckConnectivity(); err != nil {
        return nil, fmt.Errorf("failed to connect to source cluster: %w", err)
    }
    
    return cluster, nil
}

// CreateTargetCluster creates a Cluster instance from target config
func (c *Config) CreateTargetCluster() (*Cluster, error) {
    clusterType := parseClusterType(c.Clusters.Target.Type)
    
    cluster := NewClusterWithContext(
        c.Clusters.Target.Name,
        c.Clusters.Target.Context,
        clusterType,
    )
    
    // Verify connectivity
    if err := cluster.CheckConnectivity(); err != nil {
        return nil, fmt.Errorf("failed to connect to target cluster: %w", err)
    }
    
    return cluster, nil
}

// parseClusterType converts string to ClusterType
func parseClusterType(typeStr string) ClusterType {
    switch typeStr {
    case "kind":
        return ClusterTypeKind
    case "minikube":
        return ClusterTypeMinikube
    case "openshift":
        return ClusterTypeOpenShift
    default:
        return ClusterTypeGeneric
    }
}