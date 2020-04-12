$GLOBAL:sf.config | Add-Member -Name azureDevOpsItemTypes -Value @("Product Backlog Item ", "Bug ", "Task ", "Feature ") -MemberType NoteProperty

function _newSfProjectObject ($id) {
    [SfProject]$newProject = [SfProject]::new()
    if (!$id) {
        $newProject.id = _generateId
    }
    else {
        $newProject.id = $id
    }

    return $newProject
}

<#
    .SYNOPSIS
    Provisions a new sitefinity instance project.
    .DESCRIPTION
    Gets latest from the branch, builds and starts a sitefinity instance with default admin user username:admin pass:admin@2. The local path where the project files are created is specified in the constants script file (EnvConstants.ps1).
    .PARAMETER sourcePath
    Either a path pointing to a TFS branch, zip file or existing Sitefinity webapp.
    .PARAMETER displayName
    The name of the project that the tool will use to present it in the CLI
#>
function sd-project-new {
    Param(
        [string]$sourcePath,
        [string]$displayName = 'Untitled'
    )

    if (!$sourcePath) {
        $sourcePath = _proj-promptSourcePathSelect
    }

    [SfProject]$newContext = _newSfProjectObject
    $newContext.displayName = $displayName

    _createAndDetectProjectArtifactsFromSourcePath -sourcePath $sourcePath -project $newContext
    if (!$newContext.webAppPath) {
        throw "Error creating the project. The project failed to initialize with web app path."
    }

    if (!$newContext.websiteName) {
        sd-iisSite-new -context $newContext
    }
    
    sd-project-setCurrent $newContext

    return $newContext
}

function sd-project-clone {
    Param(
        [switch]$skipSourceControlMapping,
        [switch]$skipDatabaseClone
    )

    $context = sd-project-getCurrent

    $sourcePath = $context.solutionPath;
    $hasSolution = !([string]::IsNullOrEmpty($sourcePath));
    if (!$hasSolution) {
        $sourcePath = $context.webAppPath
    }

    if (!$sourcePath -or !(Test-Path $sourcePath)) {
        throw "Invalid app path";
    }

    $targetDirectoryName = [Guid]::NewGuid()
    $targetPath = $GLOBAL:sf.Config.projectsDirectory + "\$targetDirectoryName"
    if (Test-Path $targetPath) {
        throw "Path exists: ${targetPath}"
    }

    try {
        Write-Information "Copying $sourcePath to $targetPath."
        New-Item $targetPath -ItemType Directory > $null
        Copy-Item "${sourcePath}\*" $targetPath -Recurse
    }
    catch {
        $errors = "Error copying source files.`n $_";
        try {
            Remove-Item $targetPath -Force -Recurse -ErrorVariable +errors -ErrorAction SilentlyContinue
        }
        finally {
            throw $errors
        }
    }

    [SfProject]$newProject = $null
    [SfProject]$newProject = _newSfProjectObject
    $newProject.displayName = "$($context.displayName)-clone"
    if ($hasSolution) {
        $newProject.webAppPath = "$targetPath\SitefinityWebApp"
    }
    else {
        $newProject.webAppPath = $targetPath
    }

    sd-project-setCurrent -newContext $newProject >> $null

    try {
        if (!$skipSourceControlMapping -and $context.branch) {
            Write-Information "Creating the workspace."
            _createWorkspace -context $newProject -branch $context.branch
        }
    }
    catch {
        Write-Error "Clone project error. Error binding to TFS.`n$_"
    }

    try {
        Write-Information "Creating website..."
        sd-iisSite-new
    }
    catch {
        Write-Warning "Error during website creation. Message: $_"
        $newProject.websiteName = ""
    }

    [SfProject]$oldProject = $context
    $sourceDbName = _db-getNameFromDataConfig $oldProject.webAppPath
    $exists = sql-test-isDbNameDuplicate -dbName $sourceDbName
    if ($sourceDbName -and $exists -and !$skipDatabaseClone) {
        $newDbName = $newProject.id
        try {
            sd-db-setNameInDataConfig $newDbName -context $newProject
        }
        catch {
            Write-Error "Error setting new database name in config $newDbName).`n $_"
        }

        try {
            sql-copy-db -SourceDBName $sourceDbName -targetDbName $newDbName > $null
        }
        catch {
            Write-Error "Error copying old database. Source: $sourceDbName Target $newDbName`n $_"
        }
    }

    try {
        sd-appStates-removeAll
    }
    catch {
        Write-Error "Error deleting app states for $($newProject.displayName). Inner error:`n $_"
    }

    $newProject.tags.AddRange($oldProject.tags) 

    sd-project-save -context $newProject
    sd-project-setCurrent $newProject
}

