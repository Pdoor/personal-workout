#!/usr/bin/env bash
# =============================================================================
#  deploy.sh — Personal Workout
#  Deploy del repo locale su https://github.com/Pdoor/personal-workout
#
#  Uso:
#    ./deploy.sh                          # commit con messaggio default
#    ./deploy.sh "Aggiunto Coach Mode"    # commit con messaggio custom
#    ./deploy.sh --dry-run                # mostra cosa verrebbe pushato
# =============================================================================

set -euo pipefail

# --- CONFIG -------------------------------------------------------------------
REPO_URL="https://github.com/Pdoor/personal-workout.git"
BRANCH="main"
DEFAULT_MSG="Update Personal Workout · $(date +'%Y-%m-%d %H:%M')"

# --- COLORS -------------------------------------------------------------------
if [[ -t 1 ]]; then
  C_OK='\033[1;32m'; C_INFO='\033[1;34m'; C_WARN='\033[1;33m'; C_ERR='\033[1;31m'; C_RST='\033[0m'
else
  C_OK=''; C_INFO=''; C_WARN=''; C_ERR=''; C_RST=''
fi

log()  { printf "${C_INFO}→${C_RST} %s\n" "$*"; }
ok()   { printf "${C_OK}✓${C_RST} %s\n" "$*"; }
warn() { printf "${C_WARN}⚠${C_RST}  %s\n" "$*"; }
err()  { printf "${C_ERR}✗${C_RST} %s\n" "$*" >&2; }

# --- PARSE ARGS ---------------------------------------------------------------
DRY_RUN=0
COMMIT_MSG="$DEFAULT_MSG"
for arg in "$@"; do
  case "$arg" in
    --dry-run|-n) DRY_RUN=1 ;;
    --help|-h)
      sed -n '2,10p' "$0"
      exit 0 ;;
    *) COMMIT_MSG="$arg" ;;
  esac
done

# --- PREFLIGHT ----------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

command -v git >/dev/null 2>&1 || { err "git non installato"; exit 1; }

if [[ ! -f index.html ]]; then
  err "index.html non trovato in $SCRIPT_DIR"
  exit 1
fi

if [[ ! -f .gitignore ]]; then
  err ".gitignore mancante. Crealo prima di eseguire deploy."
  exit 1
fi

# --- INIT REPO SE MANCA -------------------------------------------------------
if [[ ! -d .git ]]; then
  log "Inizializzo repository git…"
  git init -q
  git branch -M "$BRANCH"
  ok "Repo inizializzato"
fi

# --- REMOTE ORIGIN ------------------------------------------------------------
if ! git remote get-url origin >/dev/null 2>&1; then
  log "Aggiungo remote origin → $REPO_URL"
  git remote add origin "$REPO_URL"
else
  CURRENT_URL=$(git remote get-url origin)
  if [[ "$CURRENT_URL" != "$REPO_URL" ]]; then
    warn "Remote origin diverso ($CURRENT_URL). Aggiorno a $REPO_URL"
    git remote set-url origin "$REPO_URL"
  fi
fi

# --- ENSURE BRANCH ------------------------------------------------------------
CURRENT_BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || echo "")"
if [[ "$CURRENT_BRANCH" != "$BRANCH" ]]; then
  if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git checkout "$BRANCH"
  else
    git checkout -b "$BRANCH"
  fi
fi

# --- DRY RUN ------------------------------------------------------------------
if [[ "$DRY_RUN" -eq 1 ]]; then
  log "DRY-RUN — nessuna modifica al repo remoto."
  echo
  echo "── File che verrebbero tracciati e caricati ──"
  git ls-files --others --cached --exclude-standard | sort
  echo
  echo "── File ignorati (esclusi dal deploy) ──"
  git ls-files --others --ignored --exclude-standard | sort | head -40
  TOT_FILES=$(git ls-files --others --cached --exclude-standard | wc -l | tr -d ' ')
  TOT_SIZE=$(git ls-files --others --cached --exclude-standard -z | xargs -0 du -ch 2>/dev/null | tail -1 | awk '{print $1}')
  echo
  ok "Totale file da pushare: $TOT_FILES — peso: $TOT_SIZE"
  echo
  echo "Per fare il deploy reale:  ./deploy.sh \"messaggio commit\""
  exit 0
fi

# --- STAGE + COMMIT -----------------------------------------------------------
log "Stage modifiche…"
git add -A

if git diff --cached --quiet; then
  warn "Nessuna modifica da committare. Provo solo il push."
else
  git commit -m "$COMMIT_MSG" -q
  ok "Commit creato: $COMMIT_MSG"
fi

# --- SYNC CON REMOTE ----------------------------------------------------------
log "Sync con il remote…"
git fetch origin "$BRANCH" 2>/dev/null || true

if git rev-parse --verify "origin/$BRANCH" >/dev/null 2>&1; then
  if ! git pull --rebase --no-edit origin "$BRANCH"; then
    err "Conflitti durante il rebase. Risolvi a mano poi rilancia: git rebase --continue && ./deploy.sh"
    exit 1
  fi
  ok "Branch allineato col remote"
fi

# --- PUSH ---------------------------------------------------------------------
log "Push su $REPO_URL ($BRANCH)…"
if git push -u origin "$BRANCH"; then
  ok "Deploy completato 🎉"
else
  err "Push fallito. Possibili cause:"
  err "  · credenziali GitHub mancanti (configura: gh auth login  oppure  Personal Access Token)"
  err "  · il repo $REPO_URL non esiste ancora — crealo su github.com prima"
  err "  · conflitti non risolti col remote"
  exit 1
fi

echo
ok "Repo: $REPO_URL"
ok "Branch: $BRANCH"
echo
echo "💡 Per attivare GitHub Pages e usare l'app via web:"
echo "   GitHub repo → Settings → Pages → Source: Deploy from a branch"
echo "   Branch: $BRANCH · Folder: / (root) → Save"
echo "   L'app sarà online a:  https://Pdoor.github.io/personal-workout/"
