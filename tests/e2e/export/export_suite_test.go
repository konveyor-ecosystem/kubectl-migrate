package export_test

import (
    "testing"

    . "github.com/onsi/ginkgo/v2"
    . "github.com/onsi/gomega"
    
    tests "github.com/konveyor-ecosystem/kubectl-migrate/tests"
)

func TestExport(t *testing.T) {
    RegisterFailHandler(Fail)
    RunSpecs(t, "Export Suite")
}

// BeforeSuite - just call the shared setup
var _ = BeforeSuite(func() {
    tests.SetupClusters()
})