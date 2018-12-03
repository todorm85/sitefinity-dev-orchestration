<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sf-undo-pendingChanges {
    [CmdletBinding()]
    Param()

    $context = _get-selectedProject
    if (!(Test-Path $context.solutionPath)) {
        throw "invalid or no solution path"
    }

    tfs-undo-pendingChanges $context.solutionPath
}

<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sf-show-pendingChanges {
    [CmdletBinding()]
    Param(
        [switch]$detailed
        )

    if ($detailed) {
        $format = "Detailed"
    } else {
        $format = "Brief"
    }

    $context = _get-selectedProject
    if (-not $context -or -not $context.solutionPath -or -not (Test-Path $context.solutionPath)) {
        throw "invalid or no solution path"
    }
    
    $workspaceName = tfs-get-workspaceName $context.solutionPath
    tfs-show-pendingChanges $workspaceName $format
}

function sf-get-hasPendingChanges {
    $pendingResult = sf-show-pendingChanges
    if ($pendingResult -eq 'There are no pending changes.') {
        return $false
    } else {
        return $true
    }
}

<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sf-get-latestChanges {
    [CmdletBinding()]
    Param(
        [switch]$overwrite
    )
    
    [SfProject]$context = _get-selectedProject
    $solutionPath = $context.solutionPath
    if (!(Test-Path $solutionPath)) {
        throw "invalid or no solution path"
    }

    if ($solutionPath -eq '') {
        throw "Solution path is not set."
    }

    Write-Host "Getting latest changes for path ${solutionPath}."
    if ($overwrite) {
        tfs-get-latestChanges -branchMapPath $solutionPath -overwrite
    } else {
        tfs-get-latestChanges -branchMapPath $solutionPath
    }
    
    $context.lastGetLatest = [System.DateTime]::Today
    _save-selectedProject $context

    Write-Host "Getting latest changes complete."
}