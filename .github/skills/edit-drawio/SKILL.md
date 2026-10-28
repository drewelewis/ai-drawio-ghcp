---
name: edit-drawio
description: 'Edit, extend, or repair existing draw.io architecture diagrams, including Azure diagrams. Use when adding or removing services, changing connections, updating labels, reorganizing layout, or modifying .drawio XML while preserving unrelated diagram content.'
---

# Edit draw.io diagrams

Make targeted changes to an existing editable diagram without recreating it.

## Workflow

1. Identify the exact file, page, and requested change. Inspect its XML, existing
   services, layers, style conventions, cell IDs, and relevant project context.
   If several files or pages could match, ask which to change.
2. Run the existing structural validator before editing to distinguish preexisting
   issues from regressions:

   ```powershell
   pwsh -NoProfile -File .\.github\skills\validate-drawio\scripts\Validate-Drawio.ps1 -Path .\diagrams\<existing-name>.drawio
   ```

   Run from this repository root or resolve its absolute path. Adapt path syntax
   to the host OS. A missing `pwsh` prerequisite is not a successful check.
3. If a page is compressed, do not treat its encoded payload as ordinary XML.
   Use an available local draw.io editor to export uncompressed XML with all
   pages retained. Otherwise ask the user for that export. Do not silently drop
   pages, upload the document to a decompression service, or regenerate it.
4. Preserve unrelated pages, IDs, labels, metadata wrappers (`object` or
   `UserObject`), links, styles, layers, and geometry. IDs only need to be unique
   within each page. Keep existing service IDs when changing their labels or
   placement. Apply the smallest coherent edit rather than reserializing the
   whole file or replacing the architecture.
5. Allocate new IDs for added cells; use existing parent/layer conventions. When
   deleting a cell, inspect descendants and every connector referencing it.
   Update or remove affected connectors and descendants so nothing dangles.
   Reparent deliberately if a child should survive; adjust its relative geometry
   to preserve its position.
6. For Azure changes, use the built-in Azure icon style already present. If a new
   icon path is needed, consult the repository's
   `.github/skills/azure-drawio/references/azure-conventions.md` or verify it in the
   local editor. Do not invent stencil names, imply private connectivity merely
   by moving a service, or add unrequested security or resilience guarantees.
7. Re-run structural validation and compare against the baseline. Fix regressions
   caused by the edit. Preserve the intended flow and layout; inspect the result
   visually in a local draw.io editor when available.
8. Return a link to the changed diagram and a short account of changes, baseline
   issues, and validation results. If rendering was unavailable, state that the
   visual check was not performed. Structural validity is not architecture
   certification.
9. If the user requests refreshed SVGs, use `export-drawio` after saving the
   changes. Ask before replacing existing exports; do not silently leave a stale
   SVG while claiming it reflects the updated diagram.
