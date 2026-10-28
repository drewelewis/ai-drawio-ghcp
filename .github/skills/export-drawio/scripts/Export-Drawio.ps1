#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string] $Path,

    [string] $OutputDirectory,
    [string] $DrawioPath,
    [switch] $Force,

    [ValidateRange(1, 600)]
    [int] $TimeoutSeconds = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$source = Get-Item -LiteralPath $Path
if ($source -isnot [System.IO.FileInfo] -or $source.Extension -notin @('.drawio', '.xml')) {
    throw 'The input must be a .drawio or .xml file.'
}
$validator = Join-Path $PSScriptRoot '..\..\validate-drawio\scripts\Validate-Drawio.ps1'
& $validator -Path $source.FullName
if ($LASTEXITCODE -ne 0) {
    throw 'Diagram validation failed; no SVGs were exported.'
}

$document = [System.Xml.XmlDocument]::new()
$document.XmlResolver = $null
$document.Load($source.FullName)
$pageCount = if ($document.DocumentElement.Name -ceq 'mxGraphModel') {
    1
}
else {
    $document.SelectNodes('/mxfile/diagram').Count
}
$destination = if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $source.DirectoryName
}
else {
    $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
}
if ((Test-Path -LiteralPath $destination) -and -not (Test-Path -LiteralPath $destination -PathType Container)) {
    throw "Output directory is not a directory: $destination"
}
$outputs = @(for ($page = 1; $page -le $pageCount; $page++) {
    $name = if ($pageCount -eq 1) { "$($source.BaseName).svg" } else { "$($source.BaseName)-page-$page.svg" }
    Join-Path $destination $name
})
foreach ($output in $outputs) {
    if (Test-Path -LiteralPath $output) {
        $existing = Get-Item -LiteralPath $output -Force
        if ($existing -isnot [System.IO.FileInfo] -or $existing.LinkType) {
            throw "Refusing to replace a directory or link: $output"
        }
        if (-not $Force) {
            throw "Output already exists: $output. Use -Force only after approving replacement."
        }
    }
}

if ($DrawioPath) {
    if (-not (Test-Path -LiteralPath $DrawioPath -PathType Leaf)) {
        throw "draw.io executable not found: $DrawioPath"
    }
    $renderer = (Resolve-Path -LiteralPath $DrawioPath).ProviderPath
}
else {
    $commands = @(Get-Command drawio, draw.io -CommandType Application -ErrorAction SilentlyContinue)
    $candidates = @($commands | Select-Object -ExpandProperty Source)
    if ($IsWindows) {
        $candidates += Join-Path $env:ProgramFiles 'draw.io\draw.io.exe'
        $candidates += Join-Path $env:LOCALAPPDATA 'Programs\draw.io\draw.io.exe'
        $candidates += Join-Path $env:LOCALAPPDATA 'draw.io\draw.io.exe'
    }
    elseif ($IsMacOS) {
        $candidates += '/Applications/draw.io.app/Contents/MacOS/draw.io'
        $candidates += Join-Path $HOME 'Applications/draw.io.app/Contents/MacOS/draw.io'
    }
    $renderer = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if (-not $renderer) {
        throw 'draw.io Desktop was not found. Install it from https://github.com/jgraph/drawio-desktop/releases or supply -DrawioPath. The VS Code extension alone is not sufficient.'
    }
}

$null = [System.IO.Directory]::CreateDirectory($destination)
$stagingDirectory = Join-Path $destination ".drawio-export-$([guid]::NewGuid().ToString('N'))"
$null = New-Item -ItemType Directory -Path $stagingDirectory
$stagedFiles = @($outputs | ForEach-Object { Join-Path $stagingDirectory ([System.IO.Path]::GetFileName($_)) })
try {
    for ($index = 0; $index -lt $pageCount; $index++) {
        $process = [System.Diagnostics.Process]::new()
        try {
            $process.StartInfo.FileName = $renderer
            $process.StartInfo.UseShellExecute = $false
            $process.StartInfo.CreateNoWindow = $true
            $process.StartInfo.RedirectStandardOutput = $true
            $process.StartInfo.RedirectStandardError = $true
            $null = $process.StartInfo.Environment.Remove('ELECTRON_RUN_AS_NODE')
            foreach ($argument in @(
                '--export', '--format', 'svg', '--embed-svg-images', '--embed-svg-fonts', 'false',
                '--page-index', ($index + 1).ToString(), '--output', $stagedFiles[$index], $source.FullName
            )) {
                $process.StartInfo.ArgumentList.Add($argument)
            }
            $null = $process.Start()
            $stdout = $process.StandardOutput.ReadToEndAsync()
            $stderr = $process.StandardError.ReadToEndAsync()
            if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
                $process.Kill($true)
                $process.WaitForExit()
                throw "draw.io export timed out after $TimeoutSeconds seconds on page $($index + 1)."
            }
            $log = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()
            if ($process.ExitCode -ne 0) {
                throw "draw.io export failed on page $($index + 1) (exit $($process.ExitCode)). $log"
            }
            if ($log.Trim()) {
                Write-Host $log.Trim()
            }
        }
        finally {
            $process.Dispose()
        }

        if (-not (Test-Path -LiteralPath $stagedFiles[$index] -PathType Leaf)) {
            throw "draw.io produced no SVG for page $($index + 1)."
        }
        $settings = [System.Xml.XmlReaderSettings]::new()
        $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
        $settings.XmlResolver = $null
        $reader = [System.Xml.XmlReader]::Create($stagedFiles[$index], $settings)
        try {
            $svg = [System.Xml.XmlDocument]::new()
            $svg.XmlResolver = $null
            $svg.Load($reader)
        }
        finally {
            $reader.Dispose()
        }
        if ($svg.DocumentElement.LocalName -cne 'svg' -or
            $svg.DocumentElement.NamespaceURI -cne 'http://www.w3.org/2000/svg') {
            throw "Page $($index + 1) is not an SVG document."
        }
        if ($svg.DocumentElement.HasAttribute('content')) {
            throw "Page $($index + 1) unexpectedly contains embedded diagram XML."
        }
        foreach ($image in $svg.SelectNodes('//*[local-name()="image" or local-name()="img"]')) {
            $reference = $image.GetAttribute('href', 'http://www.w3.org/1999/xlink')
            if (-not $reference) { $reference = $image.GetAttribute('href') }
            if (-not $reference) { $reference = $image.GetAttribute('src') }
            if ($reference -notmatch '^(data:|#)') {
                throw "Page $($index + 1) has an unresolved image reference: $reference"
            }
        }
    }
    for ($index = 0; $index -lt $outputs.Count; $index++) {
        [System.IO.File]::Move($stagedFiles[$index], $outputs[$index], [bool] $Force)
        Write-Host "EXPORTED $($outputs[$index])"
    }
}
finally {
    foreach ($stagedFile in $stagedFiles) {
        if (Test-Path -LiteralPath $stagedFile) {
            Remove-Item -LiteralPath $stagedFile -Force
        }
    }
    Remove-Item -LiteralPath $stagingDirectory -Force
}

exit 0
