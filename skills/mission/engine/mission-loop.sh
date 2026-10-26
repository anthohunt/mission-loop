#!/usr/bin/env bash
# mission-loop.sh [--dry-run] <slug> [interval_seconds] : orchestrateur « Ralph » d'une mission.
# Boucle : tache courante -> TRAVAILLEUR (claude -p, frais) -> quand pret -> JUGE (claude -p, isole) -> PASS/FAIL.
# Arrets : toutes les taches PASS | marqueur retire | blocage dur (fichier mission-blocked).
#
# Reglages (variables d'environnement) :
#   MISSIONS_ROOT          dossier des missions                         defaut ~/.claude/missions
#   MISSION_CLAUDE_BIN     commande Claude Code                         defaut claude
#   MISSION_WORKER_MODEL   modele des travailleurs                      defaut sonnet
#   MISSION_JUDGE_MODEL    modele du juge                               defaut opus
#   MISSION_PERMISSION_MODE mode de permissions de claude -p            defaut bypassPermissions (voir README : a lancer dans un bac a sable)
#   MAX_TICKS              nombre de tours avant arret (0 = illimite)   defaut 0
#   MISSION_NOTIFY_CMD     commande appelee avec un message (facultatif : push, mail...)
#   MISSION_DRY_RUN=1      equivaut a --dry-run
# --dry-run : prepare le prompt du tour (travailleur ou juge), l'ecrit dans <mission>/dryrun/, verifie qu'aucun
#   {{marqueur}} n'est reste vide, et s'arrete SANS appeler de modele et SANS modifier l'etat de la mission.
set -uo pipefail
# bash >= 5.2 : « & » est special dans le remplacement des ${var//a/b} ; on veut un remplacement litteral
shopt -u patsub_replacement 2>/dev/null || true

DRY="${MISSION_DRY_RUN:-0}"
if [ "${1:-}" = "--dry-run" ]; then DRY=1; shift; fi

SLUG="${1:?usage: mission-loop.sh [--dry-run] <slug> [interval_seconds]}"
INTERVAL="${2:-1200}"
ROOT="${MISSIONS_ROOT:-$HOME/.claude/missions}"
DIR="$ROOT/$SLUG"
ENGINE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPL="$ENGINE/templates"
MARKER="$DIR/.mission-active"; BLOCKED="$DIR/mission-blocked"
STATUS="$DIR/state/status.env"; JOURNAL="$DIR/journal.md"
CARD="$DIR/MISSION-$SLUG.md"; LOG="$DIR/loop.log"
MAX_TICKS="${MAX_TICKS:-0}"
CLAUDE_BIN="${MISSION_CLAUDE_BIN:-claude}"
WORKER_MODEL="${MISSION_WORKER_MODEL:-sonnet}"
JUDGE_MODEL="${MISSION_JUDGE_MODEL:-opus}"
PERM_MODE="${MISSION_PERMISSION_MODE:-bypassPermissions}"

