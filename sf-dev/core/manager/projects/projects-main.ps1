<#
    .SYNOPSIS 
    Provisions a new sitefinity instance project. 
    .DESCRIPTION
    Gets latest from the branch, builds and starts a sitefinity instance with default admin user username:admin pass:admin@2. The local path where the project files are created is specified in the constants script file (EnvConstants.ps1).
    .PARAMETER name
    The name of the new sitefinity instance.
    .PARAMETER branch
    The tfs branch from which the Sitefinity source code is downloaded. It has predefined values that can be iterated by pressing tab repeatedly.
    .PARAMETER buildSolution
    Builds the solution after downloading from tfs.
    .PARAMETER startWebApp
    Starts webapp after building the solution.
    .OUTPUTS
    None
#>
function sf-new-project {
    [CmdletBinding()]
    Param(
        [string]$displayName,
        [switch]$buildSolution,
        [switch]$startWebApp,
        [switch]$precompile,
        [string]$customBranch,
        [switch]$noAutoSelect
    )

    DynamicParam {
        # Set the dynamic parameters' name
        $ParameterName = 'predefinedBranch'
        
        # Create the dictionary 
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        # Create the collection of attributes
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        
        # Create and set the parameters' attributes
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $false
        $ParameterAttribute.Position = 1

        # Add the attributes to the attributes collection
        $AttributeCollection.Add($ParameterAttribute)

        # Generate and set the ValidateSet 
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($predefinedBranches)

        # Add the ValidateSet to the attributes collection
        $AttributeCollection.Add($ValidateSetAttribute)

        # Create and return the dynamic parameter
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
        return $RuntimeParameterDictionary
    }

    begin {
        # Bind the parameter to a friendly variable
        $predefinedBranch = $PsBoundParameters[$ParameterName]
    }

    process {
        if ($null -ne $predefinedBranch) {
            $branch = $predefinedBranch
        }
        else {
            $branch = $customBranch
        }

        [SfProject]$newContext = new-SfProject -displayName $displayName
        if (Test-Path $newContext.solutionPath) {
            throw "Path already exists:" + $newContext.solutionPath
        }

        $oldContext = _get-selectedProject

        try {
            Write-Information "Creating solution path..."
            New-Item $newContext.solutionPath -type directory > $null

            $newContext.branch = $branch
            _create-workspace $newContext -branch $branch
            $newContext.lastGetLatest = [datetime]::Today

            $webAppPath = $newContext.solutionPath + '\SitefinityWebApp'
            $newContext.webAppPath = $webAppPath

            Write-Information "Backing up original App_Data folder..."
            $originalAppDataSaveLocation = "$webAppPath/sf-dev-tool/original-app-data"
            New-Item -Path $originalAppDataSaveLocation -ItemType Directory > $null
            copy-sfRuntimeFiles -project $newContext -dest $originalAppDataSaveLocation

            Write-Information "Creating website..."
            sf-create-website -context $newContext

            # persist current context to script data
            _save-selectedProject $newContext
        }
        catch {
            Write-Warning "############ CLEANING UP ############"
            Set-Location $PSScriptRoot
        
            try {
                Write-Information "Deleting workspace..."
                tfs-delete-workspace $newContext.id $Script:tfsServerName
            }
            catch {
                Write-Warning "Error cleaning workspace or it was not created."
            }

            try {
                Write-Information "Deleting solution..."
                Remove-Item -Path $newContext.solutionPath -force -ErrorAction SilentlyContinue -ErrorVariable ProcessError -Recurse
            }
            catch {
                Write-Warning "Error cleaning solution directory or it was not created."
            }

            try {
                Write-Information "Removing website..."
                delete-website -context $newContext
            }
            catch {
                Write-Warning "Could not remove website or it was not created"
            }

            if ($oldContext) {
                set-currentProject $oldContext
            }
            $ii = $_.InvocationInfo
            $msg = $_
            if ($ii) {
                $msg = "$msg`n$($ii.PositionMessage)"
            }

            throw $msg
        }

        try {
            set-currentProject $newContext
            _create-userFriendlySlnName $newContext

            if ($buildSolution) {
                Write-Information "Building solution..."
                sf-build-solution -retryCount 3
            }

            if ($startWebApp) {
                try {
                    Write-Information "Initializing Sitefinity"
                    create-startupConfig
                    start-app
                    if ($precompile) {
                        sf-add-precompiledTemplates
                    }
                }
                catch {
                    Write-Warning "APP WAS NOT INITIALIZED. $_"
                    delete-startupConfig
                }
            }        
        }
        finally {
            if ($noAutoSelect) {
                set-currentProject $oldContext
            }
        }

        return $newContext
    }
}

