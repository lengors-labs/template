/**
 * semantic-release configuration for this repository.
 *
 * This layer is deliberately language-agnostic: it turns gitmoji commits into
 * versions, changelogs and GitHub releases and assumes nothing about a build
 * tool. A language template derived from this one adds a `prepare` plugin that
 * writes the computed version into whatever file its build tool reads.
 */

/**
 * Gitmoji table shared by the commit analyzer and the changelog generator.
 *
 * Each entry is `[emoji, release type, changelog section]` and mirrors the
 * gitmoji table documented in `AGENTS.md`: that file is the contract, this
 * table is its machine-readable form. Keep the two in sync.
 */
const GITMOJI = [
  ['💥', 'major', 'Breaking Changes'],

  ['✨', 'minor', 'New Features'],
  ['🗑️', 'minor', 'Deprecations'],

  ['🐛', 'patch', 'Bug Fixes'],
  ['🚑️', 'patch', 'Bug Fixes'],
  ['🥅', 'patch', 'Bug Fixes'],

  ['🔒', 'patch', 'Security'],
  ['🔐', 'patch', 'Security'],

  ['⚡️', 'patch', 'Performance'],
  ['♻️', 'patch', 'Refactoring and Style'],
  ['💄', 'patch', 'Refactoring and Style'],
  ['✏️', 'patch', 'Refactoring and Style'],

  ['➕', 'patch', 'Dependencies and Build'],
  ['➖', 'patch', 'Dependencies and Build'],
  ['⬆️', 'patch', 'Dependencies and Build'],
  ['⬇️', 'patch', 'Dependencies and Build'],
  ['📌', 'patch', 'Dependencies and Build'],
  ['👷', 'patch', 'Dependencies and Build'],
  ['💚', 'patch', 'Dependencies and Build'],
  ['🍱', 'patch', 'Dependencies and Build'],
  ['📦', 'patch', 'Dependencies and Build'],

  ['🔧', 'patch', 'Configuration and Tooling'],
  ['🔊', 'patch', 'Configuration and Tooling'],
  ['🔇', 'patch', 'Configuration and Tooling'],
  ['📱', 'patch', 'Configuration and Tooling'],

  ['🔥', 'patch', 'Removals'],
]

/** Release types, most significant first. */
const SEVERITY = ['major', 'minor', 'patch']

/** Changelog sections, most significant first. */
const SECTIONS = [...new Set(GITMOJI.map(([, , section]) => section))]

/**
 * Spellings accepted for a given emoji.
 *
 * A few glyphs carry a variation selector (U+FE0F) in some fonts and not in
 * others, so both forms are recognised.
 *
 * @param {string} emoji Canonical emoji from the table.
 * @returns {string[]} Every spelling that should match.
 */
function spellings (emoji) {
  return [emoji, emoji.replace(/\uFE0F/g, '')]
}

/**
 * Recognise the gitmoji that prefixes a commit subject.
 *
 * @param {string} message Full commit message.
 * @returns {{type: string, section: string, text: string}|null} `null` when the
 * commit does not follow the convention, which makes it release-neutral.
 */
function parse (message) {
  const subject = message.split('\n', 1)[0].trim()

  for (const [emoji, type, section] of GITMOJI) {
    for (const spelling of spellings(emoji)) {
      if (subject.startsWith(spelling)) {
        return { type, section, text: subject.slice(spelling.length).trim() }
      }
    }
  }

  return null
}

/**
 * Highest release type implied by a set of commits.
 *
 * @param {object[]} commits Commits since the previous release.
 * @returns {string|undefined} Release type, or `undefined` when nothing in the
 * range warrants a release.
 */
function releaseType (commits) {
  const types = new Set(commits.map((commit) => parse(commit.message)?.type).filter(Boolean))
  return SEVERITY.find((type) => types.has(type))
}

/**
 * Group commits into changelog sections, preserving the table's section order.
 *
 * @param {object[]} commits Commits since the previous release.
 * @returns {Map<string, object[]>} Section title to commits.
 */
function groupBySection (commits) {
  const groups = new Map()

  for (const commit of commits) {
    const parsed = parse(commit.message)
    if (!parsed) continue

    const entry = { text: parsed.text, hash: commit.hash.slice(0, 7) }
    groups.set(parsed.section, [...(groups.get(parsed.section) ?? []), entry])
  }

  return new Map(SECTIONS.filter((section) => groups.has(section)).map((section) => [section, groups.get(section)]))
}

/**
 * Render the changelog body for a release.
 *
 * @param {Map<string, object[]>} sections Grouped commits.
 * @param {string} repositoryUrl Repository URL, used to link the commits.
 * @returns {string} Markdown changelog.
 */
function renderNotes (sections, repositoryUrl) {
  const lines = []

  for (const [section, commits] of sections) {
    lines.push(`### ${section}`, '')
    for (const { text, hash } of commits) lines.push(`* [\`${hash}\`](${repositoryUrl}/commit/${hash}) ${text}`)
    lines.push('')
  }

  return lines.join('\n').trim()
}

module.exports = {
  // `main` holds released code only; `rc` is the long-lived integration branch
  // and the key semantic-release uses to select the `rc` channel.
  branches: ['main', { name: 'rc', prerelease: 'rc' }],

  // The version lives in the tag and never in a file: this repository has no
  // build tool. Language templates that do have one add a `prepare` step.
  tagFormat: 'v${version}',

  plugins: [
    {
      analyzeCommits: (pluginConfig, { commits, logger }) => {
        const type = releaseType(commits)
        logger.log('Next release type: %s', type ?? 'none')
        return type
      },

      generateNotes: (pluginConfig, { commits, options }) =>
        renderNotes(groupBySection(commits), options.originalRepositoryURL ?? options.repositoryUrl),
    },

    // Creates the GitHub release and the git tags. This repository publishes no
    // package, so neither `@semantic-release/npm` nor `@semantic-release/git`
    // is used: nothing but the tag records the version.
    '@semantic-release/github',
  ],
}
