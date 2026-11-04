#Requires -Version 7.2
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Users, Microsoft.Graph.Groups
<#
.SYNOPSIS
    Creates Kruszon employees and one security group per department in Microsoft Entra ID from a CSV file.

.DESCRIPTION
    Idempotent: users and groups that already exist are skipped, so you can run it again after editing the CSV.
    Initial passwords go to identity/out/ (git-ignored) - never to the console or the repository - and every
    user must change the password at first sign-in.
    The script signs in to the directory of -Domain, so it also works when a personal Microsoft account
    (for example one created with a Gmail address) owns the subscription. Any failed Graph call stops it.
    -DynamicGroups creates groups whose membership follows the Department attribute. Dynamic membership
    requires Microsoft Entra ID P1 or P2 (the 30-day P2 trial is enough).

.EXAMPLE
    ./identity/New-KruszonIdentity.ps1 -Domain contoso123.onmicrosoft.com -WhatIf

.EXAMPLE
    ./identity/New-KruszonIdentity.ps1 -Domain contoso123.onmicrosoft.com -DynamicGroups
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    # Your tenant's verified domain, e.g. the default <name>.onmicrosoft.com (Entra ID > Overview).
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9-]+(\.[a-z0-9-]+)+$')]
    [string] $Domain,

    [string] $CsvPath = (Join-Path $PSScriptRoot 'employees.csv'),

    # Required before a license can be assigned to the user.
    [string] $UsageLocation = 'PL',

    [switch] $DynamicGroups
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-Ascii {
    # Polish letters are not allowed in a user principal name: "Łukasz Dąbrowski" -> "Lukasz Dabrowski".
    param([Parameter(Mandatory)][string] $Text)
    # "ł" has no Unicode decomposition, so it is replaced explicitly; the rest loses its accents below.
    $Text = $Text.Replace('ł', 'l').Replace('Ł', 'L')
    $decomposed = $Text.Normalize([Text.NormalizationForm]::FormD)
    $plain = foreach ($character in $decomposed.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($character) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            $character
        }
    }
    return -join $plain
}

function Get-RandomCharacter {
    param([Parameter(Mandatory)][string] $From)
    return $From[[Security.Cryptography.RandomNumberGenerator]::GetInt32($From.Length)]
}

function New-InitialPassword {
    # 16 characters, at least one of each class, no look-alikes (0/O, 1/l/I).
    $classes = 'ABCDEFGHJKLMNPQRSTUVWXYZ', 'abcdefghijkmnopqrstuvwxyz', '23456789', '!@#%*-_+?'
    $characters = [System.Collections.Generic.List[char]]::new()
    foreach ($class in $classes) {
        $characters.Add((Get-RandomCharacter -From $class))
    }
    $all = -join $classes
    while ($characters.Count -lt 16) {
        $characters.Add((Get-RandomCharacter -From $all))
    }
    # Fisher-Yates shuffle with a cryptographic random number generator.
    for ($i = $characters.Count - 1; $i -gt 0; $i--) {
        $j = [Security.Cryptography.RandomNumberGenerator]::GetInt32($i + 1)
        $swap = $characters[$i]
        $characters[$i] = $characters[$j]
        $characters[$j] = $swap
    }
    return -join $characters
}

$employees = @(Import-Csv -Path $CsvPath -Encoding utf8)
if ($employees.Count -eq 0) {
    throw "No rows in $CsvPath."
}
$requiredColumns = 'GivenName', 'Surname', 'JobTitle', 'Department', 'Office'
$missingColumns = @($requiredColumns | Where-Object { $_ -notin $employees[0].PSObject.Properties.Name })
if ($missingColumns.Count -gt 0) {
    throw "Missing CSV columns: $($missingColumns -join ', ')"
}

# Every employee gets an ASCII alias like "lukasz.szymanski" used for the UPN and the mail nickname.
$people = foreach ($employee in $employees) {
    $alias = (ConvertTo-Ascii "$($employee.GivenName).$($employee.Surname)").ToLowerInvariant() -replace '[^a-z0-9.]', ''
    [pscustomobject]@{
        Employee          = $employee
        Alias             = $alias
        UserPrincipalName = "$alias@$Domain"
    }
}

# -TenantId keeps the sign-in inside your directory. Without it, a personal Microsoft account signs in as a
# consumer account, and Microsoft Graph rejects user management with 403 Forbidden or 405 MethodNotAllowed.
Connect-MgGraph -TenantId $Domain -Scopes 'User.ReadWrite.All', 'Group.ReadWrite.All' -NoWelcome -ErrorAction Stop

