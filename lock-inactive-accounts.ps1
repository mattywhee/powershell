<#

Title: Lock Inactive User Accounts After 90 Days
Purpose: This script automatically locks user accounts that have been inactive for 90+ days using Microsoft Graph
Author: PowerShell Automation
Date: 12/10/2024

# Basic usage with certificate authentication
.\Lock-InactiveAccounts.ps1 -TenantId "your-tenant-id" -ClientId "your-app-id" -CertificateThumbprint "cert-thumbprint"

# Custom inactivity period and excluded accounts
.\Lock-InactiveAccounts.ps1 -TenantId "your-tenant-id" -ClientId "your-app-id" -CertificateThumbprint "cert-thumbprint" -InactiveDays 60 -ExcludedAccounts @("admin@contoso.com", "service@contoso.com")

# Include email notification
.\Lock-InactiveAccounts.ps1 -TenantId "your-tenant-id" -ClientId "your-app-id" -CertificateThumbprint "cert-thumbprint" -SendEmail -EmailTo "admin@contoso.com" -EmailFrom "automation@contoso.com"

# Preview mode (don't actually lock accounts)
.\Lock-InactiveAccounts.ps1 -TenantId "your-tenant-id" -ClientId "your-app-id" -CertificateThumbprint "cert-thumbprint" -WhatIf

# Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Users, Microsoft.Graph.Mail

#>

param(
    [Parameter(Mandatory=$true)]
    [string]$TenantId,
    
    [Parameter(Mandatory=$true)]
    [string]$ClientId,
    
    [Parameter(Mandatory=$true)]
    [string]$CertificateThumbprint,
    
    [Parameter(Mandatory=$false)]
    [int]$InactiveDays = 90,
    
    [Parameter(Mandatory=$false)]
    [string[]]$ExcludedAccounts = @(
        "admin@contoso.com",
        "serviceaccount@contoso.com",
        "breakglass@contoso.com",
        "automation@contoso.com"
    ),
    
    [Parameter(Mandatory=$false)]
    [switch]$SendEmail = $false,
    
    [Parameter(Mandatory=$false)]
    [string]$EmailTo = "",
    
    [Parameter(Mandatory=$false)]
    [string]$EmailFrom = "",
    
    [Parameter(Mandatory=$false)]
    [string]$EmailSubject = "Daily Inactive Account Lock Report",
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf = $false
)

# Function to connect to Microsoft Graph using certificate authentication
function Connect-GraphWithCertificate {
    param(
        [string]$TenantId,
        [string]$ClientId,
        [string]$CertificateThumbprint
    )
    
    try {
        Write-Host "Connecting to Microsoft Graph using certificate authentication..." -ForegroundColor Green
        
        Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome
        
        $context = Get-MgContext
        Write-Host "Successfully connected to tenant: $($context.TenantId)" -ForegroundColor Green
        Write-Host "Connected as app: $($context.AppName)" -ForegroundColor Green
        
        return $true
    }
    catch {
        Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
        return $false
    }
}

