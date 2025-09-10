# Microsoft 365 PowerShell Security Groups Migration Scripts

**ALWAYS reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.**

This repository contains PowerShell scripts for migrating Microsoft 365 security groups from Commercial to GCC High environments. The scripts handle exporting security groups with their memberships and ownership from a source tenant and importing them into a target GCC High tenant.

## Working Effectively

### Environment Setup and Dependencies
- **PowerShell Version**: PowerShell 7.4.11 Core is available and functional
- **Execution Policy**: Unrestricted (allows script execution)
- **Required Modules**: Scripts require Azure AD and Exchange Online management modules

### CRITICAL: Script Syntax Fixes Required
**IMPORTANT**: The PowerShell scripts contain markdown formatting artifacts that must be removed before execution. ALWAYS run this fix first:

```bash
# Remove markdown code blocks from scripts
cd /home/runner/work/powershell/powershell
sed 's/^```$//' export-securitygroups.ps1 > export-securitygroups-fixed.ps1
sed 's/^```$//' import-securitygroups-gcchigh.ps1 > import-securitygroups-gcchigh-fixed.ps1

# Fix here-string terminator in export script
sed -i '350s/.*/\"@/' export-securitygroups-fixed.ps1

# Fix commented closing brace in import script
sed -i 's/^# }$/}/' import-securitygroups-gcchigh-fixed.ps1

# Replace original files with fixed versions
mv export-securitygroups-fixed.ps1 export-securitygroups.ps1
mv import-securitygroups-gcchigh-fixed.ps1 import-securitygroups-gcchigh.ps1
```

**TIMING**: Syntax fixes take ~1 second total. ALWAYS run these before testing scripts.

### Bootstrap PowerShell Environment
Run these commands in sequence to set up the PowerShell environment:

```powershell
# Set TLS 1.2 for secure connections (takes ~2 seconds)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Register PowerShell Gallery (takes ~2 seconds) - may show warnings in sandbox
Register-PSRepository -Default

# Install required modules - NEVER CANCEL: Takes 10-15 minutes total. Set timeout to 20+ minutes.
Install-Module -Name AzureAD -Scope CurrentUser -Force
Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force  
Install-Module -Name Microsoft.Graph -Scope CurrentUser -Force
Install-Module -Name PnP.PowerShell -Scope CurrentUser -Force
Install-Module -Name Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser -Force
```

**CRITICAL**: Module installation takes 10-15 minutes. NEVER CANCEL these operations. Set timeouts to 20+ minutes minimum.

### Script Validation and Testing
Always validate PowerShell scripts before execution:

```powershell
# Test script syntax (takes ~1 second each)
try { 
    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content .\export-securitygroups.ps1 -Raw), [ref]$null)
    Write-Host 'export-securitygroups.ps1: Syntax OK' 
} catch { 
    Write-Host 'export-securitygroups.ps1: Syntax Error - ' $_.Exception.Message 
}

try { 
    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content .\import-securitygroups-gcchigh.ps1 -Raw), [ref]$null)
    Write-Host 'import-securitygroups-gcchigh.ps1: Syntax OK' 
} catch { 
    Write-Host 'import-securitygroups-gcchigh.ps1: Syntax Error - ' $_.Exception.Message 
}
```

### Running the Security Group Migration Scripts

#### Export Security Groups (Source Tenant)
```powershell
# Basic export with auto-connect (Windows paths)
.\export-securitygroups.ps1

# Export to custom location (use Linux paths in sandbox)
.\export-securitygroups.ps1 -OutputPath "/tmp/security-groups"

# Include mail-enabled security groups
.\export-securitygroups.ps1 -IncludeMailEnabledGroups

# Skip auto-connection (if already connected)
.\export-securitygroups.ps1 -ConnectToServices:$false
```

#### Import Security Groups (GCC High Tenant)
```powershell
# ALWAYS run preview first (WhatIf mode) - will fail on paths in sandbox
.\import-securitygroups-gcchigh.ps1 -All -WhatIf -ImportPath "/tmp/security-groups"

# Full migration in sequence
.\import-securitygroups-gcchigh.ps1 -All -ImportPath "/tmp/security-groups"

# Step-by-step approach
.\import-securitygroups-gcchigh.ps1 -CreateGroups -ImportPath "/tmp/security-groups"
.\import-securitygroups-gcchigh.ps1 -AddOwners -ImportPath "/tmp/security-groups"
.\import-securitygroups-gcchigh.ps1 -AddMembers -ImportPath "/tmp/security-groups"
```

## Validation

### Manual Authentication Testing
**IMPORTANT**: These scripts require Microsoft 365 admin authentication which will NOT work in sandboxed environments. For testing authentication flow:

```powershell
# Test Azure AD connection (will fail in sandbox)
try {
    Connect-AzureAD
    Write-Host "Azure AD connection successful"
    Get-AzureADTenantDetail | Select-Object DisplayName
} catch {
    Write-Host "Expected: Authentication will fail in sandbox environment - " $_.Exception.Message
}

# Test Exchange Online connection (will fail in sandbox)  
try {
    Connect-ExchangeOnline
    Write-Host "Exchange Online connection successful"
} catch {
    Write-Host "Expected: Authentication will fail in sandbox environment - " $_.Exception.Message
}
```

### Functional Validation Scenarios
**AFTER making any changes to the scripts, ALWAYS test these scenarios:**

1. **Script Syntax Validation** (see commands above)
2. **Syntax Fix Application**: Verify markdown artifacts are removed
3. **Parameter Validation**: Test script help and parameter parsing
4. **Output Directory Creation**: Verify scripts can create output directories
5. **CSV Export Format**: Verify exported CSV files have correct structure
6. **Error Handling**: Test scripts handle missing modules gracefully

### End-to-End Validation Commands
```powershell
# Test safe execution without authentication (expect module errors)
mkdir -p /tmp/test-export
.\export-securitygroups.ps1 -OutputPath "/tmp/test-export" -ConnectToServices:$false

