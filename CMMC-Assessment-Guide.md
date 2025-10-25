# CMMC Compliance Assessment Tool - Documentation

## Overview

The CMMC Compliance Assessment Tool is a PowerShell-based solution designed to assess Microsoft 365 tenants against NIST 800-171 Revision 3 requirements. This tool helps organizations prepare for CMMC (Cybersecurity Maturity Model Certification) compliance by automating the collection of evidence and generating detailed compliance reports.

## What is CMMC?

CMMC is a unified standard for implementing cybersecurity across the Defense Industrial Base (DIB). It combines various cybersecurity standards and best practices, with NIST SP 800-171 as a foundational requirement. Organizations working with the Department of Defense must demonstrate compliance with CMMC requirements.

## NIST 800-171 R3 Control Families

The tool assesses controls across the following NIST 800-171 R3 families:

- **AC** - Access Control
- **AU** - Audit and Accountability  
- **AT** - Awareness and Training
- **CM** - Configuration Management
- **IA** - Identification and Authentication
- **IR** - Incident Response
- **MA** - Maintenance
- **MP** - Media Protection
- **PE** - Physical Protection
- **PS** - Personnel Security
- **RE** - Recovery
- **RM** - Risk Management
- **CA** - Security Assessment
- **SC** - System and Communications Protection
- **SI** - System and Information Integrity

## Currently Assessed Controls

### IA-2: Identification and Authentication (Organizational Users)
**Requirement:** Uniquely identify and authenticate organizational users

**Assessment:**
- Checks for active Conditional Access policies enforcing MFA
- Verifies MFA registration rates across the user population
- Validates that authentication requirements are properly configured

**Evidence Collected:**
- List of active MFA-enforcing Conditional Access policies
- Percentage of users with MFA registered
- Policy states and configurations

**Compliance Criteria:**
- At least one active CA policy enforcing MFA
- 100% of users with MFA registered

---

### IA-5: Authenticator Management
**Requirement:** Manage information system authenticators

**Assessment:**
- Validates password expiration policies
- Checks authentication method policies
- Reviews password complexity requirements

**Evidence Collected:**
- Password validity period settings
- Authentication methods policy configuration
- Domain password settings

**Compliance Criteria:**
- Password expiration set to 60 days or less
- Authentication methods properly configured

---

### AC-7: Unsuccessful Logon Attempts
**Requirement:** Enforce a limit of consecutive invalid logon attempts

**Assessment:**
- Checks for sign-in risk-based Conditional Access policies
- Validates Azure AD Identity Protection configuration
- Reviews automated response policies

**Evidence Collected:**
- Risk-based Conditional Access policies
- Sign-in risk levels configured
- Identity Protection status

**Compliance Criteria:**
- Active risk-based policies configured
- Sign-in risk policies enabled

---

### AC-2: Account Management
**Requirement:** Manage information system accounts

**Assessment:**
- Reviews privileged role assignments
- Validates admin account percentage is reasonable
- Checks for Privileged Identity Management (PIM) usage

**Evidence Collected:**
- Count of privileged role members by role
- Percentage of privileged accounts
- PIM configuration status

**Compliance Criteria:**
- Privileged accounts less than 5% of total users
- PIM implemented for just-in-time access (recommended)

---

### AC-3: Access Enforcement
**Requirement:** Enforce approved authorizations for logical access

**Assessment:**
- Reviews guest user access restrictions
- Validates external collaboration settings
- Checks guest user permissions

**Evidence Collected:**
- Guest invite policy configuration
- Guest user permission settings
- Total guest user count

**Compliance Criteria:**
- Guest invites restricted to specific roles
- Guest users cannot create security groups

---

### AC-12: Session Termination
**Requirement:** Automatically terminate user sessions after a defined period of inactivity

**Assessment:**
- Checks Conditional Access session controls
- Validates sign-in frequency settings
- Reviews persistent browser policies

**Evidence Collected:**
- Session control policies
- Sign-in frequency configurations
- Persistent browser settings

**Compliance Criteria:**
- Session timeout policies configured
- Sign-in frequency enforced

---

### AU-2: Audit Events
**Requirement:** Identify the types of events the system is capable of logging

**Assessment:**
- Validates audit logging is enabled and active
- Checks directory audit logs
- Reviews sign-in logging

**Evidence Collected:**
- Recent audit event counts
- Latest audit activity details
- Sign-in log availability

