#!/usr/bin/env bash
# Deletes every Kruszon resource group of one environment (tags project=kruszon and env=<env>).
# Groups without these tags - official lab groups, NetworkWatcherRG - are never touched.
#
# Usage: ./scripts/destroy.sh <env> [--yes]
# A group that holds a Recovery Services vault fails to delete while backup items exist:
# stop protection and delete the backup data first (see docs/troubleshooting.md).
set -euo pipefail

env_name="${1:-}"
confirm="${2:-}"

if [[ -z "$env_name" ]]; then
  echo "Usage: $0 <env> [--yes]" >&2
  exit 1
fi

groups="$(az group list \
  --query "[?tags.project=='kruszon' && tags.env=='${env_name}'].name" \
  --output tsv | tr -d '\r')"

if [[ -z "$groups" ]]; then
  echo "No resource groups tagged project=kruszon and env=${env_name}."
  exit 0
fi

echo "Subscription: $(az account show --query name --output tsv | tr -d '\r')"
echo "Resource groups to delete:"
while IFS= read -r rg; do
  echo "  $rg"
done <<< "$groups"

if [[ "$confirm" != "--yes" ]]; then
  read -r -p "Type the environment name (${env_name}) to confirm: " answer
  if [[ "$answer" != "$env_name" ]]; then
    echo "Aborted."
    exit 1
  fi
fi

# File descriptor 3 keeps the list away from commands that read standard input.
while IFS= read -r rg <&3; do
  # A lock overrides RBAC - even an Owner cannot delete a locked group - so remove locks first.
  locks="$(az lock list --resource-group "$rg" --query "[].id" --output tsv | tr -d '\r')"
  if [[ -n "$locks" ]]; then
    while IFS= read -r lock_id <&4; do
      echo "Removing lock: $lock_id"
      az lock delete --ids "$lock_id"
    done 4<<< "$locks"
  fi
  echo "Deleting $rg (running in the background)..."
  az group delete --name "$rg" --yes --no-wait
done 3<<< "$groups"

echo "Deletion started. Check progress with:"
echo "  az group list --query \"[?tags.project=='kruszon'].{name:name, state:properties.provisioningState}\" --output table"
