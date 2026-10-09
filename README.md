#  Production-Grade Azure Kubernetes Service (AKS) Deployment with Terraform, Azure Managed Prometheus, Grafana, Azure Monitor, and Container Insights.

### Launch Azure Kubernetes Service (AKS) with Production-Grade Monitoring

For a production-ready AKS cluster, I recommend Azure Monitor + Managed Prometheus + Azure Managed Grafana + Container Insights, with OpenTelemetry for application tracing.

For your existing `aks-production` cluster, you can add monitoring without recreating the cluster.

## 1. Recommended monitoring architecture

Logical architecture: metrics, logs, and traces use separate collection paths and can be correlated through Azure Monitor and Grafana.

## 2. Best monitoring tools for AKS

| Tool                                 | Purpose                                         | Recommendation |
| ------------------------------------ | ----------------------------------------------- | -------------- |
| Azure Managed Prometheus             | Pod, node, Kubernetes and workload metrics      | Essential      |
| Azure Managed Grafana                | Production dashboards and visualization         | Essential      |
| Azure Monitor Container Insights     | Container logs, events and inventory            | Essential      |
| Log Analytics Workspace              | Centralized log storage and KQL queries         | Essential      |
| Azure Monitor Alerts                 | Thresholds, metric alerts and notifications     | Essential      |
| Application Insights + OpenTelemetry | Application performance and distributed tracing | Recommended    |
| KEDA + HPA                           | Event-based and resource-based autoscaling      | As needed      |
| K9s                                  | Live Kubernetes troubleshooting in terminal     | Recommended    |
| Kubecost or OpenCost                 | Kubernetes cost visibility                      | Optional       |

Why this setup? Azure-managed monitoring reduces the operational burden of maintaining Prometheus servers, Grafana databases, and log storage inside the AKS cluster.

## 3. Configure monitoring on your existing AKS cluster

Azure CLI · macOS / Linux / Azure Cloud Shell

### Step 1 — Set variables and connect

```
export RG="rg-aks-production"
export AKS="aks-production"

az login
az account show --output table

az aks get-credentials \
  --resource-group $RG \
  --name $AKS \
  --overwrite-existing

kubelogin convert-kubeconfig -l azurecli

kubectl get nodes
```

### Step 2 — Enable Managed Prometheus

```
az aks update \
  --resource-group $RG \
  --name $AKS \
  --enable-azure-monitor-metrics \
  --enable-control-plane-metrics
```

This enables Azure-managed Prometheus collection, including supported AKS control-plane metrics. A default Azure Monitor workspace can be provisioned automatically.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://learn.microsoft.com\&sz=32)

Microsoft Learn

+1



### Step 3 — Enable Container Insights and logging

```
az aks enable-addons \
  --resource-group $RG \
  --name $AKS \
  --addons monitoring
```

This connects container logging to Log Analytics, using a default workspace when none is specified.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://learn.microsoft.com\&sz=32)

Microsoft Learn



### Step 4 — Deploy Azure Managed Grafana

First, identify your AKS region:

```
export LOCATION=$(az aks show \
  --resource-group $RG \
  --name $AKS \
  --query location -o tsv)

az provider register \
  --namespace Microsoft.Dashboard

az extension add --name amg --upgrade
```

Create a Grafana workspace with a globally unique name:

```
export GRAFANA="grafana-aks-98600"

az grafana create \
  --name $GRAFANA \
  --resource-group $RG \
  --location $LOCATION
```

Retrieve its resource ID:

```
export GRAFANA_ID=$(az grafana show \
  --name $GRAFANA \
  --resource-group $RG \
  --query id -o tsv)
```

Then link Grafana to the Azure Monitor workspace through the AKS monitoring configuration. Use the Azure portal under AKS → Monitoring → Monitor settings, selecting the existing Grafana and Azure Monitor workspaces. Ensure the Grafana managed identity has Monitoring Reader access to the workspace.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://learn.microsoft.com\&sz=32)

Microsoft Learn



### Step 5 — Verify monitoring agents

```
kubectl get pods -n kube-system

kubectl get daemonsets -n kube-system

kubectl get pods -n kube-system | grep ama
```

Check monitoring configuration:

