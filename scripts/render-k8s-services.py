#!/usr/bin/env python3
import json
from pathlib import Path

# Resolve services.json relative to this script so it works from any
# directory.
ROOT = Path(__file__).resolve().parent.parent
NAMESPACE = "railshack"


def deployment(name):
    # A Deployment maintains one pod; the app label lets the matching Service select it.
    return {
        "apiVersion": "apps/v1",
        "kind": "Deployment",
        "metadata": {"name": name, "namespace": NAMESPACE},
        "spec": {
            "replicas": 1,
            "selector": {"matchLabels": {"app": name}},
            "template": {
                "metadata": {"labels": {"app": name}},
                "spec": {
                    "containers": [
                        {
                            "name": name,
                            # The fixed Compose project name gives each local image this tag.
                            "image": f"railshack-{name}:latest",
                            # Use the image imported by load-kind-images.sh
                            # instead of pulling from a registry.
                            "imagePullPolicy": "IfNotPresent",
                            # Inject common settings and local database credentials
                            # without repeating them.
                            "envFrom": [
                                {"configMapRef": {"name": "railshack-app"}},
                                {"secretRef": {"name": "railshack-local"}},
                            ],
                            "ports": [{"name": "http", "containerPort": 8080}],
                            # Readiness gates traffic; liveness restarts a process that stops responding.
                            "readinessProbe": {
                                "httpGet": {"path": "/readyz", "port": "http"},
                                "periodSeconds": 5,
                            },
                            "livenessProbe": {
                                "httpGet": {"path": "/healthz", "port": "http"},
                                "initialDelaySeconds": 10,
                                "periodSeconds": 10,
                            },
                        }
                    ]
                },
            },
        },
    }


def service(name):
    # A Service gives each pod stable DNS; frontend alone exposes port 80
    # for port-forwarding.
    port = 80 if name == "frontend" else 8080
    return {
        "apiVersion": "v1",
        "kind": "Service",
        "metadata": {"name": name, "namespace": NAMESPACE},
        "spec": {
            "selector": {"app": name},
            "ports": [{"name": "http", "port": port, "targetPort": "http"}],
        },
    }


catalog = json.loads((ROOT / "services.json").read_text())
resources = []
# A Kubernetes List lets kubectl apply every generated Deployment and Service in one command.
for entry in catalog:
    resources.extend((deployment(entry["name"]), service(entry["name"])))

print(json.dumps({"apiVersion": "v1", "kind": "List", "items": resources}))
