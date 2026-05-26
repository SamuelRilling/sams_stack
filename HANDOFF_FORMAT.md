# Handoff Format

How the planner (Aider) communicates with the executor (Cline) via `ai/current_task.md`.

**This format is a v1 starting point.** Revisit after 5–10 real cycles and update — your real friction points will reveal what's missing.

## The contract

- Planner writes `ai/current_task.md`. Overwrites each cycle.
- Executor reads it, implements, stops.
- One task per file. If you find yourself writing two, split into two cycles.

## Schema

```markdown
# Task: <short imperative title>

## Context
<2–5 sentences. Why this task, what came before. Link to roadmap item.>

## Goal
<One sentence. What "done" looks like.>

## Files in scope
- `path/to/file.ext` — <what to do here>
- `path/to/another.ext` — <create / modify / delete>

## Steps
1. <Concrete, verifiable action>
2. <Next action>
3. ...

## Acceptance criteria
- [ ] <Testable outcome>
- [ ] <Another testable outcome>
- [ ] Tests pass: `<command to run>`

## Out of scope
- <Things the executor should NOT do, even if tempting>

## Notes for executor
<Optional. Library versions, gotchas, style preferences not in .clinerules.>
```

## Rules for the planner

1. **One task only.** Two goals → two cycles.
2. **No code.** Pseudocode or interface sketches OK if needed. No full implementations.
3. **Specific files.** "Update the API" is bad. "Modify `src/api/users.ts` to add `getById`" is good.
4. **Verifiable acceptance criteria.** "Looks good" fails. "Returns 200 with valid JSON" passes.
5. **Explicit out-of-scope.** Executors pattern-match and over-deliver if you don't fence them.

## Rules for the executor

1. **Don't exceed scope.** If a fix outside `Files in scope` seems necessary, stop and ask.
2. **Run acceptance checks yourself.** No claiming done without running the test command.
3. **If blocked, write back.** Append a `## Blocker` section to `current_task.md` and stop. Don't invent solutions to ambiguous specs.

## Anti-patterns

| Symptom | Why it's a problem |
|---|---|
| Task is "implement the user system" | Too big; impossible to verify done |
| Acceptance criteria say "code is clean" | Not testable |
| No `Files in scope` | Executor touches unrelated files |
| Multiple `Goal` sections | This is two tasks; split |
| `Steps` reads like a Stack Overflow answer | You're writing code in the planner — stop |

## Example

See `docs/examples/handoff.md` for a real handoff produced during template development.
