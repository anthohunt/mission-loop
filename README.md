# mission-loop: a goal-driven loop for problems with an unknown path

You know **where** you want to go (a clear goal), not **how**. `mission-loop` runs a Claude Code agent loop against a **written success criterion** and stops **only** when an independent judge says it is met (or a human says stop).

Three roles, state on disk:

- a **foreman** (the loop, `engine/mission-loop.sh`) picks the next unfinished task;
- fresh **workers** (`claude -p`) do one bounded pass, journal what they did and produce proofs;
- an isolated, adversarial **judge** (`claude -p`, started by the loop, never by the worker) re-checks the proofs on disk and writes `VERDICT: PASS` or `FAIL` with concrete gaps. In doubt, it rejects.

A mission is a folder (`~/.claude/missions/<slug>/`) holding a *card* (goal, criterion, tasks with required proofs), a journal, per-task state, evidence and verdicts. A new worker is as good as the previous one because the memory is the folder, not a conversation.

The skill (`skills/mission/SKILL.md`, in French) is the doctrine an interactive agent follows to write the card with you: the criterion in plain words, validated by you, turned into an executable test; forced reflection after three failures of the same kind; a progress heartbeat; no exit but verified success. This README is in English; the skill, prompts and scripts' messages are in French.

## Install

```bash
git clone https://github.com/anthohunt/mission-loop
mkdir -p ~/.claude/skills && cp -r mission-loop/skills/mission ~/.claude/skills/
```

Requirements: bash ≥ 4 (5.x tested), `awk`, `grep`, `sed`, and [Claude Code](https://docs.claude.com/en/docs/claude-code) logged in (a separate Anthropic product under Anthropic's terms; only called here). Linux and macOS; on Windows use Git Bash (paths are converted with `cygpath` when available).

## Use

```bash
E=~/.claude/skills/mission/engine
bash $E/mission-new.sh my-mission card.md        # card.md from engine/templates/MISSION-CARD-template.md
bash $E/mission-loop.sh my-mission               # wakes every 20 minutes by default (second argument: seconds)
```

Settings (environment): `MISSIONS_ROOT` (default `~/.claude/missions`), `MISSION_CLAUDE_BIN`, `MISSION_WORKER_MODEL` (default `sonnet`), `MISSION_JUDGE_MODEL` (default `opus`), `MISSION_PERMISSION_MODE` (default `bypassPermissions`), `MAX_TICKS`, `MISSION_NOTIFY_CMD` (a command called with a message on success or hard block).

**Safety.** The default permission mode lets agents run commands without asking, which is what an unattended loop needs and also what makes it dangerous. Run it in a container or on a throwaway machine, never with credentials you cannot lose. A worker that needs a human (a secret, a physical action, a subjective call, an external authorisation) writes `mission-blocked` in the mission folder: the loop stops and notifies.

## Dry run (no model call)

```bash
bash $E/mission-loop.sh --dry-run my-mission
```

Renders the prompt of the next turn (worker, or judge if the task is marked ready) into `<mission>/dryrun/`, checks that no `{{placeholder}}` is left empty, and stops without calling a model or changing the mission's state. `bash tests/test-installation.sh` runs a full check, including a complete loop played by a fake `claude`.

## Layout

- `skills/mission/SKILL.md` — the doctrine (French).
- `skills/mission/engine/` — `mission-new.sh`, `mission-loop.sh`, `templates/` (card, worker prompt, judge prompt).
- `exemples/carte-compteur-de-mots.md` — a small example card.
- `tests/test-installation.sh` — installation proof without any model.

## Licences

Code (`engine/*.sh`, `tests/`): **Apache 2.0** (`LICENSE`, `NOTICE`). Skill text, templates, example and documentation: **CC BY 4.0** (`LICENSE-docs`). Inspired by the [Ralph loop](https://ghuntley.com/ralph/); no code copied. No third-party code is included. Author: Anthony Hunt.
