# Troubleshooting log

Problems I met, or caused on purpose, while building this environment. Every entry follows the same format: symptom, diagnosis with the tools I used, root cause, fix and lesson.

| Date | Problem | Area |
| --- | --- | --- |
| 2026-11-04 | [Microsoft Graph returns 403/405 when creating users](#microsoft-graph-returns-403405-when-creating-users) | Identity |

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