function sd-project-removeBulk {
    $sitefinities = @(sd-project-getAll)
    if ($null -eq $sitefinities[0]) {
        Write-Host "No projects found. Create one."
        return
    }

    $sfsToDelete = _proj-promptSfsSelection $sitefinities

    foreach ($selectedSitefinity in $sfsToDelete) {
        try {
            sd-project-remove -context $selectedSitefinity
        }
        catch {
            Write-Error "Error deleting project with id = $($selectedSitefinity.id): $_"
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
function sd-project-remove {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline)][SfProject]$context = $null,
        [switch]$keepDb,
        [switch]$keepWorkspace,
        [switch]$keepProjectFiles
    )

    Process {
        [SfProject]$currentProject = sd-project-getCurrent
        $clearCurrentSelectedProject = $false
        if ($null -eq $context -or $currentProject.id -eq $context.id) {
            $context = $currentProject
            $clearCurrentSelectedProject = $true
        }

        sd-project-setCurrent -newContext $context > $null

        # Del Website
        Write-Information "Deleting website..."
        $websiteName = $context.websiteName
        $siteExists = @(Get-Website | ? { $_.name -eq $websiteName }).Count -gt 0
        if ($websiteName -and $siteExists) {
            try {
                sd-iisAppPool-Stop
            }
            catch {
                Write-Warning "Could not stop app pool: $_`n"
            }

            try {
                sd-iisSite-delete
            }
            catch {
                Write-Warning "Errors deleting website ${websiteName}. $_`n"
            }
        }

        # TFS
        $workspaceName = $null
        try {
            Set-Location -Path $PSScriptRoot
            $workspaceName = tfs-get-workspaceName $context.webAppPath
        }
        catch {
            Write-Warning "No workspace to delete, no TFS mapping found."
        }

        if ($workspaceName -and !($keepWorkspace)) {
            Write-Information "Deleting workspace..."
            try {
                tfs-delete-workspace $workspaceName $GLOBAL:sf.Config.tfsServerName
            }
            catch {
                Write-Warning "Could not delete workspace $_"
            }
        }

        $dbName = _db-getNameFromDataConfig -appPath $context.webAppPath

        # Del db
        if (-not [string]::IsNullOrEmpty($dbName) -and (-not $keepDb)) {
            Write-Information "Deleting sitefinity database..."

            try {
                sql-delete-database -dbName $dbName
            }
            catch {
                Write-Warning "Could not delete database: ${dbName}. $_"
            }
        }

        # Del dir
        if (!($keepProjectFiles)) {
            try {
                $solutionPath = $context.solutionPath
                if ($solutionPath) {
                    $path = $solutionPath
                }
                else {
                    $path = $context.webAppPath
                }

                Write-Information "Unlocking all locked files in solution directory..."
                unlock-allFiles -path $path

                Write-Information "Deleting solution directory..."
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
        try {
            _removeProjectData $context
        }
        catch {
            Write-Warning "Could not remove the project entry from the tool. You can manually remove it at $($GLOBAL:sf.Config.dataPath)"
        }

        if ($clearCurrentSelectedProject) {
            sd-project-setCurrent $null > $null
        }
        else {
            sd-project-setCurrent $currentProject > $null
        }
    }
}

function sd-project-rename {
    Param(
        [string]$newName,
        [switch]$setDescription
    )

    $project = sd-project-getCurrent
    [SfProject]$context = $project

    if (-not $newName) {
        while ([string]::IsNullOrEmpty($newName)) {
            if ($newName) {
                Write-Warning "Invalid name syntax."
            }

            $newName = $(Read-Host -Prompt "Enter new project name").ToString()
        }

        if ($setDescription) {
            $context.description = $(Read-Host -Prompt "Enter description:`n").ToString()
        }
    }

    $azureDevOpsResult = _getNameParts $newName
    $newName = $azureDevOpsResult.name
    $context.description = $azureDevOpsResult.link

    if ($newName -and (-not (_validateNameSyntax $newName))) {
        throw "Name syntax is not valid. Use only alphanumerics and underscores"
    }

    $oldSolutionName = _generateSolutionFriendlyName -context $context
    $context.displayName = $newName

    if ($context.solutionPath) {
        if (-not (Test-Path "$($context.solutionPath)\$oldSolutionName")) {
            _createUserFriendlySlnName -context $context
        }

        $newSolutionName = _generateSolutionFriendlyName -context $context
        $oldSolutionPath = "$($context.solutionPath)\$oldSolutionName"
        if (Test-Path $oldSolutionPath) {
            Copy-Item -Path $oldSolutionPath -Destination "$($context.solutionPath)\$newSolutionName" -Force

            $newSlnCacheName = ([string]$newSolutionName).Replace(".sln", "")
            $oldSlnCacheName = ([string]$oldSolutionName).Replace(".sln", "")
            $oldSolutionCachePath = "$($context.solutionPath)\.vs\$oldSlnCacheName"
            if (Test-Path $oldSolutionCachePath) {
                Copy-Item -Path $oldSolutionCachePath -Destination "$($context.solutionPath)\.vs\$newSlnCacheName" -Force -Recurse -ErrorAction SilentlyContinue
                unlock-allFiles -path $oldSolutionCachePath
                Remove-Item -Path $oldSolutionCachePath -Force -Recurse
            }

            unlock-allFiles -path $oldSolutionPath
            Remove-Item -Path $oldSolutionPath -Force
        }
    }

    sd-iisSite-changeDomain -domainName "$($newName).$($context.id)"

    _update-prompt
    sd-project-save $context
}

function sd-project-getCurrent {
    $Script:globalContext
}

function sd-project-setCurrent {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline)][SfProject]$newContext
    )

    process {
        if (!$newContext) {
            $Script:globalContext = $newContext
            _update-prompt
            return
        }

        try {
            _proj-initialize -project $newContext
            _validateProject $newContext
        }
        catch {
            Write-Error "$_"
        }

        $Script:globalContext = $newContext

        _update-prompt

        if ($Global:SfEvents_OnAfterProjectSelected) {
            $Global:SfEvents_OnAfterProjectSelected | % { Invoke-Command -ScriptBlock $_ }
        }
    }
}

