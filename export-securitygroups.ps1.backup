<#

Title: Export Office 365 Security Groups for Tenant Migration
Purpose: This script exports security groups, membership, and ownership for migration from Commercial M365 to GCC High
Author: Migration Assistant
Date: 8/26/2025

# Basic usage - connects automatically and exports to default location
.\Export-SecurityGroups.ps1

# Custom output location
.\Export-SecurityGroups.ps1 -OutputPath "D:\Migration\SecurityGroups\"

# Include mail-enabled security groups
.\Export-SecurityGroups.ps1 -IncludeMailEnabledGroups

# Don't auto-connect (if already connected)
.\Export-SecurityGroups.ps1 -ConnectToServices:$false

# Requires -Modules AzureAD, ExchangeOnlineManagement

#>

param(
[Parameter(Mandatory=$false)]
[string]$OutputPath = “C:\temp\seclists",

```
[Parameter(Mandatory=$false)]
[switch]$ConnectToServices = $true,

[Parameter(Mandatory=$false)]
[switch]$IncludeMailEnabledGroups = $false
```

)

# Function to create output directory

function Ensure-OutputDirectory {
param([string]$Path)

```
if (!(Test-Path -Path $Path)) {
    Write-Host "Creating output directory: $Path" -ForegroundColor Green
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}
```

}

# Function to connect to required services

function Connect-RequiredServices {
Write-Host “Connecting to Azure AD…” -ForegroundColor Yellow
try {
Connect-AzureAD -ErrorAction Stop
Write-Host “Successfully connected to Azure AD” -ForegroundColor Green
}
catch {
Write-Error “Failed to connect to Azure AD: $($_.Exception.Message)”
exit 1
}

```
Write-Host "Connecting to Exchange Online..." -ForegroundColor Yellow
try {
    Connect-ExchangeOnline -ShowProgress $true -ErrorAction Stop
    Write-Host "Successfully connected to Exchange Online" -ForegroundColor Green
}
catch {
    Write-Error "Failed to connect to Exchange Online: $($_.Exception.Message)"
    exit 1
}
```

}

# Function to get user details by ObjectId

function Get-UserDetails {
param([string]$ObjectId)

```
try {
    $user = Get-AzureADUser -ObjectId $ObjectId -ErrorAction SilentlyContinue
    if ($user) {
        return @{
            DisplayName = $user.DisplayName
            UserPrincipalName = $user.UserPrincipalName
            MailNickname = $user.MailNickname
            ObjectId = $user.ObjectId
            UserType = $user.UserType
        }
    }
}
catch {
    Write-Warning "Could not retrieve user details for ObjectId: $ObjectId"
}

return $null
```

}

# Function to get group details by ObjectId

function Get-GroupDetails {
param([string]$ObjectId)

```
try {
    $group = Get-AzureADGroup -ObjectId $ObjectId -ErrorAction SilentlyContinue
    if ($group) {
        return @{
            DisplayName = $group.DisplayName
            ObjectId = $group.ObjectId
            GroupType = $group.GroupTypes -join ";"
        }
    }
}
catch {
    Write-Warning "Could not retrieve group details for ObjectId: $ObjectId"
}

return $null
```

}

# Main execution

Write-Host “===== Office 365 Security Groups Export for Migration =====” -ForegroundColor Cyan
Write-Host “Output Directory: $OutputPath” -ForegroundColor White
Write-Host “Include Mail-Enabled Groups: $IncludeMailEnabledGroups” -ForegroundColor White
Write-Host “”

# Ensure output directory exists

Ensure-OutputDirectory -Path $OutputPath

# Connect to services if requested

if ($ConnectToServices) {
Connect-RequiredServices
}

# Get all security groups

Write-Host “Retrieving security groups…” -ForegroundColor Yellow

$securityGroups = @()