# Microsoft Graph cmdlets ignore $ErrorActionPreference, so every Graph call below passes -ErrorAction Stop:
# a failed call must stop the script, not be reported as a success.

$outDirectory = Join-Path $PSScriptRoot 'out'
$outFile = Join-Path $outDirectory ('initial-passwords-{0:yyyyMMdd-HHmmss}.csv' -f (Get-Date))
$createdCount = 0

foreach ($person in $people) {
    $upn = $person.UserPrincipalName
    if (Get-MgUser -Filter "userPrincipalName eq '$upn'" -ErrorAction Stop) {
        Write-Verbose "User $upn already exists - skipped."
        continue
    }
    if (-not $PSCmdlet.ShouldProcess($upn, 'Create user')) {
        continue
    }
    $password = New-InitialPassword
    $employee = $person.Employee
    $userParameters = @{
        AccountEnabled    = $true
        DisplayName       = "$($employee.GivenName) $($employee.Surname)"
        GivenName         = $employee.GivenName
        Surname           = $employee.Surname
        UserPrincipalName = $upn
        MailNickname      = $person.Alias
        JobTitle          = $employee.JobTitle
        Department        = $employee.Department
        OfficeLocation    = $employee.Office
        UsageLocation     = $UsageLocation
        PasswordProfile   = @{
            Password                      = $password
            ForceChangePasswordNextSignIn = $true
        }
    }
    $null = New-MgUser @userParameters -ErrorAction Stop
    # Save each password as soon as its user exists, so a later failure cannot lose it.
    $null = New-Item -ItemType Directory -Path $outDirectory -Force
    [pscustomobject]@{ UserPrincipalName = $upn; InitialPassword = $password } |
        Export-Csv -Path $outFile -NoTypeInformation -Encoding utf8 -Append
    $createdCount++
    Write-Host "Created user $upn"
}

$departments = @($employees.Department | Sort-Object -Unique)
foreach ($department in $departments) {
    $groupName = "GRP-Kruszon-$(ConvertTo-Ascii $department)" -replace '\s+', '-'
    $group = Get-MgGroup -Filter "displayName eq '$groupName'" -ErrorAction Stop | Select-Object -First 1
    if (-not $group) {
        if (-not $PSCmdlet.ShouldProcess($groupName, 'Create security group')) {
            continue
        }
        $groupParameters = @{
            DisplayName     = $groupName
            Description     = "Kruszon employees - department: $department"
            MailEnabled     = $false
            MailNickname    = ($groupName -replace '[^A-Za-z0-9-]', '').ToLowerInvariant()
            SecurityEnabled = $true
        }
        if ($DynamicGroups) {
            $groupParameters.GroupTypes = @('DynamicMembership')
            $groupParameters.MembershipRule = "(user.department -eq `"$department`")"
            $groupParameters.MembershipRuleProcessingState = 'On'
        }
        $group = New-MgGroup @groupParameters -ErrorAction Stop
        Write-Host "Created group $groupName"
    }

    # A dynamic group maintains its own members from the rule - members cannot be added by hand.
    if ($group.GroupTypes -contains 'DynamicMembership') {
        continue
    }

    # Assigned membership: add the department's employees who are not members yet (safe to run again).
    $memberIds = @(Get-MgGroupMember -GroupId $group.Id -All -ErrorAction Stop | Select-Object -ExpandProperty Id)
    foreach ($person in @($people | Where-Object { $_.Employee.Department -eq $department })) {
        $user = Get-MgUser -Filter "userPrincipalName eq '$($person.UserPrincipalName)'" -ErrorAction Stop
        if (-not $user) {
            # A brand-new user can take a moment to appear in queries - run the script again to add them.
            Write-Warning "User $($person.UserPrincipalName) not found yet; not added to $groupName."
            continue
        }
        if ($user.Id -in $memberIds) {
            continue
        }
        if ($PSCmdlet.ShouldProcess($groupName, "Add member $($person.UserPrincipalName)")) {
            New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $user.Id -ErrorAction Stop
            Write-Host "Added $($person.UserPrincipalName) to $groupName"
        }
    }
}

if ($createdCount -gt 0) {
    Write-Warning "Initial passwords of $createdCount new users saved to $outFile (git-ignored). Hand them over securely, then delete the file."
}
