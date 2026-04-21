#!/bin/bash
# xtract.sh
# Collecte les fichiers sensibles de cloudHobo, les empaquète en tarball
# et chiffre le tout avec ansible-vault.
#
# La tarball chiffrée est déposée dans :
#   ~/git/ansiblHobo/files/vault/sensitive_configs.tar.gz.vault
#
set -euo pipefail

# ─── Chemins ──────────────────────────────────────────────────────────────────
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$HOME/git/cloudHobo"
DEST_REPO="$HOME/git/ansiblHobo/files/vault"
WORK_DIR="$(mktemp -d)"
STAGING="$WORK_DIR/staging"
TARBALL="$WORK_DIR/sensitive_configs.tar.gz"
OUTPUT="$DEST_REPO/sensitive_configs.tar.gz.vault"

# ─── Nettoyage automatique ────────────────────────────────────────────────────
trap 'rm -rf "$WORK_DIR"' EXIT

# ─── Vault password file ─────────────────────────────────────────────────────
VAULT_PASSWORD_FILE="${HOME}/git/ansiblHobo/.vault_pass"
VAULT_ARGS=(--vault-password-file "$VAULT_PASSWORD_FILE")

[[ -f "$VAULT_PASSWORD_FILE" ]] || fail "Vault password file introuvable : $VAULT_PASSWORD_FILE"

# ─── Helpers ──────────────────────────────────────────────────────────────────
log()  { echo "  $*"; }
ok()   { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }
fail() { echo "❌ $*" >&2; exit 1; }

is_docker_compose() {
    local file="$1"
    # Un docker-compose contient "services:" au niveau racine
    grep -qE "^\s*services\s*:" "$file" 2>/dev/null
}

copy_file() {
    local src="$1"
    local dest="$STAGING/${src#$SRC/}"
    if [[ -f "$src" ]]; then
        mkdir -p "$(dirname "$dest")"
        if cp "$src" "$dest" 2>/dev/null; then
            log "$(realpath --relative-to="$SRC" "$src")"
        elif sudo cp "$src" "$dest" 2>/dev/null; then
            sudo chown "$(id -un):$(id -gn)" "$dest"
            log "[sudo] $(realpath --relative-to="$SRC" "$src")"
        else
            warn "Permission refusée (même avec sudo): $src"
        fi
    else
        warn "Introuvable: $src"
    fi
}

# ─── Sanity checks ────────────────────────────────────────────────────────────
[[ -d "$SRC" ]]       || fail "Source introuvable : $SRC"
command -v ansible-vault &>/dev/null || fail "ansible-vault non trouvé"

mkdir -p "$STAGING" "$DEST_REPO"

echo ""
echo "📦 xtract.sh"
echo "   Source      : $SRC"
echo "   Destination : $OUTPUT"
echo ""

# ─── 1. CONFIGS (hors docker-compose) ────────────────────────────────────────
echo "── 1/4  Collecte des configs ──────────────────────────────────────────"
while IFS= read -r file; do
    # Exclure les docker-compose yml
    if [[ "$file" == *.yml || "$file" == *.yaml ]]; then
        is_docker_compose "$file" && continue
    fi
    copy_file "$file"
done < <(find "$SRC" -type f \( \
    -name "*.yml"  -o \
    -name "*.yaml" -o \
    -name "*.conf" -o \
    -name "*.toml" -o \
    -name "*.ini"  -o \
    -name "*.env"  \
\) ! -path "*/__pycache__/*" 2>/dev/null)

# ─── 2. SECRETS EXPLICITES ───────────────────────────────────────────────────
echo ""
echo "── 2/4  Collecte des secrets explicites ───────────────────────────────"
while IFS= read -r file; do
    copy_file "$file"
done < <(find "$SRC" -type f \( \
    -name "cli_pw"    -o \
    -name "*.key"     -o \
    -name "*.secret"  -o \
    -name "*.token"   -o \
    -name "*.session" -o \
    -name "*.cookie*" -o \
    -name "*.pem"     -o \
    -name "*.p12"     \
\) 2>/dev/null)

# ─── 3. HOME ASSISTANT .storage ──────────────────────────────────────────────
echo ""
echo "── 3/4  Home Assistant .storage ───────────────────────────────────────"
if [[ -d "$SRC/homeassistant/volumes/.storage" ]]; then
    while IFS= read -r file; do
        copy_file "$file"
    done < <(find "$SRC/homeassistant/volumes/.storage" -type f 2>/dev/null)
else
    warn ".storage introuvable, ignoré"
fi

# ─── 4. PACKAGING + VAULT ────────────────────────────────────────────────────
echo ""
echo "── 4/4  Packaging & chiffrement ───────────────────────────────────────"

file_count=$(find "$STAGING" -type f | wc -l)
[[ "$file_count" -gt 0 ]] || fail "Aucun fichier collecté, abandon."
log "$file_count fichier(s) collecté(s)"

# Tarball
tar -czf "$TARBALL" -C "$STAGING" .
log "Tarball créée : $(du -sh "$TARBALL" | cut -f1)"

# Chiffrement
ansible-vault encrypt "${VAULT_ARGS[@]}" --output "$OUTPUT" "$TARBALL"

ok "Tarball chiffrée : $OUTPUT"
echo ""
