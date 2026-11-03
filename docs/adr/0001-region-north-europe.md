# 0001. North Europe as the primary region, West Europe for disaster recovery

- **Status:** accepted
- **Date:** 2026-10-19

<!-- PL: To przykład wypełnionego ADR. Sprawdź fakty na stronach z sekcji Sources (dostępność usług się zmienia), dopisz własne argumenty i zmień datę. -->

## Context

Kruszon operates in Poland, so Poland Central (Warsaw) is the closest Azure region. The lab has three constraints:

- browser access to VMs must cost nothing - the Bastion **Developer** SKU is free, but only in selected regions;
- the Site Recovery exercise needs a second region for failover;
- one region for every lab keeps the allowed-locations policy and the cost reports simple.

## Decision

Deploy everything to **North Europe** (Ireland). Use **West Europe** (Netherlands) only for backup and Site Recovery tests.

## Consequences

- **Good:** Bastion Developer is available in North Europe and West Europe, but not in Poland Central (Microsoft documentation, checked 2026-10-19).
- **Good:** North Europe and West Europe are an Azure region pair, the classic disaster-recovery setup.
- **Bad / accepted risk:** higher latency from Poland than Poland Central, and data stored outside Poland. A real Polish company with data-residency requirements would pick Poland Central and pay for Bastion Basic or Standard.

## Alternatives considered

| Option | Why not |
| --- | --- |
| Poland Central | no Bastion Developer, so secure VM access would cost an hourly fee |
| Two regions active-active | doubles cost; not needed for the exam scope |

## Sources

- [Azure Bastion SKU comparison and regional availability](https://learn.microsoft.com/azure/bastion/bastion-sku-comparison)
