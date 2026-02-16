# Testing Framework for kubectl-migrate

This directory contains the end-to-end (e2e) testing framework for kubectl-migrate using Ginkgo and Gomega.

## Table of Contents
- [Directory Structure](#directory-structure)
- [Prerequisites](#prerequisites)
- [Configuration](#configuration)
- [Running Tests](#running-tests)
- [Writing New Tests](#writing-new-tests)
- [Test Utilities](#test-utilities)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Directory Structure
```
tests/
├── config.yaml              # Cluster configuration (git-ignored)
├── config.yaml.template     # Template for cluster configuration
├── shared.go                # Global cluster variables and setup function
├── e2e_suite_test.go       # Main test suite (optional)
├── utils/                   # Testing utilities
│   ├── cluster.go          # Cluster management (Cluster struct)
│   ├── command.go          # Command execution utilities
│   └── config.go           # Configuration loading
└── e2e/                     # End-to-end test suites
    ├── export/
    │   ├── export_suite_test.go  # Export test suite setup
    │   ├── export_test.go        # Export test cases
    │   └── README.md             # Export test documentation
    └── transform/
        └── ...
```

## Prerequisites

1. **Go 1.24+** installed
2. **Ginkgo CLI** installed:
```bash
   go install github.com/onsi/ginkgo/v2/ginkgo@latest
```
3. **kubectl** installed and configured
4. **Two Kubernetes clusters** running (kind, minikube, or OpenShift) for now only kind is supported

## Configuration

### Step 1: Set Up Clusters

You need two Kubernetes clusters for testing:

**For Kind clusters:**
```bash
# Create source cluster
kind create cluster --name src-cluster

# Create target cluster
kind create cluster --name tgt-cluster
```

**For Minikube:**
```bash
minikube start -p src-cluster
minikube start -p tgt-cluster
```

### Step 2: Verify Cluster Contexts

Check your available contexts:
```bash
kubectl config get-contexts
```

You should see output like:
```
CURRENT   NAME                  CLUSTER
*         kind-src-cluster      kind-src-cluster
          kind-tgt-cluster      kind-tgt-cluster
```

Note the **NAME** column - these are your context names.

### Step 3: Configure Tests

Copy the config template:
```bash
cp config.yaml.template config.yaml
```

Edit `config.yaml` with your actual cluster contexts:
```yaml
clusters:
  source:
    name: "src_cluster"
    context: "kind-src-cluster"     # Must match kubectl context name
  
  target:
    name: "tgt_cluster"
    context: "kind-tgt-cluster"     # Must match kubectl context name
```

**Important:** The `context` values must **exactly match** the NAME from `kubectl config get-contexts`.

### Step 4: Verify Connectivity

Test both clusters are accessible:
```bash
kubectl --context kind-src-cluster cluster-info
kubectl --context kind-tgt-cluster cluster-info
```

Both should return cluster information without errors.

## Running Tests

### Run All Tests
```bash
# From project root
ginkgo -v -r tests/

# From tests directory
cd tests
ginkgo -v -r
```

### Run Specific Test Suite
```bash
ginkgo -v tests/e2e/export/
```

### Run Tests in Watch Mode
```bash
ginkgo watch -v -r tests/
```

### Run with Focus
```bash
# Run only tests matching a pattern
ginkgo -v -r tests/ --focus="should create a namespace"
```

### Common Flags
- `-v` - Verbose output
- `-r` - Recursive (run all nested suites)
- `--focus="pattern"` - Run only matching tests
- `--skip="pattern"` - Skip matching tests
- `--fail-fast` - Stop on first failure
- `--race` - Run with race detector

## Writing New Tests

### Create a New Test Suite

1. **Create the directory:**
```bash
   mkdir -p tests/e2e/apply
   cd tests/e2e/apply
```

2. **Bootstrap the suite:**
```bash
   ginkgo bootstrap
```

3. **Update the suite file** (`apply_suite_test.go`):
```go
   package apply_test

   import (
       "testing"
       . "github.com/onsi/ginkgo/v2"
       . "github.com/onsi/gomega"
       
       tests "github.com/konveyor-ecosystem/kubectl-migrate/tests"
   )

   func TestApply(t *testing.T) {
       RegisterFailHandler(Fail)
       RunSpecs(t, "Apply Suite")
   }

   var _ = BeforeSuite(func() {
       tests.SetupClusters()  // This sets up SrcCluster and TgtCluster
   })
```

4. **Create your test file** (`apply_test.go`):
```go
   package apply_test

   import (
       . "github.com/onsi/ginkgo/v2"
       . "github.com/onsi/gomega"
       
       tests "github.com/konveyor-ecosystem/kubectl-migrate/tests"
   )

   var _ = Describe("Apply Command Tests", func() {
       
       It("should apply resources to target cluster", func() {
           // Your test logic
       })
   })
```

## Test Utilities

### Cluster Operations

The `Cluster` struct provides methods for common operations:
```go
// Create namespace
err := tests.SrcCluster.CreateNamespace("my-namespace")

// Delete namespace
err := tests.SrcCluster.DeleteNamespace("my-namespace")

// Deploy test application (nginx deployment + service)
err := tests.SrcCluster.DeployApp("my-namespace", "test-app")

// Run kubectl command
result := tests.SrcCluster.RunKubectl("get", "pods", "-n", "my-namespace")

// Get pods
result := tests.SrcCluster.GetPods("my-namespace")

// Check connectivity
err := tests.SrcCluster.CheckConnectivity()
```

### Command Execution
```go
// Run any command
result := utils.RunCommand("kind", "get", "clusters")

// Run kubectl (without cluster context)
result := utils.RunKubectl("version")

// Check if command succeeded
if result.Success() {
    fmt.Println("Command output:", result.Stdout)
} else {
    fmt.Println("Command failed:", result.Stderr)
}
```

### Using Both Clusters
```go
It("should migrate from source to target", func() {
    testNs := "migration-test"
    
    // Setup on source
    tests.SrcCluster.CreateNamespace(testNs)
    tests.SrcCluster.DeployApp(testNs, "app")
    
    // Verify on source
    result := tests.SrcCluster.GetPods(testNs)
    Expect(result.Success()).To(BeTrue())
    
    // Export, transform, apply logic here...
    
    // Setup on target
    tests.TgtCluster.CreateNamespace(testNs)
    
    // Verify on target
    result = tests.TgtCluster.GetPods(testNs)
    Expect(result.Success()).To(BeTrue())
    
    // Cleanup both clusters
    tests.SrcCluster.DeleteNamespace(testNs)
    tests.TgtCluster.DeleteNamespace(testNs)
})
```

## Best Practices

### 1. Always Clean Up Resources

Use `AfterEach` or `DeferCleanup` to ensure cleanup:
```go
var _ = Describe("My Tests", func() {
    var testNs string
    
    BeforeEach(func() {
        testNs = "test-ns-" + randomString()
        tests.SrcCluster.CreateNamespace(testNs)
        
        DeferCleanup(func() {
            tests.SrcCluster.DeleteNamespace(testNs)
        })
    })
    
    It("should do something", func() {
        // Test logic - cleanup happens automatically
    })
})
```

### 2. Use Unique Namespace Names

Avoid conflicts by using unique names:
```go
testNs := fmt.Sprintf("test-%d", GinkgoRandomSeed())
// or
testNs := "test-" + uuid.New().String()[:8]
```

### 3. Document Your Test Scenarios

Create a README.md in each test directory documenting:
- What scenarios are tested
- Prerequisites
- Expected outcomes

### 4. Use Descriptive Test Names
```go
// Good
It("should successfully export deployment and service resources", func() {

// Bad
It("should work", func() {
```

### 5. Test Isolation

Each test should be independent and not rely on state from other tests:
```go
// Good - each test creates its own namespace
It("test 1", func() {
    ns := "test-1"
    tests.SrcCluster.CreateNamespace(ns)
    defer tests.SrcCluster.DeleteNamespace(ns)
})

It("test 2", func() {
    ns := "test-2"
    tests.SrcCluster.CreateNamespace(ns)
    defer tests.SrcCluster.DeleteNamespace(ns)
})
```

### 6. Use Table-Driven Tests for Multiple Scenarios
```go
DescribeTable("namespace operations",
    func(namespace string, shouldSucceed bool) {
        err := tests.SrcCluster.CreateNamespace(namespace)
        if shouldSucceed {
            Expect(err).NotTo(HaveOccurred())
            defer tests.SrcCluster.DeleteNamespace(namespace)
        } else {
            Expect(err).To(HaveOccurred())
        }
    },
    Entry("valid namespace", "test-valid", true),
    Entry("invalid characters", "test_invalid!", false),
    Entry("too long", strings.Repeat("a", 100), false),
)
```

## Troubleshooting

### Tests Don't Run

**Problem:** `Found no test suites`

**Solution:** Make sure you have a `*_suite_test.go` file in the directory:
```bash
cd tests/e2e/your-directory
ginkgo bootstrap
```

### Context Not Found Error

**Problem:** `error: context "kind-xxx" does not exist`

**Solution:** 
1. Check your contexts: `kubectl config get-contexts`
2. Update `config.yaml` with exact context names
3. Ensure clusters are running: `kind get clusters` or `minikube status`

### Import Errors

**Problem:** `no required module provides package`

**Solution:**
```bash
go mod tidy
go get github.com/konveyor-ecosystem/kubectl-migrate/tests/utils
```

### SrcCluster or TgtCluster is nil

**Problem:** `runtime error: invalid memory address`

**Solution:** Make sure your suite file calls `tests.SetupClusters()`:
```go
var _ = BeforeSuite(func() {
    tests.SetupClusters()
})
```

### Namespace Already Exists

**Problem:** Tests fail because namespace already exists from previous run

**Solution:** Use unique namespace names or ensure cleanup:
```bash
# Manual cleanup if needed
kubectl --context kind-src-cluster delete namespace test-namespace --ignore-not-found
```

## Contributing

When adding new tests:

1. Create tests in the appropriate `e2e/` subdirectory
2. Document test scenarios in a README.md
3. Ensure tests clean up resources
4. Use descriptive test names
5. Add comments for complex logic
6. Run tests locally before submitting PR: `ginkgo -v -r tests/`

## Additional Resources

- [Ginkgo Documentation](https://onsi.github.io/ginkgo/)
- [Gomega Matchers](https://onsi.github.io/gomega/)
- [kubectl-migrate Documentation](../README.md)