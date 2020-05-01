function sf {
    [CmdletBinding()]
    param (
        [switch]$getLatestChanges,
        [switch]$forceGetLatest,
        [switch]$stopIfNoNewGetlatest,
        [switch]$discardExistingChanges,
        [switch]$cleanSolution,
        [switch]$buildSolution,
        [switch]$reOrInitializeSitefinityApp,
        [switch]$resetAppPool,
        [switch]$precompileTemplates,
        [switch]$ensureSitefinityIsRunning,
        [switch]$saveApplicationState,
        [Parameter(ValueFromPipeline)]
        [SfProject]$project
    )
    
    Process {
        if (!$project) {
            $project = sf-project-getCurrent
        }

        InProjectScope -project $project {
            if ($discardExistingChanges -and (sf-sourceControl-hasPendingChanges)) {
                sf-sourceControl-undoPendingChanges
                $newChangesDetected = $true
            }
        
            if ($getLatestChanges) {
                $newChangesDetected = $false
                $getLatestOutput = sf-sourceControl-getLatestChanges -overwrite:$forceGetLatest
                if (!$getLatestOutput -or !($getLatestOutput.Contains('All files are up to date.'))) {
                    $newChangesDetected = $true
                }
            
                $project.lastGetLatest = [DateTime]::Now
                sf-project-save -context $project
        
                if (!$newChangesDetected -and $stopIfNoNewGetlatest) {
                    Write-Information "No new changes detected, stopping."
                }
            }
        
            if ($cleanSolution) {
                sf-sol-clean -cleanPackages $true
            }

            if ($buildSolution) {
                sf-sol-build -retryCount 3
            }

            if ($resetAppPool) {
                sf-iisAppPool-Reset
            }
            if ($reOrInitializeSitefinityApp) {
                sf-app-reinitialize
            }

            if ($precompileTemplates) {
                sf-appPrecompiledTemplates-add
            }

            if ($ensureSitefinityIsRunning) {
                sf-app-sendRequestAndEnsureInitialized
            }

            if ($saveApplicationState) {
                Start-Sleep -Seconds 1
                sf-appStates-save -stateName "init"
            }
        }
    }
}