```
az aks show \
  --resource-group $RG \
  --name $AKS \
  --query "{metrics:azureMonitorProfile,addons:addonProfiles.monitoring}" \
  --output json
```

## 4. Grafana dashboards to configure

[Giant Swarm - The Curated Platform Engineering Stack](https://images.openai.com/static-rsc-4/XXVbEriHiJNkiu7aj-iwMd_G4ToOu1WFnCC1hnWrGyftAH8fVbhAsBWB_Lpcw57twpJY6Uu86bmZRKM8TqjNCOqjUNaudxjpZFeUSMmSZISvTHLjeA1EbsFGGgIPUp3n6WyI3vWkjF742cY4amERNGCbpQHGheKv428QBlYz1pQ?purpose=inline)

Kubernetes Cluster Overview

CPU and memory utilization, node readiness, pod counts, cluster capacity and resource pressure.

[Kubernetes / Views / Pods | Grafana Labs](https://images.openai.com/static-rsc-4/dQH3yrZmsN5747oGmOYQzx4BDANUCLM3iXg8XLcbZzv7FsO7zW30TaPqHGmDqfGhMns2ufT5TeUMSX8YxINYpDAysbwRFPH07rb6quOZGLSeWE_tD0YkfyvVR2Y8rlqnBrjD8tg5hdyjkj8xxS2DrdqRVIukl8CSkmNokZ2i63A?purpose=inline)

Pods and Workloads

Container restarts, pod readiness, CPU throttling, OOM kills, deployment availability and HPA behavior.

[Analyze HTTP request health and performance | Grafana Cloud documentation](https://images.openai.com/static-rsc-4/gaiOGKx22Wg1iQZRwv6uXTG3q_gjN55cUBb3Zoe3J5qt995xUnGwPC-X_03PU-edYJgFX8FSZuIllQcMSVs-r1aqaS-3oOVH6YCx4WW7OCXfVXPHCqIbQrzOkL3YSPWYrlEcFm66bBYQpEYGYpq6E_nPN0QLvPebp0oaqeqt8Bs?purpose=inline)

Application Performance

Request rates, HTTP errors, p95/p99 latency, throughput and application health.

## 5. Production alerting recommendations

| Alert                   | Suggested starting threshold                 | Severity |
| ----------------------- | -------------------------------------------- | -------- |
| Node NotReady           | More than 5 minutes                          | Critical |
| Pod CrashLoopBackOff    | Persistent for 5 minutes                     | High     |
| Container memory        | Over 90% of limit                            | High     |
| CPU utilization         | Over 85% for 10 minutes                      | Warning  |
| HTTP 5xx error rate     | Over 5% for 5 minutes                        | High     |
| Persistent volume usage | Over 85%                                     | Warning  |
| Deployment unavailable  | Desired replicas not available for 5 minutes | Critical |

These are initial recommendations, not automatically configured alerts. Tune them against real workload behavior and configure Azure Monitor action groups for email, Teams or incident-management notifications.

## 6. Live monitoring from your Mac

Install K9s:

```
brew install k9s

k9s
```

Useful Kubernetes commands:

```
kubectl top nodes
kubectl top pods -A
kubectl get hpa -A
kubectl get pods -A
kubectl get events -A --sort-by=.lastTimestamp
kubectl logs deployment/webapp -n production
```

For `kubectl top`, ensure the Kubernetes Metrics Server is healthy.

## 7. Production deployment checklist

Monitoring readiness

0 / 9

Managed Prometheus enabled

Container Insights enabled

Azure Managed Grafana connected

Control-plane metrics enabled

Dashboards validated

Application metrics instrumented

Alert rules and action groups configured

Log retention and ingestion costs reviewed

Monitoring access secured with Azure RBAC

Final recommendation: For your AKS production web application, start with the managed Azure monitoring stack above. Add application-level OpenTelemetry, alerts, and cost controls before considering a self-hosted Prometheus/Grafana stack.

Microsoft's [official AKS monitoring setup guide](https://learn.microsoft.com/en-us/azure/azure-monitor/containers/kubernetes-monitoring-enable) covers the supported configuration and permissions. Managed Grafana, metrics ingestion, logs and retention can incur separate Azure charges.