if ($IncludeMailEnabledGroups) {
# Get all groups (including mail-enabled security groups)
$allGroups = Get-AzureADGroup -All $true | Where-Object {
$*.SecurityEnabled -eq $true
}
} else {
# Get only pure security groups (not mail-enabled)
$allGroups = Get-AzureADGroup -All $true | Where-Object {
$*.SecurityEnabled -eq $true -and
$_.MailEnabled -eq $false
}
}

Write-Host “Found $($allGroups.Count) security groups to export” -ForegroundColor Green

# Initialize arrays for different exports

$groupsExport = @()
$membersExport = @()
$ownersExport = @()

$counter = 0
foreach ($group in $allGroups) {
$counter++
$percentComplete = [math]::Round(($counter / $allGroups.Count) * 100, 2)
Write-Progress -Activity “Processing Security Groups” -Status “Processing group $counter of $($allGroups.Count): $($group.DisplayName)” -PercentComplete $percentComplete

```
Write-Host "Processing: $($group.DisplayName)" -ForegroundColor White

# Get group properties
$groupObj = [PSCustomObject]@{
    GroupName = $group.DisplayName
    GroupDescription = $group.Description
    GroupObjectId = $group.ObjectId
    MailNickname = $group.MailNickname
    SecurityEnabled = $group.SecurityEnabled
    MailEnabled = $group.MailEnabled
    GroupTypes = ($group.GroupTypes -join ";")
    CreatedDateTime = $group.CreatedDateTime
    DirSyncEnabled = $group.DirSyncEnabled
    OnPremisesSecurityIdentifier = $group.OnPremisesSecurityIdentifier
    Visibility = $group.Visibility
}

$groupsExport += $groupObj

# Get group members
try {
    $members = Get-AzureADGroupMember -ObjectId $group.ObjectId -All $true
    foreach ($member in $members) {
        $memberDetails = $null
        
        if ($member.ObjectType -eq "User") {
            $memberDetails = Get-UserDetails -ObjectId $member.ObjectId
            if ($memberDetails) {
                $memberObj = [PSCustomObject]@{
                    GroupName = $group.DisplayName
                    GroupObjectId = $group.ObjectId
                    MemberType = "User"
                    MemberDisplayName = $memberDetails.DisplayName
                    MemberUserPrincipalName = $memberDetails.UserPrincipalName
                    MemberMailNickname = $memberDetails.MailNickname
                    MemberObjectId = $member.ObjectId
                    MemberUserType = $memberDetails.UserType
                }
                $membersExport += $memberObj
            }
        }
        elseif ($member.ObjectType -eq "Group") {
            $memberDetails = Get-GroupDetails -ObjectId $member.ObjectId
            if ($memberDetails) {
                $memberObj = [PSCustomObject]@{
                    GroupName = $group.DisplayName
                    GroupObjectId = $group.ObjectId
                    MemberType = "Group"
                    MemberDisplayName = $memberDetails.DisplayName
                    MemberUserPrincipalName = ""
                    MemberMailNickname = ""
                    MemberObjectId = $member.ObjectId
                    MemberUserType = ""
                }
                $membersExport += $memberObj
            }
        }
    }
}
catch {
    Write-Warning "Could not retrieve members for group: $($group.DisplayName) - $($_.Exception.Message)"
}

# Get group owners
try {
    $owners = Get-AzureADGroupOwner -ObjectId $group.ObjectId -All $true
    foreach ($owner in $owners) {
        $ownerDetails = $null
        
        if ($owner.ObjectType -eq "User") {
            $ownerDetails = Get-UserDetails -ObjectId $owner.ObjectId
            if ($ownerDetails) {
                $ownerObj = [PSCustomObject]@{
                    GroupName = $group.DisplayName
                    GroupObjectId = $group.ObjectId
                    OwnerType = "User"
                    OwnerDisplayName = $ownerDetails.DisplayName
                    OwnerUserPrincipalName = $ownerDetails.UserPrincipalName
                    OwnerMailNickname = $ownerDetails.MailNickname
                    OwnerObjectId = $owner.ObjectId
                    OwnerUserType = $ownerDetails.UserType
                }
                $ownersExport += $ownerObj
            }
        }
        elseif ($owner.ObjectType -eq "Group") {
            $ownerDetails = Get-GroupDetails -ObjectId $owner.ObjectId
            if ($ownerDetails) {
                $ownerObj = [PSCustomObject]@{
                    GroupName = $group.DisplayName
                    GroupObjectId = $group.ObjectId
                    OwnerType = "Group"
                    OwnerDisplayName = $ownerDetails.DisplayName
                    OwnerUserPrincipalName = ""
                    OwnerMailNickname = ""
                    OwnerObjectId = $owner.ObjectId
                    OwnerUserType = ""
                }
                $ownersExport += $ownerObj
            }
        }
    }
}
catch {
    Write-Warning "Could not retrieve owners for group: $($group.DisplayName) - $($_.Exception.Message)"
}
```

}

