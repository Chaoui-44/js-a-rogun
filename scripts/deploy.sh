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

echo "▶ Projet Cloudflare Pages…"
$W pages project create "$PROJECT" --production-branch main >/dev/null 2>&1 || true
SITE_URL="https://${PROJECT}.pages.dev"

echo "▶ Secrets (clé Anthropic + jeton)…"
printf '%s' "$ANTHROPIC_API_KEY" | $W pages secret put ANTHROPIC_API_KEY --project-name "$PROJECT"
printf '%s' "$APP_TOKEN"        | $W pages secret put APP_TOKEN --project-name "$PROJECT"

echo "▶ Publication du site + proxy…"
OUT="$($W pages deploy app --project-name "$PROJECT" --branch main 2>&1 | tee /dev/stderr)"

echo
echo "✅ Terminé."
echo "Site : $SITE_URL"
echo
echo "Ouvrez CE LIEN sur votre téléphone (l'appli se configure toute seule), puis « Installer » :"
echo "${SITE_URL}/#/setup?t=${APP_TOKEN}"
echo
echo "Gardez ce jeton : $APP_TOKEN"
