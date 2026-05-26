# Claude Code Prompts

Three prompts to publish Sam's Stack. Run them in order from `~/projects/sams_stack/` after unzipping the package there.

---

## Prompt 1 — Verify local setup

```
I have just unzipped the Sam's Stack template into this directory. Before publishing, verify:

1. Run: ls -la
   Confirm these files/dirs exist: setup.sh, README.md, TEMPLATE_SETUP.md, HANDOFF_FORMAT.md, LICENSE, .clinerules, .gitignore, ai/, docs/, test/, .github/

2. Run: chmod +x setup.sh test/test_setup.sh

3. Run: bash -n setup.sh && bash -n test/test_setup.sh
   Both must succeed (syntax check).

4. Run: ./test/test_setup.sh
   Must exit 0 with "All tests passed." Report the test count.

5. Read README.md and check for:
   - Any reference to my personal info that should not be public (paths like /home/samuel/, my OpenRouter key, etc.)
   - Broken markdown links

6. Read setup.sh and check for any hardcoded paths that should be dynamic.

Stop after step 6 and show me a summary. Do not modify any files yet.
```

---

## Prompt 2 — Initialize as standalone repo and push to GitHub

```
Now initialize this directory as a new git repo and prepare to push to GitHub.

1. Run: git init && git branch -M main

2. Run: git add -A && git status
   Show me what will be committed.

3. Verify .gitignore is working:
   - Run: git check-ignore .planner_env .aider/chat.md 2>&1
   - Both should be reported as ignored. If not, stop and report.

4. Verify no secrets in tracked files:
   - Run: git ls-files | xargs grep -l "sk-or-v1-[a-zA-Z0-9]" 2>/dev/null
   - If anything matches, STOP and tell me. Do not commit.

5. Create the initial commit:
   git commit -m "feat: initial release of Sam's Stack template"

6. Tell me to:
   a. Create a new public repo on GitHub named "sams_stack" (do not initialize it with a README on GitHub)
   b. Add the remote and push:
      git remote add origin https://github.com/samuelrilling94/sams_stack.git
      git push -u origin main

7. After I confirm the push succeeded, instruct me to:
   a. Go to repo Settings → General
   b. Scroll to "Template repository" — check the box
   c. Verify the "Use this template" button appears on the repo homepage

Do not execute the push or any GitHub operations yourself. Show me the exact commands and wait.
```

---

## Prompt 3 — Test the template end-to-end as a user would

```
Now validate the template works for someone using it for the first time.

1. Create a sandbox dir: mkdir -p ~/projects/sams_stack_test && cd ~/projects/sams_stack_test

2. Simulate the "Use this template" → clone flow:
   git clone https://github.com/samuelrilling94/sams_stack.git ./my-test-project
   cd ./my-test-project

3. Examine the cloned repo: ls -la
   Confirm everything from the original template is present.

4. Show me what the user would see if they ran ./setup.sh --help (without actually running setup since it would modify my real ~/.planner_env and ~/.bashrc).

5. Do a dry validation:
   - bash -n setup.sh (syntax)
   - ./test/test_setup.sh (full test suite — uses sandboxed HOME, will NOT touch my real config)
   - Report results.

6. Verify the GitHub CI workflow file is syntactically valid:
   - Read .github/workflows/ci.yml
   - Confirm it has on: triggers, two jobs (test, validate-docs), and runs ./test/test_setup.sh

7. Suggest 3 improvements I could add later (do not implement). For example: shellcheck strict mode, a release-tagging script, a project-name placeholder system.

8. After we confirm the template works:
   - Clean up: cd ~/ && rm -rf ~/projects/sams_stack_test

Stop after step 8. Do not push more changes unless I ask.
```

---

## Suggested order of operations on your end

1. Download the zip, extract to `~/projects/sams_stack/`
2. `cd ~/projects/sams_stack && claude code`
3. Run Prompt 1. Review output. Fix anything flagged.
4. Run Prompt 2. Manually execute the GitHub commands when shown.
5. Mark the repo as a Template (Settings → General → Template repository).
6. Run Prompt 3 to validate the full clone → setup flow works.
7. Tag a release: `git tag v0.1.0 && git push --tags`
8. Optional: add a GitHub release with notes.

## After publishing

To use the template for a real project:
1. Click "Use this template" on the repo page
2. Name your new project (e.g., `sernac-complaint-generator`)
3. Clone, run `./setup.sh`, start building.
4. Each new fork is independent — they don't share `~/.planner_env` since that's keyed to project directory.

Wait — actually the env file is in `$HOME` and shared across forks. The `PROJECT_DIR` var inside it points to one project. If you're juggling multiple template-based projects, run `./setup.sh` in each to repoint. Easy enhancement later: per-project env files.
