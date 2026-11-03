#Requires -Version 7.2
#Requires -Modules Az.Accounts, Az.Resources
<#
.SYNOPSIS
    Previews (what-if) and deploys infra/main.bicep at subscription scope.

.DESCRIPTION
    Without -WhatIfOnly the script shows the what-if result first and asks for confirmation before
    anything changes. Azure PowerShell needs the Bicep CLI on PATH - `az bicep install` and the VS Code
    extension do not put it there. Windows: winget install -e --id Microsoft.Bicep; macOS: brew install bicep
    (after brew tap azure/bicep).

.EXAMPLE
    ./scripts/deploy.ps1 -Environment dev -WhatIfOnly

.EXAMPLE
    ./scripts/deploy.ps1 -Environment dev
#>
[CmdletBinding()]
param(
    [ValidateSet('dev', 'prod')]
    [string] $Environment = 'dev',

    [string] $Location = 'northeurope',

    [switch] $WhatIfOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$templateFile = Join-Path $repoRoot 'infra/main.bicep'
$parameterFile = Join-Path $repoRoot "infra/main.$Environment.bicepparam"

if (-not (Test-Path $parameterFile)) {
    throw "Missing parameter file: $parameterFile"
}

$context = Get-AzContext
if (-not $context) {
    throw 'Not signed in. Run Connect-AzAccount first.'
}
Write-Host "Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))"

$deployment = @{
    Name                  = "kruszon-$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Location              = $Location
    TemplateFile          = $templateFile
    TemplateParameterFile = $parameterFile
}

if ($WhatIfOnly) {
    # Lists what would be created (+), modified (~) or deleted (-) - nothing is deployed.
    New-AzSubscriptionDeployment @deployment -WhatIf
    return
}

# -Confirm runs what-if, prints the result and waits for your answer before deploying.
$result = New-AzSubscriptionDeployment @deployment -Confirm
if ($result) {
    Write-Host "Provisioning state: $($result.ProvisioningState)"
    $result.Outputs
}
