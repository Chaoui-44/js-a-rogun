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
if ($LASTEXITCODE -ne 0) { & npx.cmd wrangler login; if ($LASTEXITCODE -ne 0) { Fail 'connexion Cloudflare impossible' } }

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

Write-Host '> Site (Cloudflare Pages)...'
$null = Wr pages project create $Project --production-branch main
$null = Wr pages deploy app --project-name $Project --branch main
if ($script:code -ne 0) { Fail 'deploiement du site echoue' }
$siteUrl = "https://$Project.pages.dev"

Write-Host '> Proxy (Worker)...'
$key   | & npx.cmd wrangler secret put ANTHROPIC_API_KEY --config worker/wrangler.toml
if ($LASTEXITCODE -ne 0) { Fail 'secret ANTHROPIC_API_KEY non enregistre' }
$token | & npx.cmd wrangler secret put APP_TOKEN --config worker/wrangler.toml
if ($LASTEXITCODE -ne 0) { Fail 'secret APP_TOKEN non enregistre' }
$out = Wr deploy --config worker/wrangler.toml --var "ALLOWED_ORIGIN:$siteUrl"
if ($script:code -ne 0) { Fail 'deploiement du Worker echoue' }
$m = [regex]::Match($out, 'https://[A-Za-z0-9.-]+\.workers\.dev')
if (-not $m.Success) { Fail "adresse du Worker introuvable dans la sortie ci-dessus" }
$workerUrl = $m.Value

Write-Host ''
Write-Host 'TERMINE.' -ForegroundColor Green
Write-Host "Site  : $siteUrl"
Write-Host "Proxy : $workerUrl"
Write-Host ''
Write-Host "Ouvrez CE LIEN sur votre telephone (l'appli se configure toute seule), puis 'Installer' :"
Write-Host "$siteUrl/#/setup?w=$workerUrl&t=$token" -ForegroundColor Yellow
Write-Host ''
Write-Host "Gardez ce jeton : $token"
