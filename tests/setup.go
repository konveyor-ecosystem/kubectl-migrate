package tests

import (
    "github.com/konveyor-ecosystem/kubectl-migrate/tests/utils"
    . "github.com/onsi/ginkgo/v2"
    . "github.com/onsi/gomega"
)

// Global cluster instances available to all tests
var (
    SrcCluster *utils.Cluster
    TgtCluster *utils.Cluster
)

// SetupClusters initializes the source and target clusters
// Call this from any suite's BeforeSuite
func SetupClusters() {
    GinkgoWriter.Println("========================================")
    GinkgoWriter.Println("Setting up test clusters...")
    GinkgoWriter.Println("========================================")
    
    // Load configuration
    GinkgoWriter.Println("\nLoading configuration from config.yaml...")
    config, err := utils.GetConfig()
    Expect(err).NotTo(HaveOccurred(), "Failed to load config.yaml")
    GinkgoWriter.Println("✓ Configuration loaded")
    
    // Create and verify source cluster
    GinkgoWriter.Println("\nConnecting to source cluster...")
    GinkgoWriter.Printf("   - Name: %s\n", config.Clusters.Source.Name)
    GinkgoWriter.Printf("   - Context: %s\n", config.Clusters.Source.Context)
    
    SrcCluster, err = config.CreateCluster(config.Clusters.Source)
    Expect(err).NotTo(HaveOccurred(), "Failed to connect to source cluster")
    GinkgoWriter.Printf("✓ Source cluster connected: %s\n", SrcCluster)
    
    // Create and verify target cluster
    GinkgoWriter.Println("\nConnecting to target cluster...")
    GinkgoWriter.Printf("   - Name: %s\n", config.Clusters.Target.Name)
    GinkgoWriter.Printf("   - Context: %s\n", config.Clusters.Target.Context)
    
    TgtCluster, err = config.CreateCluster(config.Clusters.Target)
    Expect(err).NotTo(HaveOccurred(), "Failed to connect to target cluster")
    GinkgoWriter.Printf("✓ Target cluster connected: %s\n", TgtCluster)
    
    GinkgoWriter.Println("\n========================================")
    GinkgoWriter.Println("Clusters ready!")
    GinkgoWriter.Println("========================================\n")
}