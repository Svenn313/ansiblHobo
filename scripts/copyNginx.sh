#!/bin/bash
# copyNginx.sh
# Copie les fichiers de configuration nginx vers ansiblHobo/files/nginx/
set -euo pipefail

# ─── Chemins ──────────────────────────────────────────────────────────────────
SRC="/etc/nginx"
DEST="$HOME/git/ansiblHobo/files/nginx"

# ─── Helpers ──────────────────────────────────────────────────────────────────
log()  { echo "  $*"; }
ok()   { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }
fail() { echo "❌ $*" >&2; exit 1; }

# ─── Sanity checks ────────────────────────────────────────────────────────────
[[ -d "$SRC" ]] || fail "Source introuvable : $SRC"

echo ""
echo "📋 copyNginx.sh"
echo "   Source      : $SRC"
echo "   Destination : $DEST"
echo ""

# ─── 1. nginx.conf ────────────────────────────────────────────────────────────
echo "── 1/2  nginx.conf ────────────────────────────────────────────────────"
mkdir -p "$DEST"
if [[ -f "$SRC/nginx.conf" ]]; then
    cp "$SRC/nginx.conf" "$DEST/nginx.conf"
    ok "nginx.conf"
else
    warn "nginx.conf introuvable, ignoré"
fi

# ─── 2. sites-available ───────────────────────────────────────────────────────
echo ""
echo "── 2/3  sites-available ───────────────────────────────────────────────"
mkdir -p "$DEST/sites-available"
count=0
while IFS= read -r file; do
    sudo cp "$file" "$DEST/sites-available/$(basename "$file")"
    log "$(basename "$file")"
    count=$((count + 1))
done < <(find "$SRC/sites-available" -maxdepth 1 -type f)
echo ""

[[ $count -gt 0 ]] && ok "$count fichier(s) copié(s)" || warn "Aucun fichier dans sites-available"

# ─── 3. snippets ────────────────────────────────────────────────
echo "" 
echo "─── 3/3 snippets.conf ────────────────────────────────────────"
mkdir -p "$DEST/snippets"
sudo cp /etc/nginx/snippets/security-headers.conf $DEST/snippets/security-headers.conf
sudo cp /etc/nginx/snippets/proxy.conf $DEST/snippets/proxy.conf
sudo cp /etc/nginx/snippets/tls.conf $DEST/snippets/tls.conf
sudo cp /etc/nginx/snippets/ip-restrictions.conf $DEST/snippets/ip-restrictions.conf
echo ""
