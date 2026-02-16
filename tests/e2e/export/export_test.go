package export_test

import (
    . "github.com/onsi/ginkgo/v2"
    . "github.com/onsi/gomega"
    
    tests "github.com/konveyor-ecosystem/kubectl-migrate/tests"
)

var _ = Describe("Export Command Tests", func() {
    
    It("should create a namespace on source cluster", func() {
        testNs := "test-namespace-12345"
        
        GinkgoWriter.Printf("Creating namespace: %s\n", testNs)
        
        // Create namespace
        err := tests.SrcCluster.CreateNamespace(testNs)
        Expect(err).NotTo(HaveOccurred())
        
        GinkgoWriter.Println("✓ Namespace created")
        
        // Verify it exists
        result := tests.SrcCluster.RunKubectl("get", "namespace", testNs)
        GinkgoWriter.Printf("Get namespace result:\n%s\n", result.Stdout)
        Expect(result.Success()).To(BeTrue())
        
        // Cleanup
        err = tests.SrcCluster.DeleteNamespace(testNs)
        Expect(err).NotTo(HaveOccurred())
        
        GinkgoWriter.Println("✓ Namespace deleted")
    })
})