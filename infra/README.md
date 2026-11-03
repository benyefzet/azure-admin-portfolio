# infra — the Kruszon environment in Bicep

`main.bicep` is deployed at subscription scope: it creates the resource groups and calls one module per area. A module is switched on with a `deploy*` flag in `main.dev.bicepparam`, so every commit stays deployable.

| Module | Week | State |
| --- | --- | --- |
| `modules/network.bicep` | T3–T5 | exemplar: hub-spoke, peering, NSG, ASG (extend it) |
| `modules/storage.bicep` | T3, T5, T6 | starter: storage account with secure defaults (extend it) |
| `modules/compute.bicep` | T7 | plan only - you write it |
| `modules/apps.bicep` | T8–T9 | plan only - you write it |
| `modules/operations.bicep` | T10 | plan only - you write it |

## Deploy and clean up

```powershell
./scripts/deploy.ps1 -Environment dev -WhatIfOnly
./scripts/deploy.ps1 -Environment dev
```

```bash
az deployment sub what-if --location northeurope --parameters infra/main.dev.bicepparam   # CLI equivalent
./scripts/destroy.sh dev
```

## Naming and tags

`<type>-kruszon-<role>-<env>`, type prefixes from the Cloud Adoption Framework: `rg`, `vnet`, `snet`, `nsg`, `asg`, `pip`, `lbe`, `vmss`, `st`, `app`, `asp`, `cr`, `ca`, `log`, `rsv`. Storage accounts and registries allow no hyphens (`stkruszondev…`).

Every resource carries `project=kruszon`, `env`, `owner` and `managedBy=bicep`. `scripts/destroy.sh` deletes only groups with `project=kruszon`.

## CI: what-if on every pull request (week T11)

`.github/workflows/validate.yml` builds and lints every Bicep file on each push. The what-if job starts once you configure OpenID Connect - no secrets stored in GitHub:

```bash
app_id=$(az ad app create --display-name gh-azure-admin-portfolio --query appId --output tsv)
az ad sp create --id "$app_id"
az ad app federated-credential create --id "$app_id" --parameters '{
  "name": "pull-requests",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<github-user>/azure-admin-portfolio:pull_request",
  "audiences": ["api://AzureADTokenExchange"]
}'
az role assignment create --assignee "$app_id" --role Contributor --scope "/subscriptions/<subscription-id>"
```

Then add repository variables (Settings → Secrets and variables → Actions → Variables): `AZURE_CLIENT_ID` (= `app_id`), `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`. Contributor on the whole subscription is acceptable for a lab; in production scope it to the resource groups the pipeline manages.
