#!/usr/bin/env bash
# Essai d'installation SANS modele : cree une mission d'exemple, fait un tour a blanc (--dry-run), verifie les resultats.
# Usage : bash tests/test-installation.sh        (depuis la racine du depot ; bash >= 4, awk, grep)
set -euo pipefail
RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE="$RACINE/skills/mission/engine"
export MISSIONS_ROOT="$(mktemp -d)"
trap 'rm -rf "$MISSIONS_ROOT"' EXIT
ok(){ echo "OK   $*"; }
ko(){ echo "ECHEC $*" >&2; exit 1; }

echo "== creation de la mission d'exemple"
DIR="$(bash "$ENGINE/mission-new.sh" demo "$RACINE/exemples/carte-compteur-de-mots.md")"
[ -f "$DIR/.mission-active" ] && ok "marqueur cree" || ko "pas de marqueur"
[ "$(cat "$DIR/state/tasks.list" | tr '\n' ' ')" = "T1 T2 " ] && ok "taches T1 T2 detectees" || ko "taches"
[ "$(cat "$DIR/state/status.env" | tr '\n' ' ')" = "T1=PENDING T2=PENDING " ] && ok "statuts PENDING" || ko "statuts"
bash "$ENGINE/mission-new.sh" demo "$RACINE/exemples/carte-compteur-de-mots.md" 2>/dev/null && ko "double creation acceptee" || ok "double creation refusee"

echo "== tour a blanc : travailleur"
bash "$ENGINE/mission-loop.sh" --dry-run demo
[ -s "$DIR/dryrun/worker-T1.md" ] && ok "prompt travailleur ecrit" || ko "pas de prompt travailleur"
grep -q 'mission-blocked' "$DIR/dryrun/worker-T1.md" && ok "chemin du blocage dur present" || ko "chemin blocage"
grep -q '{{' "$DIR/dryrun/worker-T1.md" && ko "marqueur non rempli" || ok "aucun marqueur vide"
[ "$(cat "$DIR/state/status.env" | tr '\n' ' ')" = "T1=PENDING T2=PENDING " ] && ok "etat inchange" || ko "etat modifie"

echo "== tour a blanc : juge (T1 declaree prete)"
touch "$DIR/state/T1.ready"
bash "$ENGINE/mission-loop.sh" --dry-run demo
[ -s "$DIR/dryrun/judge-T1.md" ] && ok "prompt juge ecrit" || ko "pas de prompt juge"
grep -q 'verdicts/T1-1.txt' "$DIR/dryrun/judge-T1.md" && ok "chemin du verdict present" || ko "chemin verdict"
grep -q '{{' "$DIR/dryrun/judge-T1.md" && ko "marqueur non rempli" || ok "aucun marqueur vide"
[ -e "$DIR/verdicts/T1-1.txt" ] && ko "verdict cree par le dry-run" || ok "aucun verdict cree"

echo "== fin de mission simulee (statuts PASS) : le tour a blanc ne touche pas au marqueur"
printf 'T1=PASS\nT2=PASS\n' > "$DIR/state/status.env"
bash "$ENGINE/mission-loop.sh" --dry-run demo
[ -f "$DIR/.mission-active" ] && ok "marqueur conserve en dry-run" || ko "marqueur retire"

echo "== esperluette litterale dans le journal (bash 5.2)"
printf 'T1=PENDING\nT2=PENDING\n' > "$DIR/state/status.env"; rm -f "$DIR/state/T1.ready"
printf '\nessai A & B\n' >> "$DIR/journal.md"
bash "$ENGINE/mission-loop.sh" --dry-run demo >/dev/null 2>&1
grep -q 'essai A & B' "$DIR/dryrun/worker-T1.md" && ok "esperluette conservee" || ko "esperluette alteree"

echo "== boucle reelle avec un FAUX claude (aucun modele) : travailleur -> juge PASS -> fin"
FAUX="$MISSIONS_ROOT/faux-claude"
cat > "$FAUX" <<'F'
#!/usr/bin/env bash
P="$(cat)"
if printf '%s' "$P" | grep -q 'Tu es le \*\*JUGE\*\*'; then
  V="$(printf '%s' "$P" | grep -o '`[^`]*verdicts/[^`]*\.txt`' | head -1 | tr -d '`')"
  printf 'VERDICT: PASS\nTASK: x\n' > "$V"
else
  R="$(printf '%s' "$P" | grep -o '`[^`]*state/T[0-9]*\.ready`' | head -1 | tr -d '`')"
  touch "$R"
fi
F
chmod +x "$FAUX"
MISSION_CLAUDE_BIN="$FAUX" MISSION_PERMISSION_MODE=default MAX_TICKS=20 bash "$ENGINE/mission-loop.sh" demo 0 >/dev/null 2>&1 || ko "boucle terminee en erreur"
[ ! -e "$DIR/.mission-active" ] && ok "marqueur retire a la fin" || ko "marqueur toujours la"
grep -q 'MISSION REUSSIE' "$DIR/journal.md" && ok "journal : mission reussie" || ko "journal"
[ "$(cat "$DIR/state/status.env" | tr '\n' ' ')" = "T1=PASS T2=PASS " ] && ok "T1 et T2 en PASS" || ko "statuts finaux"
echo "TOUT EST VERT"
