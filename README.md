# Welcome to Template &middot; [![GitHub license](https://img.shields.io/github/license/lengors-labs/template?color=blue)](https://github.com/lengors-labs/template/blob/main/LICENSE)

Welcome to **template**, the generic, language-agnostic starting point for new
repositories in the [`lengors-labs`](https://github.com/lengors-labs) organization.

This template is deliberately minimal. Most of the organization's conventions are
maintained once in [`lengors-labs/.github`](https://github.com/lengors-labs/.github)
and inherited automatically by every repository that does not override them. What
remains here is the content that **cannot** be inherited, plus the files that make
this repository usable as a template.

## What's in here

- `README.md` — this file: the project's introduction and usage notes.
- `LICENSE` — [The Unlicense](./LICENSE), placing the project in the public domain.
- `AGENTS.md` — project instructions for AI agents: commit conventions, pull
  request conventions, issue and pull request linking policy, and Git/GitHub
  safety rules.
- `.releaserc.js` — the semantic-release configuration: gitmoji commits become
  versions, changelogs and GitHub releases.
- `.github/workflows/publish-new-version.yml` — the workflow that runs it.
- `docs/release.md` — the branch model, the numbering behaviour and how a
  language template extends the pipeline with its own version bump.
- `.github/CODEOWNERS` — default code owners for the repository.

## What's inherited

These files live in [`lengors-labs/.github`](https://github.com/lengors-labs/.github)
and apply to this repository without being duplicated here:

- `CODE_OF_CONDUCT.md` — our code of conduct.
- `CONTRIBUTING.md` — contribution guidelines.
- `SECURITY.md` — security policy.
- `SUPPORT.md` — support resources.
- `.github/FUNDING.yml` — sponsorship configuration.
- `.github/ISSUE_TEMPLATE/` — issue forms and issue configuration.
- `.github/PULL_REQUEST_TEMPLATE.md` — default pull request template.

Do not copy them into this repository: an override would silently freeze that file
at the version it was taken from, and future organization-wide updates would no
longer reach generated projects.

## Getting started

1. Click **Use this template** at the top of this repository, or open
   <https://github.com/lengors-labs/template/generate>.
2. Choose the owner and name of the new repository.
3. Replace the contents of this `README.md` with a description of your project.
4. Adjust `.github/CODEOWNERS` if the maintainers differ from the defaults.
5. Add the repository secrets the release pipeline needs — `GH_APP_ID`,
   `GH_PRIVATE_KEY`, `GPG_PRIVATE_KEY` and `GPG_PASSPHRASE` — to the `publisher`
   environment. Without them the release workflow fails on the first push.
6. Update the **Project** section of `AGENTS.md` with the description, package
   manager, and any globally relevant scripts of the new project.

Do not fork or clone this repository as a starting point, and do not branch from
`main` to begin a project. Using it as a template produces a new repository with a
fresh history, which is what you want; a fork keeps a dependency on this repository
that is never useful.

## Releasing

Every project generated from this template starts with a working release
pipeline: gitmoji commits on `rc` produce `x.y.z-rc.n` prereleases, and promoting
`rc` into `main` produces the final release. Versions live in git tags, changelogs
and GitHub releases — nothing is written into a file.

The branch model, the numbering behaviour and the extension point for build tools
are documented in [`docs/release.md`](./docs/release.md).

## Contributing

Contributions are welcome! Please refer to our [Contribution Guidelines](https://github.com/lengors-labs/.github/blob/main/CONTRIBUTING.md)
for more information on how to get involved, including the commit and pull request
conventions enforced by this repository (also documented in [`AGENTS.md`](./AGENTS.md)).

## License

This project is licensed under [The Unlicense](./LICENSE), which places it in the
public domain.