winpath(){ if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi; }
log(){ printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" | tee -a "$LOG" >&2; }
notify(){ log "NOTIFY: $*"; if [ -n "${MISSION_NOTIFY_CMD:-}" ]; then $MISSION_NOTIFY_CMD "$*" >/dev/null 2>&1 || true; fi; }

# fill <fichier> CLE=valeur ... : remplace {{CLE}} par la valeur (remplacement litteral)
fill(){ local f="$1"; shift; local c; c="$(awk 'ok{print;next} /^---[[:space:]]*$/{ok=1}' "$f")"; local kv k v   # le preambule (jusqu'au premier « --- ») documente le gabarit, il n'est pas envoye
  for kv in "$@"; do k="${kv%%=*}"; v="${kv#*=}"; c="${c//\{\{$k\}\}/$v}"; done
  printf '%s' "$c"; }

run_claude(){ # model prompt
  # prompt via stdin (pas en argument) : evite « Argument list too long » quand le journal grossit
  printf '%s' "$2" | "$CLAUDE_BIN" -p --model "$1" --permission-mode "$PERM_MODE" --add-dir "$(winpath "$DIR")" >>"$LOG" 2>&1; }

# remplace le statut d'une tache dans status.env (portable : pas de sed -i)
set_status(){ local id="$1" val="$2" tmp="$STATUS.tmp"
  awk -F= -v id="$id" -v val="$val" 'BEGIN{OFS="="} $1==id{print id, val; next} {print}' "$STATUS" > "$tmp" && mv "$tmp" "$STATUS"; }

[ -d "$DIR" ] || { echo "mission introuvable : $DIR (lance mission-new.sh d'abord)" >&2; exit 1; }
[ -f "$MARKER" ] || { echo "pas de marqueur pour $SLUG (mission terminee, ou mission-new.sh pas lance)" >&2; exit 1; }
mkdir -p "$DIR/verdicts" "$DIR/evidence"

if [ "$DRY" != 1 ]; then
  printf '%s\n' "$$" > "$MARKER"
  log "loop start pid=$$ interval=${INTERVAL}s dir=$DIR permission-mode=$PERM_MODE worker=$WORKER_MODEL judge=$JUDGE_MODEL"
  [ "$PERM_MODE" = bypassPermissions ] && log "ATTENTION : les agents tournent sans demande de permission ; utilise un conteneur ou une machine jetable."
else
  log "DRY-RUN : aucun modele ne sera appele, l'etat de la mission ne change pas"
fi

tick=0
while true; do
  [ -f "$MARKER" ] || { log "marqueur retire -> stop"; exit 0; }
  if [ -f "$BLOCKED" ]; then notify "BLOCAGE DUR : $(cat "$BLOCKED" 2>/dev/null)"; exit 0; fi

  CUR=""
  while IFS='=' read -r t st; do [ "${st:-}" = "PASS" ] || { CUR="$t"; break; }; done < "$STATUS"

  if [ -z "$CUR" ]; then
    log "TOUTES LES TACHES PASS"; notify "MISSION $SLUG REUSSIE"
    if [ "$DRY" != 1 ]; then
      printf '\n## MISSION REUSSIE %s\n' "$(date '+%Y-%m-%d %H:%M')" >> "$JOURNAL"
      rm -f "$MARKER"
    fi
    exit 0
  fi

  READY="$DIR/state/$CUR.ready"
  if [ -f "$READY" ]; then
    n=$(( $(ls "$DIR/verdicts/$CUR-"*.txt 2>/dev/null | wc -l) + 1 ))
    VERDICT="$DIR/verdicts/$CUR-$n.txt"
    jp="$(fill "$TPL/judge-prompt.md" "SLUG=$SLUG" "TASK_ID=$CUR" \
      "CARD_PATH=$(winpath "$CARD")" "EVIDENCE_DIR=$(winpath "$DIR/evidence")" "VERDICT_PATH=$(winpath "$VERDICT")")"
    if [ "$DRY" = 1 ]; then
      mkdir -p "$DIR/dryrun"; printf '%s\n' "$jp" > "$DIR/dryrun/judge-$CUR.md"
      if printf '%s' "$jp" | grep -q '{{[A-Z_]*}}'; then log "DRY-RUN : marqueur non rempli dans le prompt du juge"; exit 4; fi
      log "DRY-RUN : prompt du JUGE pour $CUR ecrit dans dryrun/judge-$CUR.md ($(printf '%s' "$jp" | wc -c) octets), aucun appel"; exit 0
    fi
    log "JUGE $CUR (verdict #$n)"
    # un juge qui ne produit PAS de fichier verdict = rate de process (pas un FAIL) -> nouvel essai
    attempt=0
    while [ "$attempt" -lt 3 ]; do
      run_claude "$JUDGE_MODEL" "$jp"
      [ -f "$VERDICT" ] && break
      attempt=$((attempt+1)); log "JUGE $CUR rate (aucun verdict ecrit) -> essai $attempt/3"
    done
    if [ ! -f "$VERDICT" ]; then
      log "JUGE $CUR ne produit aucun verdict apres 3 essais -> BLOCAGE DUR"
      printf 'le juge ne produit aucun verdict pour %s apres 3 essais (processus casse)' "$CUR" > "$BLOCKED"
      continue
    fi
    rm -f "$READY"
    if grep -qiE 'VERDICT: *PASS' "$VERDICT"; then
      set_status "$CUR" PASS; log "JUGE $CUR = PASS"
      { printf '\n### passe JUGE %s - PASS (%s)\n' "$CUR" "$(date '+%H:%M')"; cat "$VERDICT" 2>/dev/null; printf '\n'; } >> "$JOURNAL"
    else
      log "JUGE $CUR = FAIL"
      { printf '\n### passe JUGE %s - FAIL (%s)\n' "$CUR" "$(date '+%H:%M')"; cat "$VERDICT" 2>/dev/null; printf '\n'; } >> "$JOURNAL"
    fi
  else
    wp="$(fill "$TPL/worker-prompt.md" "SLUG=$SLUG" "TASK_ID=$CUR" \
      "MISSION_DIR=$(winpath "$DIR")" "CARD_PATH=$(winpath "$CARD")" "JOURNAL_PATH=$(winpath "$JOURNAL")" \
      "EVIDENCE_DIR=$(winpath "$DIR/evidence")" "READY_FILE=$(winpath "$READY")" "JOURNAL_TAIL=$(tail -n 40 "$JOURNAL")")"
    if [ "$DRY" = 1 ]; then
      mkdir -p "$DIR/dryrun"; printf '%s\n' "$wp" > "$DIR/dryrun/worker-$CUR.md"
      if printf '%s' "$wp" | grep -q '{{[A-Z_]*}}'; then log "DRY-RUN : marqueur non rempli dans le prompt du travailleur"; exit 4; fi
      log "DRY-RUN : prompt du TRAVAILLEUR pour $CUR ecrit dans dryrun/worker-$CUR.md ($(printf '%s' "$wp" | wc -c) octets), aucun appel"; exit 0
    fi
    log "TRAVAILLEUR $CUR"
    printf '\n### passe CONTREMAITRE (%s) - j'"'"'assigne %s a un travailleur\n' "$(date '+%H:%M')" "$CUR" >> "$JOURNAL"
    run_claude "$WORKER_MODEL" "$wp"
  fi

  tick=$((tick+1))
  if [ "$MAX_TICKS" -gt 0 ] && [ "$tick" -ge "$MAX_TICKS" ]; then log "MAX_TICKS=$MAX_TICKS atteint -> stop (test)"; exit 3; fi
  sleep "$INTERVAL"
done
