# Git Conventions

> Shared git operation standards for all AI tools and all platforms.

---

## Commit Rules (mandatory)

- **No empty commits**: Do not create a commit when there are no changes
- **Atomic commits**: One commit does one thing -- do not bundle unrelated changes
- **Build before commit**: Code must compile before committing (except spec/doc-only commits)

---

## Commit Message Format

```
<type>(<scope>): <subject>

<body>
```

### Type Reference

| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `refactor` | Restructuring (not a new feature, not a fix) |
| `style` | Code formatting (no runtime impact) |
| `docs` | Documentation only |
| `test` | Adding/modifying tests |
| `chore` | Build tooling, dependency, or config changes |

### Scope

Scope identifies the affected module or area. Examples:
- `feat(chat): add message recall`
- `fix(profile): fix avatar upload failure`
- `refactor(network): unify error handling`
- `docs(specs): update task status`
- `chore(deps): bump library version`

### Subject Line Rules

- Imperative mood: "add feature" not "added feature"
- No period at end
- Max 72 characters
- Lowercase first letter (after type prefix)

### Body (optional)

- Explain **why**, not just **what**
- Wrap at 72 characters
- Separate from subject with a blank line
- Reference task IDs when applicable: `(T{nn})`

### Task Commit Examples

```
feat(settings): implement self-setting page (T06)

chore(specs): mark T06 as in-progress (ios)

fix(chat): handle nil message timestamp in list render

refactor(network): extract common pagination logic
```

---

## Branch Naming

| Branch Pattern | Purpose |
|----------------|---------|
| `master` / `main` | Stable main branch |
| `feat/v{version}` | Version integration branch (merge target) |
| `feat/{repo}/{version}` | Platform version branch |
| `feat/{scope}` | Feature branch |
| `fix/{scope}` | Fix branch |
| `refactor/{scope}` | Refactor branch |

### Version Branch Convention

```
master (stable)
  |
  +-- feat/v{version}     <- version integration branch
       |
       +-- (all task commits land here directly when using version worktree)
```

When using per-task worktrees (legacy mode):
```
feat/v{version}
  +-- feat/{repo}/{date}/T{nn}-{task-name}   <- task branch
```

---

## Merge Conflict Handling

When conflicts arise:

### General Rules

1. **Analyze both sides**: Read the conflicting changes, understand intent of each
2. **Never blindly pick one side**: `git checkout --ours` or `--theirs` loses information
3. **Manual merge**: Combine both sets of changes where possible
4. **Build verify after resolve**: Conflicts resolved -> must compile before commit
5. **Test after resolve**: Verify no runtime regression from the merge

### Build/Config File Conflicts (special care)

For dependency configuration files (Podfile, build.gradle, package.json, etc.):
- Never use `git checkout --ours/--theirs` (may drop dependency declarations)
- Check both sides for added dependencies/configs
- Manually merge: keep all additions from both sides
- Run dependency install after resolve (pod install, gradle sync, npm install)
- Build verify is mandatory

### Specs File Conflicts

When two agents update specs files simultaneously:
- `tasks/ios.md` and `tasks/android.md` are independent files -> no conflict expected
- Before each specs commit: `git pull --rebase` to pick up other agent's changes
- Rebase conflict -> attempt auto-resolve, if complex -> report and wait for human

### Conflict Resolution Commit

```
merge: resolve conflict in {filename}

Kept both: {side A's change} + {side B's change}
Reason: {why this resolution is correct}
```

---

## Pre-Commit Checklist

Before every commit, verify:

```
[ ] Changes are related (atomic commit)
[ ] Code compiles (for code changes)
[ ] Commit message follows format
[ ] No secrets or credentials in staged files
[ ] No unintended files staged (check git diff --cached)
```

---

## Specs Repo Git Workflow

When committing to the specs repo (task status updates, logs):

```
1. cd {specs_repo}
2. git pull --rebase   <- pick up changes from other agents
3. git add {specific_files}
4. git commit -m "{message}"
5. If rebase needed -> resolve, then continue
```

Never use `git add .` or `git add -A` in the specs repo -- always stage specific files to avoid committing unrelated changes.
