$classStartMarker = "# class::"
$classElementMarker = '# ::'

$psmFileContent = Get-Content "$PSScriptRoot/../sf-dev/sf-dev.psm1"
$docText = '# Sf-Dev PowerShell Module Auto-Generated Documentation'

for ($i = 0; $i -lt $psmFileContent.Count; $i++) {
    $line = $psmFileContent[$i].Trim()
    
    if ($line.startsWith($classStartMarker)) {
        $docText += "`n## $($line.TrimStart($classStartMarker))`n"
    }

    if ($line.startsWith($classElementMarker)) {
        $elementDescription = $line.TrimStart($classElementMarker)
            
        $elementName = $psmFileContent[$i + 1].Split(')')[0].Trim() + ')'

        $docText += "`n- $elementName`n`n    $elementDescription`n"
    }
}

$docText.Trim().Replace('[void]', '') | Out-File "$PSScriptRoot/../docs.md" -Encoding utf8