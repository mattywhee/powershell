# Playwright Screenshot Tool - Quick Start Guide

## Installation

1. Clone the repository and navigate to the project directory
2. Install dependencies:
   ```bash
   npm install
   ```

## Quick Test

Run the built-in test to verify everything is working:

```bash
npm test
```

This will:
- Generate a sample HTML compliance report
- Capture a full-page screenshot
- Save the screenshot to `./screenshots/`

## Common Use Cases

### 1. Preview a Single Report

```bash
node screenshot-report.js --input path/to/report.html
```

### 2. Process Multiple Reports

```bash
node screenshot-report.js --input ./reports --output ./screenshots
```

### 3. Custom Output Directory

```bash
node screenshot-report.js --test --output ./my-screenshots
```

### 4. Integration with PowerShell Scripts

When your PowerShell script generates an HTML report, save it to a file:

```powershell
# In your PowerShell script
$htmlContent | Out-File -FilePath "C:\Reports\compliance-report.html" -Encoding UTF8
```

Then capture the screenshot:

```bash
node screenshot-report.js --input "C:\Reports\compliance-report.html"
```

## Output Examples

The tool generates high-quality PNG screenshots that capture:
- Complete report layout and styling
- All tables and data
- Headers, summaries, and footers
- Color-coded sections (success, warning, error)

## Tips

1. **Batch Processing**: Place all your HTML reports in one directory and process them all at once
2. **Automation**: Integrate into your CI/CD pipeline for automated report generation
3. **Sharing**: Screenshots are perfect for sharing with stakeholders who don't have access to the HTML files
4. **Documentation**: Build a library of report examples for training and reference

## Need Help?

```bash
node screenshot-report.js --help
```

Or see the full documentation in `SCREENSHOT-TOOL-DOCS.md`
