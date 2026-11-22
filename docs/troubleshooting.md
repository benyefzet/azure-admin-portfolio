# Troubleshooting log

Problems I met, or caused on purpose, while building this environment. Every entry follows the same format: symptom, diagnosis with the tools I used, root cause, fix and lesson.

| Date | Problem | Area |
| --- | --- | --- |
| 2026-11-04 | [Microsoft Graph returns 403/405 when creating users](#microsoft-graph-returns-403405-when-creating-users) | Identity |
| 2026-11-07 | [Microsoft 365 admin center rejects my personal account](#microsoft-365-admin-center-rejects-my-personal-account) | Identity |
| 2026-11-09 | [B2B guest invited with a typo in the email](#b2b-guest-invited-with-a-typo-in-the-email) | Identity |
| 2026-11-07 | [Entra ID P2 trial fails with error 43881](#entra-id-p2-trial-fails-with-error-43881) (open) | Identity |
| 2026-11-22 | [A policy denial names the expression that failed](#a-policy-denial-names-the-expression-that-failed) | Governance |
| 2026-11-22 | [az policy state fails with SubscriptionNotRegistered](#az-policy-state-fails-with-subscriptionnotregistered) | Governance |

## Reading an Azure error

Four error codes cover nearly everything that has blocked a deployment in this subscription. The code names the mechanism, so it says where to look before any guessing starts.

| Error code | Mechanism | What fixes it |
| --- | --- | --- |
| `RequestDisallowedByPolicy` | Azure Policy, `Deny` effect | Read `evaluatedExpressions` in the error, then change the request or the policy |
| `ScopeLocked` | A `CanNotDelete` or `ReadOnly` lock | Remove the lock: `az lock delete --name <name> --resource-group <group>` |
| `AuthorizationFailed` | Azure RBAC, no permission at that scope | Check the role assignment and its scope; a management group is a different scope from the subscription |
| `SubscriptionNotRegistered` | Resource provider not registered | `az provider register --namespace <provider>`, then wait for `Registered` |

Two of them have their own entries below: [the policy denial](#a-policy-denial-names-the-expression-that-failed) and [the missing provider](#az-policy-state-fails-with-subscriptionnotregistered). `ScopeLocked` came from a deliberate delete lock on a throwaway resource group.

## Azure Policy effects

Only an effect that changes a resource needs a managed identity, and a role assignment to go with it.

| Effect | What it does | Needs an identity? |
| --- | --- | --- |
| `Deny` | Rejects the request before the resource exists | No |
| `Audit` | Lets the request through, marks the resource non-compliant | No |
| `AuditIfNotExists` | Checks whether a related resource exists | No |
| `Append` | Adds fields to the request | No |
| `Modify` | Changes a resource's tags or properties | Yes |
| `DeployIfNotExists` | Deploys the missing related resource | Yes |
| `Disabled` | Not evaluated at all | No |

Two settings are easy to confuse. `enforcementMode: DoNotEnforce` sits on the **assignment**: the effect is not enforced, but compliance is still evaluated and reported, which is how `kruszon-require-env-tag-on-rg` runs here. `effect: Disabled` sits in the **definition**: the policy is not evaluated, so there is no compliance data either.

---

## Microsoft Graph returns 403/405 when creating users

**Symptom:** `New-KruszonIdentity.ps1` printed `Created user ...`, but no user appeared in Microsoft Entra ID. Every `New-MgUser` call had failed with `405 (MethodNotAllowed)` and every `Get-MgUser` call with `403 (Forbidden)`, both with `ErrorCode: UnknownError`.

**Diagnosis:**

1. The same error came back for every user, on reads as well as writes, so the whole session was rejected rather than single requests.
2. The Microsoft Graph reference for [creating a user](https://learn.microsoft.com/graph/api/user-post-users) lists delegated permissions for personal Microsoft accounts as not supported. My subscription is owned by a personal Microsoft account created with a Gmail address.
3. After reconnecting with `Connect-MgGraph -TenantId <domain>`, the same script created all users.

**Root cause:** without `-TenantId`, `Connect-MgGraph` signed the personal account in as a consumer account instead of into my directory, and a consumer account cannot manage users. Microsoft Graph PowerShell cmdlets also ignore `$ErrorActionPreference`, so the script kept going and reported success.

**Fix:** sign in with `-TenantId`, and pass `-ErrorAction Stop` to every Graph call so that a failure stops the script ([script](../identity/New-KruszonIdentity.ps1)).

**Lesson:** check the result in the portal, not only the script output, and run `Get-MgContext` when Graph errors do not match the permissions you expect.

---

## Microsoft 365 admin center rejects my personal account

**Symptom:** I could not manage licenses in the Microsoft 365 admin center while signed in as the personal Microsoft account that owns my Azure subscription, although the same account created the tenant.

**Diagnosis:**

1. Since September 2024 license assignment lives in the Microsoft 365 admin center. The Microsoft Entra admin center and the Azure portal only show it.
2. The Microsoft 365 admin center does not accept personal Microsoft accounts, only work or school accounts, which in my case means an account inside the tenant.

**Root cause:** my subscription owner is a personal account created with a Gmail address, and it is a consumer identity, not a member of the directory.

**Fix:** I created a cloud-only account in the tenant, made it Global Administrator and gave it a billing role, and I use it for every admin center that refuses the personal account.

**Lesson:** create a dedicated cloud-only administrator in the first hour, before you need a portal that only accepts directory accounts.

---

## B2B guest invited with a typo in the email

**Symptom:** the guest invitation for the accounting firm went to an address with a typo in the domain, so it could not be accepted.

**Diagnosis:**

1. Microsoft Entra ID → Users → the guest → Properties: I corrected the email address.
2. The invitation had to be sent again to the corrected address. After that it was accepted, and the guest kept its group membership (`IT Lab Administrators`).
3. The user principal name of that guest still contains the typo.

**Root cause:** a guest's user principal name is created from the address in the first invitation, so correcting the email later does not rewrite it.

**Fix:** correct the email and send the invitation again if the typo does not matter to you. If you want a clean user principal name, delete the guest (and remove it from deleted users) and invite again.

**Lesson:** read the address back before you press Invite. The proof is in [the guest profile](../identity/README.md#b2b-guest-for-the-accounting-firm).

---

## Entra ID P2 trial fails with error 43881

**Status:** open. I will update this entry after Microsoft support answers.

**Symptom:** starting the Microsoft Entra ID P2 trial in the Microsoft 365 admin center ends on an error page that says Microsoft needs more information to verify the order, with `Error code: 43881`. The page offers a link to open a support ticket and lists the details support needs: error code, correlation ID (`cV`), tenant ID and the signed-in user.

**Diagnosis:**

1. I used the cloud-only Global Administrator, not the personal account (see the entry above).
2. The billing profile was complete and the account had a billing role, and the error stayed.
3. The page sends the order to Microsoft's verification, so I cannot clear it from inside the tenant.

**Root cause:** not confirmed. The message points at order verification on Microsoft's side.

**Workaround:** I practise dynamic groups and self-service password reset in Microsoft Learn simulations, and the license evidence in [`identity/`](../identity/README.md) stays marked as planned until the trial works.

**Lesson:** a trial of a paid Entra feature can stop at order verification whatever your admin roles are, so plan labs so that one missing license does not block the rest of the week.

---

## A policy denial names the expression that failed

**Symptom:** `az group create --name rg-kruszon-policytest --location westus` failed with `RequestDisallowedByPolicy` and a wall of JSON. Nothing was created.

**Diagnosis:**

1. The first lines name the assignment and the definition behind it: `kruszon-allowed-rg-locations`, built from the built-in `Allowed locations for resource groups`.
2. The part worth reading is `evaluationDetails.evaluatedExpressions`, which lists every condition of the rule with the value it saw and the verdict:

```json
{ "result": "True", "expression": "location", "expressionValue": "westus",
  "targetValue": ["northeurope", "westeurope"], "operator": "NotIn" }
```

3. Both expressions returned `True`, so the rule matched and `policyDefinitionEffect` applied: `Deny`.

**Root cause:** the request was correct; the guardrail did its job. This denial was deliberate, to prove the policy works.

**Fix:** none needed. The same resource group was created in North Europe without complaint.

**Lesson:** read a policy error from the bottom up. `evaluatedExpressions` tells you which field and which value triggered the rule, so you know whether to change the request or the policy. Guessing from the headline message wastes time when several assignments could be to blame.

---

## az policy state fails with SubscriptionNotRegistered

**Symptom:** `az policy state trigger-scan` returned `(SubscriptionNotRegistered) The subscription ... is not registered to use namespace Microsoft.PolicyInsights`, while the policies themselves were clearly working — a `Deny` had just rejected a resource group.

**Diagnosis:**

1. Enforcement and reporting are different services. Enforcement happens in `Microsoft.Authorization`, which was registered; compliance data is served by `Microsoft.PolicyInsights`, which was not.
2. A new subscription only has a default set of resource providers registered. The portal registers a missing one quietly the first time you open that service, so the gap shows up when a request comes from the CLI or a template instead.
3. `az provider show --namespace Microsoft.PolicyInsights --query registrationState -o tsv` returned `NotRegistered`.

**Root cause:** the resource provider for Azure Policy compliance data had never been registered on this subscription.

**Fix:**

```powershell
az provider register --namespace Microsoft.PolicyInsights
az provider show --namespace Microsoft.PolicyInsights --query registrationState -o tsv   # wait for Registered
az policy state trigger-scan                                                             # omit --no-wait to block until done
```

Registration took about two minutes, the scan a few more. Only then did the compliance view show the two test resource groups.

**Lesson:** an empty compliance report is not proof of compliance. Before trusting `100% (0 out of 0)`, check that the provider is registered and that a scan has actually run.

---

## Planned exercises

### App spoke cannot reach the data spoke (week T5)

*This exercise is planned. The description shows the expected diagnosis path and will be replaced with my own output and screenshots.*

**Symptom:** on a VM in `vnet-kruszon-app-dev`, `nslookup <storage>.blob.core.windows.net` returns the private endpoint address `10.2.1.4` (DNS works), but `curl -v https://<storage>.blob.core.windows.net/orders` times out. The same VM reaches resources in the hub.

**Diagnosis:**

1. Network Watcher → **Next hop** from the VM to `10.2.1.4`: next hop type `None`.
2. VM NIC → **Effective routes**: the hub peering (`10.0.0.0/16`) is present, `10.2.0.0/16` is not; the address falls into the default system route for private ranges, whose next hop is `None` (traffic dropped).

**Root cause:** VNet peering is not transitive. Both spokes are peered with the hub, but not with each other.

**Fix options:**

- direct peering `app ↔ data`: simple and cheap, but every new spoke needs links to all others;
- a route table on `snet-web` that sends `10.2.0.0/16` to an NVA in `snet-shared` (IP forwarding enabled on its NIC and in the OS): central control, more moving parts.

**Lesson:** in hub-spoke, spoke-to-spoke traffic needs a router in the hub (NVA or Azure Firewall) or a direct peering.