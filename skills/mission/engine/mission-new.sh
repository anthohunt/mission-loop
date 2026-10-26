#!/usr/bin/env bash
# mission-new.sh <slug> <carte.md> : cree une mission a partir d'une carte remplie.
# Reglage : MISSIONS_ROOT (defaut ~/.claude/missions).
# Une tache = une ligne « - [ ] **T<n> ... » dans la carte ; les identifiants T<n> sont extraits.
set -euo pipefail

SLUG="${1:?usage: mission-new.sh <slug> <carte.md>}"
CARD="${2:?usage: mission-new.sh <slug> <carte.md>}"
ROOT="${MISSIONS_ROOT:-$HOME/.claude/missions}"
DIR="$ROOT/$SLUG"

[ -f "$CARD" ] || { echo "carte introuvable: $CARD" >&2; exit 1; }
case "$SLUG" in *[!a-zA-Z0-9._-]*|"") echo "slug invalide (lettres, chiffres, . _ - seulement): $SLUG" >&2; exit 1;; esac
if [ -e "$DIR/.mission-active" ]; then echo "mission $SLUG deja active ($DIR)" >&2; exit 1; fi

mkdir -p "$DIR/evidence" "$DIR/verdicts" "$DIR/state"
cp "$CARD" "$DIR/MISSION-$SLUG.md"

grep -oE '\*\*T[0-9]+' "$DIR/MISSION-$SLUG.md" | sed 's/\*\*//' | awk '!seen[$0]++' > "$DIR/state/tasks.list"
if [ ! -s "$DIR/state/tasks.list" ]; then echo "aucune tache T<n> trouvee dans la carte" >&2; exit 1; fi

: > "$DIR/state/status.env"
while read -r t; do printf '%s=PENDING\n' "$t" >> "$DIR/state/status.env"; done < "$DIR/state/tasks.list"

{
  printf '# JOURNAL - mission %s\n' "$SLUG"
  printf 'Creee : %s\n\n' "$(date '+%Y-%m-%d %H:%M')"
  printf '## Taches\n'; cat "$DIR/state/tasks.list"; printf '\n'
} > "$DIR/journal.md"

echo "PENDING" > "$DIR/.mission-active"
echo "$DIR"
