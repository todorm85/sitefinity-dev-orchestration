function _data-getAllProjects {
    param(
        [string[]]$tagsFilter
    )
    $data = New-Object XML
    $data.Load($GLOBAL:sf.Config.dataPath)
    $sfs = $data.data.sitefinities.sitefinity
    [System.Collections.Generic.List``1[SfProject]]$sitefinities = New-Object System.Collections.Generic.List``1[SfProject]
    if ($sfs) {
        $sfs | ForEach-Object {
            if ($_.lastGetLatest) {
                $lastGetLatest = [System.DateTime]::Parse($_.lastGetLatest)
            }
            else {
                $lastGetLatest = $null
            }

            $tags = @()
            if ($_.tags) {
                $tags = $_.tags.Split(' ')
            }

            $clone = [SfProject]::new()
            $clone.id = $_.id;
            $clone.branch = $_.branch;
            $clone.description = $_.description;
            $clone.displayName = $_.displayName;
            $clone.solutionPath = $_.solutionPath;
            $clone.webAppPath = $_.webAppPath;
            $clone.websiteName = $_.websiteName;
            $clone.tags = $tags;
            $clone.lastGetLatest = $lastGetLatest;
            $clone.daysSinceLastGet = _getDaysSinceDate $lastGetLatest;

            $sitefinities.Add($clone)
        }
    }

    if ($tagsFilter) {
        $sitefinities = _filterProjectsByTags -sitefinities $sitefinities -tagsFilter $tagsFilter
    }

    return $sitefinities
}

function _removeProjectData {
    Param($context)
    Write-Information "Updating script databse..."
    $id = $context.id
    try {
        $data = New-Object XML
        $data.Load($GLOBAL:sf.Config.dataPath) > $null
        $sitefinities = $data.data.sitefinities.sitefinity
        ForEach ($sitefinity in $sitefinities) {
            if ($sitefinity.id -eq $id) {
                $sitefinitiesParent = $data.SelectSingleNode('/data/sitefinities')
                $sitefinitiesParent.RemoveChild($sitefinity)
            }
        }

        $data.Save($GLOBAL:sf.Config.dataPath) > $null
    }
    catch {
        throw "Error deleting sitefinity from ${dataPath}. Message: $_"
    }
}

function _setProjectData {
    Param([SfProject]$context)

    $context = [SfProject]$context
    $data = New-Object XML
    $data.Load($GLOBAL:sf.Config.dataPath) > $null
    $sitefinities = $data.data.sitefinities.sitefinity
    ForEach ($sitefinity in $sitefinities) {
        if ($sitefinity.id -eq $context.id) {
            $sitefinityEntry = $sitefinity
            break
        }
    }

    if ($null -eq $sitefinityEntry) {
        $sitefinityEntry = $data.CreateElement("sitefinity");
        $sitefinities = $data.SelectSingleNode('/data/sitefinities')
        $sitefinities.AppendChild($sitefinityEntry) > $null
    }

    $tags = ''
    if ($context.tags) {
        $context.tags | % { $tags = "$tags $_" }
    }

    $tags = $tags.TrimStart(' ')

    $sitefinityEntry.SetAttribute("id", $context.id)
    $sitefinityEntry.SetAttribute("displayName", $context.displayName)
    $sitefinityEntry.SetAttribute("solutionPath", $context.solutionPath)
    $sitefinityEntry.SetAttribute("webAppPath", $context.webAppPath)
    $sitefinityEntry.SetAttribute("websiteName", $context.websiteName)
    $sitefinityEntry.SetAttribute("branch", $context.branch)
    $sitefinityEntry.SetAttribute("description", $context.description)
    $sitefinityEntry.SetAttribute("tags", $tags)
    $sitefinityEntry.SetAttribute("lastGetLatest", $context.lastGetLatest)

    $data.Save($GLOBAL:sf.Config.dataPath) > $null
}

function _setDefaultTagsFilter {
    param (
        [string[]]$defaultTagsFilter
    )
    
    $data = New-Object XML
    $data.Load($GLOBAL:sf.Config.dataPath) > $null
    $serializedFilter = ""
    $defaultTagsFilter | ForEach-Object { $serializedFilter = "$serializedFilter $_" }
    $serializedFilter = $serializedFilter.Trim()
    $data.data.SetAttribute("defaultTagsFilter", $serializedFilter) > $null
    
    $data.Save($GLOBAL:sf.Config.dataPath) > $null
}

function _getDefaultTagsFilter {
    $data = New-Object XML
    $data.Load($GLOBAL:sf.Config.dataPath) > $null
    $result = $data.data.GetAttribute("defaultTagsFilter").Split(" ")
    if ($result) {
        return ,$result
    } else {
        return @()
    }
}
