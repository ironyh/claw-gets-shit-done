# Wizard Roadmap

Short answer: more wizards are not overkill if they reduce setup mistakes.

## Principle

Add a wizard when:
- users repeatedly misconfigure the same area
- the wizard can ask 3-7 clear questions
- outputs are deterministic flags/config files

Do not add a wizard when:
- it only wraps one command with no branching
- defaults already work for most users

## High-ROI Wizards

## 1) Install Wizard (already present)

Current value:
- path autodetect
- project bootstrap mode selection
- loop + delivery baseline prompts

## 2) Discord Wiring Wizard (implemented)

Questions:
- delivery channel/thread id
- forum channel id
- slash allow strategy (`*` vs explicit ids)

Outputs:
- installer flags
- plugin local config
- allowFrom patch

## 3) Loop Tuning Wizard (recommended next)

Questions:
- cadence profile (`stable|balanced|aggressive`)
- max files per run
- multi-sub-agent parallelism

Outputs:
- cron expressions
- scope/safety flags

## 4) Project Bootstrap Wizard (optional)

Questions:
- brownfield vs greenfield confirmation
- idea file selection
- bootstrap mode override

Outputs:
- first-run command plan (`/gsd-map-codebase`, `/gsd-new-project`, etc.)

## Rollout Plan

Phase 1:
- keep existing interactive installer
- add docs + preset command bundles (done)

Phase 2:
- keep Discord Wiring Wizard in interactive installer
- add Loop Tuning Wizard presets/profiles

Phase 3:
- optional project bootstrap helper wizard if support load justifies it
