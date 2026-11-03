# governance — guardrails for the subscription

<!-- PL: Uzupełnij po tygodniu T2: zrzut ekranu zgodności polityk (Policy > Compliance), macierz dostępu, wnioski. -->

**Business need:** nobody should be able to deploy outside Europe, start an expensive VM by mistake or leave untagged resources; the help desk must restart VMs without being able to delete them; spending must raise an alert before it hurts.

| File | What it does | Exam skills |
| --- | --- | --- |
| `main.bicep` | policy assignments (allowed locations, allowed VM sizes, tag inheritance), custom role, budget | Azure Policy, custom roles, costs |
| `management-groups.sh` | `mg-kruszon` hierarchy, subscription moved under `mg-kruszon-dev` | management groups |
| `roles/vm-operator.json` | the same custom role in the JSON format the exam shows | interpret role definitions |

## Deploy

```bash
az deployment sub create --location northeurope --parameters governance/main.bicepparam
./governance/management-groups.sh <subscription-id>
```

CLI alternative for the custom role (set `deployCustomRole = false` in `main.bicepparam` first):

```bash
az role definition create --role-definition @governance/roles/vm-operator.json   # put your subscription ID in AssignableScopes
```

## Access matrix

<!-- PL: Kto, jaka rola, na jakim zakresie. Przypisuj role grupom, nie osobom. -->

| Who | Role | Scope |
| --- | --- | --- |
| GRP-Kruszon-IT | Contributor | rg-kruszon-network-dev |
| Help desk group | Kruszon VM Operator | subscription |
| Accounting firm (guest) | Reader | rg-kruszon-data-dev |

## Lessons

- The built-in "Allowed virtual machine size SKUs" policy checks virtual machines only - scale sets need a custom definition.
- A budget sends alerts; it never stops or deletes resources.
- …
