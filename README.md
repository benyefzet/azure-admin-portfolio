# Kruszon Bakery — Azure infrastructure (AZ-104 portfolio)

<!-- PL: Pierwsze zdanie ma powiedzieć rekruterowi w 30 sekund, co zbudowałeś i czym. Każdy komentarz z dopiskiem PL usuń, gdy wypełnisz jego sekcję. -->

Infrastructure for a fictional bakery chain (3 shops, an online store, 25 employees), built with Bicep, Azure CLI and PowerShell while preparing for the Microsoft AZ-104 exam.

[![validate](https://github.com/benyefzet/azure-admin-portfolio/actions/workflows/validate.yml/badge.svg)](https://github.com/benyefzet/azure-admin-portfolio/actions/workflows/validate.yml)

## Architecture

![Architecture](docs/images/architecture.png)

<!-- PL: Wklej diagram (draw.io lub Excalidraw z oficjalnymi ikonami Azure) jako docs/images/architecture.png. Pod nim 2–3 zdania: hub-spoke, co stoi w której sieci, jak płynie ruch. -->

Hub-and-spoke network in North Europe: shared services in the hub, web tier in the app spoke, storage behind a private endpoint in the data spoke. West Europe is the disaster-recovery region.

## Modules

<!-- PL: Status zmieniaj na bieżąco: planned → in progress → done. Link w kolumnie Module prowadzi do README modułu. -->

| Module | Azure services | AZ-104 skills | Status |
| --- | --- | --- | --- |
| [identity](identity/) | Microsoft Entra ID, Microsoft Graph PowerShell | users, groups, licenses, external users, SSPR | planned |
| [governance](governance/) | Azure Policy, RBAC, management groups, Cost Management | policy, custom roles, scopes, budgets, tags | planned |
| [network](infra/modules/network.bicep) | VNet, peering, NSG, ASG, UDR, Bastion, DNS, Load Balancer | networking (15–20 %) | in progress |
| [storage](infra/modules/storage.bicep) | Storage account, Blob, Azure Files, private endpoint | storage (15–20 %) | planned |
| [compute](infra/modules/compute.bicep) | VM Scale Sets, availability zones, autoscale | compute | planned |
| [apps](infra/modules/apps.bicep) | App Service, deployment slots, ACR, Container Apps | compute | planned |
| [operations](infra/modules/operations.bicep) | Azure Monitor, Log Analytics, Backup, Site Recovery | monitoring (10–15 %) | planned |

## Deploy

Prerequisites: Azure CLI 2.53+, PowerShell 7 with the `Az` module, an Azure subscription where you are Owner.

```powershell
Connect-AzAccount
./scripts/deploy.ps1 -Environment dev -WhatIfOnly   # preview only
./scripts/deploy.ps1 -Environment dev               # what-if, confirm, deploy
```

Governance (policies, custom role, budget) is a separate deployment:

```bash
az deployment sub create --location northeurope --parameters governance/main.bicepparam
```

## Clean up

```bash
./scripts/destroy.sh dev    # deletes every resource group tagged project=kruszon, env=dev (removes locks first)
```

## Cost

<!-- PL: Wpisz realne liczby z Cost Management po każdym tygodniu (docs/cost.md). Rekruterzy cenią świadomość kosztów. -->

Full environment: ~X USD per hour while running, ~Y USD per month for what stays deployed. Details: [docs/cost.md](docs/cost.md).

## Decisions

Architecture decision records: [docs/adr](docs/adr/) — e.g. [why North Europe and not Poland Central](docs/adr/0001-region-north-europe.md).

## Troubleshooting log

Real failures I caused or met, how I diagnosed them and what fixed them: [docs/troubleshooting.md](docs/troubleshooting.md).

## What I learned

<!-- PL: 3–5 konkretnych punktów, np. "peering nie jest przechodni – ruch spoke↔spoke wymaga NVA lub bezpośredniego peeringu". Bez ogólników. -->

- …

## Certifications

- [Microsoft Certified: Azure Fundamentals (AZ-900)](https://learn.microsoft.com/api/credentials/share/en-us/KrzysztofWaka-3059/438B8E4171C35F34?sharingId=203E19A9C23B6006)
- Microsoft Certified: Azure Administrator Associate (AZ-104) — in progress
