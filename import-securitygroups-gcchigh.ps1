<# 

Title: Import Office 365 Security Groups for GCC High Tenant
Purpose: This script imports security groups, membership, and ownership from exported CSV files
Author: Migration Assistant
Date: 8/26/2025

# Full migration (recommended sequence)
.\Import-SecurityGroups-GCCHigh.ps1 -All

# Step-by-step approach
.\Import-SecurityGroups-GCCHigh.ps1 -CreateGroups
.\Import-SecurityGroups-GCCHigh.ps1 -AddOwners  
.\Import-SecurityGroups-GCCHigh.ps1 -AddMembers

# Preview mode (highly recommended first!)
.\Import-SecurityGroups-GCCHigh.ps1 -All -WhatIf

# Custom file locations
.\Import-SecurityGroups-GCCHigh.ps1 -All -GroupsFile "C:\Migration\Groups.csv" -ImportPath "C:\Migration\"

# Add prefixes for testing
.\Import-SecurityGroups-GCCHigh.ps1 -CreateGroups -GroupNamePrefix "MIGRATED_" -WhatIf

# Requires -Modules AzureAD, ExchangeOnlineManagement

#>

param(
[Parameter(Mandatory=$false)]
[string]$ImportPath = “C:\temp\seclists",

```
[Parameter(Mandatory=$false)]
[string]$GroupsFile = "",

[Parameter(Mandatory=$false)]
[string]$MembersFile = "",

[Parameter(Mandatory=$false)]
[string]$OwnersFile = "",

[Parameter(Mandatory=$false)]
[switch]$CreateGroups = $false,

[Parameter(Mandatory=$false)]
[switch]$AddOwners = $false,

[Parameter(Mandatory=$false)]
[switch]$AddMembers = $false,

[Parameter(Mandatory=$false)]
[switch]$All = $false,

[Parameter(Mandatory=$false)]
[switch]$WhatIf = $false,

[Parameter(Mandatory=$false)]
[switch]$ConnectToServices = $true,

[Parameter(Mandatory=$false)]
[string]$GroupNamePrefix = "",

[Parameter(Mandatory=$false)]
[string]$GroupNameSuffix = "",

[Parameter(Mandatory=$false)]
[switch]$SkipExistingGroups = $true,

[Parameter(Mandatory=$false)]
[switch]$ContinueOnError = $true
```

)

# Initialize logging

$timestamp = Get-Date -Format “yyyyMMdd_HHmmss”
$logFile = Join-Path -Path $ImportPath -ChildPath “SecurityGroupImport_$timestamp.log”
$errorLogFile = Join-Path -Path $ImportPath -ChildPath “SecurityGroupImport_Errors_$timestamp.log”

# Function to write log entries

function Write-Log {
param(
[string]$Message,
[string]$Level = “INFO”,
[switch]$NoConsole
)

```
$logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
Add-Content -Path $logFile -Value $logEntry

if (!$NoConsole) {
    switch ($Level) {
        "ERROR" { Write-Host $Message -ForegroundColor Red }
        "WARNING" { Write-Host $Message -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $Message -ForegroundColor Green }
        "INFO" { Write-Host $Message -ForegroundColor White }
        default { Write-Host $Message }
    }
}
```

}

# Function to write error log

function Write-ErrorLog {
param([string]$Message)

```
$errorEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
Add-Content -Path $errorLogFile -Value $errorEntry
Write-Log -Message $Message -Level "ERROR"
```

}

# Function to find the most recent export files

function Find-ExportFiles {
param([string]$Path)

```
$files = @{}

if ([string]::IsNullOrEmpty($GroupsFile)) {
    $groupsFiles = Get-ChildItem -Path $Path -Filter "SecurityGroups_*.csv" | Sort-Object LastWriteTime -Descending
    if ($groupsFiles.Count -gt 0) {
        $files.Groups = $groupsFiles[0].FullName
        Write-Log "Auto-detected groups file: $($files.Groups)"
    }
} else {
    $files.Groups = $GroupsFile
}

if ([string]::IsNullOrEmpty($MembersFile)) {
    $membersFiles = Get-ChildItem -Path $Path -Filter "SecurityGroupMembers_*.csv" | Sort-Object LastWriteTime -Descending
    if ($membersFiles.Count -gt 0) {
        $files.Members = $membersFiles[0].FullName
        Write-Log "Auto-detected members file: $($files.Members)"
    }
} else {
    $files.Members = $MembersFile
}

if ([string]::IsNullOrEmpty($OwnersFile)) {
    $ownersFiles = Get-ChildItem -Path $Path -Filter "SecurityGroupOwners_*.csv" | Sort-Object LastWriteTime -Descending
    if ($ownersFiles.Count -gt 0) {
        $files.Owners = $ownersFiles[0].FullName
        Write-Log "Auto-detected owners file: $($files.Owners)"
    }
} else {
    $files.Owners = $OwnersFile
}

return $files
```

}

