# Azure diagram conventions

## Represent architecture honestly

- Label the view as logical, deployment, or network. A subscription or resource
  group is an organizational scope, not a network security boundary.
- Only show a VNet, subnet, private endpoint, zone, or regional failover when
  supported by the request or inspected configuration. Putting a PaaS icon inside
  a VNet does not make its public endpoint private.
- Separate request/data flows from identity, secret access, and telemetry. Label
  arrows with their purpose and known protocol. Dashed connectors need a legend;
  they do not automatically mean encrypted traffic.
- Show managed identity only when it is specified or clearly labeled as proposed.
  Never place credentials, access tokens, connection strings, or private account
  identifiers in a diagram.
- Use current product names in labels. Do not assert specific SKUs, regional
  availability, compliance, or resilience guarantees without evidence.

## Native draw.io Azure icons

Use built-in images, not invented `mxgraph.azure.*` stencil identifiers:

```text
shape=image;aspect=fixed;verticalLabelPosition=bottom;verticalAlign=top;align=center;html=0;image=img/lib/azure2/app_services/App_Services.svg;
```

The following paths were checked against draw.io's public Azure image library.
They are editor-relative resource paths, not files that must be copied into this
repository.

| Label | Value of the `image` style property |
| --- | --- |
| Azure App Service | `img/lib/azure2/app_services/App_Services.svg` |
| Azure API Management | `img/lib/azure2/app_services/API_Management_Services.svg` |
| Azure Functions | `img/lib/azure2/compute/Function_Apps.svg` |
| Azure Kubernetes Service | `img/lib/azure2/compute/Kubernetes_Services.svg` |
| Azure Storage | `img/lib/azure2/storage/Storage_Accounts.svg` |
| Azure Key Vault | `img/lib/azure2/security/Key_Vaults.svg` |
| Application Insights | `img/lib/azure2/management_governance/Application_Insights.svg` |
| Azure Virtual Network | `img/lib/azure2/networking/Virtual_Networks.svg` |
| Azure Application Gateway | `img/lib/azure2/networking/Application_Gateways.svg` |
| Azure Front Door | `img/lib/azure2/networking/Front_Doors.svg` |
| Private endpoint | `img/lib/azure2/other/Private_Endpoints.svg` |
| Microsoft Entra ID | `img/lib/azure2/identity/Azure_Active_Directory.svg` |

The Entra ID resource path retains a legacy filename; use the current product name
in the label. Editor versions can have different libraries. If another service
icon is needed, verify its exact path in the installed editor or the public
draw.io library. If it cannot be verified, use a clearly labeled generic rectangle
and report that fallback. Do not substitute an unrelated service icon.

Use icons without distortion, cropping, flipping, rotation, or recoloring, and
keep product names close to icons. Prefer references to the editor's built-in
library over downloading or embedding binaries. The validator checks graph XML,
not whether the editor can resolve these images.

## XML and layout

- Use uncompressed XML so reviews and targeted edits remain practical.
- Keep cell IDs unique within each page. IDs may repeat on separate pages.
- Containers have their own vertex and geometry. Child geometry is relative to
  its parent; do not mix absolute page coordinates with container coordinates.
- Reference connector endpoints using `source` and `target` cell IDs. An
  intentionally free endpoint instead needs an `mxPoint` with
  `as="sourcePoint"` or `as="targetPoint"` inside its geometry.
- Use `edgeStyle=orthogonalEdgeStyle;endArrow=block;html=0;` for normal directional
  flows. Preserve the actual flow direction rather than adding bidirectional
  arrows for convenience.
- Prefer plain labels with `html=0`. Escape `&`, `<`, `>`, and quotes in XML
  attributes. If an existing diagram uses HTML labels, preserve and escape both
  the HTML and XML layers correctly.
- Do not add external tracking links, remote rendering calls, or timestamps that
  introduce unnecessary diff noise.

## Sources

- [draw.io Azure image library](https://github.com/jgraph/drawio/tree/dev/src/main/webapp/img/lib/azure2)
- [Microsoft Azure icon usage guidelines](https://learn.microsoft.com/azure/architecture/icons/)
- [draw.io XML editing](https://www.drawio.com/doc/faq/diagram-source-edit)
- [draw.io uncompressed XML export](https://www.drawio.com/doc/faq/export-to-xml)
