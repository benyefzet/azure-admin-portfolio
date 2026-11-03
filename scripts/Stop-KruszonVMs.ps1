#Requires -Version 7.2
#Requires -Modules Az.Accounts, Az.Compute
<#
.SYNOPSIS
    Deallocates every Kruszon VM and VM scale set of one environment, so compute billing stops.

.DESCRIPTION
    "Stopped" (shut down from inside the OS, or Stop-AzVM -StayProvisioned) keeps the hardware reserved and
    compute is still billed. "Stopped (deallocated)" releases it - you keep paying only for disks and static
    public IP addresses. This script always deallocates.

.EXAMPLE
    ./scripts/Stop-KruszonVMs.ps1 -Environment dev -WhatIf

.EXAMPLE
    ./scripts/Stop-KruszonVMs.ps1 -Environment dev
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('dev', 'prod')]
    [string] $Environment = 'dev'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-KruszonTag {
    param($Tags)
    # Tags can be null, and a missing key must not throw.
    if ($null -eq $Tags) { return $false }
    return $Tags.ContainsKey('project') -and $Tags['project'] -eq 'kruszon' -and
        $Tags.ContainsKey('env') -and $Tags['env'] -eq $Environment
}

$virtualMachines = @(Get-AzVM -Status | Where-Object { Test-KruszonTag $_.Tags })
foreach ($vm in $virtualMachines) {
    if ($vm.PowerState -eq 'VM deallocated') {
        Write-Verbose "$($vm.Name) is already deallocated."
        continue
    }
    if ($PSCmdlet.ShouldProcess("$($vm.ResourceGroupName)/$($vm.Name)", 'Deallocate virtual machine')) {
        $null = Stop-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Force -NoWait
        Write-Host "Deallocating VM $($vm.Name)"
    }
}

# Instances of a Uniform scale set are not returned by Get-AzVM, so scale sets are handled separately.
$scaleSets = @(Get-AzVmss | Where-Object { Test-KruszonTag $_.Tags })
foreach ($scaleSet in $scaleSets) {
    if ($PSCmdlet.ShouldProcess("$($scaleSet.ResourceGroupName)/$($scaleSet.Name)", 'Deallocate scale set')) {
        $null = Stop-AzVmss -ResourceGroupName $scaleSet.ResourceGroupName -VMScaleSetName $scaleSet.Name -Force -AsJob
        Write-Host "Deallocating scale set $($scaleSet.Name)"
    }
}

if ($virtualMachines.Count -eq 0 -and $scaleSets.Count -eq 0) {
    Write-Host "No VMs or scale sets tagged project=kruszon and env=$Environment."
}