# Function to connect to required services

function Connect-RequiredServices {
Write-Log “Connecting to Azure AD…” -Level “INFO”
try {
Connect-AzureAD -ErrorAction Stop | Out-Null
Write-Log “Successfully connected to Azure AD” -Level “SUCCESS”
}
catch {
Write-ErrorLog “Failed to connect to Azure AD: $($_.Exception.Message)”
exit 1
}

```
Write-Log "Connecting to Exchange Online..." -Level "INFO"
try {
    Connect-ExchangeOnline -ShowProgress $true -ErrorAction Stop
    Write-Log "Successfully connected to Exchange Online" -Level "SUCCESS"
}
catch {
    Write-ErrorLog "Failed to connect to Exchange Online: $($_.Exception.Message)"
    exit 1
}
```

}

# Function to find user in target tenant

function Find-TargetUser {
param(
[string]$DisplayName,
[string]$MailNickname,
[string]$OriginalUPN
)

```
$user = $null

# Try by display name first
if (![string]::IsNullOrEmpty($DisplayName)) {
    try {
        $users = Get-AzureADUser -Filter "DisplayName eq '$DisplayName'" -ErrorAction SilentlyContinue
        if ($users -and $users.Count -eq 1) {
            return $users[0]
        }
    }
    catch {
        # Continue to next method
    }
}

# Try by mail nickname if available
if (![string]::IsNullOrEmpty($MailNickname)) {
    try {
        $users = Get-AzureADUser -Filter "MailNickname eq '$MailNickname'" -ErrorAction SilentlyContinue
        if ($users -and $users.Count -eq 1) {
            return $users[0]
        }
    }
    catch {
        # Continue to next method
    }
}

# Try by UPN (in case domain is same)
if (![string]::IsNullOrEmpty($OriginalUPN)) {
    try {
        $user = Get-AzureADUser -Filter "UserPrincipalName eq '$OriginalUPN'" -ErrorAction SilentlyContinue
        if ($user) {
            return $user
        }
    }
    catch {
        # User not found
    }
}

return $null
```

}

# Function to find group in target tenant

function Find-TargetGroup {
param(
[string]$DisplayName,
[string]$MailNickname
)

```
$fullGroupName = "$GroupNamePrefix$DisplayName$GroupNameSuffix"

# Try by display name first
try {
    $groups = Get-AzureADGroup -Filter "DisplayName eq '$fullGroupName'" -ErrorAction SilentlyContinue
    if ($groups -and $groups.Count -eq 1) {
        return $groups[0]
    }
}
catch {
    # Continue to next method
}

# Try by mail nickname if available
if (![string]::IsNullOrEmpty($MailNickname)) {
    try {
        $groups = Get-AzureADGroup -Filter "MailNickname eq '$MailNickname'" -ErrorAction SilentlyContinue
        if ($groups -and $groups.Count -eq 1) {
            return $groups[0]
        }
    }
    catch {
        # Group not found
    }
}

return $null
```

}

# Function to create security groups

