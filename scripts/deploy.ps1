# scripts/deploy.ps1 — run from PowerShell on Windows
# Syncs source files to Lightsail and triggers the SIT-UI build.
#
# Usage:
#   .\scripts\deploy.ps1              # sync all & build
#   .\scripts\deploy.ps1 -Only frontend
#   .\scripts\deploy.ps1 -Only lms

param(
    [ValidateSet('all','frontend','lms')]
    [string]$Only = 'all'
)

$ErrorActionPreference = 'Stop'

$Key        = "C:\Users\A103605\Projects\FrappleLMS\ec2\frappe-lms-key.pem"
$RemoteHost = "ec2-user@13.213.150.153"
$RemoteDir  = "/opt/frappe-lms"
$Root       = Split-Path $PSScriptRoot -Parent   # repo root

function Log($msg)  { Write-Host "[deploy] $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "[warn]   $msg" -ForegroundColor Yellow }

$ssh = "ssh -i `"$Key`" -o StrictHostKeyChecking=no $RemoteHost"
$scp = "scp -i `"$Key`" -o StrictHostKeyChecking=no"

# ── 1. Ensure staging dir on server ───────────────────────────────────────
Log "Preparing remote staging directory..."
Invoke-Expression "$ssh `"sudo mkdir -p $RemoteDir/src && sudo chown ec2-user:ec2-user $RemoteDir/src`""

# ── 2. Upload changed directories ─────────────────────────────────────────
$syncFrontend = $Only -in @('all','frontend')
$syncLms      = $Only -in @('all','lms')

if ($syncFrontend) {
    Log "Uploading frontend/ (excluding node_modules)..."
    # Create a temp tar excluding node_modules
    $tmpTar = "$env:TEMP\lms-frontend.tar.gz"
    & tar -czf $tmpTar -C $Root `
        --exclude="frontend/node_modules" `
        --exclude="frontend/dist" `
        --exclude="frontend/.vite" `
        "frontend"
    Invoke-Expression "$scp `"$tmpTar`" ${RemoteHost}:/tmp/frontend.tar.gz"
    Invoke-Expression "$ssh `"cd $RemoteDir/src && tar xzf /tmp/frontend.tar.gz && rm /tmp/frontend.tar.gz`""
    Remove-Item $tmpTar -Force
    Log "frontend/ uploaded."
}

if ($syncLms) {
    Log "Uploading lms/..."
    $tmpTar = "$env:TEMP\lms-app.tar.gz"
    & tar -czf $tmpTar -C $Root `
        --exclude="lms/__pycache__" `
        --exclude="lms/public/dist" `
        "lms"
    Invoke-Expression "$scp `"$tmpTar`" ${RemoteHost}:/tmp/lms-app.tar.gz"
    Invoke-Expression "$ssh `"cd $RemoteDir/src && tar xzf /tmp/lms-app.tar.gz && rm /tmp/lms-app.tar.gz`""
    Remove-Item $tmpTar -Force
    Log "lms/ uploaded."
}

# ── 3. Upload and run server deploy script ────────────────────────────────
Log "Uploading server deploy script..."
Invoke-Expression "$scp `"$Root\docker\deploy.sh`" ${RemoteHost}:/tmp/deploy.sh"
Invoke-Expression "$ssh `"sudo mv /tmp/deploy.sh $RemoteDir/deploy.sh && sudo chmod +x $RemoteDir/deploy.sh`""

Log "Triggering server build..."
Invoke-Expression "$ssh `"cd $RemoteDir && sudo bash deploy.sh SIT-UI`""
