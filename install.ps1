# OpenCode Skills Installer for Windows

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigDir = Join-Path $env:USERPROFILE ".config\opencode"

Write-Host "OpenCode Skills Installer" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan
Write-Host ""

# Create config directories if they don't exist
$SkillDir = Join-Path $ConfigDir "skill"
$CommandDir = Join-Path $ConfigDir "command"

if (-not (Test-Path $SkillDir)) {
    New-Item -ItemType Directory -Path $SkillDir -Force | Out-Null
}
if (-not (Test-Path $CommandDir)) {
    New-Item -ItemType Directory -Path $CommandDir -Force | Out-Null
}

# Copy skills
Write-Host "Installing skills..." -ForegroundColor Yellow
$SourceSkillDir = Join-Path $ScriptDir "skill"
if (Test-Path $SourceSkillDir) {
    $skills = Get-ChildItem -Path $SourceSkillDir -Directory
    foreach ($skill in $skills) {
        $destPath = Join-Path $SkillDir $skill.Name
        if (Test-Path $destPath) {
            Remove-Item -Path $destPath -Recurse -Force
        }
        Copy-Item -Path $skill.FullName -Destination $destPath -Recurse -Force
    }
    Write-Host "  Installed $($skills.Count) skills" -ForegroundColor Green
} else {
    Write-Host "  No skills directory found" -ForegroundColor Red
}

# Copy commands
Write-Host "Installing slash commands..." -ForegroundColor Yellow
$SourceCommandDir = Join-Path $ScriptDir "command"
if (Test-Path $SourceCommandDir) {
    $commands = Get-ChildItem -Path $SourceCommandDir -File -Filter "*.md"
    foreach ($cmd in $commands) {
        Copy-Item -Path $cmd.FullName -Destination $CommandDir -Force
    }
    Write-Host "  Installed $($commands.Count) commands" -ForegroundColor Green
} else {
    Write-Host "  No command directory found" -ForegroundColor Red
}

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host "Skills installed to: $SkillDir" -ForegroundColor Cyan
Write-Host "Commands installed to: $CommandDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "Restart OpenCode to use the new skills." -ForegroundColor Yellow
