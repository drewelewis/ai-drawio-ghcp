#requires -Version 7.0
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$validator = Join-Path $PSScriptRoot 'Validate-Drawio.ps1'
$templatePath = Join-Path $PSScriptRoot '..\..\azure-drawio\assets\azure-web-app.drawio'
$template = [System.IO.File]::ReadAllText($templatePath)
$runtime = (Get-Process -Id $PID).Path
$temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "drawio-validator-$([guid]::NewGuid().ToString('N'))"
$null = New-Item -ItemType Directory -Path $temporaryDirectory
$fixtures = [System.Collections.Generic.List[string]]::new()
$cases = [System.Collections.Generic.List[object]]::new()

function Add-Case {
    param([string] $Name, [string] $Xml, [int] $ExpectedExit, [string] $ExpectedMessage)
    $file = Join-Path $temporaryDirectory "$Name.drawio"
    [System.IO.File]::WriteAllText($file, $Xml)
    $fixtures.Add($file)
    $cases.Add([pscustomobject]@{
        Name = $Name
        Path = $file
        ExpectedExit = $ExpectedExit
        ExpectedMessage = $ExpectedMessage
    })
}

try {
    Add-Case 'azure-template' $template 0 '1 graph(s) structurally valid'
    $document = [System.Xml.XmlDocument]::new()
    $document.LoadXml($template)
    Add-Case 'standalone-model' $document.SelectSingleNode('//mxGraphModel').OuterXml 0 '1 graph(s) structurally valid'
    $secondPage = $document.DocumentElement.FirstChild.CloneNode($true)
    $secondPage.SetAttribute('id', 'second-page')
    $null = $document.DocumentElement.AppendChild($secondPage)
    $multiplePages = $document.OuterXml
    Add-Case 'multiple-pages' $multiplePages 0 '2 graph(s) structurally valid'

    $document.LoadXml($template)
    $cell = $document.SelectSingleNode('//mxCell[@id="app-service"]')
    $wrapper = $document.CreateElement('object')
    $wrapper.SetAttribute('id', $cell.GetAttribute('id'))
    $wrapper.SetAttribute('label', $cell.GetAttribute('value'))
    $cell.RemoveAttribute('id')
    $cell.RemoveAttribute('value')
    $null = $cell.ParentNode.ReplaceChild($wrapper, $cell)
    $null = $wrapper.AppendChild($cell)
    Add-Case 'wrapped-cell' $document.OuterXml 0 'structurally valid'
    $freeEndpoint = $template.Replace(' source="users"', '')
    $document.LoadXml($freeEndpoint)
    $geometry = $document.SelectSingleNode('//mxCell[@id="users-to-api"]/mxGeometry')
    $point = $document.CreateElement('mxPoint')
    $point.SetAttribute('as', 'sourcePoint')
    $point.SetAttribute('x', '170')
    $point.SetAttribute('y', '365')
    $null = $geometry.AppendChild($point)
    Add-Case 'free-endpoint' $document.OuterXml 0 'structurally valid'
    $point.RemoveAttribute('y')
    Add-Case 'zero-default-endpoint' $document.OuterXml 0 'structurally valid'
    $point.SetAttribute('x', 'NaN')
    Add-Case 'invalid-free-endpoint' $document.OuterXml 1 "invalid sourcePoint 'x'"

    Add-Case 'duplicate-id' ($template.Replace('id="storage"', 'id="app-service"')) 1 "Duplicate cell ID 'app-service'"
    Add-Case 'missing-id' ($template.Replace('id="storage"', '')) 1 'has no ID'
    Add-Case 'unknown-parent' ($template.Replace('parent="azure-scope"', 'parent="missing"')) 1 "unknown parent 'missing'"
    Add-Case 'unknown-target' ($template.Replace('target="storage"', 'target="missing"')) 1 "unknown target 'missing'"
    Add-Case 'missing-endpoint' $freeEndpoint 1 'no source reference or explicit sourcePoint'
    Add-Case 'parent-cycle' ($template.Replace('id="1" parent="0"', 'id="1" parent="app-service"')) 1 'parent cycle'
    Add-Case 'missing-root' ($template.Replace('<mxCell id="0" />', '')) 1 "Missing root cell '0'"
    Add-Case 'root-parent' ($template.Replace('<mxCell id="0" />', '<mxCell id="0" parent="1" />')) 1 "Root cell '0' must not have a parent"
    Add-Case 'missing-layer' ($template.Replace('<mxCell id="1" parent="0" />', '')) 1 'Missing layer cell'
    Add-Case 'missing-geometry' ($template.Replace('<mxGeometry x="760" y="210" width="64" height="64" as="geometry" />', '')) 1 'needs one mxGeometry'
    Add-Case 'negative-size' ($template.Replace('width="64"', 'width="-64"')) 1 "invalid geometry 'width'"
    Add-Case 'nonfinite-coordinate' ($template.Replace('x="760"', 'x="NaN"')) 1 "invalid geometry 'x'"
    Add-Case 'duplicate-page' ($multiplePages.Replace('id="second-page"', 'id="azure-logical-web-app"')) 1 'Duplicate diagram page ID'
    $document.LoadXml($multiplePages)
    $document.SelectSingleNode('/mxfile/diagram[@id="second-page"]//mxCell[@id="app-to-storage"]').SetAttribute('target', 'missing')
    Add-Case 'invalid-second-page' $document.OuterXml 1 "Graph 2: Edge 'app-to-storage' has unknown target 'missing'"
    Add-Case 'compressed-page' '<mxfile><diagram id="compressed">encoded-payload</diagram></mxfile>' 1 'Compressed unchecked'
    Add-Case 'empty-file' '<mxfile />' 1 'no diagram pages'
    Add-Case 'malformed-xml' '<mxfile><diagram></mxfile>' 1 'Cannot read diagram XML'
    Add-Case 'unsupported-root' '<diagram />' 1 'Unsupported root'
    Add-Case 'dtd' '<!DOCTYPE mxfile [<!ENTITY test "blocked">]><mxfile>&test;</mxfile>' 1 'Cannot read diagram XML'

    $cases.Add([pscustomobject]@{
        Name = 'missing-file'
        Path = Join-Path $temporaryDirectory 'does-not-exist.drawio'
        ExpectedExit = 1
        ExpectedMessage = 'Cannot read diagram XML'
    })

    foreach ($case in $cases) {
        $output = (& $runtime -NoProfile -File $validator -Path $case.Path 2>&1 | Out-String)
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne $case.ExpectedExit -or -not $output.Contains($case.ExpectedMessage)) {
            throw "FAIL $($case.Name): expected exit $($case.ExpectedExit) and '$($case.ExpectedMessage)', got exit $exitCode.`n$output"
        }
        Write-Host "PASS $($case.Name)"
    }
    Write-Host "$($cases.Count) validator regression tests passed."
}
finally {
    foreach ($fixture in $fixtures) {
        Remove-Item -LiteralPath $fixture -Force
    }
    Remove-Item -LiteralPath $temporaryDirectory -Force
}

exit 0