function sf-clone-project {
    Param(
        [SfProject]$context,
        [switch]$noAutoSelect
    )

    if (!$context) {
        $context = _get-selectedProject
    }

    $sourcePath = $context.solutionPath;
    if ([string]::IsNullOrEmpty($sourcePath)) {
        $sourcePath = $context.webAppPath
    }

    if ([string]::IsNullOrEmpty($sourcePath) -or -not (Test-Path $sourcePath)) {
        throw "Invalid app path";
    }

    $targetId = _generateId
    $targetPath = $Script:projectsDirectory + "\${targetId}"
    if (Test-Path $targetPath) {
        throw "Path exists: ${targetPath}"
    }

    try {
        Write-Information "Copying $sourcePath to $targetPath."
        New-Item $targetPath -ItemType Directory > $null
        Copy-Item "${sourcePath}\*" $targetPath -Recurse
    }
    catch {
        throw "Error copying source files.`n $_"        
    }

    [SfProject]$newProject = $null
    try {
        [SfProject]$newProject = sf-import-project -displayName "$($context.displayName)-clone" -path $targetPath -cloneDb -branch $context.branch -id $targetId -noAutoSelect:$noAutoSelect
    }
    catch {
        throw "Error importing project.`n $_"        
    }

    try {
        sf-delete-allAppStates
    }
    catch {
        throw "Error deleting app states.`n $_"        
    }

    return $newProject
}

<#
    .SYNOPSIS 
    Imports a new sitefinity instance project from given local path. 
    .DESCRIPTION
    A sitefinity web app project or Sitefinity solution can be imported. 
    .PARAMETER displyName
    The name of the imported sitefinity instance.
    .PARAMETER path
    The directory which contains either Telerik.Sitefinity.sln or SitefinityWebApp.csproj files. The app automatically detects whether the full Sitefinity source code or just the webapp that uses Sitefinity CMS is available.
    .OUTPUTS
    None
#>
function sf-import-project {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$displayName,
        [Parameter(Mandatory = $true)][string]$path,
        [switch]$cloneDb,
        [string]$existingSiteName,
        [string]$branch,
        [string]$id,
        [switch]$noAutoSelect
    )

    if (!(Test-Path $path)) {
        throw "Invalid path"
    }

    $isSolution = Test-Path "$path\Telerik.Sitefinity.sln"
    $isWebApp = Test-Path "$path\web.config"
    if (-not $isWebApp -and -not $isSolution) {
        throw "No web app or solution found."
    }

    if ($isWebApp -and $isSolution) {
        throw "Cannot determine whether webapp or solution."
    }

    [SfProject]$newContext = new-SfProject -displayName $displayName -id $id
    if ($isSolution) {
        $newContext.solutionPath = $path
        $newContext.webAppPath = $path + '\SitefinityWebApp'
        $newContext.branch = $branch
        if ($branch) {
            try {
                _create-workspace -context $newContext -branch $branch
            }
            catch {
                Write-Error "Errors while creating workspace: $_"                
            }
        }

        _create-userFriendlySlnName $newContext
    }
    else {
        $newContext.solutionPath = ''
        $newContext.webAppPath = $path
    }

    $oldContext = _get-selectedProject
    set-currentProject $newContext
    try {
        try {
            _save-selectedProject $newContext
        }
        catch {
            set-currentProject $oldContext
            throw "Could not import sitefinity. Could not write project to db. $_"
        }

        if ($existingSiteName) {
            $newContext.websiteName = $existingSiteName
        }
        else {
            try {
                Write-Information "Creating website..."
                sf-create-website -context $newContext > $null
            }
            catch {
                Write-Warning "Error during website creation. Message: $_"
                $newContext.websiteName = ""
            }
        }

        $currentDbName = sf-get-appDbName
        if ($currentDbName) {
            if ($cloneDb) {
                try {
                    sf-set-appDbName $newContext.id
                }
                catch {
                    Write-Warning "Error setting new database name in config ($($newContext.id)).`n $_"                    
                }
                    
                try {
                    [SqlClient]$sql = _get-sqlClient
                    $sql.CopyDb($currentDbName, $newContext.id)
                }
                catch {
                    Write-Warning "Error copying old database. Source: $currentDbName Target $($newContext.id)`n $_"
                }
            }
        }
    }
    finally {
        if ($noAutoSelect) {
            set-currentProject $oldContext
        }
    }
    
    return $newContext
}

