# Usage: .\ad_enum.ps1 (run in Windows PowerShell on a domain-joined machine with the AD module)
$ErrorActionPreference = 'Stop'
$Out = Join-Path $env:TEMP ("ad_enum_{0}.txt" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

function Add-Section {
    param([string]$Title, [object]$Data)
    Add-Content -Path $Out -Value "`n========== $Title =========="
    if ($null -eq $Data) {
        Add-Content -Path $Out -Value '(none or unavailable)'
    } else {
        Add-Content -Path $Out -Value ($Data | Out-String -Width 220)
    }
}

try {
    Import-Module ActiveDirectory -ErrorAction Stop
    $Domain = Get-ADDomain
} catch {
    Write-Error "ActiveDirectory module or domain access unavailable: $($_.Exception.Message)"
    exit 1
}

$DN = $Domain.DistinguishedName
$Users = @(Get-ADUser -Filter * -Properties ServicePrincipalName,Enabled,PasswordNeverExpires,AdminCount)
$Computers = @(Get-ADComputer -Filter * -Properties OperatingSystem)
$SPNs = @($Users | Where-Object { $_.ServicePrincipalName.Count -gt 0 })

Add-Section 'DOMAIN' ($Domain | Select-Object DNSRoot,DistinguishedName,PDCEmulator,DomainMode)
Add-Section 'CURRENT IDENTITY' (whoami /all)
Add-Section 'DOMAIN PASSWORD POLICY' (Get-ADDefaultDomainPasswordPolicy | Select-Object MinPasswordLength,ComplexityEnabled,LockoutThreshold,PasswordHistoryCount,MaxPasswordAge)
Add-Section 'DOMAIN USERS' ($Users | Select-Object SamAccountName,Enabled,AdminCount,PasswordNeverExpires | Sort-Object SamAccountName | Format-Table -AutoSize)
Add-Section 'SERVICE ACCOUNTS / SPNS' ($SPNs | Select-Object SamAccountName,@{N='SPNs';E={$_.ServicePrincipalName -join '; '}} | Format-Table -Wrap)
Add-Section 'DOMAIN COMPUTERS' ($Computers | Select-Object Name,OperatingSystem | Format-Table -AutoSize)

try {
    Add-Section 'DOMAIN ADMINS' (Get-ADGroupMember -Identity 'Domain Admins' -Recursive | Select-Object Name,SamAccountName,ObjectClass | Format-Table -AutoSize)
} catch {
    Add-Section 'DOMAIN ADMINS' $_.Exception.Message
}

$Targets = @([pscustomobject]@{ Name='Domain root'; DN=$DN })
foreach ($User in $Users) {
    $Targets += [pscustomobject]@{ Name=$User.SamAccountName; DN=$User.DistinguishedName }
}

try {
    $GPOs = @(Get-ADObject -LDAPFilter '(objectClass=groupPolicyContainer)' -SearchBase "CN=Policies,CN=System,$DN" -Properties displayName)
    Add-Section 'GROUP POLICY OBJECTS' ($GPOs | Select-Object Name,DisplayName,DistinguishedName | Format-List)
    foreach ($GPO in $GPOs) {
        $Targets += [pscustomobject]@{ Name="GPO: $($GPO.DisplayName)"; DN=$GPO.DistinguishedName }
    }
} catch {
    Add-Section 'GROUP POLICY OBJECTS' $_.Exception.Message
}

try {
    Add-Section 'OU GPO LINKS' (Get-ADOrganizationalUnit -Filter * -Properties gPLink | Where-Object { $_.gPLink } | Select-Object Name,gPLink | Format-List)
} catch {
    Add-Section 'OU GPO LINKS' $_.Exception.Message
}

$RightsCount = 0
foreach ($Target in $Targets) {
    try {
        $Entries = @( (Get-Acl -Path ("AD:\" + $Target.DN)).Access | Where-Object {
            $_.AccessControlType -eq 'Allow' -and
            $_.ActiveDirectoryRights.ToString() -match 'GenericAll|GenericWrite|WriteDacl|WriteOwner|ExtendedRight|WriteProperty'
        })
        if ($Entries.Count -gt 0) {
            $RightsCount += $Entries.Count
            Add-Section "SENSITIVE ALLOW ACES: $($Target.Name)" ($Entries | Select-Object IdentityReference,ActiveDirectoryRights,ObjectType,IsInherited | Format-Table -AutoSize)
        }
    } catch {
        Add-Section "ACL UNAVAILABLE: $($Target.Name)" $_.Exception.Message
    }
}

Write-Host '========== AD ENUMERATION =========='
Write-Host "Domain: $($Domain.DNSRoot)"
Write-Host "Users: $($Users.Count) | Computers: $($Computers.Count) | SPN accounts: $($SPNs.Count)"
Write-Host "Sensitive ACE entries to review: $RightsCount (includes legitimate admin permissions)"
Write-Host "Full report: $Out"
