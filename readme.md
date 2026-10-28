# Azure architecture diagrams with GitHub Copilot

[![Validate repository](https://github.com/drewelewis/ai-drawio-ghcp/actions/workflows/validate.yml/badge.svg)](https://github.com/drewelewis/ai-drawio-ghcp/actions/workflows/validate.yml)

Clone this repository, open it in VS Code, and describe an Azure architecture to
GitHub Copilot. The included skills guide Copilot to create, edit, validate, and export
editable draw.io diagrams using Azure service icons.

This is a **Copilot skills workspace**, not an application or a VS Code extension.
There is no application build, MCP server, Azure subscription, or deployment step.
The output is an uncompressed `.drawio` XML file that you can edit and keep in Git.

## What you need

| Requirement | Why / setup |
| --- | --- |
| [Git](https://git-scm.com/downloads) | Clone the repository. |
| [Visual Studio Code](https://code.visualstudio.com/) | Open the cloned folder as your workspace. |
| [GitHub Copilot access in VS Code](https://code.visualstudio.com/docs/copilot/setup) | Sign in and use an agent-capable chat mode that supports Agent Skills. Your account or organization must permit it. |
| [Draw.io VS Code Integration](https://marketplace.visualstudio.com/items?itemName=hediet.vscode-drawio) | Preview and visually edit diagrams. This third-party extension uses a local draw.io editor by default. [draw.io Desktop](https://github.com/jgraph/drawio-desktop/releases) is an alternative. |
| [PowerShell 7+](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) (`pwsh`) | Run structural validation and repository checks on Windows, macOS, or Linux. Windows PowerShell 5.1 is not sufficient. |

No Node.js, Python, Azure CLI, API keys, or additional PowerShell modules are
required. Copilot usage is subject to your plan's limits and data-handling policies.
PowerShell is required for validation, not for manually opening the example.
Automated SVG export additionally requires draw.io Desktop; the VS Code extension
alone does not provide its command-line renderer. The desktop application is an
optional dependency and is not installed automatically by these skills.

## Quick start: create your first diagram

The commands below use a **PowerShell 7 terminal** on Windows, macOS, or Linux.
After installing PowerShell, run `pwsh` to start one.

### 1. Clone and open the workspace

```powershell
git clone https://github.com/drewelewis/ai-drawio-ghcp.git
Set-Location ai-drawio-ghcp
code .
```

If `code` is not on your PATH, use **File > Open Folder** in VS Code and select
the cloned folder. Open the repository root, not just an individual diagram.
Review the contents before trusting the workspace or approving agent tool calls.

### 2. Set up the editor and check the tools

Sign in to GitHub Copilot and install **Draw.io VS Code Integration** from the
Extensions view. It is also listed in this workspace's extension recommendations;
recommendations do not install anything automatically.

In the VS Code terminal, start PowerShell 7 and run from the repository root:

```powershell
$PSVersionTable.PSVersion
& .\.github\scripts\Test-Repository.ps1
```

The checks cover skill metadata, local documentation links, PowerShell syntax,
bundled diagrams, validator regressions, and SVG export error handling. These
dependency-free checks do not install or run the real renderer. A successful run ends with
`PASS repository checks`.

### 3. Ask Copilot to create a diagram

Open Copilot Chat, choose an agent-capable mode, and paste:

```text
/azure-drawio Create diagrams/web-app.drawio as a logical Azure architecture
diagram for a technical design review.

Show application users calling Azure API Management, which calls Azure App
Service. App Service reads and writes Azure Storage, retrieves secrets from
Azure Key Vault using a proposed managed identity, and sends telemetry to
Application Insights.

Use Azure icons and labeled directional connectors. Distinguish the primary
request flow from secret access and telemetry. Do not imply private networking,
zone redundancy, or production readiness. Use the repository's validator and
summarize the assumptions and validation results.
```

If your client does not expose a slash command, use an ordinary-language request
beginning with **"Use the azure-drawio skill to..."** instead. Skills are also
selected automatically when their descriptions match the task.

The agent should create the output directory and editable diagram, run structural
validation when PowerShell is available, and report any assumptions or checks it
could not perform. Review tool approval prompts rather than approving blindly.

### 4. Open and review the result

Open `diagrams/web-app.drawio` from the VS Code Explorer. If it opens as text,
use **Reopen Editor With...** and select the draw.io editor, or open it in
draw.io Desktop.

Check the icon rendering, labels, connector routing, and boundaries. Structural
validation does **not** prove that the visual layout is correct or that an Azure
design is secure, deployable, or production-ready. Keep the `.drawio` source even
if you export an SVG or PNG for documentation.

To try the editor without using Copilot, open the
[starter diagram](.github/skills/azure-drawio/assets/azure-web-app.drawio) and use
**Save As** to work on a copy. It is an illustrative logical example, not a
production reference architecture.

## Included skills

| Skill | Purpose | Example request |
| --- | --- | --- |
| [azure-drawio](.github/skills/azure-drawio/SKILL.md) | Create an Azure architecture diagram. | `/azure-drawio Diagram an event-driven application with Azure Functions and Service Bus.` |
| [edit-drawio](.github/skills/edit-drawio/SKILL.md) | Update a diagram while preserving unrelated content and cell IDs. | `/edit-drawio Add Azure Front Door before API Management in diagrams/web-app.drawio.` |
| [validate-drawio](.github/skills/validate-drawio/SKILL.md) | Check diagram XML structure and references. | `/validate-drawio Check diagrams/web-app.drawio without changing it.` |
| [export-drawio](.github/skills/export-drawio/SKILL.md) | Render every page to SVG with embedded icon images. | `/export-drawio Export diagrams/web-app.drawio to SVG in docs/images.` |

For best results, describe the audience, intended view (logical, deployment, or
network), services, directional flows, and known constraints. The skills ask about
material unknowns instead of inventing private connectivity or resilience claims.

### Where skills apply

Skills live in `.github/skills/<name>/SKILL.md` and are discovered in the opened
workspace. **Cloning this repository does not install skills globally** or enable
them automatically in other projects.

Work in this clone, or copy all four skill directories together into another
project's `.github/skills/` folder, preserving their names and layout. The create
and edit skills depend on the validation skill's script, as does SVG export.
Review existing files before merging; do not overwrite other project customizations. Standalone
validation does not require the repository-level CI files.

## Validate diagrams yourself

From a PowerShell 7 terminal at the repository root:

```powershell
& .\.github\skills\validate-drawio\scripts\Validate-Drawio.ps1 -Path .\diagrams\web-app.drawio
```

Validate several files together:

```powershell
& .\.github\skills\validate-drawio\scripts\Validate-Drawio.ps1 -Path @('.\diagrams\app.drawio', '.\diagrams\network.drawio')
```

Exit code `0` means structural validation passed; `1` means a file could not be
read or failed validation. The validator supports multi-page `mxfile` documents,
standalone `mxGraphModel` documents, metadata-wrapped cells, and explicitly
positioned free connector endpoints. It checks IDs, parents, parent cycles,
connector endpoints, and geometry. It rejects DTDs and compressed pages.

For compressed diagrams, use a local draw.io editor:
**File > Export as > XML**, deselect **Compressed**, and preserve all pages.
Validate the export rather than replacing a multi-page original with one page.

The validator does not contact Azure, resolve icons, or render the diagram.
Built-in Azure icon availability depends on the draw.io editor version.
If an icon cannot be verified, the creation skill uses a labeled generic shape
and reports the substitution rather than inventing an icon identifier.

## Export to SVG with Copilot

Install [draw.io Desktop](https://github.com/jgraph/drawio-desktop/releases) if you
want automated SVG export, then ask Copilot:

```text
/export-drawio Export diagrams/web-app.drawio to SVG in docs/images.
```

You can also ask the creation skill to create a diagram **and export it to SVG**;
it hands the rendering step to `export-drawio`. Rendering is local, with no online
conversion service. Diagrams that reference external images may cause the renderer
to fetch those images; review untrusted inputs and follow your data policies.

Run the same exporter yourself in PowerShell 7:

```powershell
& .\.github\skills\export-drawio\scripts\Export-Drawio.ps1 -Path .\diagrams\web-app.drawio -OutputDirectory .\docs\images
```

- A single-page diagram produces `web-app.svg`.
- A multi-page diagram produces `web-app-page-1.svg`, `web-app-page-2.svg`, etc.
  Every page is exported, not just the first.
- Azure icon images are embedded in the SVG. Unresolved image references are
  reported as failures rather than producing a misleadingly portable export.
- These are standard SVG images without embedded diagram XML. Keep the original
  `.drawio` file for editing; the exporter does not modify it.
- Output defaults to the input directory. Existing SVGs are not replaced unless
  you explicitly supply `-Force`. All pages are rendered and checked before any
  SVG is published, protecting existing outputs from rendering failures.
- Rendering has a 120-second timeout per page; `-TimeoutSeconds` can adjust it.

The script finds `drawio` or `draw.io` on PATH and common Windows/macOS desktop
installations. For another installation, supply its executable explicitly:

```powershell
& .\.github\skills\export-drawio\scripts\Export-Drawio.ps1 -Path .\diagrams\web-app.drawio -DrawioPath 'C:\Program Files\draw.io\draw.io.exe'
```

On macOS, the default executable is inside the installed `draw.io.app` bundle.
Headless Linux requires a display, for example launching `pwsh` under an installed
`xvfb-run`. Do not disable Chromium sandboxing to bypass setup issues.

Exported SVGs still need visual review: successful rendering and XML checks cannot
prove that labels, layout, and architecture semantics are correct.

## Troubleshooting

| Problem | What to check |
| --- | --- |
| Copilot cannot find a skill | Open the cloned repository root. Use **Chat: Open Customizations** to inspect discovery and confirm that the four skills appear. Check your client version, selected agent mode, and organization policies against the [Agent Skills documentation](https://code.visualstudio.com/docs/copilot/customization/agent-skills). |
| A slash command is missing | Ask in ordinary language and explicitly name the skill. Invocation controls vary between Copilot clients and versions. |
| `pwsh` is not recognized or version 5.1 is running | Install PowerShell 7+, open a new terminal, and run `pwsh`. Check `$PSVersionTable.PSVersion`. |
| Script execution is blocked | Follow your organization's approved PowerShell configuration; do not disable security controls just to run these checks. |
| A diagram opens as XML | Install the draw.io extension and use **Reopen Editor With...**, or open it in draw.io Desktop. |
| An Azure icon is blank | Check the editor's Azure library/version and the image path. Structural validation cannot verify icon resolution. |
| SVG export cannot find draw.io | Install draw.io Desktop or supply `-DrawioPath`. The VS Code extension is not the desktop CLI. |
| SVG export refuses an existing file | Choose another output directory or approve replacement with `-Force`. |
| SVG export fails or times out | Inspect the renderer diagnostics, update the desktop renderer if its flags are unsupported, and check display availability on Linux. No placeholder SVG is produced. |
| Compressed XML is rejected | Export uncompressed XML locally with all pages retained, then validate again. |
| GitHub rejects a push | Cloning does not grant write access. Fork the repository or use a repository you own for your diagrams. |

## Privacy and limitations

- Never put credentials, tokens, connection strings, or confidential resource
  details in prompts, diagrams, issues, or pull requests.
- This repository is public. Keep private customer or internal topologies in a
  separate private repository and follow your organization's AI usage policies.
- The validator runs locally, but Copilot prompts and project context are handled
  according to your selected service/model and organization settings.
- Do not upload private diagrams to online renderers or decompression services
  without permission.
- These skills document designs; they do not discover live resources, provision
  infrastructure, or certify security, availability, compliance, or cost.

## Contributing and checks

See [CONTRIBUTING.md](CONTRIBUTING.md) for the contribution workflow. Run all
repository checks before submitting changes:

```powershell
& .\.github\scripts\Test-Repository.ps1
```

The [GitHub Actions workflow](.github/workflows/validate.yml) runs the same checks
on Windows, Linux, and macOS for pushes to `main` and pull requests.
Its Windows job additionally downloads a pinned, checksum-verified draw.io Desktop
archive and tests real single-page and multi-page SVG exports with embedded Azure
icons. Renderer-backed checks on Linux and macOS are not currently automated.

To run real-renderer integration checks locally:

```powershell
& .\.github\skills\export-drawio\scripts\Test-DrawioExport.ps1 -DrawioPath 'C:\Program Files\draw.io\draw.io.exe'
```

## License and attribution

The skills, scripts, documentation, and original example diagram are available
under the [MIT License](LICENSE).

Azure product names and icons belong to their respective owners. No icon binaries
are bundled in this repository; diagrams reference draw.io's built-in libraries.
Microsoft's [Azure icon usage guidelines](https://learn.microsoft.com/azure/architecture/icons/)
and third-party tool licenses apply independently. This project is not affiliated
with or endorsed by Microsoft, GitHub, or draw.io.

## References

- [VS Code Agent Skills](https://code.visualstudio.com/docs/copilot/customization/agent-skills)
- [draw.io XML editing](https://www.drawio.com/doc/faq/diagram-source-edit)
- [draw.io XML export](https://www.drawio.com/doc/faq/export-to-xml)
- [draw.io SVG export](https://www.drawio.com/doc/faq/export-to-svg)
- [draw.io Desktop CLI options](https://github.com/jgraph/drawio-desktop/blob/dev/src/main/args.js)
- [Microsoft Azure architecture icons and usage guidelines](https://learn.microsoft.com/azure/architecture/icons/)