function sf-delete-projects {
    $sitefinities = @(get-allProjectsForCurrentContainer)
    if ($null -eq $sitefinities[0]) {
        Write-Host "No projects found. Create one."
        return
    }

    sf-show-projects $sitefinities

    $choices = Read-Host -Prompt 'Choose sitefinities (numbers delemeted by space)'
    $choices = $choices.Split(' ')
    [System.Collections.Generic.List``1[object]]$sfsToDelete = New-Object System.Collections.Generic.List``1[object]
    foreach ($choice in $choices) {
        [SfProject]$selectedSitefinity = $sitefinities[$choice]
        if ($null -eq $selectedSitefinity) {
            Write-Error "Invalid selection $choice"
        }

        $sfsToDelete.Add($selectedSitefinity)
    }

    foreach ($selectedSitefinity in $sfsToDelete) {
        try {
            sf-delete-project -context $selectedSitefinity -noPrompt
        }
        catch {
            Write-Error "Error deleting project with id = $($selectedSitefinity.id)"       
        }
    }
}

<#
    .SYNOPSIS 
    Deletes a sitefinity instance managed by the script.
    .DESCRIPTION
    Everything is deleted - local project files, database, TFS workspace if no switches are passed. 
    .PARAMETER keepWorkspace
    Keeps the workspace if one exists.
    .PARAMETER keepProjectFiles
    Keeps the project files.
    .PARAMETER keepProjectFiles
    Forces the deletion by resetting IIS to free any locked files by the app.
    .OUTPUTS
    None
#>
function sf-delete-project {
    [CmdletBinding()]
    Param(
        [switch]$keepDb,
        [switch]$keepWorkspace,
        [switch]$keepProjectFiles,
        [switch]$noPrompt,
        [SfProject]$context = $null
    )
    
    if ($null -eq $context) {
        $context = _get-selectedProject
    }

    $solutionPath = $context.solutionPath
    $workspaceName = tfs-get-workspaceName $context.webAppPath
    $dbName = sf-get-appDbName $context
    $websiteName = $context.websiteName
    
    if ($websiteName) {
        try {
            sf-stop-pool -context $context
        }
        catch {
            Write-Warning "Could not stop app pool: $_"            
        }
    }

    # while ($true) {
    #     $isConfirmed = Read-Host -Prompt "WARNING! Current operation will reset IIS. You also need to have closed the current sitefinity solution in Visual Studio and any opened browsers for complete deletion. Continue [y/n]?"
    #     if ($isConfirmed -eq 'y') {
    #         break;
    #     }

    #     if ($isConfirmed -eq 'n') {
    #         return
    #     }
    # }

    Set-Location -Path $PSScriptRoot

    # Del workspace
    if ($workspaceName -ne '' -and !($keepWorkspace)) {
        Write-Information "Deleting workspace..."
        try {
            tfs-delete-workspace $workspaceName $Script:tfsServerName
        }
        catch {
            Write-Warning "Could not delete workspace $_"
        }
    }

    # Del db
    if (-not [string]::IsNullOrEmpty($dbName) -and (-not $keepDb)) {
        Write-Information "Deleting sitefinity database..."
        [SqlClient]$sql = _get-sqlClient
        try {
            $sql.Delete($dbName)
        }
        catch {
            Write-Warning "Could not delete database: ${dbName}. $_"
        }
    }

    # Del Website
    Write-Information "Deleting website..."
    if ($websiteName) {
        try {
            delete-website $context
        }
        catch {
            Write-Warning "Errors deleting website ${websiteName}. $_"
        }
    }

    # Del dir
    if (!($keepProjectFiles)) {
        try {
            Write-Information "Unlocking all locked files in solution directory..."
            sf-unlock-allFiles

            Write-Information "Deleting solution directory..."
            if ($solutionPath -ne "") {
                $path = $solutionPath
            }
            else {
                $path = $context.webAppPath
            }

            Remove-Item $path -recurse -force -ErrorAction SilentlyContinue -ErrorVariable ProcessError
            if ($ProcessError) {
                throw $ProcessError
            }
        }
        catch {
            Write-Warning "Errors deleting sitefinity directory. $_"
        }
    }

    Write-Information "Deleting data entry..."
    _sfData-delete-project $context
    set-currentProject $null

    if (-not ($noPrompt)) {
        sf-select-project
    }
}

