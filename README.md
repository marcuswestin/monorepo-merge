# monorepo-merge
Import multiple repos into a single mono repo, into custom subfolder paths, while maintaining full commit history for all repos

## Get started

See `import-repos-into-monorepo.sh` and change:

- Set your github org/account name: `GITHUB_ORG="..."`
- Set your wanted new monorepo name: `MONOREPO_NAME="..."`
- Set repos to import and target folder under `# Execute Phase 1`
- Set repos to import and target folder under `# Execute Phase 2`
- Set repos to import and target folder under `# Execute Phase 3`
- Run it: `import-repos-into-monorepo.sh`
- Finally, follow the instructions for how to push the new repo.
  - (Note that this requires a `push --force`! Make sure it is a new, unused repo name)
