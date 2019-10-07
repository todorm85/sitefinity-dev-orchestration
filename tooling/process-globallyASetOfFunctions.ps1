# $path = "$PSScriptRoot\..\sf-dev\core"
$path = "$PSScriptRoot\..\"

# $oldNames = Invoke-Expression "& `"$PSScriptRoot/get-Functions.ps1`" -path `"$path`""
$oldNames = @('sf-data-getAllProjects', 'sf-proj-tools-StartAllProjectsBatch', 'sf-proj-setDescription', 'sf-proj-new', 'sf-proj-clone', 'sf-proj-import', 'sf-proj-removeBulk', 'sf-proj-remove', 'sf-proj-rename', 'sf-proj-reset', 'sf-proj-setCurrent', 'sf-proj-getCurrent', 'sf-proj-getDescription', 'sf-proj-tags-add', 'sf-proj-tags-remove', 'sf-proj-tags-removeAll', 'sf-proj-tags-getAll', 'sf-proj-tags-setDefaultFilter', 'sf-proj-tags-getDefaultFilter', 'sf-proj-tools-updateAllProjectsTfsInfo', 'sf-proj-tools-clearAllProjectsLeftovers', 'sf-proj-tools-goto', 'sf-proj-select', 'sf-proj-show', 'sf-proj-showAll', 'sf-sol-build', 'sf-sol-rebuild', 'sf-sol-clean', 'sf-sol-clearPackages', 'sf-sol-open', 'sf-sol-buildWebAppProj', 'sf-sol-unlockAllFiles', 'sf-tfs-undoPendingChanges', 'sf-tfs-showPendingChanges', 'sf-tfs-hasPendingChanges', 'sf-tfs-getLatestChanges', 'sf-iis-pool-resetThread', 'sf-iis-pool-reset', 'sf-iis-pool-stop', 'sf-iis-pool-change', 'sf-iis-pool-getId', 'sf-iis-subApp-set', 'sf-iis-subApp-remove', 'sf-iis-site-rename', 'sf-iis-site-open', 'sf-iis-site-new', 'sf-app-configs-setStorageMode', 'sf-app-configs-getStorageMode', 'sf-app-configs-getFromDb', 'sf-app-configs-clearInDb', 'sf-app-configs-setInDb', 'sf-app-db-getName', 'sf-app-db-setName', 'sf-app-reset', 'sf-app-addPrecompiledTemplates', 'sf-app-states-save', 'sf-app-states-restore', 'sf-app-states-remove', 'sf-app-states-removeAll')

function Rename-Function {
    param (
        [string]$text
    )
    
    $text = $text.Replace("_", "");
    $result = "";
    $setCapital = $true;
    for ($i = 0; $i -lt $text.Length; $i++) {
        $letter = $text[$i]
        if ($setCapital) {
            $newResult = $letter.ToString().ToUpperInvariant();
        } else {
            $newResult = $letter
        }

        if ($letter -eq '-') {
            $setCapital = $true;
        } else {
            $result = "$result$newResult"
            $setCapital = $false;
        }
    }

    $result
}

$scripts = Get-ChildItem $path -Recurse | Where-Object { $_.Extension -eq '.ps1'}

$scripts | % { 
    $content = Get-Content $_.FullName
    $oldNames | % {
        # $newTitle = Rename-Function($_)
        [string]$oldName = [string]$_
        $newTitle = "sf-" + $oldName
        $content = $content -replace $oldName, $newTitle
    }

    $content | Set-Content -Path $_.FullName
}
