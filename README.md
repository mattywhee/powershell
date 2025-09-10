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
