# Destroy Sample App Action

Destroys a deployed Kubernetes sample application.

## Usage

### Basic Destruction

```yaml
- name: Destroy app
  uses: ./.github/actions/destroy-sample-app
  with:
    app-name: wordpress
```

### With Always Condition (Recommended)

```yaml
- name: Destroy app
  if: always()  # Runs even if previous steps fail
  uses: ./.github/actions/destroy-sample-app
  with:
    app-name: wordpress
```

### Complete Example

```yaml
steps:
  - name: Checkout code
    uses: actions/checkout@v4

  - name: Create Kind Cluster
    uses: helm/kind-action@v1

  - name: Deploy and validate
    uses: ./.github/actions/deploy-sample-app
    with:
      app-name: wordpress
      verify-health: 'true'

  # App is running - do additional work here
  - name: Custom tests
    run: |
      kubectl get all
      # Your testing logic

  # Cleanup at the end
  - name: Destroy app
    if: always()
    uses: ./.github/actions/destroy-sample-app
    with:
      app-name: wordpress
```

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `app-name` | Yes | Name of the sample app to destroy (e.g., `hello-world`, `wordpress`) |

## What It Does

1. **Checks** if the app directory exists
2. **Runs** the app's `destroy.sh` script if available
3. **Falls back** to `kubectl delete all -l app=<app-name>` if no script exists
4. **Verifies** cleanup by showing remaining resources

## How It Finds Cleanup Scripts

The action looks for app-specific destroy scripts:

```text
sample-resources/
├── hello-world/
│   └── destroy.sh       ← Uses this if it exists
└── wordpress/
    └── destroy.sh       ← Uses this if it exists
```

If no `destroy.sh` exists, uses generic kubectl delete.

## Notes

- **Always use `if: always()`** to ensure cleanup runs even if tests fail
- The action ignores runtime errors to avoid failing the workflow, but invalid inputs (such as an invalid `app-name`) will still cause the action to exit with code 1
- Use **after** the `deploy-sample-app` action
- For local cleanup, use `make resources-destroy <app-name>` directly