function sd-project-getAll {
    [OutputType([SfProject[]])]
    param(
        [string[]]$tagsFilter
    )

    $sitefinities = _data-getAllProjects
    if ($tagsFilter) {
        $sitefinities = _filterProjectsByTags -sitefinities $sitefinities -tagsFilter $tagsFilter
    }

    return $sitefinities
}

function _proj-tryUseExisting {

    Param(
        [Parameter(Mandatory = $true)][SfProject]$project,
        [Parameter(Mandatory = $true)][string]$path
    )


    if (Test-Path -Path "$path\SitefinityWebApp") {
        $path = "$path\SitefinityWebApp"
    }

    $isWebApp = Test-Path "$path\web.config"
    if (!$isWebApp) {
        return
    }

    Write-Information "Detected existing app..."

    $project.webAppPath = $path
    _proj-detectSite -project $project
    return $true
}

function _getNameParts {
    Param([string]$name)
    $description = ''
    $titleKeys = $GLOBAL:sf.config.azureDevOpsItemTypes
    $title = $name
    foreach ($key in $titleKeys) {
        if ($name.StartsWith($key)) {
            $name = $name.Replace($key, '');
            $nameParts = $name.Split(':');
            $itemId = $nameParts[0].Trim();
            $title = $nameParts[1].Trim();
            for ($i = 2; $i -lt $nameParts.Count; $i++) {
                $title = "$title$($nameParts[$i])"
            }

            $title = $title.Trim();
            $title = _getValidTitle $title

            $description = "https://prgs-sitefinity.visualstudio.com/sitefinity/_workitems/edit/$itemId"
        }
    }

    return @{ name = $title; link = $description }
}

function _getValidTitle {
    param (
        [string]$title
    )

    $validStartEnd = "^[A-Za-z]$";
    $validMiddle = "^\w$";
    while (!($title[0] -match $validStartEnd)) {
        $title = $title.Substring(1)
    }

    while (!($title[$title.Length - 1] -match $validStartEnd)) {
        $title = $title.Substring(0, $title.Length - 1)
    }

    $resultTitle = '';
    for ($i = 0; $i -lt $title.Length; $i++) {
        if ($title[$i] -match $validMiddle) {
            $resultTitle = "$resultTitle$($title[$i])"
        }
        elseif ($title[$i] -eq ' ') {
            $resultTitle = "${resultTitle}_"
        }
    }

    if ($resultTitle.Length -ge 51) {
        $resultTitle = $resultTitle.Remove(50);
    }

    return $resultTitle;
}

