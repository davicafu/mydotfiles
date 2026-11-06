# Global instructions

Loaded in every project. A project's own CLAUDE.md/AGENTS.md wins where they disagree.

## Principles

- Simple and explicit over clever. No speculative functionality, no new abstractions or dependencies without a real need.
- The amount of process follows the size and risk of the task (Protocol, step 2).
- Deep modules with small, explicit interfaces; the domain's own vocabulary (`domain-modeling`); small vertical slices that run end to end.
- Record significant architectural decisions as ADRs.

## Route by task

Before acting, match the task to a skill and load it; its steps replace your default approach. A skill that is not installed is skipped: follow the protocol below instead. Skills from Claude Code plugins may carry the plugin's prefix (`mattpocock-skills:`, `cc-skills-golang:`). A project skill covering the same ground runs alongside these, and its conventions win.

| Task | Skill |
|---|---|
| Reviewing someone's PR or branch | `thermo-nuclear-code-quality-review`, plus `council-review` for a second, independent read |
| Live production problem on ClickHouse | `clickhouse-cloud-ops` |
| Standup summary of a day's work | `daily` |
| Bug, failing test, unexpected behaviour, regression | `diagnosing-bugs` |
| Writing or changing code with tests | `tdd` |
| Go code (style, errors, concurrency, testing, performance) | the matching `golang-*` skill (samber pack) |
| Module boundaries, interfaces, seams, testability | `codebase-design` |
| Domain terms, glossary, ADRs | `domain-modeling` |
| Stress-testing a plan or idea | `grilling` |
| Design question a throwaway build can answer | `prototype` |
| Facts from docs or primary sources | `research` |
| Steps only a human can do (credentials, dashboards, infra) | `wizard` |
| Writing a PR body | `pr` |
| Context running out, or another agent continues | `handoff` |
| Writing a skill, CLAUDE.md or AGENTS.md | `writing-for-agents` |

A project's instructions go in its AGENTS.md; its CLAUDE.md is a single `@AGENTS.md` line, so every agent reads the same file.

## Protocol

1. **Understand.** Read the code, config and docs the task touches. Ask only for decisions that are mine and that the repo cannot answer; for the rest, pick the conventional option and say which.
2. **Scale the process to the task (ODD).** Add structure only in proportion to what the work requires, and never ask me for commands per change.
   - **Simple** (one-line fix, rename, small isolated change): just do it.
   - **Uncertain** (unknown behavior, unclear API, unfamiliar code): research first (`research`), then decide. Do not touch code until the uncertainty is resolved.
   - **Substantial** (multi-step, new feature, design work): write a feature doc I can see before code changes, with goal, scope and non-goals, a checklist where each step ends on a checkable result, acceptance criteria, and an evidence section filled in as you verify. This doc is the plan; for architectural changes it states the trade-offs. Save a summary and a pointer to it in Engram, not a copy.
   - **Critical** (auth, payments, data migrations, concurrency, anything that touches production behavior): everything above, plus observed TDD (`tdd`): show the test failing (Red), passing (Green), then Refactor, with the output of each phase.
   - If unsure of the level, pick the lower one and say so; escalate if the work proves bigger than it looked.
3. **Change.** Match the surrounding code: naming, comment density, idioms, language of comments and docs. Keep the diff to what was asked; report anything else you notice instead of fixing it.
4. **Debug from evidence.** Reproduce first, find the root cause, then fix. A fix without a reproduction is a guess.
5. **Verify.** Run the check that proves it (tests, linter, dry run, the command itself) and read its output. Review the final diff for unintended changes. A claim without evidence is a hypothesis; label it so. Never claim tests passed without running them; say what could not be run.
6. **Report.** Lead with the outcome: what changed, how it was verified, what was skipped or failed, and the exact output for failures. State assumptions. Never invent results, implementation details or dependencies.

Review feedback, mine or a reviewer's, is checked against the code before acting on it: agree where it holds, and say why where it does not.

## Guardrails

- **Outward-facing actions wait for my yes.** PR comments, approvals, reviews, issue updates, chat messages, emails: show me the exact text first and post only after I approve. Approval covers that one action.
- **Commit and push only when I ask.** Stage only the files of the task; other uncommitted changes are mine.
- **Production is read-only.** Write statements, migrations, scaling and config changes are written out for me to run; you do not run them.
- **Back up before replacing.** Before deleting or overwriting anything you did not create in this session, look at it and keep a copy.
- **Secrets stay out of chat, commits and logs.** Point to where a credential is needed; I provide it.

## Memory

- The agent's built-in memory (Claude Auto Memory or its equivalent), if it has one: stable operational preferences and useful repo-specific reminders.
- Engram: durable technical discoveries, architectural decisions, historical context. For feature docs, store a summary, the decisions and a pointer, never the full text.
- Feature docs live in the repo (default `docs/features/<name>.md`, unless the project says otherwise).
- Do not save every command, interaction or temporary task detail; retrieve only history relevant to the current task.
- Repository docs and current source code are authoritative over stale memories.
