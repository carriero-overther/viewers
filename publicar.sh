#!/usr/bin/env bash
# Publica (o actualiza) el visor de un proyecto en
# https://carriero-overther.github.io/viewers/<proyecto>/
#
# Uso, desde la raíz de este repo:
#   ./publicar.sh <proyecto> <index.html> [vault.json] [--permitir-achicar]
#
#   <proyecto>    carpeta destino, p. ej. ovt-ia-e3-ocr
#   <index.html>  visor del repo privado del proyecto (p. ej. .../visor/index.html)
#   [vault.json]  vault cifrado nuevo; si se omite, se conserva el publicado
#
# Reemplaza TODA la historia por un único commit (orphan + force push), para no
# acumular versiones viejas del vault en un repo público.
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

ACHICAR=0
ARGS=()
for a in "$@"; do
  case "$a" in
    --permitir-achicar) ACHICAR=1 ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) ARGS+=("$a") ;;
  esac
done
[ "${#ARGS[@]}" -ge 2 ] && [ "${#ARGS[@]}" -le 3 ] || die "uso: ./publicar.sh <proyecto> <index.html> [vault.json] [--permitir-achicar]"
PROYECTO="${ARGS[0]}"; INDEX="${ARGS[1]}"; VAULT="${ARGS[2]:-}"
abs() { [ -e "$1" ] || die "no existe $1"; echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"; }
INDEX="$(abs "$INDEX")"
[ -n "$VAULT" ] && VAULT="$(abs "$VAULT")"

# El visor tiene que estar commiteado en el repo de su proyecto (trazabilidad).
SRC_DIR="$(dirname "$INDEX")"
if git -C "$SRC_DIR" rev-parse 2>/dev/null; then
  [ -z "$(git -C "$SRC_DIR" status --porcelain -- "$(basename "$INDEX")")" ] \
    || die "$INDEX tiene cambios sin commitear en su repo; commitealo antes de publicar"
fi

# --- Repo y cuenta correctos ------------------------------------------------
cd "$(dirname "$0")"
[ "$(git rev-parse --show-toplevel 2>/dev/null)" = "$PWD" ] || die "correr desde el repo viewers"
REMOTE="$(git remote get-url origin)"
[ "$REMOTE" = "git@github-overthere:carriero-overther/viewers.git" ] || die "origin inesperado: $REMOTE"
[ "$(git config user.name)" = "carriero-overther" ] || die "autor de git no es carriero-overther"
[ -z "$(git status --porcelain)" ] || die "hay cambios sin publicar en el repo; revisalos primero"

# --- Validaciones ------------------------------------------------------------
[[ "$PROYECTO" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "nombre de proyecto inválido: $PROYECTO"
[ -f "$INDEX" ] || die "no existe $INDEX"
if rg -q 'localStorage|sessionStorage|indexedDB' "$INDEX"; then
  die "$INDEX usa almacenamiento del navegador; los visores comparten dominio y no deben guardar nada"
fi

DEST_VAULT="$PROYECTO/data/vault.json"
if [ -n "$VAULT" ]; then
  [ -f "$VAULT" ] || die "no existe $VAULT"
  # Solo se publica un vault cifrado: exactamente {v, iter, s, iv, ct}.
  python3 -I - "$VAULT" "$DEST_VAULT" "$ACHICAR" <<'PY' || exit 1
import json, os, sys
nuevo, actual, achicar = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
v = json.load(open(nuevo))
if not isinstance(v, dict) or set(v) != {"v", "iter", "s", "iv", "ct"}:
    sys.exit(f"ERROR: {nuevo} no parece un vault cifrado (claves: {sorted(v) if isinstance(v, dict) else type(v).__name__}). ¿Es un fragmento en claro?")
if v["iter"] < 210000:
    sys.exit(f"ERROR: iter={v['iter']} < 210000")
if os.path.exists(actual):
    viejo = len(json.load(open(actual))["ct"])
    if len(v["ct"]) < viejo and not achicar:
        sys.exit(f"ERROR: el vault nuevo es MÁS CHICO que el publicado ({len(v['ct'])} < {viejo}). "
                 "El vault es acumulativo: puede faltar una parte. Si es a propósito, usá --permitir-achicar.")
print(f"vault OK: ct={len(v['ct'])} chars, iter={v['iter']}")
PY
elif [ ! -f "$DEST_VAULT" ]; then
  die "$PROYECTO es nuevo y no le pasaste vault.json"
fi

# --- Copiar ------------------------------------------------------------------
mkdir -p "$PROYECTO/data"
cp "$INDEX" "$PROYECTO/index.html"
if [ -n "$VAULT" ] && [ ! "$VAULT" -ef "$DEST_VAULT" ]; then cp "$VAULT" "$DEST_VAULT"; fi

if [ -z "$(git status --porcelain)" ]; then
  echo "Nada cambió en $PROYECTO; no se publica."
  exit 0
fi
git status --short

# --- Commit único + force push -----------------------------------------------
ORIGEN="$(git -C "$SRC_DIR" log -1 --format=%h -- "$(basename "$INDEX")" 2>/dev/null || true)"
MSG="publish: $PROYECTO${ORIGEN:+ (visor $ORIGEN)}"
git checkout -q --orphan publish
git add -A
git commit -q -m "$MSG"
git branch -D main -q
git branch -m main
git push -q -f origin main

echo "Publicado: $(git log --oneline -1)"
echo "URL: https://carriero-overther.github.io/viewers/$PROYECTO/  (puede tardar ~1 min; hard refresh)"
