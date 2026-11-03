# Troubleshooting log

<!-- PL: Każdy wpis to jedna awaria, którą wywołałeś celowo albo napotkałeś. To najmocniejszy dowód umiejętności administratora. Format: objaw, diagnoza (narzędzia i ich wynik), przyczyna, naprawa, wniosek. Poniższy wpis to wzór do odtworzenia w T5: zrób to ćwiczenie, wklej własne wyniki i zrzuty, a potem usuń ten komentarz. -->

| Date | Problem | Area |
| --- | --- | --- |
| YYYY-MM-DD | [App spoke cannot reach the data spoke](#app-spoke-cannot-reach-the-data-spoke) | networking |

## App spoke cannot reach the data spoke

**Symptom:** on a VM in `vnet-kruszon-app-dev`, `nslookup <storage>.blob.core.windows.net` returns the private endpoint address `10.2.1.4` (DNS works), but `curl -v https://<storage>.blob.core.windows.net/orders` times out. The same VM reaches resources in the hub.

**Diagnosis:**

1. Network Watcher → **Next hop** from the VM to `10.2.1.4`: next hop type `None`.
2. VM NIC → **Effective routes**: the hub peering (`10.0.0.0/16`) is present, `10.2.0.0/16` is not; the address falls into the default system route for private ranges, whose next hop is `None` (traffic dropped).

**Root cause:** VNet peering is not transitive. Both spokes are peered with the hub, but not with each other.

**Fix (choose one and record why):**

- direct peering `app ↔ data` - simple and cheap, but every new spoke needs links to all others;
- route table on `snet-web` sending `10.2.0.0/16` to an NVA in `snet-shared` (IP forwarding enabled on its NIC and in the OS) - central control, more moving parts.

**Lesson:** in hub-spoke, spoke-to-spoke traffic needs a router in the hub (NVA or Azure Firewall) or a direct peering.

<!-- PL: Kolejne wpisy dopisuj powyżej w tabeli i jako nowe sekcje. Propozycje do wywołania: zła sonda load balancera (T5), reguła NSG o wyższym priorytecie blokująca ruch (T4), polityka odrzucająca wdrożenie (T2), magazyn Recovery Services, którego nie da się usunąć (T10). -->