<#
    .SYNOPSIS
    Renames the current selected sitefinity.
    .PARAMETER markUnused
    If set renames the instanse to '-' and the workspace name to 'unused_{current date}.
    .OUTPUTS
    None
#>
function sf-rename-project {
    [CmdletBinding()]
    Param(
        [switch]$markUnused,
        [string]$newName,
        [switch]$setDescription,
        [SfProject]$project
    )

    if (!$project) {
        $project = _get-selectedProject
    }

    if ($newName -and (-not (validate-nameSyntax $newName))) {
        Write-Error "Name syntax is not valid. Use only alphanumerics and underscores"
    }

    [SfProject]$context = $project
    $oldName = $context.displayName

    if ($markUnused) {
        $newName = _get-unusedProjectName
        $context.description = ""
    }
    elseif (-not $newName) {
        $oldName | Set-Clipboard
        while ([string]::IsNullOrEmpty($newName) -or (-not (validate-nameSyntax $newName))) {
            if ($newName) {
                Write-Warning "Invalid name syntax."
            }

            $newName = $(Read-Host -Prompt "Enter new project name").ToString()
        }

        if ($setDescription) {
            $context.description = $(Read-Host -Prompt "Enter description:`n").ToString()
        }
    }

    $oldSolutionName = generate-solutionFriendlyName -context $context
    if (-not (Test-Path "$($context.solutionPath)\$oldSolutionName")) {
        _create-userFriendlySlnName -context $context
    }

    $context.displayName = $newName

    $newSolutionName = generate-solutionFriendlyName -context $context
    Copy-Item -Path "$($context.solutionPath)\$oldSolutionName" -Destination "$($context.solutionPath)\$newSolutionName" -Force

    $newSlnCacheName = ([string]$newSolutionName).Replace(".sln", "")
    $oldSlnCacheName = ([string]$oldSolutionName).Replace(".sln", "")
    $oldSolutionCachePath = "$($context.solutionPath)\.vs\$oldSlnCacheName"
    if (Test-Path $oldSolutionCachePath) {
        Copy-Item -Path $oldSolutionCachePath -Destination "$($context.solutionPath)\.vs\$newSlnCacheName" -Force -Recurse -ErrorAction SilentlyContinue
        unlock-allFiles -path $oldSolutionCachePath
        Remove-Item -Path $oldSolutionCachePath -Force -Recurse
    }

    $domain = generate-domainName -context $context
    change-domain -context $context -domainName $domain

    $oldSolutionPath = "$($context.solutionPath)\$oldSolutionName"
    unlock-allFiles -path $oldSolutionPath
    Remove-Item -Path $oldSolutionPath -Force

    _save-selectedProject $context
    set-currentProject $context
}

function _create-userFriendlySlnName ($context) {
    $solutionFilePath = "$($context.solutionPath)\Telerik.Sitefinity.sln"
    $targetFilePath = "$($context.solutionPath)\$(generate-solutionFriendlyName $context)"
    Copy-Item -Path $solutionFilePath -Destination $targetFilePath
}

function _save-selectedProject {
    Param($context)

    _validate-project $context

    _sfData-save-project $context
}

function _validate-project {
    Param($context)

    if ($null -ne $context) {
        if ($context.id -eq '') {
            throw "Invalid sitefinity context. No sitefinity id."
        }

        if ($context.solutionPath -ne '') {
            if (-not (Test-Path $context.solutionPath)) {
                throw "Invalid sitefinity context. Solution path does not exist."
            }
        }
        
        if (-not $context.webAppPath -and -not(Test-Path $context.webAppPath)) {
            throw "Invalid sitefinity context. No web app path or it does not exist."
        }
    }
}

