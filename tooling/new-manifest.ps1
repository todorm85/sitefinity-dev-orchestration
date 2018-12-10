Param(
    $env
)

# module discovery
$rootModule = "sf-dev"
$scripts = Get-ChildItem "$PSScriptRoot\..\module\core" -Recurse | Where-Object { $_.Extension -eq '.ps1'}
# functions discovery
$modulesLines = $scripts | Get-Content
$functionsLines = $modulesLines | Where-Object { $_.contains("function") }

$functionNamePattern = "^\s*?function\s+?(?<name>(sf-).+?)\s+({|\().*$"
$filteredNames = $functionsLines | Where-Object { $_ -match $functionNamePattern } | % { $Matches["name"] }
$functionNames = New-Object System.Collections.ArrayList($null)
$functionNames.AddRange($filteredNames) > $null

if ($env -eq 'dev') {
    $functionNames = '*'
}

# generate manifest
New-ModuleManifest `
    -Path "$PSScriptRoot\..\module\sf-dev.psd1" `
    -RootModule $rootModule `
    -ModuleVersion '1.0' `
    -FunctionsToExport $functionNames `
    -CmdletsToExport '' `
    -VariablesToExport '' `
    -Author 'Todor Mitskovski' `
    -Description 'Sitefinity core dev automation tools' `
    -ScriptsToProcess 'bootstrap\load-nestedModules.ps1' `
    -Guid "570fb657-4d88-4883-8b39-2dae4db1280c"
    -PowerShellVersion '5.0' -ClrVersion '4.0';