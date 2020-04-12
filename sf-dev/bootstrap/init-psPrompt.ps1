# https://stackoverflow.com/questions/5725888/windows-powershell-changing-the-command-prompt

function Global:prompt {
    Write-Host "PS $(Get-Location)>" -NoNewline
    Write-Host "$Script:prompt" -ForegroundColor Green -NoNewline
    return " "
}

function _update-prompt {
    try {
        _setConsoleTitle

        $project = sf-project-getCurrent
        $projectName = if ($project) { $project.displayName } else { '' }
        if ($projectName) {
            $prompt = " [$projectName]"
        }
        else {
            $prompt = ""
        }

        $Script:prompt = $prompt
    }
    catch {
        Write-Error "$_"
    }
}

function _setConsoleTitle {
    $newContext = sf-project-getCurrent
    if ($newContext) {
        $binding = sf-iisSite-getBinding
        if ($newContext.branch) {
            $branch = ($newContext.branch).Split([string[]]("$/CMS/Sitefinity 4.0"), [System.StringSplitOptions]::RemoveEmptyEntries)[0]
        }
        else {
            $branch = 'No TFS'
        }

        [System.Console]::Title = "$($newContext.id)|$($newContext.displayName)|$branch"
        Set-Location $newContext.webAppPath
    }
    else {
        [System.Console]::Title = ""
    }
}