function Import-SecurityGroups {
param([array]$Groups)

```
Write-Log "Starting security group creation process..." -Level "INFO"
$successCount = 0
$errorCount = 0
$skippedCount = 0

foreach ($group in $Groups) {
    $fullGroupName = "$GroupNamePrefix$($group.GroupName)$GroupNameSuffix"
    
    try {
        # Check if group already exists
        if ($SkipExistingGroups) {
            $existingGroup = Find-TargetGroup -DisplayName $group.GroupName -MailNickname $group.MailNickname
            if ($existingGroup) {
                Write-Log "Group '$fullGroupName' already exists - skipping" -Level "WARNING"
                $skippedCount++
                continue
            }
        }
        
        if ($WhatIf) {
            Write-Log "[WHATIF] Would create group: $fullGroupName" -Level "INFO"
            continue
        }
        
        # Prepare group parameters
        $groupParams = @{
            DisplayName = $fullGroupName
            SecurityEnabled = [bool]::Parse($group.SecurityEnabled)
            MailEnabled = [bool]::Parse($group.MailEnabled)
            Description = $group.GroupDescription
        }
        
        # Add MailNickname if provided and group is mail-enabled
        if (![string]::IsNullOrEmpty($group.MailNickname)) {
            $groupParams.MailNickname = $group.MailNickname
        }
        
        # Create the group
        $newGroup = New-AzureADGroup @groupParams
        Write-Log "Successfully created group: $fullGroupName (ObjectId: $($newGroup.ObjectId))" -Level "SUCCESS"
        $successCount++
        
        # Small delay to ensure replication
        Start-Sleep -Seconds 2
    }
    catch {
        $errorMessage = "Failed to create group '$fullGroupName': $($_.Exception.Message)"
        Write-ErrorLog $errorMessage
        $errorCount++
        
        if (!$ContinueOnError) {
            throw
        }
    }
}

Write-Log "Group creation completed - Success: $successCount, Errors: $errorCount, Skipped: $skippedCount" -Level "INFO"
```

}

# Function to add group owners

function Import-GroupOwners {
param([array]$Owners)

```
Write-Log "Starting group ownership assignment process..." -Level "INFO"
$successCount = 0
$errorCount = 0

$ownersByGroup = $Owners | Group-Object -Property GroupName

foreach ($groupOwners in $ownersByGroup) {
    $groupName = $groupOwners.Name
    $targetGroup = Find-TargetGroup -DisplayName $groupName
    
    if (!$targetGroup) {
        Write-ErrorLog "Target group not found: $groupName"
        continue
    }
    
    foreach ($owner in $groupOwners.Group) {
        try {
            if ($owner.OwnerType -eq "User") {
                $targetUser = Find-TargetUser -DisplayName $owner.OwnerDisplayName -MailNickname $owner.OwnerMailNickname -OriginalUPN $owner.OwnerUserPrincipalName
                
                if (!$targetUser) {
                    Write-ErrorLog "Target user not found for owner: $($owner.OwnerDisplayName)"
                    $errorCount++
                    continue
                }
                
                if ($WhatIf) {
                    Write-Log "[WHATIF] Would add owner '$($targetUser.DisplayName)' to group '$groupName'" -Level "INFO"
                    continue
                }
                
                # Check if user is already an owner
                $existingOwners = Get-AzureADGroupOwner -ObjectId $targetGroup.ObjectId
                if ($existingOwners.ObjectId -contains $targetUser.ObjectId) {
                    Write-Log "User '$($targetUser.DisplayName)' is already owner of group '$groupName'" -Level "WARNING"
                    continue
                }
                
                Add-AzureADGroupOwner -ObjectId $targetGroup.ObjectId -RefObjectId $targetUser.ObjectId
                Write-Log "Added owner '$($targetUser.DisplayName)' to group '$groupName'" -Level "SUCCESS"
                $successCount++
            }
            elseif ($owner.OwnerType -eq "Group") {
                $targetOwnerGroup = Find-TargetGroup -DisplayName $owner.OwnerDisplayName
                
                if (!$targetOwnerGroup) {
                    Write-ErrorLog "Target owner group not found: $($owner.OwnerDisplayName)"
                    $errorCount++
                    continue
                }
                
                if ($WhatIf) {
                    Write-Log "[WHATIF] Would add owner group '$($targetOwnerGroup.DisplayName)' to group '$groupName'" -Level "INFO"
                    continue
                }
                
                # Check if group is already an owner
                $existingOwners = Get-AzureADGroupOwner -ObjectId $targetGroup.ObjectId
                if ($existingOwners.ObjectId -contains $targetOwnerGroup.ObjectId) {
                    Write-Log "Group '$($targetOwnerGroup.DisplayName)' is already owner of group '$groupName'" -Level "WARNING"
                    continue
                }
                
                Add-AzureADGroupOwner -ObjectId $targetGroup.ObjectId -RefObjectId $targetOwnerGroup.ObjectId
                Write-Log "Added owner group '$($targetOwnerGroup.DisplayName)' to group '$groupName'" -Level "SUCCESS"
                $successCount++
            }
        }
        catch {
            $errorMessage = "Failed to add owner '$($owner.OwnerDisplayName)' to group '$groupName': $($_.Exception.Message)"
            Write-ErrorLog $errorMessage
            $errorCount++
            
            if (!$ContinueOnError) {
                throw
            }
        }
    }
}

Write-Log "Owner assignment completed - Success: $successCount, Errors: $errorCount" -Level "INFO"
```

}

