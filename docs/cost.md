# Cost

<!-- PL: Wpisuj realne kwoty z Cost Management (Cost analysis, grupowanie po tagu project i po grupie zasobów) na koniec każdego tygodnia. Ceny jednostkowe bierz z kalkulatora Azure dla North Europe i podawaj datę sprawdzenia. -->

Prices checked: YYYY-MM-DD, region North Europe, pay-as-you-go, USD.

## Running cost of the full environment

| Component | SKU | Unit price | Running hours per week | Cost per week |
| --- | --- | --- | --- | --- |
| Load balancer | Standard, ≤ 5 rules | … USD/h | … | … |
| Public IP addresses | Standard, static | … USD/h each | … | … |
| Private endpoint | blob | … USD/h | … | … |
| VM scale set | Standard_B2ats_v2 × 2 | free-account hours, then … USD/h | … | … |
| App Service plan | S1 Linux (F1 otherwise) | … USD/h | … | … |
| Log Analytics | pay-as-you-go | first 5 GB/month free | – | … |

## Actual spend

| Week | Spend (USD) | Biggest item | What I changed |
| --- | --- | --- | --- |
| T0 | … | … | … |

## Cost controls in place

- budget with alerts at 50 % and 80 % (actual) and 100 % (forecast) — `governance/main.bicep`;
- allowed VM sizes policy;
- `scripts/destroy.sh` after every session, `scripts/Stop-KruszonVMs.ps1` when I keep the environment;
- auto-shutdown on every VM.
