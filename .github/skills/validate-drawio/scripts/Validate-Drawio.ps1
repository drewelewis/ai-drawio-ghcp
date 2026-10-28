#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string[]] $Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$failed = $false

foreach ($inputPath in $Path) {
    $reader = $null
    try {
        $resolvedPath = (Resolve-Path -LiteralPath $inputPath -ErrorAction Stop).ProviderPath
        $settings = [System.Xml.XmlReaderSettings]::new()
        $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
        $settings.XmlResolver = $null
        $reader = [System.Xml.XmlReader]::Create($resolvedPath, $settings)
        $document = [System.Xml.XmlDocument]::new()
        $document.XmlResolver = $null
        $document.Load($reader)
    }
    catch {
        Write-Error "${inputPath}: Cannot read diagram XML: $($_.Exception.Message)" -ErrorAction Continue
        $failed = $true
        continue
    }
    finally {
        if ($null -ne $reader) {
            $reader.Dispose()
        }
    }

    $issues = [System.Collections.Generic.List[string]]::new()
    $models = [System.Collections.Generic.List[System.Xml.XmlElement]]::new()
    $root = $document.DocumentElement
    if ($null -eq $root) {
        $issues.Add('The document has no root element.')
    }
    elseif ($root.Name -ceq 'mxGraphModel') {
        $models.Add($root)
    }
    elseif ($root.Name -ceq 'mxfile') {
        $pages = @($root.SelectNodes('diagram'))
        if ($pages.Count -eq 0) {
            $issues.Add('The mxfile has no diagram pages.')
        }
        $pageIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($page in $pages) {
            $pageId = $page.GetAttribute('id')
            if ($pageId -ne '' -and -not $pageIds.Add($pageId)) {
                $issues.Add("Duplicate diagram page ID '$pageId'.")
            }
            $pageModels = @($page.SelectNodes('mxGraphModel'))
            if ($pageModels.Count -ne 1) {
                $issues.Add("Page '$($page.GetAttribute('name'))' must contain one inline mxGraphModel. For compressed pages, export XML with Compressed unchecked and all pages retained.")
            }
            else {
                $models.Add($pageModels[0])
            }
        }
    }
    else {
        $issues.Add("Unsupported root '$($root.Name)'; expected mxfile or mxGraphModel.")
    }

    for ($pageIndex = 0; $pageIndex -lt $models.Count; $pageIndex++) {
        $model = $models[$pageIndex]
        $context = "Graph $($pageIndex + 1)"
        $graphRoots = @($model.SelectNodes('root'))
        if ($graphRoots.Count -ne 1) {
            $issues.Add("${context}: Expected one root collection.")
            continue
        }

        $cells = @($graphRoots[0].SelectNodes('mxCell | */mxCell'))
        $byId = [System.Collections.Generic.Dictionary[string, System.Xml.XmlElement]]::new([System.StringComparer]::Ordinal)
        foreach ($cell in $cells) {
            $id = $cell.GetAttribute('id')
            if ($cell.ParentNode -ne $graphRoots[0]) {
                $id = $cell.ParentNode.GetAttribute('id')
            }
            if ([string]::IsNullOrWhiteSpace($id)) {
                $issues.Add("${context}: A cell or its metadata wrapper has no ID.")
            }
            elseif (-not $byId.TryAdd($id, $cell)) {
                $issues.Add("${context}: Duplicate cell ID '$id'.")
            }
        }

        if (-not $byId.ContainsKey('0')) {
            $issues.Add("${context}: Missing root cell '0'.")
        }
        elseif ($byId['0'].GetAttribute('parent') -ne '') {
            $issues.Add("${context}: Root cell '0' must not have a parent.")
        }
        $layers = @($cells | Where-Object {
            $_.GetAttribute('parent') -ceq '0' -and
            $_.GetAttribute('vertex') -cne '1' -and
            $_.GetAttribute('edge') -cne '1'
        })
        if ($layers.Count -eq 0) {
            $issues.Add("${context}: Missing layer cell parented to root '0'.")
        }

        foreach ($entry in $byId.GetEnumerator()) {
            $id = $entry.Key
            $cell = $entry.Value
            $parentId = $cell.GetAttribute('parent')
            if ($id -cne '0' -and ($parentId -eq '' -or -not $byId.ContainsKey($parentId))) {
                $issues.Add("${context}: Cell '$id' has missing or unknown parent '$parentId'.")
            }

            $ancestors = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
            $cursor = $id
            while ($cursor -ne '' -and $byId.ContainsKey($cursor)) {
                if (-not $ancestors.Add($cursor)) {
                    $issues.Add("${context}: Cell '$id' belongs to a parent cycle.")
                    break
                }
                $cursor = $byId[$cursor].GetAttribute('parent')
            }

            $isVertex = $cell.GetAttribute('vertex') -ceq '1'
            $isEdge = $cell.GetAttribute('edge') -ceq '1'
            if ($isVertex -and $isEdge) {
                $issues.Add("${context}: Cell '$id' cannot be both a vertex and an edge.")
            }
            if (-not $isVertex -and -not $isEdge) {
                continue
            }
            $geometries = @($cell.SelectNodes('mxGeometry'))
            if ($geometries.Count -ne 1 -or $geometries[0].GetAttribute('as') -cne 'geometry') {
                $issues.Add("${context}: Cell '$id' needs one mxGeometry with as='geometry'.")
                continue
            }
            $geometry = $geometries[0]
            foreach ($attribute in @('x', 'y', 'width', 'height')) {
                if (-not $geometry.HasAttribute($attribute)) {
                    continue
                }
                $number = 0.0
                $isNumber = [double]::TryParse(
                    $geometry.GetAttribute($attribute),
                    [System.Globalization.NumberStyles]::Float,
                    [System.Globalization.CultureInfo]::InvariantCulture,
                    [ref] $number
                )
                if (-not $isNumber -or [double]::IsNaN($number) -or [double]::IsInfinity($number) -or
                    ($attribute -in @('width', 'height') -and $number -lt 0)) {
                    $issues.Add("${context}: Cell '$id' has invalid geometry '$attribute'.")
                }
            }

            if ($isEdge) {
                foreach ($endpoint in @('source', 'target')) {
                    $endpointId = $cell.GetAttribute($endpoint)
                    if ($endpointId -ne '') {
                        if (-not $byId.ContainsKey($endpointId)) {
                            $issues.Add("${context}: Edge '$id' has unknown $endpoint '$endpointId'.")
                        }
                    }
                    else {
                        $point = $geometry.SelectSingleNode("mxPoint[@as='${endpoint}Point']")
                        if ($null -eq $point) {
                            $issues.Add("${context}: Edge '$id' has no $endpoint reference or explicit ${endpoint}Point.")
                        }
                        else {
                            foreach ($axis in @('x', 'y')) {
                                if (-not $point.HasAttribute($axis)) {
                                    continue
                                }
                                $coordinate = 0.0
                                $isCoordinate = [double]::TryParse(
                                    $point.GetAttribute($axis),
                                    [System.Globalization.NumberStyles]::Float,
                                    [System.Globalization.CultureInfo]::InvariantCulture,
                                    [ref] $coordinate
                                )
                                if (-not $isCoordinate -or [double]::IsNaN($coordinate) -or [double]::IsInfinity($coordinate)) {
                                    $issues.Add("${context}: Edge '$id' has invalid ${endpoint}Point '$axis'.")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if ($issues.Count -gt 0) {
        $failed = $true
        foreach ($issue in $issues) {
            Write-Error "${inputPath}: $issue" -ErrorAction Continue
        }
    }
    else {
        Write-Host "PASS ${inputPath}: $($models.Count) graph(s) structurally valid."
    }
}

if ($failed) {
    exit 1
}
exit 0
