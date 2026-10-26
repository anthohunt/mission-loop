# CARTE DE MISSION — <slug>

<!--
Rempli par l'opérateur (l'essentiel). Le reste est hérité par défaut (juge, escalade,
routing modèles, mécanique). Process : objectif brut -> l'agent drafte -> l'opérateur valide.
-->

## Objectif
<!-- 1 phrase, zéro jargon. Le "pourquoi ultime". -->

## Critère de succès
<!-- Les preuves observables qui disent "fini", en langage clair. C'est le contrat de qualité. -->

## Tâches
<!-- Liste ordonnée (pipeline). Chaque tâche : quoi faire + preuve(s) exigée(s).
     Types de preuve : [code] déterministe/tests unitaires · [e2e] test end-to-end · [visuel] screenshot/UX. -->
- [ ] **T1 — <titre>**
  - Faire : <...>
  - Preuves exigées : [code] <...> · [e2e] <...> · [visuel] <...>
  - Dépend de : —
- [ ] **T2 — <titre>**
  - Faire : <...>
  - Preuves exigées : [code] <...>
  - Dépend de : T1

## Travailleurs
<!-- Nombre en parallèle. Défaut 1. >1 seulement si les tâches se parallélisent vraiment. -->
1

## Options
- night-shift : off        <!-- on = éteindre le PC quand la mission PASSE -->
- intervalle : 20m         <!-- réveil du minuteur -->

---
<!-- ===== HÉRITÉ PAR DÉFAUT — ne pas éditer sauf override explicite ===== -->
## (hérité) Routing modèles
- contremaître : opus · travailleurs : sonnet (→ opus si une tâche coince) · juge : opus

## (hérité) Règles d'escalade (persistance, jamais d'abandon)
- Itérations illimitées vers le but. Bloqué → échelle OBLIGATOIRE, orientée action :
  1. réparer → 2. CHERCHER EN LIGNE → 3. reconsidérer l'approche (check contrainte avant de switcher) → 4. re-plan sur l'objectif.
- Seuls stops : PASS du juge · "stop" de l'opérateur · HARD BLOCK réel (H1 secret/identité · H2 physique · H3 jugement délégué · H4 autorisation externe) → pause + notify.
