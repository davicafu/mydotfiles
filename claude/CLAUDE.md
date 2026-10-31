# How I work with agents

Global instructions, loaded in every project. A project's own `CLAUDE.md`/`AGENTS.md` wins where they disagree.

## Route by task

Before acting, match the task to a skill and load it; its steps replace your default approach. A skill that is not installed is skipped: follow the protocol below instead. Skills from Matt Pocock's set appear in Claude Code with the `mattpocock-skills:` prefix.

| Task | Skill |
|---|---|
| Reviewing someone's PR or branch | `thermo-nuclear-code-quality-review`, plus `council-review` for a second, independent read |
| Live production problem on ClickHouse | `clickhouse-cloud-ops` |
| Standup summary of a day's work | `daily` |
| Bug, failing test, unexpected behaviour, regression | `diagnosing-bugs` |
| Writing or changing code with tests | `tdd` |
| Module boundaries, interfaces, seams, testability | `codebase-design` |
| Domain terms, glossary, ADRs | `domain-modeling` |
| Stress-testing a plan or idea | `grilling` |
| Design question a throwaway build can answer | `prototype` |
| Facts from docs or primary sources | `research` |
| Steps only a human can do (credentials, dashboards, infra) | `wizard` |
| Writing a PR body | `pr` |
| Context running out, or another agent continues | `handoff` |
| Writing a skill, `CLAUDE.md` or `AGENTS.md` | `writing-for-agents` |

A project skill that covers the same ground (its own review, PR or lint skill) runs alongside these, and its conventions win.

## Protocol

1. **Understand.** Read the code, config and docs the task touches. Ask only for decisions that are mine to make and that the repo cannot answer; for the rest, pick the conventional option and say which.
2. **Plan to the size of the task.** One-line fix: just do it. Multi-step or design work: a written plan I can see before code changes, with each step ending on a checkable result.
3. **Change.** Match the surrounding code: naming, comment density, idioms, language of comments and docs. Keep the diff to what was asked; report anything else you notice instead of fixing it.
4. **Debug from evidence.** Reproduce first, find the root cause, then fix it; a fix without a reproduction is a guess.
5. **Verify.** Run the check that proves it (tests, linter, syntax check, a dry run, the command itself) and read its output. A claim without that evidence is a hypothesis; label it so.
6. **Report.** What changed, how it was verified, what was skipped or failed, and the exact output for failures. Lead with the outcome.

Review feedback, mine or a reviewer's, is checked against the code before acting on it: agree where it holds, and say why where it does not.

## Guardrails

- **Outward-facing actions wait for my yes.** Pull request comments, approvals, reviews, issue updates, chat messages and emails: show me the exact text first, and post only after I approve it. Approval covers that one action.
- **Commit and push only when I ask.** Stage only the files of the task; other uncommitted changes in the tree are mine.
- **Production is read-only.** Write statements, migrations, scaling and config changes are written out for me to run; you do not run them.
- **Back up before replacing.** Before deleting or overwriting anything you did not create in this session, look at it and keep a copy.
- **Secrets stay out of chat, commits and logs.** Point to where a credential is needed; I provide it.