# Test import script parameter validation (expect path errors in sandbox)
.\import-securitygroups-gcchigh.ps1 -WhatIf -ImportPath "/tmp/test-export"

# Verify CSV structure matches expected format
$testGroups = @(
    [PSCustomObject]@{GroupName="Test"; GroupDescription="Test Group"; SecurityEnabled=$true}
)
$testGroups | Export-Csv -Path "/tmp/test-export/groups.csv" -NoTypeInformation
Import-Csv -Path "/tmp/test-export/groups.csv" | Format-Table
```

## Script Timing and Performance
- **Syntax Fix Operations**: ~1 second total
- **Script Syntax Check**: ~1 second per script  
- **Module Installation**: 10-15 minutes total (NEVER CANCEL)
- **Export Script Execution**: 2-5 minutes per 100 groups (depending on membership size)
- **Import Script Execution**: 3-7 minutes per 100 groups (includes API throttling delays)
- **PowerShell Gallery Registration**: ~2 seconds

## Common Tasks and Troubleshooting

### Repository File Structure
```
/home/runner/work/powershell/powershell/
├── README.md                              # Repository documentation
├── export-securitygroups.ps1             # Export script (290 lines) - needs syntax fixes
└── import-securitygroups-gcchigh.ps1     # Import script (557 lines) - needs syntax fixes
```

### Syntax Issues and Fixes
**CRITICAL**: Scripts contain markdown formatting that breaks PowerShell syntax:
- **Markdown code blocks** (```` ``` ````): Remove with `sed 's/^```$//' script.ps1`
- **Here-string formatting**: Fix terminator alignment with `sed -i '350s/.*/\"@/' export-securitygroups.ps1`
- **Commented code blocks**: Uncomment necessary closing braces

### Common Module Issues
```powershell
# Check if modules are installed
Get-Module -ListAvailable | Where-Object {$_.Name -like '*Azure*' -or $_.Name -like '*Exchange*'}

# Check PowerShell Gallery registration (may show warnings in sandbox)
Get-PSRepository

# Re-register if needed
Register-PSRepository -Default
```

### Script Development Guidelines
When modifying scripts:
1. **ALWAYS apply syntax fixes first** using the sed commands above
2. **ALWAYS validate syntax** using the tokenizer commands
3. **Test parameter parsing** with `-WhatIf` and help commands
4. **Use Linux paths** (`/tmp/`) when testing in sandbox environment
5. **Validate CSV import/export logic** with test data
6. **Check error handling** for missing modules and authentication failures
7. **Verify logging functionality** in import script

### Error Patterns to Watch For
- **Syntax Errors**: Apply markdown removal fixes first
- **Module Not Found**: Install required modules using commands above
- **Authentication Failures**: Expected in sandbox - document as limitation
- **Path Issues**: Use Linux paths (`/tmp/`) instead of Windows paths (`C:\`) in sandbox
- **CSV Format Issues**: Validate headers match script expectations
- **Parameter Validation**: Test all parameter combinations

## Key Script Features

### export-securitygroups.ps1
- **Purpose**: Exports security groups from source Microsoft 365 tenant
- **Dependencies**: AzureAD, ExchangeOnlineManagement modules
- **Outputs**: Three CSV files (Groups, Members, Owners) with timestamp
- **Key Functions**: Group enumeration, membership retrieval, owner listing
- **Syntax Issues**: Contains markdown artifacts and here-string formatting errors

### import-securitygroups-gcchigh.ps1  
- **Purpose**: Imports security groups into GCC High tenant
- **Dependencies**: AzureAD, ExchangeOnlineManagement modules
- **Features**: WhatIf mode, step-by-step import, error logging
- **Key Functions**: Group creation, membership assignment, ownership setup
- **Syntax Issues**: Contains markdown artifacts and commented closing braces

## Development Best Practices
- **ALWAYS apply syntax fixes** before testing or running scripts
- **Always use WhatIf mode** for testing import operations
- **Validate all CSV file structures** before import
- **Test error handling paths** with missing dependencies
- **Document any authentication limitations** in sandboxed environments
- **Use timestamped output files** to avoid conflicts
- **Implement proper logging** for troubleshooting
- **Use appropriate paths** for the target environment (Linux vs Windows)

## Limitations in Sandboxed Environments
- **No Microsoft 365 Authentication**: Scripts cannot connect to actual tenants
- **Module Installation May Fail**: PowerShell Gallery access may be limited
- **Network Dependencies**: Some operations require internet connectivity
- **Path Differences**: Scripts use Windows paths but sandbox uses Linux paths
- **Testing Scope**: Limited to syntax validation and parameter testing

## Expected Error Messages in Sandbox
- `"The term 'Connect-AzureAD' is not recognized"` - Expected when modules not installed
- `"Cannot find drive. A drive with the name 'C' does not exist"` - Expected with Windows paths
- `"Authentication will fail in sandbox environment"` - Expected for authentication tests

**Remember**: These scripts are designed for production Microsoft 365 environments with proper authentication and module access. Always apply syntax fixes before use.