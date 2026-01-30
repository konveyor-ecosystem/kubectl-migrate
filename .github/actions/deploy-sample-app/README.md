# Deploy Sample App Action

Deploys and optionally validates a sample Kubernetes application.

## Usage

### Basic Deployment

```yaml
- name: Deploy app
  uses: ./.github/actions/deploy-sample-app
  with:
    app-name: wordpress
```

### Deployment with Validation

```yaml
- name: Deploy and validate app
  uses: ./.github/actions/deploy-sample-app
  with:
    app-name: wordpress
    verify-health: 'true'
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

  - name: Destroy app
    if: always()
    uses: ./.github/actions/destroy-sample-app
    with:
      app-name: wordpress
```

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `app-name` | Yes | - | Name of the sample app (e.g., `hello-world`, `wordpress`) |
| `verify-health` | No | `false` | Run the app's `validate.sh` script if it exists |

## What It Does

1. **Validates** the app exists and has a `deploy.sh` script
2. **Deploys** the app using `make resources-deploy <app-name>`
3. **Validates health** (optional) by running the app's `validate.sh` script
4. **Shows status** of deployed resources

## Health Validation

When `verify-health: 'true'` is set, the action looks for a `validate.sh` script in the app directory:

```text
sample-resources/
├── hello-world/
│   ├── deploy.sh
│   └── validate.sh       ← Runs this if verify-health is true
└── wordpress/
    ├── deploy.sh
    └── validate.sh       ← Runs this if verify-health is true
```

If no `validate.sh` exists, validation is skipped (no error).

## Notes

- This action **does not** destroy the app - use the `destroy-sample-app` action for cleanup
- Each app controls its own deployment timeout in its `deploy.sh` script
- For local testing, use `make resources-deploy <app-name>` directly
