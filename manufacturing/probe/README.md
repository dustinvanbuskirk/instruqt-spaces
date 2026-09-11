# Probe

A simple Golang web service for Kubernetes demonstrations that displays
container image and version information with customizable colors.

## Features

- Displays container image name and version
- Customizable text and background colors via Dockerfile build args
- Health check endpoints
- Three deployment options: Helm, Kustomize, and plain manifests
- CI/CD pipeline via Gitea Actions, building to Gitea's own container
  registry and creating an Octopus Deploy release

## Local Development

```bash
# Run locally
go run cmd/server/main.go

# Build
go build -o server cmd/server/main.go

# Run
./server
```

## Docker Build

```bash
# Build with custom colors
docker build \
  --build-arg VERSION=1.0.0 \
  --build-arg IMAGE=probe:1.0.0 \
  --build-arg TEXT_COLOR=#FFFFFF \
  --build-arg BG_COLOR=#2C3E50 \
  -t probe:1.0.0 .

# Run
docker run -p 8080:8080 probe:1.0.0
```

## Deployment Options

### Option 1: Helm Chart

```bash
helm install probe ./deployments/helm/probe \
  --set image.tag=1.0.0

helm upgrade probe ./deployments/helm/probe \
  --set image.tag=1.1.0

helm uninstall probe
```

### Option 2: Kustomize

```bash
kubectl apply -k deployments/kustomize/overlays/dev
kubectl apply -k deployments/kustomize/overlays/staging
kubectl apply -k deployments/kustomize/overlays/prod

kubectl delete -k deployments/kustomize/overlays/dev
```

### Option 3: Plain Manifests

```bash
kubectl apply -f deployments/manifests/
kubectl delete -f deployments/manifests/
```

## CI/CD Pipeline

`.gitea/workflows/build-and-push.yaml` runs on every `v*.*.*` tag push (or
manual dispatch) and:

1. Validates the semver tag
2. Builds the Docker image with the given build args
3. Pushes it to this Gitea instance's own container registry
4. Pushes build information to Octopus Deploy
5. Creates an Octopus Deploy release

The secrets and variables it needs (`REGISTRY_USERNAME`, `REGISTRY_PASSWORD`,
`CONTAINER_REGISTRY`, `OCTOPUS_SERVER_URL`, `OCTOPUS_API_KEY`,
`OCTOPUS_SPACE`, `OCTOPUS_PROJECT`) are all set on this repo automatically
by the Terraform in `manufacturing/terraform/gitea.tf` — nothing to
configure by hand.

### Trigger a build

```bash
git tag v1.0.0
git push origin v1.0.0
```

Or use workflow dispatch from Gitea's Actions UI.

## Configuration

### Environment Variables

- `APP_VERSION`: Application version (set by Dockerfile)
- `APP_IMAGE`: Container image name (set by Dockerfile)
- `TEXT_COLOR`: Text color hex code (default: #FFFFFF)
- `BG_COLOR`: Background color hex code (default: #2C3E50)
- `PORT`: HTTP port (default: 8080)

### Customizing Colors

Colors can be customized at build time or runtime:

**Build time (Dockerfile):**
```bash
docker build --build-arg TEXT_COLOR=#000000 --build-arg BG_COLOR=#FFD700 .
```

**Runtime (Kubernetes):**
```yaml
env:
- name: TEXT_COLOR
  value: "#000000"
- name: BG_COLOR
  value: "#FFD700"
```

## Endpoints

- `GET /` - Main page displaying service information
- `GET /health` - Health check endpoint
- `GET /healthz` - Kubernetes liveness probe
- `GET /ready` - Kubernetes readiness probe

## License

This project is released into the public domain under the UNLICENSE.
