#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "Usage: $0 <resource-group> <aks-name>"
  echo "Example: $0 rg-demo-prod aks-prod-eastus"
  exit 0
fi

RG="${1:-${RG:-}}"
AKS="${2:-${AKS:-}}"

if [[ -z "$RG" || -z "$AKS" ]]; then
  echo "Error: provide both the AKS resource group and cluster name."
  echo "Usage: $0 <resource-group> <aks-name>"
  exit 1
fi

if [[ "$RG" == *"<"* || "$AKS" == *"<"* ]]; then
  echo "Error: replace the example values with the real resource group and AKS cluster names."
  echo "List accessible AKS clusters with: az aks list --query \"[].{name:name,resourceGroup:resourceGroup,location:location}\" --output table"
  exit 1
fi

if ! az account show >/dev/null 2>&1; then
  az login
fi
az account show --output table

if ! az group exists --name "$RG" >/dev/null 2>&1; then
  echo "Error: resource group '$RG' was not found in the current subscription."
  echo "Accessible AKS clusters in this subscription:"
  az aks list --query "[].{name:name,resourceGroup:resourceGroup,location:location}" --output table
  exit 1
fi

if ! az aks show --resource-group "$RG" --name "$AKS" >/dev/null 2>&1; then
  echo "Error: AKS cluster '$AKS' was not found in resource group '$RG'."
  echo "AKS clusters in this resource group:"
  az aks list --resource-group "$RG" --query "[].{name:name,location:location}" --output table
  exit 1
fi

az aks get-credentials \
  --resource-group "$RG" \
  --name "$AKS" \
  --overwrite-existing

kubelogin convert-kubeconfig -l azurecli

az aks update \
  --resource-group "$RG" \
  --name "$AKS" \
  --enable-azure-monitor-metrics \
  --enable-control-plane-metrics

az aks enable-addons \
  --resource-group "$RG" \
  --name "$AKS" \
  --addons monitoring

LOCATION=$(az aks show \
  --resource-group "$RG" \
  --name "$AKS" \
  --query location -o tsv)

az provider register --namespace Microsoft.Dashboard
az extension add --name amg --upgrade

GRAFANA="grafana-aks-$(date +%s)"

az grafana create \
  --name "$GRAFANA" \
  --resource-group "$RG" \
  --location "$LOCATION"

echo "Monitoring enabled for AKS cluster: $AKS"
echo "Grafana workspace: $GRAFANA"
