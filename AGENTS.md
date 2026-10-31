# Project instructions

## Project

Generic, language-agnostic starting point for new repositories in the `lengors-labs`
organization: it carries the repository-level content that cannot be inherited from
`lengors-labs/.github` — code owners, license, README, these instructions and the
release pipeline — and is consumed through GitHub's "Use this template" feature
rather than by branching.

No package manager or build system. Changes are Markdown, YAML and one JavaScript
configuration file for semantic-release; there is no test suite. Verify a change by
reviewing the rendered Markdown, parsing the YAML and JavaScript for syntax errors,
and, when references are touched, by following the linked paths in the
`lengors-labs` organization.

Note: every generated repository starts from this content, so treat edits here as
changes to the baseline of all future projects. Keep files generic — nothing specific
to a language, framework or program type belongs in this repository.

## Commit conventions (gitmoji + semver)

Always commit with gitmoji: `<gitmoji> <short message>` — a single-line subject, no body.
The emoji determines the semantic-release bump, so pick it by the *impact* of the change.

**Major (breaking):**
- 💥 `:boom:` — Introduce breaking changes. If a removal or other change is breaking, use 💥 instead of the "normal" emoji for that change type.

**Minor:**
- ✨ `:sparkles:` — Introduce new features.
- 🗑️ `:wastebasket:` — Deprecate code that needs to be cleaned up (still works; actual removal later = 💥 major).

**Patch:**
- 🐛 `:bug:` — Fix a bug.
- ✏️ `:pencil2:` — Fix typos.
- 🔒 `:lock:` — Fix security or privacy issues.
- 🔐 `:closed_lock_with_key:` — Add or update secrets.
- 🚑️ `:ambulance:` — Critical hotfix.
- ⚡️ `:zap:` — Improve performance.
- ♻️ `:recycle:` — Refactor code (no behavior change).
- 💄 `:lipstick:` — Add or update the UI and style files.
- ➕ `:heavy_plus_sign:` — Add a dependency.
- ➖ `:heavy_minus_sign:` — Remove a dependency.
- ⬆️ `:arrow_up:` — Upgrade dependencies.
- ⬇️ `:arrow_down:` — Downgrade dependencies.
- 📌 `:pushpin:` — Pin dependencies to specific versions.
- 🔧 `:wrench:` — Add or update configuration files.
- 👷 `:construction_worker:` — Add or update CI build system.
- 💚 `:green_heart:` — Fix CI Build.
- 🍱 `:bento:` — Add or update assets.
- 📦 `:package:` — Add or update compiled files or packages.
- 🥅 `:goal_net:` — Catch errors.
- 🔊 `:loud_sound:` — Add or update logs.
- 🔇 `:mute:` — Remove logs.
- 📱 `:iphone:` — Work on responsive design.
- 🔥 `:fire:` — Remove code or files (non-breaking; if breaking → 💥 major).

**No release triggered:**
- 📝 `:memo:` — Add or update documentation.
- 🎨 `:art:` — Improve structure / format of the code.
- ✅ `:white_check_mark:` — Add, update, or pass tests.
- 🧪 `:test_tube:` — Add a failing test.
- 💸 `:money_with_wings:` — Add sponsorships or money related infrastructure.
- 📄 `:page_facing_up:` — Add or update license.
- 🙈 `:see_no_evil:` — Add or update a .gitignore file.
- 💡 `:bulb:` — Add or update comments in source code.

Rules of thumb:
- "Does this break consumers?" Yes → 💥. No → use the specific emoji above.
- Deprecation is minor; actual removal is major.
- When in doubt between two emojis, prefer the one describing *what changed*, not why.

**Grouping:** one logically coherent concern per commit — if a single issue or request spans multiple features/fixes/chores, make one commit per unit. Tests go in their own ✅ commit (separate from the implementation they cover). If you find yourself wanting two different gitmoji for one change, split it into separate commits.

The table above is the contract: `.releaserc.js` carries its machine-readable form and
derives the version bump and the changelog section from it. Editing one without the
other silently changes what a commit means, so treat them as a single change.

## Release conventions

Pushes to `main` and `rc` run semantic-release. `main` contains released code only;
`rc` is the long-lived integration branch and topic branches are cut from it.

| Branch | Role | Version produced |
| :--- | :--- | :--- |
| `main` | Default. Released code only. | `1.2.0` |
| `rc` | Integration. Work merges here first. | `1.2.0-rc.1` |
| `feat/**`, `bug/**`, `chore/**` | Topic branches, cut from `rc`. | — |

- Versions live in git tags (`v1.2.0`). Nothing is written into a file, so there is
  no version to bump, commit or keep in sync between branches.
- `rc` deliberately restarts at `.1` after a final ships: once `1.1.0` is released,
  the next feature on `rc` opens `1.2.0-rc.1`.
- Promotion is a merge of `rc` into `main`, never a force-push — `main` only moves
  forward.
- Do not hand-edit versions, changelogs or tags: the pipeline owns them.

A language template derived from this one is the only place a build tool enters the
picture, through a `prepare` step that writes `${nextRelease.version}` into the file
the tool reads, plus a `@semantic-release/git` asset so that file is committed:

```js
['@semantic-release/exec', {
  prepareCmd: './mvnw versions:set -DnewVersion=${nextRelease.version}',
}],
['@semantic-release/git', {
  assets: ['pom.xml'],
  message: '🔖 Update `pom.xml` to `${nextRelease.version}` [skip release]',
}],
```

`prepareCmd` receives the fully computed version including the prerelease suffix, so
`1.2.0-rc.1` needs no special handling. Keep the commit plugin last, and note that it
writes to whichever branch triggered the run — a template that keeps a version file
must therefore commit it on `main` only, or the two branches diverge permanently. This
is why the generic layer omits the plugin rather than shipping it disabled.

## Pull request conventions

When creating any pull request:
- Title format: 🔀 Merge `origin/<source_branch>` into `origin/<target_branch>` (backtick the branch refs, exactly this wording).
- Body: leave **empty** — do not pass a body.
- Assignee: set to yourself — the authenticated account (via `get_me`; if unavailable, resolve from git config user.email via search_users — note noreply emails are NOT indexed by search — or ask for the username instead of guessing). (`create_pull_request` has no assignee parameter and GitHub does not auto-assign authors on API-created PRs — set it post-creation with issue-update tooling.)

## Issue & PR linking

- Never use closing keywords (`Closes`, `Fixes`, `Resolves`) in commit messages or PR titles/bodies. Plain `#<number>` references are fine for cross-referencing.
- Never close issues manually; leave issue state to the user (they may link via the PR's Development sidebar — manual links auto-close on merge — or close it themselves).

## Git & GitHub safety

- Never force-push.
- Never delete branches, worktrees, or tags without explicit user confirmation. A worktree and the local branch checked out in it are one unit: when the user confirms deleting a worktree, that confirmation also covers its associated branch — remove the worktree first (`git worktree remove <path>`), then delete the branch (`git branch -d <branch>`). Use plain `-d`, never `-D`: if the branch has unmerged commits and deletion is refused, report it instead of force-deleting. Deleting a standalone branch (no worktree involved) still requires explicit confirmation naming that branch.
- If a GitHub API/tool call fails, stop and report the error — do not retry destructively.
- Ask before acting whenever identification is ambiguous (which issue, which project, which account).