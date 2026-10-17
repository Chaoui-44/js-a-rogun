#!/usr/bin/env bash
# Déploiement complet en une commande : site (Pages) + proxy (Worker) + secrets.
# Usage : npm install && npm run deploy
# Variables facultatives : ANTHROPIC_API_KEY, APP_TOKEN, PROJECT (défaut visite-energie)
set -euo pipefail
cd "$(dirname "$0")/.."
PROJECT="${PROJECT:-visite-energie}"
W="npx wrangler"

echo "▶ Connexion Cloudflare…"
$W whoami >/dev/null 2>&1 || $W login

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then read -r -s -p "Clé API Anthropic (sk-ant-…) : " ANTHROPIC_API_KEY; echo; fi
if [ -z "${APP_TOKEN:-}" ]; then APP_TOKEN="$(openssl rand -hex 16)"; echo "Jeton d'accès généré."; fi

echo "▶ Site (Cloudflare Pages)…"
$W pages project create "$PROJECT" --production-branch main >/dev/null 2>&1 || true
SITE_OUT="$($W pages deploy app --project-name "$PROJECT" --branch main 2>&1 | tee /dev/stderr)"
SITE_URL="https://${PROJECT}.pages.dev"

echo "▶ Proxy (Worker)…"
printf '%s' "$ANTHROPIC_API_KEY" | $W secret put ANTHROPIC_API_KEY --config worker/wrangler.toml
printf '%s' "$APP_TOKEN"        | $W secret put APP_TOKEN --config worker/wrangler.toml
WORKER_OUT="$($W deploy --config worker/wrangler.toml --var "ALLOWED_ORIGIN:${SITE_URL}" 2>&1 | tee /dev/stderr)"
WORKER_URL="$(echo "$WORKER_OUT" | grep -Eo 'https://[A-Za-z0-9.-]+\.workers\.dev' | head -1)"

echo
echo "✅ Terminé."
echo "Site   : $SITE_URL"
echo "Proxy  : $WORKER_URL"
echo
echo "Ouvrez CE LIEN sur votre téléphone : l'appli se configure toute seule (puis Installer sur l'écran d'accueil) :"
echo "${SITE_URL}/#/setup?w=${WORKER_URL}&t=${APP_TOKEN}"
echo
echo "Gardez ce jeton : $APP_TOKEN"
