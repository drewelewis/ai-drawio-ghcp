---
name: azure-drawio
description: 'Create editable Azure architecture diagrams in draw.io XML. Use when asked to draw, diagram, or visualize an Azure solution, cloud architecture, service topology, deployment view, or network diagram in a .drawio file.'
---

# Create Azure architecture diagrams

Produce an editable, uncompressed `.drawio` file, not just a textual diagram or
an image. This workflow documents a design; it does not provision Azure resources.

## Workflow

1. Establish the audience, intended view (logical, deployment, or network), output
   path, services, and directional connections from the request and relevant local
   project files. Use `diagrams/<descriptive-name>.drawio` unless another location
   is requested. Do not overwrite an existing file without inspecting it.
2. Ask about decisions that materially change the design: public versus private
   ingress, regions, trust boundaries, or resilience requirements. For a requested
   conceptual sketch, label noncritical assumptions rather than blocking on
   deployment details. Never infer deployed resources or access to a subscription.
3. Read [Azure conventions](./references/azure-conventions.md). Start with the XML
   structure and styles in the [logical web-app example](./assets/azure-web-app.drawio),
   but replace the example topology with the requested architecture. Do not add
   services merely because they occur in the template.
4. Write native XML: `mxfile > diagram > mxGraphModel > root`, with root cell `0`,
   layer cell `1`, unique page-local cell IDs, and valid parent references. Use
   descriptive stable IDs and `vertex="1"` or `edge="1"` as appropriate. Every
   vertex and edge needs an `mxGeometry as="geometry"` child; edges normally use
   `relative="1"`. XML-escape all labels and attribute values.
5. Lay out the primary flow left-to-right, align service icons, use roughly
   64-by-64 icons, and leave at least 80 units between peer services. Use labeled
   containers for actual boundaries, orthogonal connectors, readable labels, and
   a legend for different connector styles. Increase page size when needed rather
   than shrinking text. Keep supporting services outside the main request path.
6. Validate the output from the repository root:

   ```powershell
   pwsh -NoProfile -File .\.github\skills\validate-drawio\scripts\Validate-Drawio.ps1 -Path .\diagrams\<descriptive-name>.drawio
   ```

   Use the equivalent native path syntax on other platforms. Resolve the script
   from this repository, not an unrelated current directory. If `pwsh` is
   unavailable, report that prerequisite; do not claim the check passed.
7. Open the file in an available local draw.io editor for a visual check. If no
   renderer is available, explicitly report that visual validation was not run.
   Never send private topology to an online renderer without permission.
8. Return a link to the saved diagram, summarize the topology and assumptions,
   and report structural and visual validation separately. Do not claim that XML
   validation proves the Azure architecture is secure or deployable.
9. If the user also requests SVG output, use the repository's `export-drawio`
   skill after saving the source. It renders all pages locally and preserves the
   `.drawio` file. Do not generate an SVG by renaming the XML source.
