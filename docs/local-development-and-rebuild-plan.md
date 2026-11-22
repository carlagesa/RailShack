# Local development guide (WSL)

This guide uses Bash commands in WSL. It starts with one container, then builds
toward running the full application locally. You do not need Windows
PowerShell, an AWS account, or AWS credentials.

## What you need

- WSL with the repository checked out in its Linux filesystem, for example
  under `~/projects/railshack`.
- Docker available from WSL. Docker Desktop with WSL integration or Docker
  Engine in WSL can provide it.
- For running the application from source: Go 1.24, Node.js 22, Python 3.13,
  JDK 21, and `curl`.

From the repository root, confirm Docker is reachable:

```bash
docker version
```

The command should show both a client and a server. If it only shows the
client, start Docker or enable its WSL integration before continuing.

## Current checkpoint

CI builds all 50 service images, but it does not publish or transfer them to
your computer. To run an image locally, build it in WSL so it is available to
your local Docker engine.

## Step 1: Run one container

Start with `user-profile`. It listens on port 8080 inside its container; map
that to port 19002 on your WSL machine. The source runner uses port 9002, so
this avoids a collision if it is still running:

```bash
docker build \
  --file docker/Dockerfile.node \
  --build-arg SERVICE=user-profile \
  --tag railshack/user-profile:dev \
  .

docker run --rm --name railshack-user-profile \
  -p 19002:8080 \
  railshack/user-profile:dev
```

Leave that command running. In a second WSL terminal, run:

```bash
curl -fsS http://localhost:19002/healthz
curl -fsS http://localhost:19002/readyz
curl -fsS http://localhost:19002/metrics
```

Stop the container with **Ctrl+C** in the first terminal. If a check fails,
look at the container output in that terminal before moving on.

## Step 2: Run services together

[`compose.yaml`](../compose.yaml) puts all 50 services, PostgreSQL, and Redis
on one private Docker network. Services find one another by the catalog name
and listen on port 8080 inside the network. Only the frontend is published to
your WSL machine, on port 19050 by default. The database password is for local
learning only.

First start a small group to check that service-name networking works:

```bash
docker compose config -q
docker compose up -d --build frontend api-gateway rate-limiter user-profile
curl -fsS http://localhost:19050/healthz
curl -fsS http://localhost:19050/api/user-profile/info
```

Compose also starts PostgreSQL and Redis for the selected services. When the
small group works, start all services and run the end-to-end smoke test:

```bash
docker compose up -d --build
bash scripts/smoke-test.sh http://localhost:19050
```

Running all 50 services uses significant memory. To stop the containers but
keep the local database data, run:

```bash
docker compose down
```

If port 19050 is already in use, set another frontend port, for example
`FRONTEND_PORT=19051`, before the `docker compose up` command.

## Step 3: Run all services in local Kubernetes

After the Compose smoke test passes, use `kind` to run the services in a local
Kubernetes cluster. You need `kind` and `kubectl` installed in WSL. Follow the
[kind Linux quick start](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
and the [kubectl Linux installation guide](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/).

### Switching from MicroK8s to kind

You do not have to uninstall MicroK8s to use kind; they can coexist. Keep
MicroK8s if it has other workloads or data you need. If you want to remove it,
first inspect its resources:

```bash
kubectl --context microk8s get namespaces
kubectl --context microk8s get pods,pvc --all-namespaces
```

Removing MicroK8s deletes its cluster and stored data. If it was installed
with Snap and you are sure nothing in it needs to be kept, remove it with:

```bash
snap list microk8s
sudo snap remove microk8s --purge
```

MicroK8s may also have added a shell alias that remains after uninstall.
Remove it from the current shell and from your Bash startup file, then install
the standalone `kubectl` client if it is not already available:

```bash
unalias kubectl 2>/dev/null || true
grep -n "alias kubectl" ~/.bashrc ~/.bash_aliases 2>/dev/null || true
if ! command -v kubectl >/dev/null || ! kubectl version --client >/dev/null 2>&1; then
  sudo snap install kubectl --classic
fi
```

Delete the matching alias line from the startup file shown by `grep`. Open a
new WSL terminal and confirm `type -a kubectl` points to the standalone client.

This is optional; the separate kubeconfig below is enough to prevent
MicroK8s/kind context mix-ups.

The Compose build creates local images that `kind` can import. Stop the
Compose containers first to free memory; this keeps the PostgreSQL data volume:

```bash
docker compose down
kind get clusters
```

If `railshack` is not listed, create it once:

```bash
kind create cluster --name railshack
```

Export the cluster context to its own kubeconfig so it cannot be confused
with MicroK8s:

```bash
mkdir -p "$HOME/.kube"
kind export kubeconfig --name railshack \
  --kubeconfig "$HOME/.kube/kind-railshack"
export KUBECONFIG="$HOME/.kube/kind-railshack"
kubectl config use-context kind-railshack
kubectl config current-context
kubectl get nodes
bash scripts/load-kind-images.sh railshack
kubectl apply -f k8s/dependencies.yaml
kubectl wait --for=condition=available deployment/postgres deployment/redis \
  --namespace railshack --timeout=120s
python3 scripts/render-k8s-services.py | kubectl apply -f -
kubectl wait --for=condition=available deployment --all \
  --namespace railshack --timeout=300s
kubectl get pods,services --namespace railshack
```

The dependencies manifest creates the namespace, shared configuration,
PostgreSQL, and Redis. The catalog renderer creates all 50 app Deployments and
Services from `services.json`; it is the only source for application workloads.
Running all 50 services uses significant memory.

The database uses temporary pod storage, so its data is lost if the PostgreSQL
pod is recreated. The credentials in the manifest are for local learning only.
Once all deployments are ready, forward the frontend service to a WSL port:

```bash
kubectl port-forward --namespace railshack service/frontend 19050:80
```

In another WSL terminal, run the full smoke test:

```bash
bash scripts/smoke-test.sh http://localhost:19050
```

Add Helm, ingress, persistent storage, and monitoring only after the basic
Kubernetes setup works. These are later learning steps, not prerequisites for
running RailShack.

## A few terms

- **Image:** the packaged application created by `docker build`.
- **Container:** a running instance of an image.
- **Docker network:** lets containers reach one another by service name.
- **Kubernetes:** manages containers across a local cluster.

AWS services and the AWS emulator are intentionally outside this beginner
path. They are not required to build or run the application locally.
