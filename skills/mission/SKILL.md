---
name: mission
description: "Loop engineering: a goal-driven iteration loop for an exploratory problem (clear goal, unknown path). A 'mission' is a full cycle: goal, agreed success criterion, loop, stop only on verified success. Hard gates: criterion before starting, forced reflection after 3 failures in the same cluster, progress heartbeat. Runs on an external engine (engine/mission-loop.sh) with fresh workers and an isolated adversarial judge. Triggers: 'new mission', '/mission', 'loop until X works', 'nouvelle mission', 'itère jusqu'à ce que X soit vrai'."
metadata:
  type: process
---

# Mission : itérer vers un succès vérifiable

Une **mission** est un cycle complet : un but, un critère de succès défini avec l'opérateur, une boucle, et un arrêt **uniquement** au succès vérifié. Elle sert quand le but est clair mais **le chemin est inconnu** : intégration avec un système boîte noire, rétro-ingénierie d'une API non documentée, débogage d'un comportement opaque, optimisation jusqu'à un seuil.

À ne pas utiliser si le travail est mécanique (refactorisation, traduction, génération guidée par une spécification), si le chemin est déjà connu, ou si le but est trop vague pour s'exprimer en critère testable (commencer par un échange de cadrage).

## Le moteur (à lire en premier)

Une mission ne tourne pas dans la conversation d'un agent (fragile : elle meurt entre deux tours et le contexte pourrit). Elle tourne sur un **moteur externe** :

• Un **minuteur simple et obstiné** relance tant que le marqueur existe et que le juge n'a pas dit PASS pour toutes les tâches. La mémoire vit **sur le carnet** (carte, journal, état sur disque) : un agent neuf équivaut à un agent qui reprend le carnet.
• **Trois rôles** : le contremaître (la boucle) assigne ; les **travailleurs** (`claude -p`, frais) font une passe bornée et journalisent ; le **juge** (`claude -p`, isolé, adversarial) audite chaque tâche annoncée prête. Le juge est lancé par le moteur, jamais par le contremaître ; son prompt est fixe ; il communique par le disque seulement (preuves en entrée, verdict en sortie) ; il suppose le travail défectueux et rejette au moindre doute.
• **Traçabilité** : chaque passe écrit dans `journal.md`. Déboguer, c'est lire le journal.
• **Persistance** : itérations illimitées ; bloqué, on monte l'échelle réparer → **chercher en ligne** → reconsidérer l'approche → replanifier. Seuls arrêts : PASS du juge, « stop » de l'opérateur, **blocage dur** réel.

Fichiers (`engine/`) :
• `templates/MISSION-CARD-template.md` : la carte (objectif, critère, tâches et preuves exigées, nombre de travailleurs, options).
• `templates/worker-prompt.md`, `templates/judge-prompt.md` : prompts fixes.
• `mission-new.sh <slug> <carte.md>` : crée `$MISSIONS_ROOT/<slug>/` (marqueur, journal, état, dossiers).
• `mission-loop.sh [--dry-run] <slug> [intervalle_s]` : l'orchestrateur. Réglages : `MISSIONS_ROOT`, `MISSION_CLAUDE_BIN`, `MISSION_WORKER_MODEL`, `MISSION_JUDGE_MODEL`, `MISSION_PERMISSION_MODE`, `MAX_TICKS`, `MISSION_NOTIFY_CMD`.

Preuves par tâche, de trois types : `[code]` déterministe, `[e2e]` test de bout en bout, `[visuel]` capture d'écran. Aiguillage par défaut : contremaître et juge sur le modèle le plus capable, travailleurs sur un modèle plus léger (qui monte d'un cran si une tâche coince).

## Lancer une mission

1. **Rédiger la carte** à partir du modèle ; l'opérateur la valide (seul point de contrôle manuel).
2. `bash engine/mission-new.sh <slug> <carte.md>`.
3. `bash engine/mission-loop.sh <slug>` (ou le faire relancer par un minuteur du système pour survivre à un redémarrage). Essai à blanc sans modèle : `--dry-run`.
4. La mission tourne seule jusqu'au PASS de toutes les tâches.

## Gate d'entrée (non négociable)

