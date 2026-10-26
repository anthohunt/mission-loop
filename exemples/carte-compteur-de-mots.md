# CARTE DE MISSION — compteur-de-mots

## Objectif
Un petit outil en ligne de commande qui compte les mots d'un fichier texte, utilisable par n'importe qui sans réglage.

## Critère de succès
• La commande `./compte-mots.sh exemple.txt` affiche le nombre exact de mots du fichier (3 mots dans un fichier de test fourni).
• Sur un fichier vide, elle affiche 0, et sur un fichier absent elle affiche un message clair et s'arrête en erreur.

## Tâches
- [ ] **T1 — Écrire l'outil**
  - Faire : créer `compte-mots.sh` dans le dossier de la mission (`evidence/T1/`).
  - Preuves exigées : [code] sortie de la commande sur un fichier de 3 mots, sur un fichier vide et sur un fichier absent
  - Dépend de : —
- [ ] **T2 — Documenter l'usage**
  - Faire : écrire `LISEZMOI.txt` (trois lignes : à quoi ça sert, comment l'appeler, ce qu'il affiche en cas d'erreur).
  - Preuves exigées : [code] le texte du LISEZMOI et la commande qu'il cite exécutée telle quelle
  - Dépend de : T1

## Travailleurs
1

## Options
- night-shift : off
- intervalle : 20m

---
## (hérité) Routing modèles
- contremaître : opus · travailleurs : sonnet (→ opus si une tâche coince) · juge : opus

## (hérité) Règles d'escalade (persistance, jamais d'abandon)
- Itérations illimitées vers le but. Bloqué → échelle : réparer, chercher en ligne, reconsidérer l'approche, re-planifier.
- Seuls arrêts : PASS du juge · « stop » de l'opérateur · blocage dur réel (secret ou identité, monde physique, jugement subjectif délégué, autorisation externe).