# Function to add group members

function Import-GroupMembers {
param([array]$Members)

```
Write-Log "Starting group membership assignment process..." -Level "INFO"
$successCount = 0
$errorCount = 0

$membersByGroup = $Members | Group-Object -Property GroupName

foreach ($groupMembers in $membersByGroup) {
    $groupName = $groupMembers.Name
    $targetGroup = Find-TargetGroup -DisplayName $groupName
    
    if (!$targetGroup) {
        Write-ErrorLog "Target group not found: $groupName"
        continue
    }
    
    foreach ($member in $groupMembers.Group) {
        try {
            if ($member.MemberType -eq "User") {
                $targetUser = Find-TargetUser -DisplayName $member.MemberDisplayName -MailNickname $member.MemberMailNickname -OriginalUPN $member.MemberUserPrincipalName
                
                if (!$targetUser) {
                    Write-ErrorLog "Target user not found for member: $($member.MemberDisplayName)"
                    $errorCount++
                    continue
                }
                
                if ($WhatIf) {
                    Write-Log "[WHATIF] Would add member '$($targetUser.DisplayName)' to group '$groupName'" -Level "INFO"
                    continue
                }
                
                # Check if user is already a member
                $existingMembers = Get-AzureADGroupMember -ObjectId $targetGroup.ObjectId
                if ($existingMembers.ObjectId -contains $targetUser.ObjectId) {
                    Write-Log "User '$($targetUser.DisplayName)' is already member of group '$groupName'" -Level "WARNING"
                    continue
                }
                
                Add-AzureADGroupMember -ObjectId $targetGroup.ObjectId -RefObjectId $targetUser.ObjectId
                Write-Log "Added member '$($targetUser.DisplayName)' to group '$groupName'" -Level "SUCCESS"
                $successCount++
            }
            elseif ($member.MemberType -eq "Group") {
                $targetMemberGroup = Find-TargetGroup -DisplayName $member.MemberDisplayName
                
                if (!$targetMemberGroup) {
                    Write-ErrorLog "Target member group not found: $($member.MemberDisplayName)"
                    $errorCount++
                    continue
                }
                
                if ($WhatIf) {
                    Write-Log "[WHATIF] Would add member group '$($targetMemberGroup.DisplayName)' to group '$groupName'" -Level "INFO"
                    continue
                }
                
                # Check if group is already a member
                $existingMembers = Get-AzureADGroupMember -ObjectId $targetGroup.ObjectId
                if ($existingMembers.ObjectId -contains $targetMemberGroup.ObjectId) {
                    Write-Log "Group '$($targetMemberGroup.DisplayName)' is already member of group '$groupName'" -Level "WARNING"
                    continue
                }
                
                Add-AzureADGroupMember -ObjectId $targetGroup.ObjectId -RefObjectId $targetMemberGroup.ObjectId
                Write-Log "Added member group '$($targetMemberGroup.DisplayName)' to group '$groupName'" -Level "SUCCESS"
                $successCount++
            }
        }
        catch {
            $errorMessage = "Failed to add member '$($member.MemberDisplayName)' to group '$groupName': $($_.Exception.Message)"
            Write-ErrorLog $errorMessage
            $errorCount++
            
            if (!$ContinueOnError) {
                throw
            }
        }
    }
}

Write-Log "Member assignment completed - Success: $successCount, Errors: $errorCount" -Level "INFO"
```

}

# Main execution

Write-Host “===== Security Groups Import for GCC High Tenant =====” -ForegroundColor Cyan
Write-Log “Import started - Parameters: CreateGroups=$CreateGroups, AddOwners=$AddOwners, AddMembers=$AddMembers, All=$All, WhatIf=$WhatIf”

