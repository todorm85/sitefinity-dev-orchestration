function Get-CsharpClasses {
    Get-ChildItem -Path "$PSScriptRoot\..\core" -Filter '*.sfdev.cs' -Recurse
}

function Get-ScriptFiles {
    Get-ChildItem -Path "$PSScriptRoot\..\core" -Filter '*.ps1' -Recurse
}

Import-Module WebAdministration -Force

# Do not dot source in function scope it won`t be loaded inside the module
# Type definitions must be added as a single bundle
$definitions = Get-CsharpClasses | % { Get-Content -Path $_.FullName -Raw } | Out-String
Add-Type -TypeDefinition $definitions
Get-ScriptFiles | Where-Object Name -Like "*.init.ps1" | ForEach-Object { . $_.FullName }
Get-ScriptFiles | Where-Object Name -NotLike "*.init.ps1" | ForEach-Object { . $_.FullName }
