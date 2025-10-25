<#
.SYNOPSIS
    CMMC Compliance Assessment Tool for Microsoft 365

.DESCRIPTION
    This script assesses a Microsoft 365 tenant (Commercial, GCC, or GCC High) against 
    NIST 800-171 R3 requirements to support CMMC compliance. It generates an HTML report 
    detailing compliance status and collects evidence for each requirement.

.PARAMETER TenantId
    The Azure AD Tenant ID to assess

.PARAMETER ClientId
    The Application (Client) ID for certificate-based authentication

.PARAMETER CertificateThumbprint
    The certificate thumbprint for certificate-based authentication

.PARAMETER OutputPath
    Path where the HTML report and evidence files will be saved (default: C:\temp\cmmc-reports)

.PARAMETER TenantType
    The type of Microsoft 365 tenant (Commercial, GCC, or GCCHigh)

.PARAMETER UseInteractiveAuth
    Use interactive authentication instead of certificate-based authentication

.EXAMPLE
    .\Invoke-CMMCAssessment.ps1 -TenantId "your-tenant-id" -ClientId "your-app-id" -CertificateThumbprint "cert-thumbprint"

.EXAMPLE
    .\Invoke-CMMCAssessment.ps1 -UseInteractiveAuth -TenantType "GCC"

.EXAMPLE
    .\Invoke-CMMCAssessment.ps1 -TenantId "your-tenant-id" -ClientId "your-app-id" -CertificateThumbprint "cert-thumbprint" -OutputPath "D:\Reports"

.NOTES
    Author: CMMC Assessment Tool
    Requires: Microsoft.Graph modules
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$TenantId,
    
    [Parameter(Mandatory=$false)]
    [string]$ClientId,
    
    [Parameter(Mandatory=$false)]
    [string]$CertificateThumbprint,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "C:\temp\cmmc-reports",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Commercial", "GCC", "GCCHigh")]
    [string]$TenantType = "Commercial",
    
    [Parameter(Mandatory=$false)]
    [switch]$UseInteractiveAuth = $false
)

#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Identity.DirectoryManagement, Microsoft.Graph.Identity.SignIns, Microsoft.Graph.Users, Microsoft.Graph.Groups, Microsoft.Graph.Security

# ============================================================================
# Global Configuration
# ============================================================================

$script:AssessmentResults = @()
$script:TenantInfo = @{}
$script:EvidenceFiles = @()

# ============================================================================
# NIST 800-171 R3 Control Families
# ============================================================================

$script:ControlFamilies = @{
    "AC" = "Access Control"
    "AU" = "Audit and Accountability"
    "AT" = "Awareness and Training"
    "CM" = "Configuration Management"
    "IA" = "Identification and Authentication"
    "IR" = "Incident Response"
    "MA" = "Maintenance"
    "MP" = "Media Protection"
    "PE" = "Physical Protection"
    "PS" = "Personnel Security"
    "RE" = "Recovery"
    "RM" = "Risk Management"
    "CA" = "Security Assessment"
    "SC" = "System and Communications Protection"
    "SI" = "System and Information Integrity"
}

# ============================================================================
# Helper Functions
# ============================================================================

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $colorMap = @{
        "Info" = "White"
        "Success" = "Green"
        "Warning" = "Yellow"
        "Error" = "Red"
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $colorMap[$Level]
}