**Compliance Criteria:**
- Audit logging active with recent events
- Sign-in logs available and populated

---

### SI-4: Information System Monitoring
**Requirement:** Monitor the information system to detect attacks and indicators of potential attacks

**Assessment:**
- Reviews sign-in log monitoring
- Analyzes failed sign-in attempts
- Checks for suspicious activity patterns

**Evidence Collected:**
- Recent sign-in event counts
- Failed sign-in statistics
- Top sign-in locations
- Activity patterns

**Compliance Criteria:**
- Sign-in monitoring active
- Recent monitoring data available

---

### SC-13: Cryptographic Protection
**Requirement:** Implement cryptographic mechanisms to prevent unauthorized disclosure

**Assessment:**
- Validates Microsoft 365 encryption at rest
- Confirms TLS encryption in transit
- Reviews organizational encryption settings

**Evidence Collected:**
- Encryption at rest status (enabled by default)
- Encryption in transit enforcement (TLS 1.2+)
- Organization verification status

**Compliance Criteria:**
- Data encrypted at rest (M365 default)
- Data encrypted in transit (M365 default)

---

### IR-4: Incident Handling
**Requirement:** Implement incident handling capability for security incidents

**Assessment:**
- Checks for security alert configuration
- Reviews automated response policies
- Validates incident detection capabilities

**Evidence Collected:**
- Security alert counts and status
- Automated blocking policies
- Incident response policy configuration

**Compliance Criteria:**
- Security alerting configured and active
- Automated response policies implemented

---

## Installation and Setup

### Prerequisites

1. **PowerShell 7.0 or later** (recommended) or Windows PowerShell 5.1
2. **Microsoft.Graph modules** installed:

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
Install-Module Microsoft.Graph.Identity.DirectoryManagement -Scope CurrentUser
Install-Module Microsoft.Graph.Identity.SignIns -Scope CurrentUser
Install-Module Microsoft.Graph.Users -Scope CurrentUser
Install-Module Microsoft.Graph.Groups -Scope CurrentUser
Install-Module Microsoft.Graph.Security -Scope CurrentUser
```

### Required Permissions

For certificate-based authentication (recommended for automation), create an Azure AD App Registration with the following Microsoft Graph API permissions:

**Application Permissions:**
- `Directory.Read.All` - Read directory data
- `Policy.Read.All` - Read organization policies
- `UserAuthenticationMethod.Read.All` - Read user authentication methods
- `AuditLog.Read.All` - Read audit logs
- `SecurityEvents.Read.All` - Read security events
- `Organization.Read.All` - Read organization information

**Note:** All permissions require admin consent.

### Setting Up Certificate-Based Authentication

1. **Create a self-signed certificate:**

```powershell
$cert = New-SelfSignedCertificate -Subject "CN=CMMC-Assessment" `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -KeyExportPolicy Exportable `
    -KeySpec Signature `
    -KeyLength 2048 `
    -KeyAlgorithm RSA `
    -HashAlgorithm SHA256 `
    -NotAfter (Get-Date).AddYears(2)

# Note the thumbprint
$cert.Thumbprint
```

2. **Export the certificate:**

```powershell
Export-Certificate -Cert $cert -FilePath "C:\Temp\CMMC-Assessment.cer"
```

3. **Upload to Azure AD App Registration:**
   - Navigate to Azure Portal > Azure Active Directory > App Registrations
   - Select your app > Certificates & secrets
   - Upload the .cer file

4. **Note your App Registration details:**
   - Tenant ID
   - Application (Client) ID
   - Certificate Thumbprint

## Usage Examples

### Basic Assessment (Interactive)

```powershell
.\Invoke-CMMCAssessment.ps1 -UseInteractiveAuth
```

This will:
- Prompt for interactive sign-in
- Connect to the default (Commercial) tenant
- Run all compliance checks
- Generate reports in `C:\temp\cmmc-reports\`

### Assessment with Certificate Authentication

```powershell
.\Invoke-CMMCAssessment.ps1 `
    -TenantId "12345678-1234-1234-1234-123456789012" `
    -ClientId "87654321-4321-4321-4321-210987654321" `
    -CertificateThumbprint "A1B2C3D4E5F6..."
```

### GCC or GCC High Tenant Assessment