Avant tout travail itératif :
1. **Reformuler le but en une phrase** (fige la cible, évite la dérive).
2. **Proposer un critère de succès testable sans jugement humain**, exprimé **en langage clair, sans jargon** : noms de fichiers, de variables, de métriques, anglicismes de métier et noms bruts de modèles sont du jargon. Si la mécanique doit être précisée, la mettre **entre parenthèses après** la version claire. Relire mot par mot avant d'envoyer : pour chaque mot, « l'opérateur pourrait-il demander ce que ça veut dire ? ». Traduire les chiffres dans une échelle intuitive (0,126 se dit « 13 % »). Format : une phrase « preuve ultime » vérifiable par l'agent, et éventuellement une vérification intermédiaire silencieuse.
3. **Faire valider le critère.** Une reformulation par l'opérateur n'est pas une validation : reproposer et redemander un OUI explicite. Sans critère validé, on ne démarre pas.
4. **Le critère devient un test exécutable** : un script qui sort 0 si PASS, 1 si FAIL. Celui qui travaille ne s'auto-évalue jamais ; le script (et, dans le moteur, le juge isolé) joue le rôle d'évaluateur externe.
5. **Marqueur de mission active** : tant qu'il existe, aucun message ressemblant à une conclusion (« on a fini », « inatteignable », « voici trois alternatives ») sans PASS vérifié.

Pourquoi : le mode d'échec n°1 du loop engineering est « pas de vérification objective du but : l'agent affine indéfiniment » ou, pire, croit avoir réussi.

## Forme d'une itération (ReAct)

**Hypothèse** (une ligne, réfutable : « je teste X parce que Y dit que Z »), **action** (le test le plus court qui confirme ou réfute), **observation** concrète (« avant : …, après : … »). Rien d'observable n'a changé = itération nulle, et c'est un signal. Tout est journalisé.

## Variation de stratégie (réflexion forcée)

Après **3 itérations consécutives du même cluster d'hypothèses** (même mécanisme central, même méthode de test) échouées : arrêt des variations ; **recherche en ligne obligatoire** sur le blocage exact (forums, issues, pas seulement la documentation) ; 2 ou 3 angles radicalement différents (pivot, parallélisation, attaque de l'environnement plutôt que du problème, regard neuf d'un agent frais) ; reprise sur l'angle le plus prometteur hors du cluster d'origine.

## Battement de cœur (anti-flailing)

Toutes les ~5 itérations ou ~20 000 jetons : « progression observable depuis le dernier battement ? ». Non = signal de tourner en rond, réflexion forcée même sans 3 échecs ; deux « non » de suite = pivot majeur.

## Recherche

Avant d'agir sur un fait incertain (nom de champ, comportement d'API, syntaxe) : chercher d'abord. Bloqué : chercher avant l'hypothèse suivante. Raffinage d'une approche qui progresse : inutile. Se calibrer en cours de route : « ai-je perdu du temps faute de recherche ? ».

## Arrêt

Autorisé **uniquement** : (a) le test de succès renvoie PASS (marqueur retiré, succès annoncé une fois, sobrement), (b) l'opérateur dit stop.
Ne sont pas des sorties : « critère inatteignable », « voici trois scénarios », « meilleur résultat atteignable », ou redéfinir l'objectif. **Renégocier le critère est un abandon déguisé.**
Si on croit être à un mur : poser **une** question, « je suis à un mur après N angles et X recherches en ligne, le test est toujours en échec ; je continue (sur quel angle) ou tu arrêtes ? ». C'est l'opérateur qui tranche.

## Blocage dur (seul cas où l'on cherche l'humain)

Seulement si avancer exige irréductiblement l'opérateur : H1 secret ou identité (mot de passe, double authentification, session personnelle), H2 monde physique (brancher, presser), H3 jugement subjectif délégué, H4 autorisation externe. Le travailleur écrit `mission-blocked` dans le dossier de la mission (raison et palier) et termine ; le moteur s'arrête et notifie. « Plus rapide », « plus simple » et « je ne sais pas » ne sont **pas** des blocages durs.

## Anti-patterns

• Tâtonner sans avoir cherché doc, forum ou issues d'abord.
• « Je sais ce que je fais » sans vérification.
• Une 4e, 5e, 6e variation du même cluster après 3 échecs.
• « Ça marche » sans avoir lancé le test du critère ; s'évaluer avec ses propres journaux.
• Ignorer un battement de cœur « pas de progrès ».
• Un critère formulé en jargon.
• Le soft-abandon par « offre d'alternatives ».

## Persistance des apprentissages (optionnel, sur demande)

Une découverte utile au-delà de la session (comportement d'une API, champ piégeux) peut être consignée avec la trace de la boucle (hypothèses testées et résultat), pour qu'un agent futur évite la même impasse.

## Limites

Un script de test est un juge déterministe : il n'audite pas le raisonnement, seulement l'état observable. Pour un succès subjectif (qualité de prose, design, pertinence), le juge LLM isolé du moteur est le garde-fou ; il reste faillible.

Inspirations : la « boucle Ralph » de Geoffrey Huntley (état sur disque, relance à chaque tour) et les crochets d'arrêt de Claude Code (un marqueur physique que l'agent ne peut pas supprimer sans satisfaire les conditions).
