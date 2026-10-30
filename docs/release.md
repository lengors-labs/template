# Versioning and releases

This repository ships the release layer that generated projects start from:
gitmoji commits become versions, changelogs and GitHub releases. The layer is
deliberately language-agnostic — nothing here knows about a build tool. The only
language-specific coupling point is described in
[Extending the pipeline](#extending-the-pipeline).

## Branch model

| Branch | Role | Channel | Produces |
| :--- | :--- | :--- | :--- |
| `main` | Default branch. Contains **released code only**. | default (`latest`) | `1.2.0` |
| `rc` | Long-lived **integration** branch. Work is merged here first. | `rc` | `1.2.0-rc.1` |
| `feat/**`, `bug/**`, `chore/**` | Short-lived topic branches, cut from `rc`. | — | — |

Topic branches are merged into `rc`; `rc` is promoted into `main` when a release
is due. Promotion is a merge, never a force-push: `main` only ever moves forward.

`rc` exists so that `main` can hold back work that is finished but not released.
One of the two has to be given up — either features land on the default branch
(and there is no hold-back), or a second branch diverges (and a promotion step
is required). This repository chooses the promotion step.

### Why `rc` and not `next`

`next` is a built-in **release** branch in semantic-release's default
configuration: work on it yields `1.1.0` on the `next` tag, not `1.1.0-next.1`.
`rc` is not, so it behaves as intended.

## Configuration

The pipeline is defined in [`.releaserc.js`](../.releaserc.js):

- `branches: ['main', { name: 'rc', prerelease: 'rc' }]` — the branch entry that
  matches the pushed branch supplies the prerelease identifier **and** the release
  channel. Neither is passed at runtime, so the workflow needs no per-branch
  configuration.
- `tagFormat: 'v${version}'` — there is one tag namespace for every release
  type; `v1.2.0-rc.1` and `v1.2.0` live in the same list.
- An inline plugin implements two steps:
  - `analyzeCommits` maps the commit's leading gitmoji to a release type, using
    the table in `AGENTS.md`. The emoji decides the bump: 💥 is major, ✨ and 🗑️
    are minor, the rest are patch, and the "no release triggered" emojis produce
    no release at all.
  - `generateNotes` groups the commits into changelog sections.
- `@semantic-release/github` publishes the release and pushes the tag.

`@semantic-release/npm` and `@semantic-release/git` are deliberately absent:
this repository publishes no package and writes no version into a file, so
nothing but the tag records the version.

### Version-file strategy

Three options exist for repositories that *do* keep a version in a file:

| | Strategy | Sync needed | Verdict |
| :--- | :--- | :--- | :--- |
| A | Bump on every branch | Yes — `main` and `rc` diverge in opposite directions and merge conflicts are recurring | Rejected |
| B | Bump on `main` only via a dynamic config | No — `rc`'s file reads as the last final version | Acceptable |
| **C** | **No version-file commits; the version comes from the tag** | **None** | **Chosen** |

Strategy A is rejected because the version file has a *different correct value*
on each branch (`1.2.0` on `main`, `1.2.0-rc.1` on `rc`), so the bump commit is
inherently branch-specific and the branches cannot stay fast-forwardable. This
repository has no build tool, which makes C free.

## Numbering across a release cycle

Verified empirically against semantic-release 24.2.9 with this configuration
(see [Verification](#verification)). Starting from `v1.0.0` on `main`:

| Step | Branch | Next version |
| :--- | :--- | :--- |
| First feature merged | `rc` | `1.1.0-rc.1` |
| Second feature merged | `rc` | `1.1.0-rc.2` |
| `rc` promoted into `main` | `main` | `1.1.0` |
| First feature after the promotion | `rc` | `1.2.0-rc.1` |

Two things worth knowing:

- **`main` ignores prerelease tags when resolving its last release.** With
  `v1.1.0-rc.1` and `v1.1.0-rc.2` already published, the promotion still computes
  `1.1.0`, not `1.1.1`.
- **`rc` restarts at `.1` after a final release.** The `1.1.0` line was consumed
  by the promotion, so the next feature opens `1.2.0-rc.1` rather than
  `1.1.0-rc.3`.

## Workflow

[`.github/workflows/publish-new-version.yml`](../.github/workflows/publish-new-version.yml)
runs on every push to `main` and `rc` and does one thing: run semantic-release.

Credentials come from a GitHub App rather than `GITHUB_TOKEN`, because commits
and tags created with `GITHUB_TOKEN` do not trigger further workflows and are not
attributed to a real actor. The required repository secrets are:

| Secret | Purpose |
| :--- | :--- |
| `GH_APP_ID` | GitHub App identifier, used to mint a short-lived token |
| `GH_PRIVATE_KEY` | GitHub App private key |
| `GPG_PRIVATE_KEY` | Signing key for the release tag |
| `GPG_PASSPHRASE` | Passphrase for the signing key |

The job runs in the `publisher` environment, so the secrets can be scoped to it
and protected by required reviewers.

## Extending the pipeline

Language templates derived from this one are the only place where a build tool
enters the picture, and they enter through a single hook: a `prepare` step that
writes the computed version into whatever file the tool reads.

```js
// .releaserc.js in a language template: copy this repository's config and add
// the two build-tool-specific plugins at the end.
plugins: [
  // ... the base inline plugin and @semantic-release/github ...

  ['@semantic-release/exec', {
    prepareCmd: './mvnw versions:set -DnewVersion=${nextRelease.version}',
  }],
  ['@semantic-release/git', {
    assets: ['pom.xml'],
    message: '🔖 Update `pom.xml` to `${nextRelease.version}` [skip release]',
  }],
],
```

Three rules apply:

1. **`prepareCmd` receives the fully computed version**, including the
   prerelease suffix, so `1.2.0-rc.1` needs no special handling.
2. **Add the version file as a `@semantic-release/git` asset.** A release that
   changes `pom.xml` but does not commit it leaves the next run reading a stale
   version.
3. **Do not reorder the base plugins.** `analyzeCommits` must run before
   `prepare`, and the commit plugin must be last so that its asset list is the
   final one.

Because the bump commit is created by `@semantic-release/git` on whichever
branch triggered the run, adding it to a template reintroduces strategy **A** and
the conflicts described above. A template that must keep a version in a file
should restrict that commit to `main` (strategy **B**) with a dynamic config
instead — which is why the generic layer omits the plugin rather than shipping it
disabled: there is no correct default that works on both branches.

## Verification

The behaviour above was verified on a scratch repository rather than assumed,
because two of the facts are not documented by semantic-release:

- `--branches` on the command line **replaces** the config-file array with plain
  strings, dropping the `prerelease` property. It cannot be used to test this
  configuration; the branch objects must come from the config file.
- A tag's channel is recorded in a git note (`refs/notes/semantic-release-*`)
  written during a real release, not derived from the tag name. Tags created by
  hand therefore carry no channel, and a hand-made `v1.1.0-rc.2` does not make
  the next run produce `rc.3`. Reproducing the table above requires running
  semantic-release for real against each branch.

To re-check on a scratch clone:

```bash
git clone --bare <scratch> origin.git
git -C origin.git symbolic-ref HEAD refs/heads/main   # a bare clone has no HEAD

cd <worktree>
cp <this repository>/.releaserc.js .
# drop @semantic-release/github; it needs GH_TOKEN and network access
npx semantic-release --dry-run --no-ci
```
