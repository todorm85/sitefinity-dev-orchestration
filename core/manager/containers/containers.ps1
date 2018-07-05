function sf-select-container {
    $container = _sf-prompt-containerSelect
    $script:selectedContainer = $container
    _sfData-save-defaultContainer $selectedContainer.name
    sf-select-project
}

function sf-create-container ($name) {
    _sfData-save-container $name
}

function sf-delete-container {
    Param(
        [switch]$removeProjects
    )

    $container = _sf-prompt-containerSelect
    $projects = @(_sfData-get-allProjects) | Where-Object {$_.containerName -eq $container.name}
    foreach ($proj in $projects) {
        if ($removeProjects) {
            _sf-set-currentProject $proj
            sf-delete-project -noPromptAfterComplete
        }
        else {
            $proj.containerName = ""
            _save-selectedProject $proj
        }
    } 

    if (_sfData-get-defaultContainerName -eq $container.name) {
        _sfData-save-defaultContainer ""
    }

    _sfData-delete-container $container.name

    Write-Host "`nOperation successful.`n"

    sf-select-container
}

function sf-set-projectContainer {
    $context = _get-selectedProject
    $container = _sf-prompt-containerSelect
    $context.containerName = $container.name
    _save-selectedProject $context
}

function _sf-get-allProjectsForCurrentContainer {
    $sitefinities = @(_sfData-get-allProjects)
    [System.Collections.ArrayList]$output = @()
    foreach ($sitefinity in $sitefinities) {
        if ($script:selectedContainer.name -eq $sitefinity.containerName) {
            $output.add($sitefinity) > $null
        }
    }

    return $output
}
