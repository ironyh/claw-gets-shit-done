# Persona & Flow Settings

Personas are advisory. GSD + queue remain execution authority.

## Default Recommendation

Use a lean role set by default:
- `VD` (priority/business framing)
- `Programmer` (implementation path)
- `QA` (risk + verification gate)

Add extra roles only when needed:
- `Designer` for UX-heavy work
- `DevOps` for CI/CD/infrastructure
- `Security` for auth/data-risk changes
- `SEO/SEM` for growth/discovery tasks

## Suggested Discussion Pattern

1. Round 1 (input): each role gives one recommendation + risk
2. Round 2 (challenge): limited role-to-role questions
3. Round 3 (converge): one decision and one `gsd_action`

Guardrails:
- max 2 role-to-role pings per role per thread per run
- no decision without acceptance criteria
- no execution without queue linkage

## Flow Presets

Small feature:
- VD -> Programmer -> QA

UX feature:
- VD -> Designer -> Programmer -> QA

Platform/reliability:
- VD -> DevOps -> Programmer -> QA (+ Security if auth/data)

Growth feature:
- VD -> SEO/SEM -> Programmer -> QA

## Anti-Pattern To Avoid

- long persona debate without explicit `promote_to_queue|need_more_data|reject`
- roles directly changing priority outside GSD/queue
- marking work done before verify evidence
