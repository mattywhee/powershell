# Quick Start Guide - CMMC Assessment Tool

## 5-Minute Setup

### Step 1: Install Required Modules

Open PowerShell as Administrator and run:

```powershell
# Install Microsoft Graph modules
Install-Module Microsoft.Graph.Authentication -Force -AllowClobber
Install-Module Microsoft.Graph.Identity.DirectoryManagement -Force -AllowClobber
Install-Module Microsoft.Graph.Identity.SignIns -Force -AllowClobber
Install-Module Microsoft.Graph.Users -Force -AllowClobber
Install-Module Microsoft.Graph.Groups -Force -AllowClobber
Install-Module Microsoft.Graph.Security -Force -AllowClobber
```

### Step 2: Run Your First Assessment

```powershell
# Navigate to the script directory
cd C:\path\to\scripts

# Run with interactive authentication (easiest way to start)
.\Invoke-CMMCAssessment.ps1 -UseInteractiveAuth
```

### Step 3: Review Your Report

The tool will:
1. Open a browser window for authentication
2. Collect compliance data from your M365 tenant
3. Generate an HTML report
4. Automatically open the report in your browser

That's it! You now have a CMMC compliance assessment report.

---

## Common Use Cases

### Use Case 1: Monthly Compliance Check

```powershell
# Create a scheduled task or add to Azure Automation
.\Invoke-CMMCAssessment.ps1 `
    -UseInteractiveAuth `
    -OutputPath "C:\ComplianceReports\$(Get-Date -Format 'yyyy-MM')"
```

### Use Case 2: Pre-Audit Assessment

```powershell
# Run before CMMC audit to identify gaps
.\Invoke-CMMCAssessment.ps1 -UseInteractiveAuth

# Review the HTML report for any non-compliant items
# Focus on Critical and High severity findings
```

### Use Case 3: GCC High Tenant

```powershell
# For GCC High tenants, specify the tenant type
.\Invoke-CMMCAssessment.ps1 -UseInteractiveAuth -TenantType "GCCHigh"
```

### Use Case 4: Automated Reporting

```powershell
# Set up certificate authentication for automation
.\Invoke-CMMCAssessment.ps1 `
    -TenantId "your-tenant-id" `
    -ClientId "your-app-id" `
    -CertificateThumbprint "your-cert-thumbprint" `
    -OutputPath "\\SharedDrive\ComplianceReports"
```

---

## Understanding Your Results

### 🟢 Green (Compliant)
Your configuration meets the NIST 800-171 requirement. Well done!

### 🔴 Red (Non-Compliant)  
This control needs attention. Check the findings for specific remediation steps.

### Severity Levels
- **Critical**: Fix immediately - significant security risk
- **High**: Fix soon - substantial risk
- **Medium**: Fix in normal course - moderate risk
- **Low**: Fix when convenient - minimal risk

---

## Quick Remediation Checklist

If your report shows non-compliant items, here's a priority checklist:

### Priority 1 - Critical Items

- [ ] **Enable MFA for all users**
  - Go to Azure AD > Security > Conditional Access
  - Create policy requiring MFA for all users
  
- [ ] **Review privileged accounts**
  - Azure AD > Roles and administrators
  - Remove unnecessary admin role assignments
  - Implement PIM (Privileged Identity Management)

- [ ] **Enable audit logging**
  - Verify Azure AD Premium licensing
  - Check Azure AD > Audit logs for recent activity

### Priority 2 - High Items

- [ ] **Configure password policies**
  - Azure AD > Security > Password Protection
  - Set password expiration to 60 days or less

- [ ] **Set up account lockout**
  - Azure AD > Security > Conditional Access
  - Create risk-based policies

- [ ] **Configure session timeouts**
  - Conditional Access > Session controls
  - Set sign-in frequency (e.g., 8 hours)

### Priority 3 - Medium/Low Items

- [ ] **Restrict guest access**
  - Azure AD > External Identities > External collaboration settings
  - Limit who can invite guests

- [ ] **Review monitoring and alerts**
  - Microsoft 365 Defender
  - Configure security alerts

---

## Troubleshooting

### "Cannot connect to Microsoft Graph"

Try:
```powershell
# Clear any existing connections
Disconnect-MgGraph

# Reconnect
Connect-MgGraph -Scopes "Directory.Read.All","Policy.Read.All"

# Verify connection
Get-MgContext
```

### "Permission denied" errors

You need:
- Global Reader role (minimum), or
- Security Reader role, or
- Global Administrator role

### "Module not found" errors

Run as Administrator:
```powershell
# List installed modules
Get-InstalledModule Microsoft.Graph*

# Reinstall if needed
Install-Module Microsoft.Graph -Force
```

---

## Next Steps

1. **Review Full Documentation**: See `CMMC-Assessment-Guide.md` for detailed information
2. **Schedule Regular Assessments**: Monthly checks help maintain compliance
3. **Track Progress**: Compare reports over time to measure improvement
4. **Engage Professionals**: Use this tool to prepare for official CMMC assessment

---

## Sample Output Structure

```
C:\temp\cmmc-reports\
├── CMMC_Assessment_Report_20251025_103045.html  ← Main report
├── CMMC_Evidence_20251025_103045.json           ← Evidence for auditors
└── [Previous reports...]
```

---

## Need Help?

- Full documentation: `CMMC-Assessment-Guide.md`
- Script comments: Review `Invoke-CMMCAssessment.ps1` inline documentation
- Microsoft Graph docs: https://learn.microsoft.com/graph/
- CMMC resources: https://www.acq.osd.mil/cmmc/

---

**Remember**: This tool helps identify compliance gaps but doesn't replace official CMMC assessment. Always engage qualified assessors for certification.