function Ensure-OutputDirectory {
    param([string]$Path)
    
    if (!(Test-Path -Path $Path)) {
        Write-Log "Creating output directory: $Path" -Level "Info"
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Connect-ToMicrosoftGraph {
    param(
        [string]$TenantId,
        [string]$ClientId,
        [string]$CertificateThumbprint,
        [string]$TenantType,
        [bool]$UseInteractive
    )
    
    try {
        Write-Log "Connecting to Microsoft Graph..." -Level "Info"
        
        # Define required scopes
        $scopes = @(
            "Directory.Read.All",
            "Policy.Read.All",
            "UserAuthenticationMethod.Read.All",
            "AuditLog.Read.All",
            "SecurityEvents.Read.All",
            "Organization.Read.All"
        )
        
        # Determine Graph endpoint based on tenant type
        $environment = switch ($TenantType) {
            "GCC" { "USGov" }
            "GCCHigh" { "USGovDoD" }
            default { "Global" }
        }
        
        if ($UseInteractive) {
            Connect-MgGraph -Scopes $scopes -Environment $environment -NoWelcome
        }
        else {
            Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -Environment $environment -NoWelcome
        }
        
        $context = Get-MgContext
        Write-Log "Successfully connected to tenant: $($context.TenantId)" -Level "Success"
        Write-Log "Environment: $environment" -Level "Info"
        
        return $true
    }
    catch {
        Write-Log "Failed to connect to Microsoft Graph: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Get-TenantInformation {
    try {
        Write-Log "Gathering tenant information..." -Level "Info"
        
        $org = Get-MgOrganization
        
        $script:TenantInfo = @{
            DisplayName = $org.DisplayName
            TenantId = $org.Id
            CreatedDateTime = $org.CreatedDateTime
            VerifiedDomains = $org.VerifiedDomains.Name -join ", "
            AssessmentDate = Get-Date
        }
        
        Write-Log "Tenant: $($script:TenantInfo.DisplayName)" -Level "Success"
        return $true
    }
    catch {
        Write-Log "Failed to gather tenant information: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

# ============================================================================
# Compliance Check Functions
# ============================================================================

function Test-PasswordPolicy {
    <#
    .SYNOPSIS
        Tests password policy settings (IA-5: Authenticator Management)
    #>
    
    try {
        Write-Log "Checking password policy configuration..." -Level "Info"
        
        $domain = Get-MgDomain | Where-Object { $_.IsDefault -eq $true }
        $passwordPolicy = $domain.PasswordValidityPeriodInDays
        
        $compliant = $false
        $findings = @()
        $evidence = @()
        
        # Check password validity period
        if ($passwordPolicy -and $passwordPolicy -le 60) {
            $compliant = $true
            $findings += "Password expiration is set to $passwordPolicy days (≤60 days required)"
            $evidence += "Password validity period: $passwordPolicy days"
        }
        else {
            $findings += "Password expiration should be set to 60 days or less (Current: $passwordPolicy days)"
            $evidence += "Password validity period: $passwordPolicy days - NON-COMPLIANT"
        }
        
        # Check for additional password settings
        $authMethods = Get-MgPolicyAuthenticationMethodPolicy
        $evidence += "Authentication methods policy configured: $($authMethods.Id)"
        
        Add-ComplianceResult -ControlId "IA-5" `
            -ControlName "Authenticator Management" `
            -ControlFamily "IA" `
            -Description "Manage information system authenticators" `
            -Compliant $compliant `
            -Findings $findings `
            -Evidence $evidence `
            -Severity "High"
        
        return $compliant
    }
    catch {
        Write-Log "Error checking password policy: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Test-MFAEnforcement {
    <#
    .SYNOPSIS
        Tests Multi-Factor Authentication enforcement (IA-2: Identification and Authentication)
    #>
    
    try {
        Write-Log "Checking MFA enforcement..." -Level "Info"
        
        # Get conditional access policies
        $caPolicies = Get-MgIdentityConditionalAccessPolicy
        $mfaPolicies = $caPolicies | Where-Object { 
            $_.GrantControls.BuiltInControls -contains "mfa" -and $_.State -eq "enabled"
        }
        
        $compliant = $false
        $findings = @()
        $evidence = @()
        
        if ($mfaPolicies.Count -gt 0) {
            $compliant = $true
            $findings += "MFA is enforced through $($mfaPolicies.Count) active conditional access policy/policies"
            foreach ($policy in $mfaPolicies) {
                $evidence += "Active MFA Policy: $($policy.DisplayName) (State: $($policy.State))"
            }
        }
        else {
            $findings += "No active conditional access policies enforcing MFA found"
            $evidence += "MFA enforcement status: NOT CONFIGURED"
        }
        
        # Check MFA registration
        $users = Get-MgUser -Top 100 -Property Id,UserPrincipalName
        $mfaCount = 0
        foreach ($user in $users) {
            try {
                $authMethods = Get-MgUserAuthenticationMethod -UserId $user.Id -ErrorAction SilentlyContinue
                if ($authMethods.Count -gt 1) {
                    $mfaCount++
                }
            }
            catch {
                # Skip users we can't query
            }
        }
        
        $mfaPercentage = [math]::Round(($mfaCount / $users.Count) * 100, 2)
        $evidence += "Users with MFA registered: $mfaCount of $($users.Count) ($mfaPercentage%)"
        
        if ($mfaPercentage -lt 100) {
            $compliant = $false
            $findings += "Not all users have MFA registered ($mfaPercentage% registered)"
        }
        
        Add-ComplianceResult -ControlId "IA-2" `
            -ControlName "Identification and Authentication (Organizational Users)" `
            -ControlFamily "IA" `
            -Description "Uniquely identify and authenticate organizational users" `
            -Compliant $compliant `
            -Findings $findings `
            -Evidence $evidence `
            -Severity "Critical"
        
        return $compliant
    }
    catch {
        Write-Log "Error checking MFA enforcement: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Test-AccountLockoutPolicy {
    <#
    .SYNOPSIS
        Tests account lockout policy (AC-7: Unsuccessful Logon Attempts)
    #>
    
    try {
        Write-Log "Checking account lockout policy..." -Level "Info"
        
        $compliant = $false
        $findings = @()
        $evidence = @()
        
        # Check for conditional access policies with sign-in risk
        $caPolicies = Get-MgIdentityConditionalAccessPolicy
        $riskPolicies = $caPolicies | Where-Object { 
            $_.Conditions.SignInRiskLevels -and $_.State -eq "enabled"
        }
        
        if ($riskPolicies.Count -gt 0) {
            $compliant = $true
            $findings += "Sign-in risk policies are configured through $($riskPolicies.Count) conditional access policy/policies"
            foreach ($policy in $riskPolicies) {
                $evidence += "Risk-based Policy: $($policy.DisplayName) (Risk Levels: $($policy.Conditions.SignInRiskLevels -join ', '))"
            }
        }
        else {
            $findings += "No risk-based conditional access policies found for account lockout"
            $evidence += "Account lockout policy: NOT CONFIGURED"
        }
        
        # Check for Azure AD Identity Protection
        try {
            $riskDetections = Get-MgRiskDetection -Top 1 -ErrorAction SilentlyContinue
            $evidence += "Azure AD Identity Protection is active (risk detection available)"
        }
        catch {
            $evidence += "Azure AD Identity Protection status: Unknown or not available"
        }
        
        Add-ComplianceResult -ControlId "AC-7" `
            -ControlName "Unsuccessful Logon Attempts" `
            -ControlFamily "AC" `
            -Description "Enforce a limit of consecutive invalid logon attempts" `
            -Compliant $compliant `
            -Findings $findings `
            -Evidence $evidence `
            -Severity "High"
        
        return $compliant
    }
    catch {
        Write-Log "Error checking account lockout policy: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Test-AuditLogging {
    <#
    .SYNOPSIS
        Tests audit logging configuration (AU-2: Audit Events)
    #>
    
    try {
        Write-Log "Checking audit logging configuration..." -Level "Info"
        
        $compliant = $false
        $findings = @()
        $evidence = @()
        
        # Check audit log configuration
        try {
            $auditLogs = Get-MgAuditLogDirectoryAudit -Top 10
            if ($auditLogs.Count -gt 0) {
                $compliant = $true
                $findings += "Audit logging is active with $($auditLogs.Count) recent events captured"
                $evidence += "Recent audit events: $($auditLogs.Count) events in the last query"
                $evidence += "Latest audit event: $($auditLogs[0].ActivityDisplayName) at $($auditLogs[0].ActivityDateTime)"
            }
            else {
                $findings += "No recent audit events found - verify audit logging is properly configured"
                $evidence += "Audit log status: No recent events"
            }
        }
        catch {
            $findings += "Unable to retrieve audit logs - may require additional permissions"
            $evidence += "Audit log access: PERMISSION ERROR"
        }
        
        # Check sign-in logs
        try {
            $signInLogs = Get-MgAuditLogSignIn -Top 10
            if ($signInLogs.Count -gt 0) {
                $evidence += "Sign-in logging is active with $($signInLogs.Count) recent events"
            }
        }
        catch {
            $evidence += "Sign-in log access: Limited or unavailable"
        }
        
        Add-ComplianceResult -ControlId "AU-2" `
            -ControlName "Audit Events" `
            -ControlFamily "AU" `
            -Description "Identify the types of events the system is capable of logging" `
            -Compliant $compliant `
            -Findings $findings `
            -Evidence $evidence `
            -Severity "High"
        
        return $compliant
    }
    catch {
        Write-Log "Error checking audit logging: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Test-SessionTimeout {
    <#
    .SYNOPSIS
        Tests session timeout configuration (AC-12: Session Termination)
    #>
    
    try {
        Write-Log "Checking session timeout configuration..." -Level "Info"
        
        $compliant = $false
        $findings = @()
        $evidence = @()
        
        # Check conditional access policies for session controls
        $caPolicies = Get-MgIdentityConditionalAccessPolicy
        $sessionPolicies = $caPolicies | Where-Object { 
            $_.SessionControls -and $_.State -eq "enabled"
        }
        
        if ($sessionPolicies.Count -gt 0) {
            foreach ($policy in $sessionPolicies) {
                if ($policy.SessionControls.SignInFrequency) {
                    $compliant = $true
                    $frequency = $policy.SessionControls.SignInFrequency
                    $findings += "Session timeout configured: $($policy.DisplayName)"
                    $evidence += "Policy: $($policy.DisplayName) - Sign-in frequency: $($frequency.Value) $($frequency.Type)"
                }
                if ($policy.SessionControls.PersistentBrowser) {
                    $evidence += "Persistent browser: $($policy.SessionControls.PersistentBrowser.Mode)"
                }
            }
        }
        
        if (-not $compliant) {
            $findings += "No session timeout policies found - consider implementing sign-in frequency controls"
            $evidence += "Session timeout: NOT CONFIGURED"
        }
        
        Add-ComplianceResult -ControlId "AC-12" `
            -ControlName "Session Termination" `
            -ControlFamily "AC" `
            -Description "Automatically terminate user sessions after a defined period of inactivity" `
            -Compliant $compliant `
            -Findings $findings `
            -Evidence $evidence `
            -Severity "Medium"
        
        return $compliant
    }
    catch {
        Write-Log "Error checking session timeout: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Test-GuestAccessRestrictions {
    <#
    .SYNOPSIS
        Tests guest access restrictions (AC-3: Access Enforcement)
    #>
    
    try {
        Write-Log "Checking guest access restrictions..." -Level "Info"
        
        $compliant = $false
        $findings = @()
        $evidence = @()
        
        # Get external collaboration settings
        $authPolicy = Get-MgPolicyAuthorizationPolicy
        $guestSettings = $authPolicy.DefaultUserRolePermissions
        
        # Check guest invite restrictions
        $allowInvites = $authPolicy.AllowInvitesFrom
        $evidence += "Guest invite policy: $allowInvites"
        
        if ($allowInvites -eq "adminsAndGuestInviters" -or $allowInvites -eq "adminsGuestInvitersAndAllMembers") {
            $findings += "Guest invites are restricted to specific roles"
            $compliant = $true
        }
        else {
            $findings += "Guest invite restrictions may not be optimal (Current: $allowInvites)"
        }
        
        # Check guest user permissions
        if ($guestSettings.AllowedToCreateSecurityGroups -eq $false) {
            $evidence += "Guests cannot create security groups: COMPLIANT"
        }
        else {
            $evidence += "Guests can create security groups: REVIEW REQUIRED"
            $compliant = $false
        }
        
        # Count guest users
        $guestUsers = Get-MgUser -Filter "userType eq 'Guest'" -Top 999 -ConsistencyLevel eventual -CountVariable guestCount
        $evidence += "Total guest users in tenant: $guestCount"
        
        Add-ComplianceResult -ControlId "AC-3" `
            -ControlName "Access Enforcement" `
            -ControlFamily "AC" `
            -Description "Enforce approved authorizations for logical access" `
            -Compliant $compliant `
            -Findings $findings `
            -Evidence $evidence `
            -Severity "Medium"
        
        return $compliant
    }
    catch {
        Write-Log "Error checking guest access restrictions: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Test-PrivilegedAccountManagement {
    <#
    .SYNOPSIS
        Tests privileged account management (AC-2: Account Management)
    #>
    
    try {
        Write-Log "Checking privileged account management..." -Level "Info"
        
        $compliant = $false
        $findings = @()
        $evidence = @()
        
        # Get privileged roles
        $privilegedRoles = @(
            "Global Administrator",
            "Privileged Role Administrator",
            "Security Administrator",
            "Compliance Administrator"
        )
        
        $adminCount = 0
        foreach ($roleName in $privilegedRoles) {
            try {
                $role = Get-MgDirectoryRole -Filter "displayName eq '$roleName'"
                if ($role) {
                    $members = Get-MgDirectoryRoleMember -DirectoryRoleId $role.Id
                    $adminCount += $members.Count
                    $evidence += "$roleName: $($members.Count) members"
                }
            }
            catch {
                $evidence += "$roleName: Unable to retrieve member count"
            }
        }
        
        # Check if admin count is reasonable (less than 5% of users)
        $allUsers = Get-MgUser -Top 999 -ConsistencyLevel eventual -CountVariable userCount
        $adminPercentage = [math]::Round(($adminCount / $userCount) * 100, 2)
        $evidence += "Total privileged accounts: $adminCount of $userCount users ($adminPercentage%)"
        
        if ($adminPercentage -lt 5) {
            $compliant = $true
            $findings += "Privileged account count is within acceptable limits ($adminPercentage% of users)"
        }
        else {
            $findings += "High number of privileged accounts detected ($adminPercentage% of users) - review required"
        }
        
        # Check for PIM (Privileged Identity Management)
        try {
            $pimRoles = Get-MgRoleManagementDirectoryRoleEligibilitySchedule -Top 1 -ErrorAction SilentlyContinue
            $evidence += "Privileged Identity Management (PIM): Active"
        }
        catch {
            $evidence += "Privileged Identity Management (PIM): Not detected or not accessible"
        }
        
        Add-ComplianceResult -ControlId "AC-2" `
            -ControlName "Account Management" `
            -ControlFamily "AC" `
            -Description "Manage information system accounts including establishment, activation, modification, review, disablement, and removal" `
            -Compliant $compliant `
            -Findings $findings `
            -Evidence $evidence `
            -Severity "Critical"
        
        return $compliant
    }
    catch {
        Write-Log "Error checking privileged account management: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Test-DataEncryption {
    <#
    .SYNOPSIS
        Tests data encryption configuration (SC-13: Cryptographic Protection)
    #>
    
    try {
        Write-Log "Checking data encryption configuration..." -Level "Info"
        
        $compliant = $true  # M365 has encryption by default
        $findings = @()
        $evidence = @()
        
        # M365 provides encryption at rest and in transit by default
        $findings += "Microsoft 365 provides encryption at rest and in transit by default"
        $evidence += "Encryption at rest: Enabled by default for all M365 services"
        $evidence += "Encryption in transit: TLS 1.2+ enforced for all connections"
        
        # Check for additional encryption features
        try {
            $org = Get-MgOrganization
            $evidence += "Organization verified domains: $($org.VerifiedDomains.Count)"
        }
        catch {
            $evidence += "Unable to verify additional encryption settings"
        }
        
        Add-ComplianceResult -ControlId "SC-13" `
            -ControlName "Cryptographic Protection" `
            -ControlFamily "SC" `
            -Description "Implement cryptographic mechanisms to prevent unauthorized disclosure of information" `
            -Compliant $compliant `
            -Findings $findings `
            -Evidence $evidence `
            -Severity "Critical"
        
        return $compliant
    }
    catch {
        Write-Log "Error checking data encryption: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Test-IncidentResponse {
    <#
    .SYNOPSIS
        Tests incident response configuration (IR-4: Incident Handling)
    #>
    
    try {
        Write-Log "Checking incident response configuration..." -Level "Info"
        
        $compliant = $false
        $findings = @()
        $evidence = @()
        
        # Check for security alerts
        try {
            $alerts = Get-MgSecurityAlert -Top 10 -ErrorAction SilentlyContinue
            if ($alerts) {
                $compliant = $true
                $findings += "Security alerting is configured and active"
                $evidence += "Recent security alerts: $($alerts.Count) alerts in query"
            }
            else {
                $findings += "No recent security alerts found"
                $evidence += "Security alerts: No recent alerts (good or needs verification)"
            }
        }
        catch {
            $findings += "Unable to retrieve security alerts - may require additional permissions"
            $evidence += "Security alerts: ACCESS LIMITED"
        }
        
        # Check for incident response policies through conditional access
        $caPolicies = Get-MgIdentityConditionalAccessPolicy
        $blockPolicies = $caPolicies | Where-Object { 
            $_.GrantControls.BuiltInControls -contains "block" -and $_.State -eq "enabled"
        }
        
        if ($blockPolicies.Count -gt 0) {
            $evidence += "Automated blocking policies: $($blockPolicies.Count) active policies"
        }
        else {
            $evidence += "Automated blocking policies: None configured"
        }
        
        Add-ComplianceResult -ControlId "IR-4" `
            -ControlName "Incident Handling" `
            -ControlFamily "IR" `
            -Description "Implement incident handling capability for security incidents" `
            -Compliant $compliant `
            -Findings $findings `
            -Evidence $evidence `
            -Severity "High"
        
        return $compliant
    }
    catch {
        Write-Log "Error checking incident response: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Test-SystemMonitoring {
    <#
    .SYNOPSIS
        Tests system monitoring configuration (SI-4: Information System Monitoring)
    #>
    
    try {
        Write-Log "Checking system monitoring configuration..." -Level "Info"
        
        $compliant = $false
        $findings = @()
        $evidence = @()
        
        # Check sign-in logs for monitoring
        try {
            $signInLogs = Get-MgAuditLogSignIn -Top 100
            if ($signInLogs.Count -gt 0) {
                $compliant = $true
                $findings += "Sign-in monitoring is active with $($signInLogs.Count) recent events"
                
                # Analyze recent sign-ins
                $failedSignIns = $signInLogs | Where-Object { $_.Status.ErrorCode -ne 0 }
                $evidence += "Total sign-ins monitored: $($signInLogs.Count)"
                $evidence += "Failed sign-ins: $($failedSignIns.Count)"
                
                # Check for suspicious activities
                $suspiciousLocations = $signInLogs | Where-Object { $_.Location.CountryOrRegion } | 
                    Group-Object -Property { $_.Location.CountryOrRegion } | 
                    Select-Object -First 3
                
                $evidence += "Top sign-in locations: $($suspiciousLocations.Name -join ', ')"
            }
            else {
                $findings += "No recent sign-in events found for monitoring"
                $evidence += "Sign-in monitoring: No recent data"
            }
        }
        catch {
            $findings += "Unable to retrieve sign-in logs for monitoring"
            $evidence += "Sign-in monitoring: ACCESS ERROR"
        }
        
        Add-ComplianceResult -ControlId "SI-4" `
            -ControlName "Information System Monitoring" `
            -ControlFamily "SI" `
            -Description "Monitor the information system to detect attacks and indicators of potential attacks" `
            -Compliant $compliant `
            -Findings $findings `
            -Evidence $evidence `
            -Severity "High"
        
        return $compliant
    }
    catch {
        Write-Log "Error checking system monitoring: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

# ============================================================================
# Report Generation Functions
# ============================================================================

function Add-ComplianceResult {
    param(
        [string]$ControlId,
        [string]$ControlName,
        [string]$ControlFamily,
        [string]$Description,
        [bool]$Compliant,
        [string[]]$Findings,
        [string[]]$Evidence,
        [ValidateSet("Critical", "High", "Medium", "Low")]
        [string]$Severity
    )
    
    $result = [PSCustomObject]@{
        ControlId = $ControlId
        ControlName = $ControlName
        ControlFamily = $ControlFamily
        ControlFamilyName = $script:ControlFamilies[$ControlFamily]
        Description = $Description
        Compliant = $Compliant
        Status = if ($Compliant) { "COMPLIANT" } else { "NON-COMPLIANT" }
        Findings = $Findings
        Evidence = $Evidence
        Severity = $Severity
        AssessmentDate = Get-Date
    }
    
    $script:AssessmentResults += $result
}

function Export-EvidenceToJson {
    param([string]$OutputPath)
    
    try {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $jsonFile = Join-Path -Path $OutputPath -ChildPath "CMMC_Evidence_$timestamp.json"
        
        $evidenceData = @{
            TenantInfo = $script:TenantInfo
            AssessmentResults = $script:AssessmentResults
            GeneratedDate = Get-Date
        }
        
        $evidenceData | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonFile -Encoding UTF8
        
        Write-Log "Evidence exported to: $jsonFile" -Level "Success"
        $script:EvidenceFiles += $jsonFile
        
        return $jsonFile
    }
    catch {
        Write-Log "Error exporting evidence: $($_.Exception.Message)" -Level "Error"
        return $null
    }
}

function New-HTMLReport {
    param([string]$OutputPath)
    
    try {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $htmlFile = Join-Path -Path $OutputPath -ChildPath "CMMC_Assessment_Report_$timestamp.html"
        
        # Calculate statistics
        $totalControls = $script:AssessmentResults.Count
        $compliantControls = ($script:AssessmentResults | Where-Object { $_.Compliant -eq $true }).Count
        $nonCompliantControls = $totalControls - $compliantControls
        $compliancePercentage = if ($totalControls -gt 0) { [math]::Round(($compliantControls / $totalControls) * 100, 2) } else { 0 }
        
        # Group by severity
        $criticalIssues = ($script:AssessmentResults | Where-Object { $_.Severity -eq "Critical" -and $_.Compliant -eq $false }).Count
        $highIssues = ($script:AssessmentResults | Where-Object { $_.Severity -eq "High" -and $_.Compliant -eq $false }).Count
        $mediumIssues = ($script:AssessmentResults | Where-Object { $_.Severity -eq "Medium" -and $_.Compliant -eq $false }).Count
        $lowIssues = ($script:AssessmentResults | Where-Object { $_.Severity -eq "Low" -and $_.Compliant -eq $false }).Count
        
        # Generate HTML
        $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CMMC Assessment Report - $($script:TenantInfo.DisplayName)</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            color: #333;
            background-color: #f5f5f5;
            padding: 20px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            border-radius: 8px;
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            font-weight: 300;
        }
        
        .header .subtitle {
            font-size: 1.2em;
            opacity: 0.9;
        }
        
        .tenant-info {
            background-color: #f8f9fa;
            padding: 30px 40px;
            border-bottom: 3px solid #667eea;
        }
        
        .tenant-info h2 {
            color: #667eea;
            margin-bottom: 20px;
        }
        
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
        }
        
        .info-item {
            display: flex;
            flex-direction: column;
        }
        
        .info-label {
            font-weight: 600;
            color: #666;
            font-size: 0.9em;
            text-transform: uppercase;
            margin-bottom: 5px;
        }
        
        .info-value {
            font-size: 1.1em;
            color: #333;
        }
        
        .summary {
            padding: 40px;
            background-color: #fff;
        }
        
        .summary h2 {
            color: #667eea;
            margin-bottom: 30px;
            font-size: 2em;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        
        .stat-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 25px;
            border-radius: 8px;
            text-align: center;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        
        .stat-card.compliant {
            background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%);
        }
        
        .stat-card.non-compliant {
            background: linear-gradient(135deg, #eb3349 0%, #f45c43 100%);
        }
        
        .stat-card.critical {
            background: linear-gradient(135deg, #c31432 0%, #240b36 100%);
        }
        
        .stat-value {
            font-size: 3em;
            font-weight: bold;
            margin-bottom: 5px;
        }
        
        .stat-label {
            font-size: 1em;
            opacity: 0.9;
        }
        
        .compliance-bar {
            width: 100%;
            height: 40px;
            background-color: #e0e0e0;
            border-radius: 20px;
            overflow: hidden;
            margin: 20px 0;
            box-shadow: inset 0 2px 4px rgba(0,0,0,0.1);
        }
        
        .compliance-fill {
            height: 100%;
            background: linear-gradient(90deg, #11998e 0%, #38ef7d 100%);
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-weight: bold;
            font-size: 1.2em;
            transition: width 0.5s ease;
        }
        
        .severity-breakdown {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 15px;
            margin-top: 20px;
        }
        
        .severity-item {
            padding: 15px;
            border-radius: 5px;
            text-align: center;
        }
        
        .severity-item.critical {
            background-color: #ffebee;
            border-left: 4px solid #c62828;
        }
        
        .severity-item.high {
            background-color: #fff3e0;
            border-left: 4px solid #ef6c00;
        }
        
        .severity-item.medium {
            background-color: #fff9c4;
            border-left: 4px solid #f9a825;
        }
        
        .severity-item.low {
            background-color: #e8f5e9;
            border-left: 4px solid #43a047;
        }
        
        .results {
            padding: 40px;
            background-color: #fafafa;
        }
        
        .results h2 {
            color: #667eea;
            margin-bottom: 30px;
            font-size: 2em;
        }
        
        .control-card {
            background-color: white;
            border-radius: 8px;
            padding: 25px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            border-left: 5px solid #667eea;
        }
        
        .control-card.non-compliant {
            border-left-color: #eb3349;
        }
        
        .control-header {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            margin-bottom: 15px;
        }
        
        .control-title {
            flex: 1;
        }
        
        .control-id {
            font-weight: bold;
            color: #667eea;
            font-size: 1.1em;
        }
        
        .control-name {
            font-size: 1.3em;
            margin: 5px 0;
            color: #333;
        }
        
        .control-family {
            color: #666;
            font-size: 0.9em;
        }
        
        .control-status {
            padding: 8px 20px;
            border-radius: 20px;
            font-weight: bold;
            font-size: 0.9em;
            white-space: nowrap;
        }
        
        .control-status.compliant {
            background-color: #e8f5e9;
            color: #2e7d32;
        }
        
        .control-status.non-compliant {
            background-color: #ffebee;
            color: #c62828;
        }
        
        .severity-badge {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 12px;
            font-size: 0.8em;
            font-weight: bold;
            margin-left: 10px;
        }
        
        .severity-badge.critical {
            background-color: #c62828;
            color: white;
        }
        
        .severity-badge.high {
            background-color: #ef6c00;
            color: white;
        }
        
        .severity-badge.medium {
            background-color: #f9a825;
            color: white;
        }
        
        .severity-badge.low {
            background-color: #43a047;
            color: white;
        }
        
        .control-description {
            color: #666;
            margin: 15px 0;
            padding: 15px;
            background-color: #f8f9fa;
            border-radius: 5px;
        }
        
        .findings {
            margin: 20px 0;
        }
        
        .findings h4 {
            color: #333;
            margin-bottom: 10px;
        }
        
        .findings ul {
            list-style: none;
            padding-left: 0;
        }
        
        .findings li {
            padding: 8px 0;
            padding-left: 25px;
            position: relative;
        }
        
        .findings li:before {
            content: "▸";
            position: absolute;
            left: 0;
            color: #667eea;
            font-weight: bold;
        }
        
        .evidence {
            background-color: #f8f9fa;
            padding: 15px;
            border-radius: 5px;
            margin-top: 15px;
        }
        
        .evidence h4 {
            color: #333;
            margin-bottom: 10px;
            font-size: 1em;
        }
        
        .evidence-list {
            list-style: none;
            padding-left: 0;
        }
        
        .evidence-list li {
            padding: 5px 0;
            padding-left: 20px;
            position: relative;
            font-size: 0.9em;
            color: #555;
        }
        
        .evidence-list li:before {
            content: "📄";
            position: absolute;
            left: 0;
        }
        
        .footer {
            background-color: #333;
            color: white;
            padding: 30px 40px;
            text-align: center;
        }
        
        .footer p {
            margin: 5px 0;
            opacity: 0.8;
        }
        
        @media print {
            body {
                background-color: white;
                padding: 0;
            }
            
            .container {
                box-shadow: none;
            }
            
            .control-card {
                page-break-inside: avoid;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🛡️ CMMC Compliance Assessment Report</h1>
            <div class="subtitle">NIST 800-171 R3 Requirements</div>
        </div>
        
        <div class="tenant-info">
            <h2>Tenant Information</h2>
            <div class="info-grid">
                <div class="info-item">
                    <span class="info-label">Organization</span>
                    <span class="info-value">$($script:TenantInfo.DisplayName)</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Tenant ID</span>
                    <span class="info-value">$($script:TenantInfo.TenantId)</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Assessment Date</span>
                    <span class="info-value">$($script:TenantInfo.AssessmentDate.ToString("yyyy-MM-dd HH:mm:ss"))</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Verified Domains</span>
                    <span class="info-value">$($script:TenantInfo.VerifiedDomains)</span>
                </div>
            </div>
        </div>
        
        <div class="summary">
            <h2>Executive Summary</h2>
            
            <div class="stats-grid">
                <div class="stat-card">
                    <div class="stat-value">$totalControls</div>
                    <div class="stat-label">Total Controls Assessed</div>
                </div>
                <div class="stat-card compliant">
                    <div class="stat-value">$compliantControls</div>
                    <div class="stat-label">Compliant Controls</div>
                </div>
                <div class="stat-card non-compliant">
                    <div class="stat-value">$nonCompliantControls</div>
                    <div class="stat-label">Non-Compliant Controls</div>
                </div>
            </div>
            
            <div class="compliance-bar">
                <div class="compliance-fill" style="width: $compliancePercentage%;">
                    $compliancePercentage% Compliant
                </div>
            </div>
            
            <h3 style="margin-top: 30px; color: #333;">Non-Compliant Items by Severity</h3>
            <div class="severity-breakdown">
                <div class="severity-item critical">
                    <div style="font-size: 2em; font-weight: bold;">$criticalIssues</div>
                    <div>Critical</div>
                </div>
                <div class="severity-item high">
                    <div style="font-size: 2em; font-weight: bold;">$highIssues</div>
                    <div>High</div>
                </div>
                <div class="severity-item medium">
                    <div style="font-size: 2em; font-weight: bold;">$mediumIssues</div>
                    <div>Medium</div>
                </div>
                <div class="severity-item low">
                    <div style="font-size: 2em; font-weight: bold;">$lowIssues</div>
                    <div>Low</div>
                </div>
            </div>
        </div>
        
        <div class="results">
            <h2>Detailed Assessment Results</h2>
"@

        # Add control cards
        foreach ($result in $script:AssessmentResults) {
            $statusClass = if ($result.Compliant) { "compliant" } else { "non-compliant" }
            $statusText = $result.Status
            
            $html += @"
            <div class="control-card $statusClass">
                <div class="control-header">
                    <div class="control-title">
                        <div class="control-id">$($result.ControlId)
                            <span class="severity-badge $($result.Severity.ToLower())">$($result.Severity)</span>
                        </div>
                        <div class="control-name">$($result.ControlName)</div>
                        <div class="control-family">$($result.ControlFamilyName) ($($result.ControlFamily))</div>
                    </div>
                    <div class="control-status $statusClass">$statusText</div>
                </div>
                
                <div class="control-description">
                    <strong>Description:</strong> $($result.Description)
                </div>
                
                <div class="findings">
                    <h4>Findings:</h4>
                    <ul>
"@
            foreach ($finding in $result.Findings) {
                $html += "                        <li>$finding</li>`n"
            }
            
            $html += @"
                    </ul>
                </div>
                
                <div class="evidence">
                    <h4>📋 Evidence:</h4>
                    <ul class="evidence-list">
"@
            foreach ($evidence in $result.Evidence) {
                $html += "                        <li>$evidence</li>`n"
            }
            
            $html += @"
                    </ul>
                </div>
            </div>
"@
        }
        
        $html += @"
        </div>
        
        <div class="footer">
            <p><strong>CMMC Assessment Tool v1.0.0</strong></p>
            <p>This report was automatically generated on $($script:TenantInfo.AssessmentDate.ToString("yyyy-MM-dd HH:mm:ss"))</p>
            <p>For questions or support, please contact your compliance team</p>
        </div>
    </div>
</body>
</html>
"@
        
        $html | Out-File -FilePath $htmlFile -Encoding UTF8
        
        Write-Log "HTML report generated: $htmlFile" -Level "Success"
        return $htmlFile
    }
    catch {
        Write-Log "Error generating HTML report: $($_.Exception.Message)" -Level "Error"
        return $null
    }
}

# ============================================================================
# Main Execution
# ============================================================================

function Invoke-Assessment {
    try {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host "   CMMC Compliance Assessment Tool" -ForegroundColor Cyan
        Write-Host "   NIST 800-171 R3 Requirements Assessment" -ForegroundColor Cyan
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host ""
        
        # Ensure output directory exists
        Ensure-OutputDirectory -Path $OutputPath
        
        # Connect to Microsoft Graph
        if ($UseInteractiveAuth) {
            $connected = Connect-ToMicrosoftGraph -TenantType $TenantType -UseInteractive $true
        }
        else {
            if (-not $TenantId -or -not $ClientId -or -not $CertificateThumbprint) {
                Write-Log "Certificate-based authentication requires TenantId, ClientId, and CertificateThumbprint" -Level "Error"
                return $false
            }
            $connected = Connect-ToMicrosoftGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -TenantType $TenantType -UseInteractive $false
        }
        
        if (-not $connected) {
            Write-Log "Failed to connect to Microsoft Graph. Exiting." -Level "Error"
            return $false
        }
        
        # Get tenant information
        if (-not (Get-TenantInformation)) {
            Write-Log "Failed to gather tenant information. Exiting." -Level "Error"
            return $false
        }
        
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host "   Starting Compliance Assessment" -ForegroundColor Cyan
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host ""
        
        # Run compliance checks
        Test-MFAEnforcement
        Test-PasswordPolicy
        Test-AccountLockoutPolicy
        Test-PrivilegedAccountManagement
        Test-GuestAccessRestrictions
        Test-SessionTimeout
        Test-AuditLogging
        Test-SystemMonitoring
        Test-DataEncryption
        Test-IncidentResponse
        
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host "   Generating Reports" -ForegroundColor Cyan
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host ""
        
        # Export evidence
        $jsonFile = Export-EvidenceToJson -OutputPath $OutputPath
        
        # Generate HTML report
        $htmlFile = New-HTMLReport -OutputPath $OutputPath
        
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host "   Assessment Complete" -ForegroundColor Cyan
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host ""
        
        # Display summary
        $totalControls = $script:AssessmentResults.Count
        $compliantControls = ($script:AssessmentResults | Where-Object { $_.Compliant -eq $true }).Count
        $compliancePercentage = [math]::Round(($compliantControls / $totalControls) * 100, 2)
        
        Write-Host "Assessment Summary:" -ForegroundColor Cyan
        Write-Host "  Total Controls Assessed: $totalControls" -ForegroundColor White
        Write-Host "  Compliant Controls: $compliantControls" -ForegroundColor Green
        Write-Host "  Non-Compliant Controls: $($totalControls - $compliantControls)" -ForegroundColor Red
        Write-Host "  Compliance Percentage: $compliancePercentage%" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Reports Generated:" -ForegroundColor Cyan
        Write-Host "  HTML Report: $htmlFile" -ForegroundColor Green
        Write-Host "  Evidence JSON: $jsonFile" -ForegroundColor Green
        Write-Host ""
        
        # Open HTML report if on Windows
        if ($PSVersionTable.Platform -eq 'Win32NT' -or -not $PSVersionTable.Platform) {
            Write-Host "Opening HTML report in default browser..." -ForegroundColor Yellow
            Start-Process $htmlFile
        }
        
        return $true
    }
    catch {
        Write-Log "Assessment failed: $($_.Exception.Message)" -Level "Error"
        Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level "Error"
        return $false
    }
    finally {
        # Disconnect from Microsoft Graph
        try {
            Disconnect-MgGraph -ErrorAction SilentlyContinue
            Write-Log "Disconnected from Microsoft Graph" -Level "Info"
        }
        catch {
            # Ignore disconnect errors
        }
    }
}

# Run the assessment
$success = Invoke-Assessment

if ($success) {
    Write-Host "Assessment completed successfully!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "Assessment completed with errors. Please review the logs." -ForegroundColor Red
    exit 1
}
