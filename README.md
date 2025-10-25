# :office: Microsoft 365 PowerShell Scripts

A curated collection of PowerShell scripts for managing and automating Microsoft 365 environments. Built with love and modules like:

- 🔗 Microsoft Graph
- 📧 Exchange Online
-  :speech_balloon: Microsoft Teams
- 👥 MSOnline & EntraID
- 🛡️ Security & Compliance
- 📁 SharePoint Online

## 🚀 Purpose

Streamline admin workflows, automate repetitive tasks, and gain deeper insights into a Microsoft 365 tenant.

## 🛠 Requirements

Make sure you have the necessary modules installed:

```powershell
Install-Module Microsoft.Graph
Install-Module ExchangeOnlineManagemen
Install-Module PnP.PowerShell
Install-Module Microsoft.Online.SharePoint.PowerShell
```

## 📋 Scripts

### 🛡️ Invoke-CMMCAssessment.ps1
**CMMC Compliance Assessment Tool** - Assesses Microsoft 365 tenants (Commercial, GCC, or GCC High) against NIST 800-171 R3 requirements to support CMMC compliance. Generates comprehensive HTML reports with compliance status and evidence collection.

**Features:**
- Assesses M365 tenant against NIST 800-171 R3 requirements
- Supports Commercial, GCC, and GCC High tenants
- Certificate-based or interactive authentication
- Comprehensive HTML report with compliance status
- Automated evidence collection for each requirement
- Evaluates key controls across multiple NIST families (AC, IA, AU, SC, IR, SI)
- JSON export of all evidence for audit purposes
- Color-coded compliance dashboard

**Key Controls Assessed:**
- Multi-Factor Authentication (MFA) enforcement
- Password policies and authenticator management
- Account lockout and unsuccessful logon attempts
- Privileged account management
- Guest access restrictions
- Session timeout configuration
- Audit logging and monitoring
- Data encryption
- Incident response capabilities
- System monitoring

**Usage:**
```powershell
# Interactive authentication (recommended for first-time use)
.\Invoke-CMMCAssessment.ps1 -UseInteractiveAuth

# Certificate-based authentication (for automation)
.\Invoke-CMMCAssessment.ps1 -TenantId "your-tenant-id" -ClientId "your-app-id" -CertificateThumbprint "cert-thumbprint"

# GCC or GCC High tenant assessment
.\Invoke-CMMCAssessment.ps1 -UseInteractiveAuth -TenantType "GCC"

# Custom output location
.\Invoke-CMMCAssessment.ps1 -UseInteractiveAuth -OutputPath "D:\ComplianceReports"
```

**Required Permissions:**
- Directory.Read.All
- Policy.Read.All
- UserAuthenticationMethod.Read.All
- AuditLog.Read.All
- SecurityEvents.Read.All
- Organization.Read.All

**Output:**
- HTML report with visual compliance dashboard
- JSON file with detailed evidence for each requirement
- Automated evidence collection for CMMC audits

### 🔒 lock-inactive-accounts.ps1
Automatically locks user accounts that have been inactive for 90+ days using Microsoft Graph. Designed for Azure Automation runbooks with certificate-based authentication.

**Features:**
- Certificate-based authentication for unattended execution
- Configurable inactivity threshold (default: 90 days) 
- Hardcoded account exclusions for service accounts
- Professional HTML email reporting
- Preview mode with -WhatIf parameter
- Compatible with Azure Automation runbooks

**Usage:**
```powershell
# Basic usage
.\lock-inactive-accounts.ps1 -TenantId "your-tenant-id" -ClientId "your-app-id" -CertificateThumbprint "cert-thumbprint"

# With email notification
.\lock-inactive-accounts.ps1 -TenantId "your-tenant-id" -ClientId "your-app-id" -CertificateThumbprint "cert-thumbprint" -SendEmail -EmailTo "admin@contoso.com" -EmailFrom "automation@contoso.com"
```
