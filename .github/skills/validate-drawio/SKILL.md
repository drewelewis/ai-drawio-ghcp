---
name: validate-drawio
description: 'Validate editable draw.io diagram XML before delivery or after edits. Use for checking .drawio files, malformed XML, duplicate cell IDs, dangling parents or connector endpoints, parent cycles, missing geometry, and compressed-page limitations in Azure architecture diagrams.'
---

# Validate draw.io diagrams

Validate local diagram structure without contacting Azure or uploading content.

## Workflow

1. Identify the file or explicitly scoped set of files. Do not claim to validate
   every diagram when only a sample was checked.
2. Run the bundled [validator](./scripts/Validate-Drawio.ps1) with PowerShell 7+
   from this repository root:

   ```powershell
   pwsh -NoProfile -File .\.github\skills\validate-drawio\scripts\Validate-Drawio.ps1 -Path .\diagrams\<name>.drawio
   ```

   Use native path syntax on other platforms or resolve an absolute script path.
   From a PowerShell session, pass several files using `-Path @('first.drawio',
   'second.drawio')`. No packages or Azure credentials are required. If `pwsh`
   is missing, report that the validator could not run.
3. Read the exit code and diagnostics. The validator checks every inline page in
   an `mxfile`, or a standalone `mxGraphModel`, for unique cell IDs, root/layer
   structure, parent references and cycles, connector references or explicit free
   endpoints, and vertex/edge geometry. It understands metadata-wrapped cells.
   It rejects DTDs and compressed pages; it never fetches external XML resources.
4. For compressed diagrams, use a local draw.io editor:
   **File > Export as > XML**, deselect **Compressed**, and preserve all pages.
   Then validate the export. Do not overwrite the original with a single-page
   conversion or upload it to an external decoder without permission.
5. If repair was requested, fix only the relevant defects, preserve unrelated
   content, and run the same check again. For a validation-only request, report
   defects without editing. Never replace invalid references with arbitrary
   valid IDs just to make the check pass.
6. Separately review architecture semantics: actual services, directional flows,
   identity, organizational versus network boundaries, and declared assumptions.
   Open the file in an available local draw.io editor to check icon resolution,
   overlap, labels, connector routing, and page bounds. If unavailable, explicitly
   mark the visual check as not run.
7. Report files/pages checked, exit status, issues, and any unperformed checks.
   Exit code `0` means structural checks passed, not that the diagram renders
   perfectly or the architecture is deployable, secure, or cost-optimized.

When modifying the validator, run its dependency-free
[regression tests](./scripts/Test-DrawioValidator.ps1).
