#!/bin/bash
# xtract.sh
# Collecte les fichiers sensibles de cloudHobo, les empaquète en tarball
# et chiffre le tout avec ansible-vault.
#
# La tarball chiffrée est déposée dans :
#   ~/git/ansiblHobo/files/vault/sensitive_configs.tar.gz.vault
#
set -euo pipefail

SECONDS=0

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
VAULT_ARGS=()
if [[ -f "$VAULT_PASSWORD_FILE" ]]; then
    VAULT_ARGS=(--vault-password-file "$VAULT_PASSWORD_FILE")
fi

# ─── Helpers ──────────────────────────────────────────────────────────────────
log()     { echo "  $*"; }
ok()      { echo "  ✅ $*"; }
warn()    { echo "  ⚠️  $*"; }
fail()    { echo "  ❌ $*" >&2; exit 1; }
section() { echo ""; echo "── $*"; }

is_docker_compose() {
    local file="$1"
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
section "1/5  Collecte des configs ───────────────────────────────────────────"
while IFS= read -r file; do
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
\)  ! -path "*/prowlarr/volumes/Definitions/*" \
    ! -path "*/__pycache__/*" 2>/dev/null)

# ─── 2. SECRETS EXPLICITES ───────────────────────────────────────────────────
section "2/5  Collecte des secrets explicites ────────────────────────────────"
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

# ─── 3. HOME ASSISTANT volumes ───────────────────────────────────────────────
section "3/5  Home Assistant volumes ─────────────────────────────────────────"
if [[ -d "$SRC/homeassistant/volumes" ]]; then
    while IFS= read -r file; do
        copy_file "$file"
    done < <(find "$SRC/homeassistant/volumes" -type f \
        ! -path "*/custom_components/*" \
        ! -path "*/www/*" \
        ! -path "*/deps/*" \
        ! -path "*/tts/*" \
        ! -name "*.db-wal" \
        ! -name "*.db-shm" \
        ! -name "*.log*" \
        2>/dev/null)
else
    warn "volumes HA introuvable, ignoré"
fi

# ─── 3.5 POSTGRES DUMP ───────────────────────────────────────────────────────
section "3.5/5  Dump PostgreSQL ──────────────────────────────────────────────"
PG_DUMP_DIR="$STAGING/postgres_dumps"
mkdir -p "$PG_DUMP_DIR"

for db in synapse mealie joplin mautrix_signal mautrix_telegram mautrix_whatsapp f1data; do
    if docker exec postgres pg_dump -U postgres "$db" > "$PG_DUMP_DIR/${db}.sql" 2>/dev/null; then
        log "Dump: $db ($(du -sh "$PG_DUMP_DIR/${db}.sql" | cut -f1))"
    else
        warn "Échec dump: $db"
    fi
done

# ─── 3.7 SQLITE DUMPS ────────────────────────────────────────────────────────
section "3.7/5  Dump SQLite ──────────────────────────────────────────────────"
SQLITE_DUMP_DIR="$STAGING/sqlite_dumps"
mkdir -p "$SQLITE_DUMP_DIR"

declare -A SQLITE_DBS=(
    ["prowlarr"]="$SRC/prowlarr/volumes/prowlarr.db"
    ["sonarr"]="$SRC/sonarr/volumes/sonarr.db"
    ["radarr"]="$SRC/radarr/volumes/radarr.db"
    ["jellyfin"]="$SRC/jellyfin/config/data/data/jellyfin.db"
)

for name in "${!SQLITE_DBS[@]}"; do
    db="${SQLITE_DBS[$name]}"
    if [[ -f "$db" ]]; then
        sqlite3 "$db" ".dump" > "$SQLITE_DUMP_DIR/${name}.sql" 2>/dev/null && \
            log "Dump SQLite: $name ($(du -sh "$SQLITE_DUMP_DIR/${name}.sql" | cut -f1))" || \
            warn "Échec dump SQLite: $name"
    else
        warn "Introuvable: $db"
    fi
done

# ─── 4. PACKAGING + VAULT ────────────────────────────────────────────────────
section "4/5  Packaging & chiffrement ────────────────────────────────────────"

file_count=$(find "$STAGING" -type f | wc -l)
[[ "$file_count" -gt 0 ]] || fail "Aucun fichier collecté, abandon."
log "$file_count fichier(s) collecté(s)"

tar -czf "$TARBALL" -C "$STAGING" .
log "Tarball créée : $(du -sh "$TARBALL" | cut -f1)"

log "Chiffrement en cours..."
ansible-vault encrypt "${VAULT_ARGS[@]}" --output "$OUTPUT" "$TARBALL"

ok "Tarball chiffrée : $OUTPUT"

# ─── 5. GIT PUSH ─────────────────────────────────────────────────────────────
section "5/5  Git push ────────────────────────────────────────────────────────"

COMMIT_MSG="Auto commit -- vault file : $(date '+%Y-%m-%d %H:%M:%S')"
cd "$HOME/git/ansiblHobo"
git add "$OUTPUT"
git commit --no-gpg-sign -m "$COMMIT_MSG" 2>&1 | while IFS= read -r line; do log "$line"; done
GIT_SSH_COMMAND="ssh -i ~/.ssh/cronKey -o IdentitiesOnly=yes" git push 2>&1 | while IFS= read -r line; do log "$line"; done

ok "Push OK → origin/main"

echo ""
echo "  Durée totale : ${SECONDS}s"
echo ""
