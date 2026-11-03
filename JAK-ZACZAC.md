# Jak zacząć z pakietem startowym

Ten pakiet to szkielet repozytorium `azure-admin-portfolio` do planu nauki AZ-104. Daje gotową strukturę, konwencje, jeden moduł wzorcowy (`infra/modules/network.bicep`) i skrypty. Resztę modułów piszesz sam, tydzień po tygodniu. Usuń ten plik, gdy skończysz konfigurację.

## 1. Repozytorium (Tydzień 0, ok. 30 min)

1. Załóż na GitHubie **publiczne** repozytorium `azure-admin-portfolio` (bez README, bo jest w pakiecie).
2. Rozpakuj pakiet i wypchnij go:

   ```bash
   cd azure-admin-portfolio
   git init -b main
   git add .
   git commit -m "Initial structure from the AZ-104 starter kit"
   git remote add origin https://github.com/<twoj-login>/azure-admin-portfolio.git
   git push -u origin main
   ```

3. W `README.md` zamień `<github-user>` na swój login. Komentarze `<!-- PL: ... -->` to podpowiedzi: GitHub ich nie wyświetla, ale usuń je, gdy wypełnisz sekcję.

## 2. Narzędzia (Tydzień 0)

| Narzędzie | Po co | Sprawdzenie |
| --- | --- | --- |
| VS Code + rozszerzenie **Bicep** | podpowiedzi i walidacja szablonów | otwórz `infra/main.bicep` – brak czerwonych podkreśleń |
| Azure CLI (2.53 lub nowszy) | wdrożenia, skrypty `.sh` | `az version` |
| PowerShell 7 + moduł `Az` | skrypty `.ps1` | `Install-Module Az -Scope CurrentUser`, potem `Get-Module Az -ListAvailable` |
| Bicep CLI w PATH | wymagany przez PowerShell (Azure CLI ma własną kopię) | Windows: `winget install -e --id Microsoft.Bicep`; macOS: `brew tap azure/bicep` i `brew install bicep`; potem `bicep --version` |
| Moduł `Microsoft.Graph` (od T1) | skrypt tożsamości | `Install-Module Microsoft.Graph -Scope CurrentUser` |
| Git | historia zmian = część portfolio | `git --version` |

Na Windows skrypty `.sh` uruchamiaj w WSL, Git Bash albo Azure Cloud Shell.

## 3. Pierwsze wdrożenie (Tydzień 3)

1. Zaloguj się: `az login` oraz `Connect-AzAccount`.
2. W `infra/main.dev.bicepparam` wpisz swój login w `owner`.
3. Podgląd zmian bez wdrażania: `./scripts/deploy.ps1 -Environment dev -WhatIfOnly`
4. Wdrożenie (najpierw pokaże what-if i zapyta o zgodę): `./scripts/deploy.ps1 -Environment dev`
5. Sprzątanie po sesji: `./scripts/destroy.sh dev`

Sieć hub-spoke bez maszyn wirtualnych kosztuje praktycznie 0 USD (sieci wirtualne i peering w obrębie regionu naliczają opłatę tylko za przesłane dane), więc możesz ją zostawić. Usuwaj wszystko, co ma maszyny, load balancer, private endpointy lub App Service.

## 4. Mapa tygodni

| Tydzień | Folder / plik | Co robisz |
| --- | --- | --- |
| T1 | `identity/` | uruchamiasz i rozbudowujesz skrypt tworzenia pracowników i grup |
| T2 | `governance/` | polityki, rola niestandardowa, budżet, grupy zarządzania |
| T3 | `infra/main.bicep`, `modules/network.bicep`, `modules/storage.bicep` | czytasz i komentujesz wzorzec, wdrażasz sieć, rozbudowujesz konto storage |
| T4–T5 | `modules/network.bicep` | reguły NSG, ASG, trasy UDR, load balancer, private endpoint, DNS |
| T6 | `modules/storage.bicep` | Blob, Azure Files, cykl życia, wersjonowanie, dostęp |
| T7 | `modules/compute.bicep` | VMSS w strefach, autoskalowanie |
| T8–T9 | `modules/apps.bicep` | App Service ze slotami, ACR, Container Apps |
| T10 | `modules/operations.bicep` | Log Analytics, alerty, kopie zapasowe |
| T11 | `.github/workflows/validate.yml` | logowanie OIDC i what-if dla pull requestów |

Każdą awarię zapisuj w `docs/troubleshooting.md`, każdą ważną decyzję w `docs/adr/`.

## 5. Zasady bezpieczeństwa

- Nigdy nie commituj haseł, kluczy storage, tokenów SAS ani plików z `identity/out/` (są w `.gitignore`).
- Hasła do VM podawaj przy wdrożeniu albo używaj kluczy SSH; parametry z hasłem oznaczaj `@secure()`.
- Repozytorium jest publiczne: przed `git push` przejrzyj `git diff --staged`.
