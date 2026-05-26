# Post-Fork Setup

After clicking "Use this template" on GitHub and cloning your fork locally.

## 1. Prerequisites you must have

- WSL2 Ubuntu, native Linux, or macOS
- An [OpenRouter account](https://openrouter.ai/) (free tier is enough)
- [VS Code](https://code.visualstudio.com) with the [Cline extension](https://marketplace.visualstudio.com/items?itemName=saoudrizwan.claude-dev)

Everything else (`git`, `python3`, `pipx`, `aider`) is installed by `setup.sh`.

## 2. Run setup

```bash
cd ~/projects/your-project
./setup.sh
```

You'll be prompted for your OpenRouter API key. Get one at https://openrouter.ai/keys.

Then activate in this shell:
```bash
source ~/.bashrc
planner-status
```

`planner-status` should show:
- Project path
- Active planner model (GLM)
- Primary and backup models defined
- API key set

## 3. Configure Cline

Open VS Code in the project:
```bash
code .
```

In Cline's settings:
1. Set your **executor model**. Recommended: a code-strong model like Nemotron, DeepSeek-Coder, or any model that fits your OpenRouter usage.
2. Confirm Cline reads `.clinerules` on every task (default behavior).
3. Optional: increase context window if your project will be large.

## 4. Customize memory files

The seeded `ai/*.md` files are generic placeholders. Edit them with your project's reality:

- `ai/architecture.md` — your stack, services, data flow
- `ai/roadmap.md` — your milestones, ordered by priority
- `ai/decisions.md` — start empty; planner appends as work proceeds
- `ai/repo_map.md` — file/module organization (update as it grows)

Leave `ai/bootstrap.md` alone unless you have a strong reason — it defines the planner role.

Commit:
```bash
git add ai/ && git commit -m "init: project memory"
```

## 5. First planning cycle

```bash
planner
```

A useful first prompt:
> Read the architecture and roadmap. Propose the first executable task for Cline. Write it to `ai/current_task.md` following the schema in `HANDOFF_FORMAT.md`.

When Aider finishes:
1. `Ctrl+C` to exit
2. Open Cline in VS Code
3. Send: *"Read `ai/current_task.md` and execute it. Follow `.clinerules`."*
4. Review the diff, commit:
   ```bash
   git add -A && git commit -m "task: <short description>"
   ```
5. Back to `planner` for the next cycle

## 6. When GLM rate-limits

Free-tier OpenRouter models hit limits. Swap to backup:
```bash
planner-swap     # → DeepSeek
planner          # resume
```

Run `planner-swap` again to switch back.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `planner: command not found` | Shell hasn't sourced env | `source ~/.bashrc` or new terminal |
| `OPENROUTER_API_KEY not set` | env file corrupted | Re-run `./setup.sh` |
| `Another planner is already running` | Stale lock | `rm .aider/planner.lock` |
| Permission denied on `run_planner.sh` | Lost exec bit | `chmod +x run_planner.sh` |
| Aider says rate-limited | GLM free tier exhausted | `planner-swap` |
| `pipx: command not found` after install | New shell needed | Open new terminal |

## Uninstall

Removes the global command, env file, and `~/.bashrc` block. Project files preserved.
```bash
./setup.sh --uninstall
```
