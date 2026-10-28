---
name: export-drawio
description: 'Export draw.io diagrams to SVG using a local draw.io Desktop renderer. Use when asked to export, render, or convert a .drawio architecture diagram to SVG, including all pages and embedded Azure icon images for documentation.'
---

# Export draw.io diagrams to SVG

Render real SVG images locally. Do not rename XML files to `.svg`, generate
placeholder images, or upload diagrams to an online conversion service.

## Workflow

1. Identify the source `.drawio` file and output directory. Preserve the source.
   Export every page: a single page produces `<name>.svg`; multiple pages produce
   `<name>-page-1.svg`, `<name>-page-2.svg`, and so on. Default to the source
   directory unless the user requests another location.
2. Check for PowerShell 7+ and draw.io Desktop. The VS Code draw.io extension
   alone does not provide the desktop CLI. The script detects `drawio` or
   `draw.io` on PATH and common desktop installation locations. Use `-DrawioPath`
   for another installation. If unavailable, report the missing prerequisite and
   direct the user to the [official desktop releases](https://github.com/jgraph/drawio-desktop/releases).
   Ask before installing software; never silently download a renderer.
3. Use the bundled [export script](./scripts/Export-Drawio.ps1) from the repository
   root in a PowerShell 7 terminal:

   ```powershell
   & .\.github\skills\export-drawio\scripts\Export-Drawio.ps1 -Path .\diagrams\web-app.drawio
   ```

   For another destination or executable:

   ```powershell
   & .\.github\skills\export-drawio\scripts\Export-Drawio.ps1 -Path .\diagrams\web-app.drawio -OutputDirectory .\docs\images -DrawioPath 'C:\Program Files\draw.io\draw.io.exe'
   ```

   Resolve paths from this repository, adapting to the host OS. On a headless
   Linux machine, run PowerShell under an available display such as `xvfb-run`.
   Do not disable Chromium sandboxing as a workaround.
4. The script first runs the sibling validation skill. Compressed pages must be
   exported as uncompressed XML locally with all pages retained. Do not replace
   the original or silently omit pages to bypass validation.
5. Existing SVGs are protected. Ask before adding `-Force` to regenerate them.
   The script renders and verifies every page in a staging directory before
   publishing outputs, so a rendering failure does not replace existing SVGs.
6. Expect standard SVGs with embedded icon images and no embedded diagram XML.
   The original `.drawio` remains the editable source. Image references must be
   embedded or fragment-local; unresolved external images cause export failure.
   External images in an input diagram may be fetched by the renderer: review
   untrusted diagrams and obtain permission before loading external resources.
7. Check the exit status and reported output paths. Open exported SVGs locally
   when possible to inspect labels, layout, and Azure icons. A parsed SVG is not
   proof of visual correctness; report when visual inspection was not performed.
8. Return links to all exported SVGs and the preserved source, plus any warnings.
   Never claim success on a nonzero exit, timeout, missing output, or incomplete
   image embedding.

When changing export behavior, run the dependency-free
[regression tests](./scripts/Test-DrawioExport.ps1). Pass `-DrawioPath` to those
tests to additionally exercise the real renderer and inspect actual SVG output.
