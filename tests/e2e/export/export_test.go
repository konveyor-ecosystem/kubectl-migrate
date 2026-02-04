package export_test

import (
    "os"
    "path/filepath"
    
    . "github.com/onsi/ginkgo/v2"
    . "github.com/onsi/gomega"
    
    "github.com/konveyor-ecosystem/kubectl-migrate/test/utils"
)

var _ = Describe("Export Command", func() {
    var (
        testNamespace string
        exportDir     string
        appName       string
    )
    
    // BeforeAll runs ONCE before all tests in this suite
    BeforeAll(func() {
        GinkgoWriter.Println("Checking kind cluster connectivity...")
        
        // Check if we can connect to a kind cluster
        err := utils.CheckKindCluster("kind")
        Expect(err).NotTo(HaveOccurred(), "Should be able to connect to kind cluster")
        
        GinkgoWriter.Println("✓ Kind cluster is accessible")
    })
    
    // BeforeEach runs before EACH test
    BeforeEach(func() {
        testNamespace = "test-export-ns"
        appName = "test-nginx"
        exportDir = filepath.Join(os.TempDir(), "kubectl-migrate-export-test")
        
        GinkgoWriter.Printf("Setting up test namespace: %s\n", testNamespace)
        
        // Create test namespace
        err := utils.CreateNamespace(testNamespace)
        Expect(err).NotTo(HaveOccurred(), "Should create namespace successfully")
        
        GinkgoWriter.Println("✓ Namespace created")
        
        // Deploy test application
        GinkgoWriter.Printf("Deploying test app: %s\n", appName)
        err = utils.DeployTestApp(testNamespace, appName)
        Expect(err).NotTo(HaveOccurred(), "Should deploy test app successfully")
        
        GinkgoWriter.Println("✓ Test app deployed")
        
        // Create export directory
        err = os.MkdirAll(exportDir, 0755)
        Expect(err).NotTo(HaveOccurred(), "Should create export directory")
        
        GinkgoWriter.Printf("✓ Export directory created: %s\n", exportDir)
    })
    
    // AfterEach runs after EACH test
    AfterEach(func() {
        GinkgoWriter.Println("Cleaning up...")
        
        // Remove export directory
        if exportDir != "" {
            err := os.RemoveAll(exportDir)
            Expect(err).NotTo(HaveOccurred(), "Should remove export directory")
            GinkgoWriter.Println("✓ Export directory removed")
        }
        
        // Delete test namespace
        if testNamespace != "" {
            err := utils.DeleteNamespace(testNamespace)
            Expect(err).NotTo(HaveOccurred(), "Should delete namespace")
            GinkgoWriter.Printf("✓ Namespace %s deleted\n", testNamespace)
        }
    })
    
    Context("Basic Export Test", func() {
        It("should successfully export resources from a namespace", func() {
            GinkgoWriter.Printf("Running export command for namespace: %s\n", testNamespace)
            
            // Run the kubectl migrate export command
            result := utils.RunCommand("kubectl", "migrate", "export", 
                testNamespace, 
                "--export-dir", exportDir)
            
            // Verify command succeeded
            GinkgoWriter.Printf("Command output:\n%s\n", result.String())
            Expect(result.Success()).To(BeTrue(), "Export command should succeed")
            
            // Verify export directory contains files
            files, err := os.ReadDir(exportDir)
            Expect(err).NotTo(HaveOccurred(), "Should be able to read export directory")
            Expect(files).NotTo(BeEmpty(), "Export directory should contain files")
            
            GinkgoWriter.Printf("✓ Exported %d files\n", len(files))
        })
    })
})