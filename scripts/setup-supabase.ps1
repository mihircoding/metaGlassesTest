# One-time NutraVision backend setup against a hosted Supabase project.
# Run from the repo root:  powershell -ExecutionPolicy Bypass -File scripts\setup-supabase.ps1
# Prompts for your database password and API keys; nothing is written to the repo.

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

function Step($text) { Write-Host "`n==> $text" -ForegroundColor Cyan }
function Sb { & npx -y supabase @args; if ($LASTEXITCODE -ne 0) { throw "supabase $($args -join ' ') failed" } }
function Plain($secure) {
    $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) }
}

Step "1/5  Log in to Supabase (a browser tab opens)"
Sb login

Step "2/5  Link this repo to your project"
Sb projects list
$ref = Read-Host "Paste the REFERENCE ID of your NutraVision project (20 letters)"
$dbPassword = Plain (Read-Host "Database password you chose when creating the project" -AsSecureString)
Sb link --project-ref $ref --password $dbPassword

Step "3/5  Create tables and security rules, then load the demo accounts"
Sb db push --include-seed --password $dbPassword

Step "4/5  API keys for the food functions"
$anthropic = Plain (Read-Host "Anthropic API key (console.anthropic.com; Enter to skip, AI photo scan won't work)" -AsSecureString)
$fdc = Plain (Read-Host "USDA FoodData Central key (api.data.gov/signup; Enter to use the rate-limited DEMO_KEY)" -AsSecureString)
if (-not $fdc) { $fdc = "DEMO_KEY" }
$secrets = @("FDC_API_KEY=$fdc")
if ($anthropic) { $secrets += "ANTHROPIC_API_KEY=$anthropic" }
Sb secrets set --project-ref $ref @secrets

Step "5/5  Deploy the food-search and analyze-food functions"
Sb functions deploy food-search analyze-food --project-ref $ref --use-api

Write-Host "`nDone. Project URL: https://$ref.supabase.co" -ForegroundColor Green
Write-Host "Tell Claude 'backend is set up' and it will connect the app."
