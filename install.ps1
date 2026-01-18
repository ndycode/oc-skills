$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$OpenCodeDir = Join-Path $env:USERPROFILE ".config\opencode"
$CodexDir = Join-Path $env:USERPROFILE ".codex\skills"

Write-Host "OC Skills Installer" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan
Write-Host ""

$SkillDir = Join-Path $OpenCodeDir "skill"
$CommandDir = Join-Path $OpenCodeDir "command"

if (-not (Test-Path $SkillDir)) { New-Item -ItemType Directory -Path $SkillDir -Force | Out-Null }
if (-not (Test-Path $CommandDir)) { New-Item -ItemType Directory -Path $CommandDir -Force | Out-Null }
if (-not (Test-Path $CodexDir)) { New-Item -ItemType Directory -Path $CodexDir -Force | Out-Null }

Write-Host "Installing OpenCode skills..." -ForegroundColor Yellow
$SourceSkillDir = Join-Path $ScriptDir "skill"
if (Test-Path $SourceSkillDir) {
    $skills = Get-ChildItem -Path $SourceSkillDir -Directory
    foreach ($skill in $skills) {
        $destPath = Join-Path $SkillDir $skill.Name
        if (Test-Path $destPath) { Remove-Item -Path $destPath -Recurse -Force }
        Copy-Item -Path $skill.FullName -Destination $destPath -Recurse -Force
    }
    Write-Host "  Installed $($skills.Count) OpenCode skills" -ForegroundColor Green
} else {
    Write-Host "  No OpenCode skills directory found" -ForegroundColor Red
}

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

Write-Host "Installing Codex skills..." -ForegroundColor Yellow
$SourceCodexDir = Join-Path $ScriptDir "codex-skill"
if (Test-Path $SourceCodexDir) {
    $codexSkills = Get-ChildItem -Path $SourceCodexDir -Directory
    foreach ($skill in $codexSkills) {
        $destPath = Join-Path $CodexDir $skill.Name
        if (Test-Path $destPath) { Remove-Item -Path $destPath -Recurse -Force }
        Copy-Item -Path $skill.FullName -Destination $destPath -Recurse -Force
    }
    Write-Host "  Installed $($codexSkills.Count) Codex skills" -ForegroundColor Green
} else {
    Write-Host "  No Codex skills directory found" -ForegroundColor Red
}

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host "OpenCode skills: $SkillDir" -ForegroundColor Cyan
Write-Host "OpenCode commands: $CommandDir" -ForegroundColor Cyan
Write-Host "Codex skills: $CodexDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "Restart OpenCode/Codex to use the new skills." -ForegroundColor Yellow
