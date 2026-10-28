# Contributing

Contributions to the skills, validator, documentation, and generic example
diagrams are welcome.

## Workflow

1. Fork the repository and clone your fork. Open the repository root in VS Code.
2. Create a branch with `git switch -c describe-your-change`.
3. Make a focused change and update directly related documentation.
4. Run the repository checks in PowerShell 7 from the repository root:

   ```powershell
   & .\.github\scripts\Test-Repository.ps1
   ```

5. If you changed a diagram, open it in a local draw.io editor and inspect icons,
   labels, routing, and boundaries. Report visual checks separately from XML
   checks.
6. Open a pull request against `main` describing the change, rationale, and checks
   performed. Changes must pass the Windows, Linux, and macOS CI jobs.

## Skill conventions

- Keep each skill in `.github/skills/<name>/SKILL.md`; the lowercase, hyphenated
  `name` must match its directory.
- Use YAML frontmatter with a `name` and a meaningful, single-line, single-quoted
  `description` of no more than 1,024 characters. Escape an apostrophe in a
  single-quoted description by doubling it.
- Include concrete discovery phrases and an actionable procedure. Keep each
  `SKILL.md` below 500 lines and load detailed resources only when needed.
- Link bundled resources using relative Markdown links. Preserve the relationships
  between creation, editing, and validation; copied skills must work together.
- Do not introduce paid services, new runtime dependencies, external uploads, or
  unverified Azure icon paths without explaining the need and updating setup docs.

## Validator and diagram changes

- Use uncompressed `.drawio` XML for reviewable diffs.
- Preserve unrelated cells, IDs, pages, metadata, and layout when editing.
- Add regression coverage when changing validation behavior. The tests use
  PowerShell and .NET only and must not require Azure credentials or network access.
- Do not claim that structural XML checks validate architecture security or
  production readiness.
- For export changes, run `Test-DrawioExport.ps1` in the export skill's scripts
  directory with `-DrawioPath` pointing to draw.io Desktop. Verify actual SVG
  content, embedded icons, page selection, overwrite protection, and unchanged
  source diagrams. The dependency-free repository checks explicitly skip real
  rendering; CI exercises it on Windows using a pinned, checksum-verified archive.
- Use only original or appropriately licensed contributions. Do not commit copied
  product icon binaries; use the editor's built-in libraries and follow the
  [Azure icon guidelines](https://learn.microsoft.com/azure/architecture/icons/).

## Public repository hygiene

Never submit private architectures, customer information, credentials, connection
strings, or tokens in a commit, example, issue, or pull request. Use fictitious,
generic details for examples. Keep your own confidential diagrams in a separate
private repository.

By submitting a contribution, you agree that it can be distributed under this
repository's [MIT License](LICENSE).
