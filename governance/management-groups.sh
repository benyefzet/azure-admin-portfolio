#!/usr/bin/env bash
# Creates the Kruszon management-group hierarchy and moves the lab subscription under mg-kruszon-dev:
#
#   Tenant Root Group
#   └── mg-kruszon
#       ├── mg-kruszon-prod
#       └── mg-kruszon-dev   <- lab subscription
#
# Policies and role assignments made on mg-kruszon are inherited by everything below it.
# The first management group in a tenant can take several minutes to appear - rerun the show command if needed.
#
# Usage: ./governance/management-groups.sh <subscription-id>
set -euo pipefail

subscription_id="${1:?Usage: $0 <subscription-id>}"

az account management-group create --name mg-kruszon --display-name "Kruszon"
az account management-group create --name mg-kruszon-prod --display-name "Kruszon - production" --parent mg-kruszon
az account management-group create --name mg-kruszon-dev --display-name "Kruszon - dev and test" --parent mg-kruszon

az account management-group subscription add --name mg-kruszon-dev --subscription "$subscription_id"

az account management-group show --name mg-kruszon --expand \
  --query "children[].{name:name, displayName:displayName}" --output table