function _get-isIdDuplicate ($id) {
    function isDuplicate ($name) {
        if ($name -and $name.Contains($id)) {
            return $true
        }
        return $false
    }

    $sitefinities = [SfProject[]](_sfData-get-allProjects)
    $sitefinities | % {
        $sitefinity = [SfProject]$_
        if ($sitefinity.id -eq $id) {
            return $true;
        }
    }

    if (Test-Path "$Script:projectsDirectory\$id") { return $true }

    $wss = tfs-get-workspaces $Script:tfsServerName | Where-Object { isDuplicate $_ }
    if ($wss) { return $false }

    Import-Module WebAdministration
    $sites = Get-Item "IIS:\Sites"
    if ($sites -and $sites.Children) {
        $names = $sites.Children.Keys | Where-Object { isDuplicate $_ }
        if ($names) { return $true }
    }
    $pools = Get-Item "IIS:\AppPools"
    if ($pools -and $pools.Children) {
        $names = $pools.Children.Keys | Where-Object { isDuplicate $_ }
        if ($names) { return $true }
    }
    [SqlClient]$sql = _get-sqlClient
    $dbs = $sql.GetDbs() | Where-Object { isDuplicate $_.name }
    if ($dbs) { return $false }

    return $false;
}

function _generateId {
    $i = 0;
    while ($true) {
        $name = "$($Script:idPrefix)$i"
        $isDuplicate = (_get-isIdDuplicate $name)
        if (-not $isDuplicate) {
            break;
        }
        
        $i++
    }

    if ([string]::IsNullOrEmpty($name) -or (-not (validate-nameSyntax $name))) {
        throw "Invalid id $name"
    }
    
    return $name
}

function set-currentProject {
    Param(
        [SfProject]$newContext,
        [switch]$fluentInited
    )

    _validate-project $newContext
    
    if ($fluentInited) {
        $Script:globalContext = $newContext
        set-consoleTitle -newContext $newContext
        Set-Prompt -project $newContext
    }
    else {
        $Global:sf = [MasterFluent]::new($newContext)
    }
}

function set-consoleTitle {
    param (
        [SfProject]$newContext
    )

    if ($newContext) {
        $ports = @(iis-get-websitePort $newContext.websiteName)
        if ($newContext.branch) {
            $branch = ($newContext.branch).Split([string[]]("$/CMS/Sitefinity 4.0"), [System.StringSplitOptions]::RemoveEmptyEntries)[0]
        }
        else {
            $branch = '/no branch'
        }

        [System.Console]::Title = "$($newContext.displayName) ($($newContext.id)) $branch $ports "
        Set-Location $newContext.webAppPath
    }
    else {
        [System.Console]::Title = ""
    }
}

function generate-solutionFriendlyName {
    Param(
        [SfProject]$context
    )
    
    if (-not ($context)) {
        $context = _get-selectedProject
    }

    $solutionName = "$($context.displayName)($($context.id)).sln"
    
    return $solutionName
}

function _get-selectedProject {
    [OutputType([SfProject])]
    $currentContext = $Script:globalContext
    if ($currentContext -eq '') {
        return $null
    }
    elseif ($null -eq $currentContext) {
        return $null
    }

    $context = $currentContext.PsObject.Copy()
    return [SfProject]$context
}

function validate-nameSyntax ($name) {
    return $name -match "^[A-Za-z]\w+$"
}

function _create-workspace ($context, $branch) {
    try {
        # create and map workspace
        Write-Information "Creating workspace..."
        $workspaceName = $context.id
        tfs-create-workspace $workspaceName $context.solutionPath $Script:tfsServerName
    }
    catch {
        throw "Could not create workspace $workspaceName in $($context.solutionPath).`n $_"
    }

    try {
        Write-Information "Creating workspace mappings..."
        tfs-create-mappings -branch $branch -branchMapPath $context.solutionPath -workspaceName $workspaceName -server $Script:tfsServerName
    }
    catch {
        throw "Could not create mapping $($branch) in $($context.solutionPath) for workspace ${workspaceName}.`n $_"
    }

    try {
        Write-Information "Getting latest workspace changes..."
        tfs-get-latestChanges -branchMapPath $context.solutionPath -overwrite > $null
        $context.lastGetLatest = [DateTime]::Today
        _save-selectedProject $context
    }
    catch {
        throw "Could not get latest workapce changes. $_"
    }
}

function _get-unusedProjectName {
    return "free"
}