function _createUserFriendlySlnName ($context) {
    $solutionFilePath = "$($context.solutionPath)\Telerik.Sitefinity.sln"
    if (!(Test-Path $solutionFilePath)) {
        return
    }

    $targetFilePath = "$($context.solutionPath)\$(_generateSolutionFriendlyName $context)"
    if (!(Test-Path $targetFilePath)) {
        Copy-Item -Path $solutionFilePath -Destination $targetFilePath
    }
}

function sd-project-save {
    Param($context)

    if (!$context.id) {
        throw "No project id."
    }

    if (-not ($context.webAppPath -and (Test-Path $context.webAppPath))) {
        throw "No web app path set or it does not exist."
    }

    _setProjectData $context
}

function _validateProject {
    Param($context)

    if (!$context.id) {
        Write-Warning "No project id."
    }

    if (-not ($context.webAppPath -and (Test-Path $context.webAppPath))) {
        Write-Warning "No web app path set or it does not exist."
    }

    if ($context.solutionPath) {
        if (-not (Test-Path $context.solutionPath)) {
            Write-Warning "Solution path does not exist."
        }

        $solutionFilePath = "$($context.solutionPath)\Telerik.Sitefinity.sln"
        if (!(Test-Path $solutionFilePath)) {
            Write-Warning "Solution file not existing."
        }
    }

    if (!$context.branch) {
        Write-Warning "Could not detect source control."
    }

    if (!$context.websiteName) {
        Write-Warning "Could not detect IIS website."
    }
}

function _getIsIdDuplicate ($id) {
    function _isDuplicate ($name) {
        if ($name -and $name.Contains($id)) {
            return $true
        }
        return $false
    }

    $sitefinities = [SfProject[]](sd-project-getAll)
    $sitefinities | ForEach-Object {
        $sitefinity = [SfProject]$_
        if ($sitefinity.id -eq $id) {
            return $true;
        }
    }

    if (Test-Path "$($GLOBAL:sf.Config.projectsDirectory)\$id") { return $true }

    $wss = tfs-get-workspaces $GLOBAL:sf.Config.tfsServerName | Where-Object { _isDuplicate $_ }
    if ($wss) { return $true }

    Import-Module WebAdministration
    $sites = Get-Item "IIS:\Sites"
    if ($sites -and $sites.Children) {
        $names = $sites.Children.Keys | Where-Object { _isDuplicate $_ }
        if ($names) { return $true }
    }
    $pools = Get-Item "IIS:\AppPools"
    if ($pools -and $pools.Children) {
        $names = $pools.Children.Keys | Where-Object { _isDuplicate $_ }
        if ($names) { return $true }
    }

    $dbs = sql-get-dbs | Where-Object { _isDuplicate $_.name }
    if ($dbs) { return $true }

    return $false;
}

function _generateId {
    $i = 0;
    while ($true) {
        $name = "$($GLOBAL:sf.Config.idPrefix)$i"
        $_isDuplicate = (_getIsIdDuplicate $name)
        if (-not $_isDuplicate) {
            break;
        }

        $i++
    }

    if ([string]::IsNullOrEmpty($name) -or (-not (_validateNameSyntax $name))) {
        throw "Invalid id $name"
    }

    return $name
}

function _generateSolutionFriendlyName {
    Param(
        [SfProject]$context
    )

    if (-not ($context)) {
        $context = sd-project-getCurrent
    }

    $solutionName = "$($context.displayName)($($context.id)).sln"

    return $solutionName
}

function _validateNameSyntax ($name) {
    return $name -match "^[A-Za-z]\w+$" -and $name.Length -lt 75
}