# Validate parameters

if (!$CreateGroups -and !$AddOwners -and !$AddMembers -and !$All) {
Write-Host “ERROR: You must specify at least one action: -CreateGroups, -AddOwners, -AddMembers, or -All” -ForegroundColor Red
Write-Host “Examples:” -ForegroundColor Yellow
Write-Host “  .\Import-SecurityGroups-GCCHigh.ps1 -All” -ForegroundColor Gray
Write-Host “  .\Import-SecurityGroups-GCCHigh.ps1 -CreateGroups” -ForegroundColor Gray
Write-Host “  .\Import-SecurityGroups-GCCHigh.ps1 -AddOwners -AddMembers” -ForegroundColor Gray
exit 1
}

# Set flags based on -All parameter

if ($All) {
$CreateGroups = $true
$AddOwners = $true
$AddMembers = $true
}

# Find export files

$exportFiles = Find-ExportFiles -Path $ImportPath

# Connect to services if requested

if ($ConnectToServices) {
Connect-RequiredServices
}

try {
# Import and create groups
if ($CreateGroups) {
if ($exportFiles.Groups -and (Test-Path $exportFiles.Groups)) {
Write-Log “Loading groups from: $($exportFiles.Groups)” -Level “INFO”
$groups = Import-Csv -Path $exportFiles.Groups
Import-SecurityGroups -Groups $groups
} else {
Write-ErrorLog “Groups file not found or not specified”
}
}

```
# Import and add owners
if ($AddOwners) {
    if ($exportFiles.Owners -and (Test-Path $exportFiles.Owners)) {
        Write-Log "Loading owners from: $($exportFiles.Owners)" -Level "INFO"
        $owners = Import-Csv -Path $exportFiles.Owners
        Import-GroupOwners -Owners $owners
    } else {
        Write-ErrorLog "Owners file not found or not specified"
    }
}

# Import and add members
if ($AddMembers) {
    if ($exportFiles.Members -and (Test-Path $exportFiles.Members)) {
        Write-Log "Loading members from: $($exportFiles.Members)" -Level "INFO"
        $members = Import-Csv -Path $exportFiles.Members
        Import-GroupMembers -Members $members
    } else {
        Write-ErrorLog "Members file not found or not specified"
    }
}

Write-Log "Import process completed successfully!" -Level "SUCCESS"
```

# }
catch {
Write-ErrorLog “Import process failed: $($*.Exception.Message)”
exit 1
}
finally {
# Create final summary
$summaryFile = Join-Path -Path $ImportPath -ChildPath “ImportSummary*$timestamp.txt”
$summary = @”
Security Groups Import Summary for GCC High

Import Date: $(Get-Date)
Log File: $logFile
Error Log: $errorLogFile

Actions Performed:

- Create Groups: $CreateGroups
- Add Owners: $AddOwners
- Add Members: $AddMembers

Parameters Used:

- WhatIf Mode: $WhatIf
- Group Name Prefix: ‘$GroupNamePrefix’
- Group Name Suffix: ‘$GroupNameSuffix’
- Skip Existing Groups: $SkipExistingGroups
- Continue On Error: $ContinueOnError

Files Processed:

- Groups: $($exportFiles.Groups)
- Owners: $($exportFiles.Owners)
- Members: $($exportFiles.Members)

Post-Migration Tasks:

1. Review error log for any failed operations
1. Test group-based permissions and access
1. Update any hardcoded group references in applications
1. Verify nested group memberships work correctly
1. Update group-based email distribution lists if applicable

Note: Check the detailed logs for complete operation results.
“@

```
$summary | Out-File -FilePath $summaryFile -Encoding UTF8
Write-Log "Created import summary: $summaryFile" -Level "SUCCESS"

Write-Host ""
Write-Host "===== Import Complete =====" -ForegroundColor Cyan
Write-Host "Check the log files for detailed results:" -ForegroundColor White
Write-Host "  Log: $logFile" -ForegroundColor Gray
Write-Host "  Errors: $errorLogFile" -ForegroundColor Gray
Write-Host "  Summary: $summaryFile" -ForegroundColor Gray
```

}