# Déploiement complet sous Windows PowerShell : site (Pages) + proxy (Worker) + secrets.
# Usage : npm install ; npm run deploy:win
# Variables facultatives : ANTHROPIC_API_KEY, APP_TOKEN, PROJECT (défaut visite-energie)
$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..')
$Project = if ($env:PROJECT) { $env:PROJECT } else { 'visite-energie' }

function Fail($msg) { Write-Host "ERREUR : $msg" -ForegroundColor Red; exit 1 }
function Wr {
  # Lance wrangler, affiche la sortie, la renvoie sous forme de texte
  $out = (& npx.cmd wrangler @args 2>&1 | ForEach-Object { "$_" }) -join "`n"
  Write-Host $out
  $script:code = $LASTEXITCODE
  return $out
}

Write-Host '> Connexion Cloudflare...'
$null = & npx.cmd wrangler whoami 2>&1
if ($LASTEXITCODE -ne 0 -and -not $env:CLOUDFLARE_API_TOKEN) {
  & npx.cmd wrangler login
  $null = & npx.cmd wrangler whoami 2>&1
  if ($LASTEXITCODE -ne 0) { Fail "connexion Cloudflare impossible. Lancez d'abord 'npx wrangler login' a la main, ou definissez CLOUDFLARE_API_TOKEN." }
}

$key = $env:ANTHROPIC_API_KEY
if (-not $key) {
  $sec = Read-Host 'Cle API Anthropic (sk-ant-...)' -AsSecureString
  $key = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
}
$key = $key.Trim()
if (-not $key) { Fail 'cle API vide' }

$token = $env:APP_TOKEN
if (-not $token) {
  $b = New-Object byte[] 16
  [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b)
  $token = -join ($b | ForEach-Object { '{0:x2}' -f $_ })
  Write-Host "Jeton d'acces genere."
}

Write-Host '> Projet Cloudflare Pages...'
$null = Wr pages project create $Project --production-branch main
$siteUrl = "https://$Project.pages.dev"

Write-Host '> Secrets (cle Anthropic + jeton)...'
$key   | & npx.cmd wrangler pages secret put ANTHROPIC_API_KEY --project-name $Project
if ($LASTEXITCODE -ne 0) { Fail 'secret ANTHROPIC_API_KEY non enregistre' }
$token | & npx.cmd wrangler pages secret put APP_TOKEN --project-name $Project
if ($LASTEXITCODE -ne 0) { Fail 'secret APP_TOKEN non enregistre' }

Write-Host '> Publication du site + proxy...'
$out = Wr pages deploy app --project-name $Project --branch main
if ($script:code -ne 0) { Fail 'deploiement echoue' }
$m = [regex]::Match($out, 'https://[A-Za-z0-9.-]+\.pages\.dev')
if ($m.Success) { $siteUrl = $m.Value }

Write-Host ''
Write-Host 'TERMINE.' -ForegroundColor Green
Write-Host "Site : $siteUrl"
Write-Host ''
Write-Host "Ouvrez CE LIEN sur votre telephone (l'appli se configure toute seule), puis 'Installer' :"
Write-Host "$siteUrl/#/setup?t=$token" -ForegroundColor Yellow
Write-Host ''
Write-Host "Gardez ce jeton : $token"
