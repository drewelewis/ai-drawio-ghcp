#requires -Version 7.0
[CmdletBinding()]
param([string] $DrawioPath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$exporter = Join-Path $PSScriptRoot 'Export-Drawio.ps1'
$templatePath = Join-Path $PSScriptRoot '..\..\azure-drawio\assets\azure-web-app.drawio'
$template = [System.IO.File]::ReadAllText($templatePath)
$runtime = (Get-Process -Id $PID).Path
$temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "drawio export tests $([guid]::NewGuid().ToString('N'))"
$null = New-Item -ItemType Directory -Path $temporaryDirectory
$source = Join-Path $temporaryDirectory 'sample diagram.drawio'
$multiSource = Join-Path $temporaryDirectory 'multiple pages.drawio'
$badSource = Join-Path $temporaryDirectory 'invalid.drawio'
$compressedSource = Join-Path $temporaryDirectory 'compressed.drawio'
$blockedDirectory = Join-Path $temporaryDirectory 'not-a-directory'
$collisionDirectory = Join-Path $temporaryDirectory 'collisions'
$null = New-Item -ItemType Directory -Path $collisionDirectory
[System.IO.File]::WriteAllText($source, $template)
[System.IO.File]::WriteAllText($badSource, '<mxfile>')
[System.IO.File]::WriteAllText($compressedSource, '<mxfile><diagram>compressed</diagram></mxfile>')
[System.IO.File]::WriteAllText($blockedDirectory, 'preserve')
$document = [System.Xml.XmlDocument]::new()
$document.LoadXml($template)
$document.SelectSingleNode('//mxCell[@id="title"]').SetAttribute('value', 'FIRST PAGE MARKER')
$secondPage = $document.DocumentElement.FirstChild.CloneNode($true)
$secondPage.SetAttribute('id', 'second-page')
$secondPage.SelectSingleNode('.//mxCell[@id="title"]').SetAttribute('value', 'SECOND PAGE MARKER')
$null = $document.DocumentElement.AppendChild($secondPage)
[System.IO.File]::WriteAllText($multiSource, $document.OuterXml)
$collision = Join-Path $collisionDirectory 'sample diagram.svg'
$multiCollision = Join-Path $collisionDirectory 'multiple pages-page-2.svg'
[System.IO.File]::WriteAllText($collision, 'preserve existing SVG')
[System.IO.File]::WriteAllText($multiCollision, 'preserve page two')

function Assert-ExportFailure {
    param([string] $Name, [string[]] $Arguments, [string] $Message)
    $output = (& $runtime -NoProfile -File $exporter @Arguments 2>&1 | Out-String)
    if ($LASTEXITCODE -eq 0 -or -not $output.Contains($Message)) {
        throw "FAIL ${Name}: expected failure containing '$Message'.`n$output"
    }
    Write-Host "PASS $Name"
}

try {
    Assert-ExportFailure 'invalid-xml' @('-Path', $badSource) 'Diagram validation failed'
    Assert-ExportFailure 'compressed-input' @('-Path', $compressedSource) 'Diagram validation failed'
    Assert-ExportFailure 'output-is-file' @('-Path', $source, '-OutputDirectory', $blockedDirectory) 'Output directory is not a directory'
    Assert-ExportFailure 'protect-existing-svg' @('-Path', $source, '-OutputDirectory', $collisionDirectory) 'Output already exists'
    Assert-ExportFailure 'preflight-all-pages' @('-Path', $multiSource, '-OutputDirectory', $collisionDirectory) 'Output already exists'
    Assert-ExportFailure 'missing-renderer' @('-Path', $source, '-DrawioPath', (Join-Path $temporaryDirectory 'missing-renderer')) 'draw.io executable not found'
    Assert-ExportFailure 'renderer-nonzero-exit' @('-Path', $source, '-DrawioPath', $runtime) 'draw.io export failed'
    Assert-ExportFailure 'failure-preserves-existing-svg' @('-Path', $source, '-OutputDirectory', $collisionDirectory, '-Force', '-DrawioPath', $runtime) 'draw.io export failed'
    if ([System.IO.File]::ReadAllText($collision) -cne 'preserve existing SVG' -or
        [System.IO.File]::ReadAllText($multiCollision) -cne 'preserve page two' -or
        (Test-Path -LiteralPath (Join-Path $collisionDirectory 'multiple pages-page-1.svg'))) {
        throw 'Failed export modified existing outputs or published a partial page set.'
    }
    Write-Host 'PASS failed exports preserve outputs'

    if ($DrawioPath) {
        $sourceHash = (Get-FileHash -LiteralPath $source).Hash
        $singleDirectory = Join-Path $temporaryDirectory 'single output'
        $multiDirectory = Join-Path $temporaryDirectory 'multi output'
        & $exporter -Path $source -OutputDirectory $singleDirectory -DrawioPath $DrawioPath
        if ($LASTEXITCODE -ne 0) { throw 'Real single-page export failed.' }
        $svgPath = Join-Path $singleDirectory 'sample diagram.svg'
        $svg = [System.Xml.XmlDocument]::new()
        $svg.XmlResolver = $null
        $svg.Load($svgPath)
        $images = @($svg.SelectNodes('//*[local-name()="image"]'))
        if ($svg.DocumentElement.LocalName -cne 'svg' -or
            $svg.DocumentElement.NamespaceURI -cne 'http://www.w3.org/2000/svg' -or
            $svg.DocumentElement.HasAttribute('content') -or
            -not $svg.DocumentElement.InnerText.Contains('Azure App Service') -or $images.Count -lt 5) {
            throw 'SVG lacks expected drawing content, labels or Azure icons, or includes diagram XML.'
        }
        foreach ($image in $images) {
            $reference = $image.GetAttribute('href', 'http://www.w3.org/1999/xlink')
            if (-not $reference) { $reference = $image.GetAttribute('href') }
            if ($reference -notmatch '^data:image/') { throw 'Azure icon was not embedded.' }
        }
        Write-Host 'PASS rendered SVG with embedded Azure icons and no diagram XML'
        & $exporter -Path $source -OutputDirectory $singleDirectory -DrawioPath $DrawioPath -Force
        if ($LASTEXITCODE -ne 0) { throw 'Approved SVG replacement failed.' }
        if ((Get-FileHash -LiteralPath $source).Hash -cne $sourceHash) { throw 'Export modified the source diagram.' }
        Write-Host 'PASS approved replacement and source preservation'

        & $exporter -Path $multiSource -OutputDirectory $multiDirectory -DrawioPath $DrawioPath
        if ($LASTEXITCODE -ne 0) { throw 'Real multi-page export failed.' }
        $svgs = @(Get-ChildItem -LiteralPath $multiDirectory -Filter '*.svg' -File)
        if ($svgs.Count -ne 2 -or (Test-Path -LiteralPath (Join-Path $multiDirectory 'multiple pages.svg'))) {
            throw 'Expected one numbered SVG for each of the two pages.'
        }
        for ($page = 1; $page -le 2; $page++) {
            $svg.Load((Join-Path $multiDirectory "multiple pages-page-$page.svg"))
            $expected = if ($page -eq 1) { 'FIRST PAGE MARKER' } else { 'SECOND PAGE MARKER' }
            if (-not $svg.DocumentElement.InnerText.Contains($expected)) { throw "Wrong page rendered in SVG $page." }
        }
        Write-Host 'PASS all pages rendered to distinct numbered SVGs'
    }
    else {
        Write-Host 'SKIP real-renderer integration: pass -DrawioPath to test actual SVG rendering.'
    }
    Write-Host 'PASS SVG export tests'
}
finally {
    Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force
}

exit 0
