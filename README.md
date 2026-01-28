# kubectl-migrate

A kubectl plugin for migrating Kubernetes workloads and their state between clusters. This plugin integrates features from the [crane](https://github.com/migtools/crane) migration tool, provides them through the familiar kubectl migrate command interface, and aims to go beyond that.

## Development setup

Standard Go development tools are expected to be installed and the **kubectl** Kubernetes command-line tool for interacting with clusters.

### Setup local k8s environment

A k8s cluster is needed. You can use one of the following options:

- **[kind](https://kind.sigs.k8s.io/)** - Simple Docker/Podman setup (recommended)
  - Quick setup: `./hack/setup-kind.sh`
  - Supports both Docker and Podman

- **[minikube](https://minikube.sigs.k8s.io/docs/)** - Preferred for local VM setup
  - Quick setup: `./hack/setup-minikube.sh`
  - Uses KVM2 driver on Linux

Or use any other Kubernetes distribution of your choice.

### Create sample resources

Check [sample-resources README](sample-resources) for sample application resources, or deploy all to the current cluster context with the following command:

```
$ make resources-deploy
```

Optionally, validate resources in the cluster:

```
$ make resources-validate
```

Similarly destroy sample workloads:

```
$ make resources-destroy
```

### Switch kubectl contexts

When testing migrations, you'll typically work with multiple clusters (source and destination). Here's how to manage your kubectl contexts:

**List all available contexts:**
```bash
$ kubectl config get-contexts
```

**Switch to a specific context:**
```bash
$ kubectl config use-context kind-kind # or minikube
```

**View current context:**
```bash
$ kubectl config current-context
```

**Execute commands against a specific context without switching:**
```bash
$ kubectl --context=kind-kind get pods
$ kubectl --context=minikube get pods
```

This is particularly useful for migration testing where you need to verify resources on both source and destination clusters.

# kubectl-migrate CLI proposal (draft)
A kubectl plugin for migrating Kubernetes workloads and their state between clusters. This plugin integrates all features from the [crane migration tool](https://github.com/migtools/crane) and provides them through the familiar `kubectl migrate` command interface.

1. **Export** - Discover and export resources from source cluster
2. **Transform** - Apply transformations to exported manifests
3. **Apply** - Deploy transformed resources to target cluster

## Installation

### Manual Installation

1. Clone the repository:
```bash
git clone https://github.com/konveyor-ecosystem/kubectl-migrate.git && cd kubectl-migrate
```

2. Build and install:
```bash
make install
```

This will build the binary and install it to `$GOPATH/bin/kubectl-migrate`.

### Via Krew (not yet available)

Once published to krew index:

```bash
kubectl krew install migrate
```

### From Release

Download the appropriate binary for your platform from the [releases page](https://github.com/konveyor-ecosystem/kubectl-migrate/releases) and place it in your `$PATH`.

## Usage

All commands are accessed via `kubectl migrate` followed by the specific subcommand.

### Basic Migration Workflow

```bash
# 1. Export resources from source cluster namespace
kubectl migrate export --namespace myapp --export-dir ./export

# 2. Transform the exported resources (optional)
kubectl migrate transform --export-dir ./export --transform-dir ./transform

# 3. Apply to target cluster
kubectl migrate apply --export-dir ./export --namespace myapp-migrated
```

## Available Commands

### Export

Export discovers and exports all resources from a specified namespace.

```bash
kubectl migrate export [namespace] [flags]

# Examples:
kubectl migrate export myapp --export-dir ./myapp-export
kubectl migrate export myapp --kubeconfig ./source-kubeconfig
```

**Key Flags:**
- `--export-dir` - Directory to export resources to
- `--kubeconfig` - Path to kubeconfig for source cluster
- `--context` - Context to use from kubeconfig

### Transform

Generate and apply JSONPatch transformations to exported resources.

```bash
kubectl migrate transform [flags]

# Examples:
kubectl migrate transform --export-dir ./export --transform-dir ./transform
kubectl migrate transform --plugin-dir ./plugins
```

**Key Flags:**
- `--export-dir` - Directory containing exported resources
- `--transform-dir` - Directory to write transformed resources
- `--plugin-dir` - Directory containing transform plugins

### Apply

Apply transformed resources to target cluster.

```bash
kubectl migrate apply [flags]

# Examples:
kubectl migrate apply --export-dir ./export --namespace target-ns
kubectl migrate apply --export-dir ./export --skip-namespaced
```

**Key Flags:**
- `--export-dir` - Directory containing resources to apply
- `--namespace` - Target namespace
- `--skip-namespaced` - Skip namespaced resources
- `--kubeconfig` - Path to kubeconfig for target cluster

### Transfer PVC

Transfer PersistentVolumeClaims between clusters.

```bash
kubectl migrate transfer-pvc [flags]

# Examples:
kubectl migrate transfer-pvc --source-context source --dest-context dest \
  --pvc-name my-pvc --pvc-namespace myapp
```

**Key Flags:**
- `--source-context` - Source cluster context
- `--dest-context` - Destination cluster context
- `--pvc-name` - Name of PVC to transfer
- `--pvc-namespace` - Namespace of PVC

### Plugin Manager

Manage kubectl-migrate plugins.

```bash
kubectl migrate plugin-manager [subcommand]

# Subcommands:
kubectl migrate plugin-manager list              # List installed plugins
kubectl migrate plugin-manager add <path>        # Add a plugin
kubectl migrate plugin-manager remove <name>     # Remove a plugin
```

### Skopeo Sync Gen

Generate Skopeo sync configuration for container images.

```bash
kubectl migrate skopeo-sync-gen [flags]

# Example:
kubectl migrate skopeo-sync-gen --export-dir ./export --output skopeo-sync.yaml
```

### Convert

Convert resources between different formats.

```bash
kubectl migrate convert [flags]

# Example:
kubectl migrate convert --input-dir ./export --output-dir ./converted
```

### Tunnel API

Tunnel API requests for specific migration scenarios.

```bash
kubectl migrate tunnel-api [flags]
```

### Version

Display version information.

```bash
kubectl migrate version
```

## Command Mapping from Crane

All `crane` commands are now available as `kubectl migrate` commands:

| Crane Command | kubectl-migrate Command |
|---------------|-------------------------|
| `crane export` | `kubectl migrate export` |
| `crane transform` | `kubectl migrate transform` |
| `crane apply` | `kubectl migrate apply` |
| `crane transfer-pvc` | `kubectl migrate transfer-pvc` |
| `crane plugin-manager` | `kubectl migrate plugin-manager` |
| `crane skopeo-sync-gen` | `kubectl migrate skopeo-sync-gen` |
| `crane convert` | `kubectl migrate convert` |
| `crane tunnel-api` | `kubectl migrate tunnel-api` |
| `crane version` | `kubectl migrate version` |

## Configuration

kubectl-migrate uses standard Kubernetes configuration:

- Kubeconfig files for cluster authentication
- Context switching for multi-cluster operations
- Standard kubectl flags like `--namespace`, `--context`, etc.

## Examples

### Migrate an application to a new cluster

```bash
# Set up contexts for source and target clusters
export SOURCE_CONTEXT=prod-cluster
export TARGET_CONTEXT=staging-cluster

# Export from source
kubectl migrate export myapp \
  --context $SOURCE_CONTEXT \
  --export-dir ./myapp-export

# Apply to target (with optional namespace change)
kubectl migrate apply \
  --context $TARGET_CONTEXT \
  --export-dir ./myapp-export \
  --namespace myapp-staging
```

### Migrate with PVC transfer

```bash
# Export application
kubectl migrate export myapp --export-dir ./myapp-export

# Transfer PVCs
kubectl migrate transfer-pvc \
  --source-context prod-cluster \
  --dest-context staging-cluster \
  --pvc-name myapp-data \
  --pvc-namespace myapp

# Apply to target
kubectl migrate apply \
  --context staging-cluster \
  --export-dir ./myapp-export
```

### Use plugins for transformation

```bash
# List available plugins
kubectl migrate plugin-manager list

# Export and transform with plugins
kubectl migrate export myapp --export-dir ./export
kubectl migrate transform \
  --export-dir ./export \
  --transform-dir ./transformed \
  --plugin-dir ./my-plugins

# Apply transformed resources
kubectl migrate apply --export-dir ./transformed
```

## Development

### Prerequisites

- Go 1.24 or later
- Access to Kubernetes clusters for testing
- kubectl installed

### Building from Source

```bash
# Clone repository
git clone https://github.com/konveyor-ecosystem/kubectl-migrate.git
cd kubectl-migrate

# Download dependencies
make deps

# Build
make build

# Run tests
make test-unit

# Install locally
make install
```

### Running Tests

```bash
make test-unit
# and run full test suite when available
```

## Code of Conduct

This project follows the Konveyor [Code of Conduct](https://github.com/konveyor/community/blob/main/CODE_OF_CONDUCT.md).

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Related Projects

- [crane](https://github.com/migtools/crane) - Original migration tool
- [crane-lib](https://github.com/konveyor/crane-lib) - Shared library for crane tools
- [Konveyor](https://www.konveyor.io/) - Application modernization and migration toolkit

## Support

For questions and support:
- Open an issue on [GitHub](https://github.com/konveyor-ecosystem/kubectl-migrate/issues)
- Join the [Konveyor community](https://github.com/konveyor/community)

## Status

This project is currently in active development. APIs and features may change.