# Function to get users inactive for specified number of days
function Get-InactiveUsers {
    param(
        [int]$InactiveDays,
        [string[]]$ExcludedAccounts
    )
    
    try {
        Write-Host "Retrieving users inactive for $InactiveDays days..." -ForegroundColor Yellow
        
        $cutoffDate = (Get-Date).AddDays(-$InactiveDays)
        $cutoffDateString = $cutoffDate.ToString("yyyy-MM-ddTHH:mm:ssZ")
        
        # Get all users with sign-in activity
        $users = Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,AccountEnabled,SignInActivity,CreatedDateTime -Filter "accountEnabled eq true"
        
        $inactiveUsers = @()
        
        foreach ($user in $users) {
            # Skip excluded accounts
            if ($ExcludedAccounts -contains $user.UserPrincipalName) {
                Write-Host "Skipping excluded account: $($user.UserPrincipalName)" -ForegroundColor Cyan
                continue
            }
            
            # Check if user has sign-in activity
            $lastSignIn = $null
            if ($user.SignInActivity -and $user.SignInActivity.LastSignInDateTime) {
                $lastSignIn = [DateTime]$user.SignInActivity.LastSignInDateTime
            }
            
            # If no sign-in activity, use account creation date
            if (-not $lastSignIn -and $user.CreatedDateTime) {
                $lastSignIn = [DateTime]$user.CreatedDateTime
            }
            
            # Check if user is inactive
            if ($lastSignIn -and $lastSignIn -lt $cutoffDate) {
                $daysSinceLastSignIn = (Get-Date) - $lastSignIn
                
                $inactiveUser = [PSCustomObject]@{
                    Id = $user.Id
                    DisplayName = $user.DisplayName
                    UserPrincipalName = $user.UserPrincipalName
                    LastSignInDate = $lastSignIn
                    DaysInactive = [math]::Round($daysSinceLastSignIn.TotalDays, 0)
                    AccountEnabled = $user.AccountEnabled
                }
                
                $inactiveUsers += $inactiveUser
                Write-Host "Found inactive user: $($user.UserPrincipalName) - Last sign-in: $lastSignIn" -ForegroundColor Red
            }
        }
        
        Write-Host "Found $($inactiveUsers.Count) inactive users" -ForegroundColor Yellow
        return $inactiveUsers
    }
    catch {
        Write-Error "Failed to retrieve inactive users: $($_.Exception.Message)"
        return @()
    }
}

# Function to block sign-in for inactive users
function Block-InactiveUsers {
    param(
        [array]$InactiveUsers,
        [switch]$WhatIf
    )
    
    $blockedUsers = @()
    $errors = @()
    
    foreach ($user in $InactiveUsers) {
        try {
            if ($WhatIf) {
                Write-Host "WHATIF: Would block sign-in for user: $($user.UserPrincipalName)" -ForegroundColor Magenta
                $blockedUsers += $user
            }
            else {
                Write-Host "Blocking sign-in for user: $($user.UserPrincipalName)" -ForegroundColor Red
                
                # Update user to disable account
                Update-MgUser -UserId $user.Id -AccountEnabled:$false
                
                $blockedUsers += $user
                Write-Host "Successfully blocked sign-in for: $($user.UserPrincipalName)" -ForegroundColor Green
            }
        }
        catch {
            $errorMsg = "Failed to block user $($user.UserPrincipalName): $($_.Exception.Message)"
            Write-Error $errorMsg
            $errors += $errorMsg
        }
    }
    
    return @{
        BlockedUsers = $blockedUsers
        Errors = $errors
    }
}

