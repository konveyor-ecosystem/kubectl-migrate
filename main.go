package main

import (
	"os"

	"github.com/konveyor-ecosystem/kubectl-migrate/cmd/apply"
	"github.com/konveyor-ecosystem/kubectl-migrate/cmd/convert"
	export "github.com/konveyor-ecosystem/kubectl-migrate/cmd/export"
	plugin_manager "github.com/konveyor-ecosystem/kubectl-migrate/cmd/plugin-manager"
	"github.com/konveyor-ecosystem/kubectl-migrate/cmd/runfn"
	skopeo_sync_gen "github.com/konveyor-ecosystem/kubectl-migrate/cmd/skopeo-sync-gen"
	transfer_pvc "github.com/konveyor-ecosystem/kubectl-migrate/cmd/transfer-pvc"
	"github.com/konveyor-ecosystem/kubectl-migrate/cmd/transform"
	tunnel_api "github.com/konveyor-ecosystem/kubectl-migrate/cmd/tunnel-api"
	"github.com/konveyor-ecosystem/kubectl-migrate/cmd/version"
	"github.com/konveyor-ecosystem/kubectl-migrate/internal/flags"
	"github.com/spf13/cobra"
	"k8s.io/cli-runtime/pkg/genericclioptions"
)

func main() {
	f := &flags.GlobalFlags{}
	root := cobra.Command{
		Use:   "kubectl-migrate",
		Short: "Kubernetes migration tool - kubectl plugin for migrating workloads between clusters",
		Long: `kubectl-migrate is a kubectl plugin that helps migrate workloads and their state between Kubernetes clusters.
It provides commands for exporting, transforming, and applying resources across clusters.

This tool integrates all features from the crane migration tool and can be used with the 'kubectl migrate' prefix.`,
	}
	f.ApplyFlags(&root)
	root.AddCommand(export.NewExportCommand(genericclioptions.IOStreams{In: os.Stdin, Out: os.Stdout, ErrOut: os.Stderr}, f))
	root.AddCommand(transfer_pvc.NewTransferPVCCommand(genericclioptions.IOStreams{In: os.Stdin, Out: os.Stdout, ErrOut: os.Stderr}))
	root.AddCommand(tunnel_api.NewTunnelAPIOptions(genericclioptions.IOStreams{In: os.Stdin, Out: os.Stdout, ErrOut: os.Stderr}))
	root.AddCommand(convert.NewConvertOptions(genericclioptions.IOStreams{In: os.Stdin, Out: os.Stdout, ErrOut: os.Stderr}))
	root.AddCommand(transform.NewTransformCommand(f))
	root.AddCommand(skopeo_sync_gen.NewSkopeoSyncGenCommand(f))
	root.AddCommand(apply.NewApplyCommand(f))
	root.AddCommand(plugin_manager.NewPluginManagerCommand(f))
	root.AddCommand(version.NewVersionCommand(f))
	root.AddCommand(runfn.NewFnRunCommand(f))
	if err := root.Execute(); err != nil {
		os.Exit(1)
	}
}
