# identity — Microsoft Entra ID

<!-- PL: Uzupełnij po tygodniu T1: zrzuty ekranu w docs/images/identity-*.png, wnioski, czas wykonania. -->

**Business need:** Kruszon's 25 employees work in six departments; they need accounts on day one, and access must follow their department automatically.

`-WhatIf` still signs in to Microsoft Graph, because the script checks which users and groups already exist.

**Solution:** `New-KruszonIdentity.ps1` reads `employees.csv`, creates users with Microsoft Graph PowerShell and one security group per department (assigned or dynamic membership).

## Run

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
./identity/New-KruszonIdentity.ps1 -Domain <tenant>.onmicrosoft.com -WhatIf          # preview
./identity/New-KruszonIdentity.ps1 -Domain <tenant>.onmicrosoft.com -DynamicGroups   # needs Entra ID P1/P2
```

## Configured in the portal (screenshots below)

| Exam skill | What I configured | Evidence |
| --- | --- | --- |
| Manage licenses | group-based licensing for GRP-Kruszon-IT | screenshot after Lab 01 |
| External users | B2B guest invited for the accounting firm | |
| SSPR | self-service password reset for GRP-Kruszon-IT (pilot) | |
| User and group properties | dynamic rule `user.department -eq "Sprzedaż"` | |

## Decisions and lessons

<!-- PL: Np. dlaczego grupy dynamiczne, a nie przypisane; co się stało z polskimi znakami w UPN. -->

- …