Write-Progress -Activity “Processing Security Groups” -Completed

# Export to CSV files

$timestamp = Get-Date -Format “yyyyMMdd_HHmmss”

Write-Host “Exporting data to CSV files…” -ForegroundColor Yellow

# Export Groups

$groupsFile = Join-Path -Path $OutputPath -ChildPath “SecurityGroups_$timestamp.csv”
$groupsExport | Export-Csv -Path $groupsFile -NoTypeInformation -Encoding UTF8
Write-Host “Exported $($groupsExport.Count) groups to: $groupsFile” -ForegroundColor Green

# Export Members

$membersFile = Join-Path -Path $OutputPath -ChildPath “SecurityGroupMembers_$timestamp.csv”
$membersExport | Export-Csv -Path $membersFile -NoTypeInformation -Encoding UTF8
Write-Host “Exported $($membersExport.Count) group memberships to: $membersFile” -ForegroundColor Green

# Export Owners

$ownersFile = Join-Path -Path $OutputPath -ChildPath “SecurityGroupOwners_$timestamp.csv”
$ownersExport | Export-Csv -Path $ownersFile -NoTypeInformation -Encoding UTF8
Write-Host “Exported $($ownersExport.Count) group ownerships to: $ownersFile” -ForegroundColor Green

# Create summary report

# $summaryFile = Join-Path -Path $OutputPath -ChildPath “ExportSummary_$timestamp.txt”
$summary = @”
Office 365 Security Groups Export Summary

Export Date: $(Get-Date)
Total Security Groups Exported: $($groupsExport.Count)
Total Group Memberships Exported: $($membersExport.Count)
Total Group Ownerships Exported: $($ownersExport.Count)

Files Created:

- Groups: $groupsFile
- Members: $membersFile
- Owners: $ownersFile

Notes for Migration:

- Users are identified by DisplayName and MailNickname to avoid domain conflicts
- Review nested group memberships carefully
- Verify all owners exist in target tenant before group creation
- Consider group naming conflicts in target tenant
- Mail-enabled security groups require Exchange Online management

Migration Considerations:

1. Create users in target tenant first
1. Create groups without members initially
1. Add members and owners after group creation
1. Update any applications or services that reference these groups
1. Test group-based permissions thoroughly
   “@

$summary | Out-File -FilePath $summaryFile -Encoding UTF8
Write-Host “Created summary report: $summaryFile” -ForegroundColor Green

Write-Host “”
Write-Host “===== Export Complete =====” -ForegroundColor Cyan
Write-Host “Review the exported files before proceeding with migration.” -ForegroundColor White
Write-Host “Remember to disconnect from services when finished:” -ForegroundColor Yellow
Write-Host “  Disconnect-AzureAD” -ForegroundColor Gray
Write-Host “  Disconnect-ExchangeOnline” -ForegroundColor Gray