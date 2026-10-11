# AKS Production Monitoring

Short setup for enabling AKS monitoring in production.

## Quick start

Replace the values below with your real AKS resource group and cluster name before running the commands. Do not use the example names shown here.

```bash
export RG="<your-resource-group>"
export AKS="<your-aks-cluster-name>"

az login
az aks get-credentials --resource-group "$RG" --name "$AKS" --overwrite-existing
kubelogin convert-kubeconfig -l azurecli
```

## 1) Enable metrics

```bash
az aks update \
  --resource-group "$RG" \
  --name "$AKS" \
  --enable-azure-monitor-metrics \
  --enable-control-plane-metrics
```

## 2) Enable logs and Container Insights

```bash
az aks enable-addons \
  --resource-group "$RG" \
  --name "$AKS" \
  --addons monitoring
```

## 3) Create Grafana workspace

```bash
export LOCATION=$(az aks show --resource-group "$RG" --name "$AKS" --query location -o tsv)

az provider register --namespace Microsoft.Dashboard
az extension add --name amg --upgrade

export GRAFANA="grafana-aks-$(date +%s)"

az grafana create \
  --name "$GRAFANA" \
  --resource-group "$RG" \
  --location "$LOCATION"
```

## 4) Verify

```bash
kubectl get pods -n kube-system
kubectl get daemonsets -n kube-system
az aks show \
  --resource-group "$RG" \
  --name "$AKS" \
  --query "{metrics:azureMonitorProfile,addons:addonProfiles.monitoring}" \
  --output json
```

## Useful commands

```bash
kubectl top nodes
kubectl top pods -A
kubectl get pods -A
kubectl get events -A --sort-by=.lastTimestamp
kubectl logs deployment/webapp -n production
```

## Recommended alerts

- Node NotReady: > 5 minutes
- Pod CrashLoopBackOff: persistent > 5 minutes
- Memory usage: > 90% of limit
- CPU usage: > 85% for 10 minutes
- HTTP 5xx: > 5% for 5 minutes

## Automation

Use the helper script with the real values:

```bash
az aks list --query "[].{name:name,resourceGroup:resourceGroup,location:location}" --output table
./scripts/enable-aks-monitoring.sh "<resource-group-from-list>" "<cluster-name-from-list>"
```

The script reuses your existing Azure CLI login, checks that the cluster exists, then enables Azure Monitor metrics, turns on Container Insights, and creates a Grafana workspace.

For official guidance: https://learn.microsoft.com/en-us/azure/azure-monitor/containers/kubernetes-monitoring-enable