```powershell
# GCC Tenant
.\Invoke-CMMCAssessment.ps1 -UseInteractiveAuth -TenantType "GCC"

# GCC High Tenant
.\Invoke-CMMCAssessment.ps1 -UseInteractiveAuth -TenantType "GCCHigh"
```

### Custom Output Location

```powershell
.\Invoke-CMMCAssessment.ps1 `
    -UseInteractiveAuth `
    -OutputPath "D:\ComplianceReports\CMMC-$(Get-Date -Format 'yyyyMMdd')"
```

### Automated Assessment (Azure Automation)

Create an Azure Automation Runbook with the following configuration:

1. Upload the script to the Automation Account
2. Install required modules in the Automation Account
3. Create a certificate credential
4. Schedule the runbook with parameters:

```powershell
param(
    [string]$TenantId = Get-AutomationVariable -Name 'TenantId',
    [string]$ClientId = Get-AutomationVariable -Name 'ClientId',
    [string]$CertificateThumbprint = Get-AutomationVariable -Name 'CertThumbprint'
)

.\Invoke-CMMCAssessment.ps1 -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint
```

## Output Files

The tool generates two primary output files:

### 1. HTML Report (`CMMC_Assessment_Report_YYYYMMDD_HHMMSS.html`)

A comprehensive, visually appealing HTML report containing:

- **Executive Summary**
  - Total controls assessed
  - Compliant vs. non-compliant counts
  - Overall compliance percentage
  - Visual compliance bar
  - Non-compliant items by severity

- **Tenant Information**
  - Organization name
  - Tenant ID
  - Assessment date
  - Verified domains

- **Detailed Assessment Results**
  - Individual control cards for each assessed requirement
  - Control ID, name, and family
  - Compliance status (Compliant/Non-Compliant)
  - Severity level (Critical/High/Medium/Low)
  - Detailed findings
  - Evidence collected

The HTML report automatically opens in your default browser on Windows systems.

### 2. JSON Evidence File (`CMMC_Evidence_YYYYMMDD_HHMMSS.json`)

A structured JSON file containing all assessment data:

```json
{
  "TenantInfo": {
    "DisplayName": "Contoso Corporation",
    "TenantId": "12345678-1234-1234-1234-123456789012",
    "AssessmentDate": "2025-10-25T10:30:00Z",
    "VerifiedDomains": "contoso.com, contoso.onmicrosoft.com"
  },
  "AssessmentResults": [
    {
      "ControlId": "IA-2",
      "ControlName": "Identification and Authentication",
      "Compliant": true,
      "Findings": [...],
      "Evidence": [...]
    }
  ]
}
```

This file can be used for:
- Audit evidence submission
- Compliance tracking over time
- Integration with other tools
- Historical comparisons

## Understanding the Report

### Compliance Status

- **COMPLIANT** (Green) - The control meets NIST 800-171 R3 requirements
- **NON-COMPLIANT** (Red) - The control does not meet requirements and needs remediation

### Severity Levels

- **Critical** - Must be addressed immediately; poses significant security risk
- **High** - Should be addressed urgently; poses substantial risk
- **Medium** - Should be addressed in normal course; moderate risk
- **Low** - Should be addressed when convenient; minimal risk

### Interpreting Findings

Each control includes:
- **Description** - What the control requires
- **Findings** - What was discovered during assessment
- **Evidence** - Specific data points collected to support the finding

## Remediation Guidance

### Non-Compliant MFA (IA-2)

**Issue:** MFA not enforced or not all users registered

**Remediation:**
1. Create Conditional Access policy requiring MFA for all users
2. Enable user MFA registration campaign
3. Monitor MFA registration rates
4. Consider using Security Defaults for basic protection

### Non-Compliant Password Policy (IA-5)

**Issue:** Password expiration exceeds 60 days

**Remediation:**
1. Navigate to Azure AD > Password Protection
2. Set password expiration to 60 days or less
3. Consider implementing banned password lists
4. Enable Azure AD Password Protection

### No Session Timeout (AC-12)

**Issue:** User sessions do not automatically timeout

**Remediation:**
1. Create Conditional Access policy with session controls
2. Set sign-in frequency to appropriate value (e.g., 8 hours)
3. Configure persistent browser settings appropriately
4. Test policies with pilot group before full deployment

### High Privileged Account Count (AC-2)

**Issue:** Too many users with admin privileges

**Remediation:**
1. Review and remove unnecessary admin role assignments
2. Implement Privileged Identity Management (PIM)
3. Use just-in-time admin access
4. Create dedicated admin accounts (separate from regular accounts)
5. Regularly audit privileged access