# Function to create HTML email content
function New-EmailContent {
    param(
        [array]$BlockedUsers,
        [array]$Errors,
        [int]$InactiveDays,
        [switch]$WhatIf
    )
    
    $runDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC"
    $actionText = if ($WhatIf) { "Preview Mode - No accounts were actually blocked" } else { "Production Mode - Accounts have been blocked" }
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f8f9fa; padding: 20px; border-radius: 5px; margin-bottom: 20px; }
        .summary { background-color: #e3f2fd; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .success { background-color: #e8f5e8; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .error { background-color: #ffebee; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background-color: #f2f2f2; font-weight: bold; }
        .footer { font-size: 12px; color: #666; margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; }
    </style>
</head>
<body>
    <div class="header">
        <h2>🔒 Inactive Account Lock Report</h2>
        <p><strong>Execution Date:</strong> $runDate</p>
        <p><strong>Mode:</strong> $actionText</p>
        <p><strong>Inactivity Threshold:</strong> $InactiveDays days</p>
    </div>
    
    <div class="summary">
        <h3>📊 Summary</h3>
        <ul>
            <li><strong>Accounts Processed:</strong> $($BlockedUsers.Count)</li>
            <li><strong>Errors Encountered:</strong> $($Errors.Count)</li>
        </ul>
    </div>
"@

    if ($BlockedUsers.Count -gt 0) {
        $html += @"
    <div class="success">
        <h3>✅ Blocked Accounts</h3>
        <table>
            <tr>
                <th>Display Name</th>
                <th>User Principal Name</th>
                <th>Last Sign-In Date</th>
                <th>Days Inactive</th>
            </tr>
"@
        
        foreach ($user in $BlockedUsers) {
            $lastSignInFormatted = if ($user.LastSignInDate) { $user.LastSignInDate.ToString("yyyy-MM-dd HH:mm:ss") } else { "Never" }
            $html += @"
            <tr>
                <td>$($user.DisplayName)</td>
                <td>$($user.UserPrincipalName)</td>
                <td>$lastSignInFormatted</td>
                <td>$($user.DaysInactive)</td>
            </tr>
"@
        }
        
        $html += @"
        </table>
    </div>
"@
    }
    else {
        $html += @"
    <div class="success">
        <h3>✅ No Inactive Accounts Found</h3>
        <p>No user accounts met the criteria for being locked due to inactivity.</p>
    </div>
"@
    }

    if ($Errors.Count -gt 0) {
        $html += @"
    <div class="error">
        <h3>❌ Errors</h3>
        <ul>
"@
        
        foreach ($error in $Errors) {
            $html += "<li>$error</li>"
        }
        
        $html += @"
        </ul>
    </div>
"@
    }

    $html += @"
    <div class="footer">
        <p>This report was automatically generated by the Inactive Account Lock automation script.</p>
        <p>For questions or concerns, please contact your IT administrator.</p>
    </div>
</body>
</html>
"@

    return $html
}

# Function to send email using Microsoft Graph
function Send-EmailReport {
    param(
        [string]$EmailTo,
        [string]$EmailFrom,
        [string]$Subject,
        [string]$HtmlContent
    )
    
    try {
        Write-Host "Sending email report to: $EmailTo" -ForegroundColor Yellow
        
        $message = @{
            Subject = $Subject
            Body = @{
                ContentType = "HTML"
                Content = $HtmlContent
            }
            ToRecipients = @(
                @{
                    EmailAddress = @{
                        Address = $EmailTo
                    }
                }
            )
        }
        
        # Send the email
        Send-MgUserMail -UserId $EmailFrom -Message $message
        
        Write-Host "Email report sent successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to send email report: $($_.Exception.Message)"
        return $false
    }
}

# Main execution
try {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Inactive Account Lock Script Started" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    # Connect to Microsoft Graph
    if (-not (Connect-GraphWithCertificate -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint)) {
        throw "Failed to connect to Microsoft Graph"
    }
    
    # Get inactive users
    $inactiveUsers = Get-InactiveUsers -InactiveDays $InactiveDays -ExcludedAccounts $ExcludedAccounts
    
    # Block inactive users
    $result = Block-InactiveUsers -InactiveUsers $inactiveUsers -WhatIf:$WhatIf
    
    # Generate report
    Write-Host "Generating execution report..." -ForegroundColor Yellow
    $emailContent = New-EmailContent -BlockedUsers $result.BlockedUsers -Errors $result.Errors -InactiveDays $InactiveDays -WhatIf:$WhatIf
    
    # Send email if requested
    if ($SendEmail -and $EmailTo -and $EmailFrom) {
        $emailSent = Send-EmailReport -EmailTo $EmailTo -EmailFrom $EmailFrom -Subject $EmailSubject -HtmlContent $emailContent
    }
    
    # Display summary
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Execution Summary" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Total inactive users found: $($inactiveUsers.Count)" -ForegroundColor White
    Write-Host "Users processed: $($result.BlockedUsers.Count)" -ForegroundColor White
    Write-Host "Errors encountered: $($result.Errors.Count)" -ForegroundColor White
    
    if ($WhatIf) {
        Write-Host "PREVIEW MODE: No accounts were actually blocked" -ForegroundColor Magenta
    }
    else {
        Write-Host "Accounts have been locked for sign-in" -ForegroundColor Red
    }
    
    Write-Host "Script completed successfully" -ForegroundColor Green
}
catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    exit 1
}
finally {
    # Disconnect from Graph
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue
        Write-Host "Disconnected from Microsoft Graph" -ForegroundColor Yellow
    }
    catch {
        # Ignore disconnect errors
    }
}