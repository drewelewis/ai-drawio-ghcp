#requires -Version 7.0
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).ProviderPath
$githubRoot = Join-Path $repositoryRoot '.github'
$skillsRoot = Join-Path $githubRoot 'skills'
$skillDirectories = @(Get-ChildItem -LiteralPath $skillsRoot -Directory)

foreach ($requiredSkill in @('azure-drawio', 'edit-drawio', 'validate-drawio', 'export-drawio')) {
    if ($requiredSkill -cnotin $skillDirectories.Name) {
        throw "Missing required skill '$requiredSkill'."
    }
}

foreach ($directory in $skillDirectories) {
    $skillPath = Join-Path $directory.FullName 'SKILL.md'
    $text = Get-Content -LiteralPath $skillPath -Raw
    $frontmatter = [regex]::Match(
        $text,
        '\A---\r?\n(?<fields>.*?)\r?\n---(?:\r?\n|\z)',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
    if (-not $frontmatter.Success) {
        throw "Missing YAML frontmatter in '$skillPath'."
    }
    $fields = $frontmatter.Groups['fields'].Value
    $names = [regex]::Matches($fields, '(?m)^name: (?<value>[a-z0-9]+(?:-[a-z0-9]+)*)\r?$')
    $descriptions = [regex]::Matches($fields, '(?m)^description: ''(?<value>(?:[^''\r\n]|'''')+)''\r?$')
    if ($names.Count -ne 1 -or $descriptions.Count -ne 1) {
        throw "Expected one bare name and one single-line, single-quoted description in '$skillPath'."
    }
    $name = $names[0].Groups['value'].Value
    $description = $descriptions[0].Groups['value'].Value.Replace("''", "'")
    if ($name.Length -gt 64 -or $name -cne $directory.Name) {
        throw "Invalid or mismatched skill name in '$skillPath'."
    }
    if ([string]::IsNullOrWhiteSpace($description) -or $description.Length -gt 1024) {
        throw "Description must contain 1-1024 characters in '$skillPath'."
    }
    if (($text -split '\r?\n').Count -ge 500) {
        throw "Keep '$skillPath' below 500 lines."
    }
    Write-Host "PASS skill metadata: $name"
}

$agentPath = Join-Path $githubRoot 'agents\azure-diagram-architect.agent.md'
$agentText = Get-Content -LiteralPath $agentPath -Raw
$agentMetadata = [regex]::Match(
    $agentText,
    '\A---\r?\nname: Azure Diagram Architect\r?\ndescription: ''(?<description>(?:[^''\r\n]|'''')+)''\r?\n---(?:\r?\n|\z)'
)
if (-not $agentMetadata.Success -or $agentMetadata.Groups['description'].Value.Length -gt 1024) {
    throw "Invalid Azure Diagram Architect agent metadata in '$agentPath'."
}
Write-Host 'PASS Azure Diagram Architect agent metadata'

$markdownFiles = @(Get-ChildItem -LiteralPath $repositoryRoot -Filter '*.md' -File) +
    @(Get-ChildItem -LiteralPath $githubRoot -Filter '*.md' -Recurse -File)
foreach ($file in $markdownFiles) {
    $text = Get-Content -LiteralPath $file.FullName -Raw
    foreach ($link in [regex]::Matches($text, '\]\((?<target>[^)\r\n]+)\)')) {
        $target = $link.Groups['target'].Value.Trim([char[]] '<>')
        if ($target -match '^(?:[a-z][a-z0-9+.-]*:|#)') {
            continue
        }
        $relativePath = [System.Uri]::UnescapeDataString(($target -split '#', 2)[0])
        if (-not (Test-Path -LiteralPath (Join-Path $file.DirectoryName $relativePath))) {
            throw "Broken local link in '$($file.FullName)': $target"
        }
    }
}
Write-Host 'PASS local documentation links'

foreach ($file in Get-ChildItem -LiteralPath $githubRoot -Filter '*.ps1' -Recurse -File) {
    $tokens = $null
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName, [ref] $tokens, [ref] $parseErrors
    )
    if ($parseErrors.Count -gt 0) {
        throw "PowerShell syntax errors in '$($file.FullName)': $($parseErrors | Out-String)"
    }
    Write-Host "PASS PowerShell syntax: $($file.Name)"
}

$recommendationsPath = Join-Path $repositoryRoot '.vscode\extensions.json'
$recommendations = Get-Content -LiteralPath $recommendationsPath -Raw | ConvertFrom-Json
if ('hediet.vscode-drawio' -notin $recommendations.recommendations) {
    throw 'Missing draw.io editor recommendation.'
}
Write-Host 'PASS editor recommendations'

$diagramFiles = @(Get-ChildItem -LiteralPath $skillsRoot -Filter '*.drawio' -Recurse -File)
$diagramsDirectory = Join-Path $repositoryRoot 'diagrams'
if (Test-Path -LiteralPath $diagramsDirectory) {
    $diagramFiles += @(Get-ChildItem -LiteralPath $diagramsDirectory -Filter '*.drawio' -Recurse -File)
}
if ($diagramFiles.Count -eq 0) {
    throw 'No example diagrams found.'
}
$validatorDirectory = Join-Path $skillsRoot 'validate-drawio\scripts'
& (Join-Path $validatorDirectory 'Validate-Drawio.ps1') -Path ([string[]] $diagramFiles.FullName)
if ($LASTEXITCODE -ne 0) {
    throw 'Diagram validation failed.'
}
& (Join-Path $validatorDirectory 'Test-DrawioValidator.ps1')
if ($LASTEXITCODE -ne 0) {
    throw 'Validator regression tests failed.'
}
& (Join-Path $skillsRoot 'export-drawio\scripts\Test-DrawioExport.ps1')
if ($LASTEXITCODE -ne 0) {
    throw 'SVG export regression tests failed.'
}

Write-Host 'PASS repository checks'
exit 0