## Limitations and Considerations

### Current Limitations

1. **Scope of Controls** - This tool assesses 10 key controls from NIST 800-171 R3. Full CMMC compliance requires assessment of all 110+ requirements.

2. **Microsoft 365 Focus** - The tool only assesses M365 configurations. CMMC also requires assessment of:
   - Physical security controls
   - Personnel security
   - System and network security beyond M365
   - Documentation and procedures

3. **Point-in-Time Assessment** - The assessment reflects configuration at the time of execution. Continuous monitoring is recommended.

4. **Automated Interpretation** - While the tool provides compliance status, human review and interpretation is necessary for complete assessment.

### Best Practices

1. **Run Regular Assessments** - Schedule monthly or quarterly assessments to track compliance over time

2. **Remediate Systematically** - Address Critical and High severity items first

3. **Document Exceptions** - If a control cannot be implemented, document the compensating controls

4. **Maintain Evidence** - Keep all assessment reports and evidence for audit purposes

5. **Combine with Manual Review** - Use this tool as part of a comprehensive compliance program, not as a replacement for professional assessment

## Extending the Tool

The tool is designed to be extensible. To add new controls:

1. **Create a new test function:**

```powershell
function Test-NewControl {
    <#
    .SYNOPSIS
        Tests [Control Name] (XX-##: Control Title)
    #>
    
    try {
        Write-Log "Checking [control description]..." -Level "Info"
        
        $compliant = $false
        $findings = @()
        $evidence = @()
        
        # Add your assessment logic here
        
        Add-ComplianceResult -ControlId "XX-##" `
            -ControlName "Control Name" `
            -ControlFamily "XX" `
            -Description "Control description" `
            -Compliant $compliant `
            -Findings $findings `
            -Evidence $evidence `
            -Severity "High"
        
        return $compliant
    }
    catch {
        Write-Log "Error checking control: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}
```

2. **Call the function in the Invoke-Assessment function:**

```powershell
# Run compliance checks
Test-NewControl
```

## Troubleshooting

### Issue: "Failed to connect to Microsoft Graph"

**Solution:**
- Verify tenant ID, client ID, and certificate thumbprint are correct
- Ensure certificate is installed in the correct certificate store
- Check that the Azure AD app has required API permissions
- Verify admin consent has been granted

### Issue: "Permission denied" errors during assessment

**Solution:**
- Review Azure AD app permissions
- Ensure all required permissions are granted
- Verify admin consent is applied
- Check user permissions if using interactive authentication

### Issue: "No recent audit events found"

**Solution:**
- Audit logging may take up to 24 hours to populate
- Verify Azure AD Premium P1 or P2 license (required for some audit logs)
- Check that audit logging is not disabled
- Ensure sufficient permissions to read audit logs

### Issue: HTML report not opening automatically

**Solution:**
- Check the output path for the generated file
- Manually open the HTML file from the output directory
- Verify default browser is configured correctly
- On non-Windows systems, manually open the file

## Support and Contributing

For issues, suggestions, or contributions:
1. Review existing scripts and patterns in the repository
2. Follow PowerShell best practices
3. Test thoroughly before submitting
4. Document all changes

## Compliance Disclaimer

This tool is provided as-is to assist with CMMC compliance preparation. It does not:
- Guarantee CMMC certification
- Replace official CMMC assessment
- Cover all NIST 800-171 R3 requirements
- Constitute legal or compliance advice

Organizations should:
- Engage qualified CMMC assessors for official certification
- Implement comprehensive compliance programs
- Consult with compliance professionals
- Maintain ongoing compliance monitoring

## Version History

- **v1.0.0** (2025-10-25)
  - Initial release
  - 10 key NIST 800-171 R3 controls
  - HTML report generation
  - JSON evidence export
  - Support for Commercial, GCC, and GCC High tenants
  - Certificate-based and interactive authentication

## References

- [NIST SP 800-171 Revision 3](https://csrc.nist.gov/publications/detail/sp/800-171/rev-3/final)
- [CMMC Model Overview](https://www.acq.osd.mil/cmmc/)
- [Microsoft Graph API Documentation](https://learn.microsoft.com/en-us/graph/)
- [Azure AD Conditional Access](https://learn.microsoft.com/en-us/azure/active-directory/conditional-access/)