function _proj-initialize {
    param (
        [Parameter(Mandatory = $true)][SfProject]$project
    )

    if ($project.isInitialized) {
        return
    }

    if (!(Test-Path $project.webAppPath)) {
        Write-Error "Current project $($project.id) has no valid web app path."
        $project.isInitialized = $true
        return
    }

    $errors = ''
    try {
        _proj-detectSolution -project $project
    }
    catch {
        $errors += "`nSolution detection: $_."
    }

    _createUserFriendlySlnName $project

    try {
        _proj-detectTfs -project $project
    }
    catch {
        $errors += "`nSource control detection: $_."
    }

    try {
        _proj-detectSite -project $project
    }
    catch {
        $errors += "`nSite detection from IIS: $_."
    }

    if ($errors) {
        Write-Error "Some errors occurred during project detection. $errors"
    }

    sd-project-save -context $project

    $project.isInitialized = $true
}

function _createAndDetectProjectArtifactsFromSourcePath {
    param (
        [Parameter(Mandatory = $true)][Sfproject]$project,
        [Parameter(Mandatory = $true)][string]$sourcePath
    )

    if (!(_proj-tryCreateFromBranch -project $project -sourcePath $sourcePath) -and
        !(_proj-tryCreateFromZip -project $project -sourcePath $sourcePath) -and
        !(_proj-tryUseExisting -project $project -path $sourcePath)
    ) {
        throw "Source path does not exist"
    }
}

function _proj-createProjectDirectory {
    param (
        [Parameter(Mandatory = $true)][Sfproject]$project
    )

    Write-Information "Creating project files..."
    $projectDirectory = "$($GLOBAL:sf.Config.projectsDirectory)\$($project.id)"
    if (Test-Path $projectDirectory) {
        throw "Path already exists:" + $projectDirectory
    }

    New-Item $projectDirectory -type directory > $null
    $projectDirectory
}

function _proj-detectSolution ([SfProject]$project) {
    if (_proj-isSolution -project $project) {
        $project.solutionPath = (Get-Item "$($project.webAppPath)\..\").Target
        _createUserFriendlySlnName $project
    }
    else {
        $project.solutionPath = ''
    }
}

function _proj-tryCreateFromBranch {
    param (
        [Parameter(Mandatory = $true)][Sfproject]$project,
        [Parameter(Mandatory = $true)][string]$sourcePath
    )

    if ($sourcePath.StartsWith("$/CMS/")) {
        $projectDirectory = _proj-createProjectDirectory -project $project
        $project.solutionPath = $projectDirectory;
        $project.webAppPath = "$projectDirectory\SitefinityWebApp";
        _createWorkspace -context $project -branch $sourcePath
        return $true
    }
}

function _proj-tryCreateFromZip {
    param (
        [Parameter(Mandatory = $true)][Sfproject]$project,
        [Parameter(Mandatory = $true)][string]$sourcePath
    )

    if ($sourcePath.EndsWith('.zip') -and (Test-Path $sourcePath)) {
        $projectDirectory = _proj-createProjectDirectory -project $project
        expand-archive -path $sourcePath -destinationpath $projectDirectory
        $isSolution = (Test-Path -Path "$projectDirectory\Telerik.Sitefinity.sln") -and (Test-Path "$projectDirectory\SitefinityWebApp")
        if ($isSolution) {
            $project.webAppPath = "$projectDirectory\SitefinityWebApp"
            $project.solutionPath = "$projectDirectory"
        }
        else {
            $project.webAppPath = "$projectDirectory"
        }

        # license from daily builds, if using source code zip no license is included
        $dir = (Get-Item -Path $sourcePath).Directory
        $licensePath = "$($dir.FullName)\Sitefinity.lic"
        $sfPath = "$($project.webAppPath)\App_Data\Sitefinity"
        if (Test-Path $licensePath) {
            if (!(Test-Path $sfPath)) {
                New-Item $sfPath -ItemType Directory
            }

            Copy-Item $licensePath $sfPath
        }

        return $true
    }
}

function _proj-detectTfs ([SfProject]$project) {
    if (!(_proj-isSolution -project $project)) {
        return
    }

    $branch = tfs-get-branchPath -path $project.solutionPath
    if ($branch) {
        $project.branch = $branch
        _updateLastGetLatest -context $project
    }
    else {
        $project.branch = '';
    }
}

function _proj-isSolution ([SfProject]$project) {
    Test-Path "$($project.webAppPath)\..\Telerik.Sitefinity.sln"
}

function _proj-detectSite ([Sfproject]$project) {
    $siteName = iis-find-site -physicalPath $project.webAppPath
    if ($siteName) {
        $project.websiteName = $siteName
    }
    else {
        $project.websiteName = ''
    }
}