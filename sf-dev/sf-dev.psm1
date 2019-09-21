Using module toko-admin

# declare types - all have to be here at psm file to be able to export the types to be used outside the module. (also needed for intellisense in editors)

class Config {
    [string]$dataPath
    [string]$idPrefix
    [string]$projectsDirectory
    [string]$browserPath
    [string]$vsPath
    [string]$msBuildPath
    [string]$tfsServerName
    [string]$defaultUser
    [string]$defaultPassword
    [string]$sqlServerInstance
    [string]$sqlUser
    [string]$sqlPass
    [string[]]$predefinedBranches
    [string[]]$predefinedBuildPaths
}

class SfProject {
    [string]$id
    [string]$displayName
    [string]$solutionPath
    [string]$webAppPath
    [string]$websiteName

    #needed for performance when selecting sitefinities
    [string]$branch
    [string]$description
    [string]$lastGetLatest
    [bool]$isInitialized
    [string]$tags

    SfProject() {
        $this.id = _generateId
        $this.displayName = $this.id
    }

    SfProject([string]$id) {
        $this.id = $id
        $this.displayName = $id
    }
     
    [void] Details() {
        sf-show-currentProject -context $this
    }
}

#fluent

class FluentBase {
    [SfProject] hidden $_project
    [SfProject] hidden GetProject () {
        if (!$this._project) {
            throw "You must select a project to work with first."
        }

        return $this._project
    }

    FluentBase([SfProject]$project) {
        $this._project = $project
    }

    # hide object methods from fluent intellisense

    [string] hidden ToString() { return ([object]$this).ToString() }

    [int] hidden GetHashCode() { return ([object]$this).GetHashCode() }

    [bool] hidden Equals([object]$obj) { return ([object]$this).Equals($obj) }

    [type] hidden GetType() { return ([object]$this).GetType() }
}

class MasterFluent : FluentBase {
    [SolutionFluent] $solution
    [WebAppFluent] $webApp
    [IISFluent] $IIS
    [ProjectFluent] $project

    MasterFluent ([SfProject]$project) : base($project) {
        $this.solution = [SolutionFluent]::new($project)
        $this.webApp = [WebAppFluent]::new($project)
        $this.IIS = [IISFluent]::new($project)
        $this.project = [ProjectFluent]::new($project)
        set-currentProject -newContext $project -fluentInited
    }
}

# class::Tags operations
class TagsFluent : FluentBase {
    TagsFluent ([SfProject]$project) : base($project) { }

    [void] hidden ValidateTag([string]$tag) {
        if (!$tag -or $tag.StartsWith('-') -or $tag.Contains(' ')) {
            throw "Invalid tag name. Must not contain spaces and start with '-'"
        }
    }

    # ::Tags the current project
    [void] Add([string]$tagName) {
        $this.ValidateTag($tagName)
        [SfProject]$project = $this.GetProject()
        if (!$project.tags) {
            $project.tags = $tagName
        }
        else {
            $project.tags += " $tagName"
        }

        _save-selectedProject -context $project
    }

    # ::Removes the tag from current project
    [void] Remove([string]$tagName) {
        $this.ValidateTag($tagName)
        if (!$tagName) {
            throw "Invalid tag name to remove."
        }

        [SfProject]$project = $this.GetProject()
        if ($project.tags -and $project.tags.Contains($tagName)) {
            $project.tags = $project.tags.Replace($tagName, '').Replace('  ', ' ').Trim()
        }

        _save-selectedProject -context $project
    }

    # ::Removes all tags from current project
    [void] RemoveAll() {
        [SfProject]$project = $this.GetProject()
        $project.tags = ''
        _save-selectedProject -context $project
    }

    # ::Removes all tags from current project
    [string] GetAll() {
        [SfProject]$project = $this.GetProject()
        return $project.tags
    }

    # ::Sets a default filtering to apply when selecting items without providing a tagFilter
    [void] SetDefaultTagFilter([string]$tagsFilter) {
        _sfData-save-defaultTagsFilter -defaultTagsFilter $tagsFilter
    }
    
    # ::Gets the default tagFilter
    [string] GetDefaultTagFilter() {
        return _sfData-get-defaultTagsFilter
    }
}

# class::Project operations
class ProjectFluent : FluentBase {
    [TagsFluent] $tags

    ProjectFluent ([SfProject]$project) : base($project) {
        $this.tags = [TagsFluent]::new($project)
    }

    # ::Prompts the user to select a project to work with from previously created or imported.
    [void] Select () {
        $filter = $this.tags.GetDefaultTagFilter()
        $this.Select($filter)
    }

    # ::Prompts the user to select a projects managed by the tool filtered by their tags. If tagsFilter is equal to '+' only untagged projects are shown. Tags in tag filter are delimited by space. If a tag is prefixed with '-' projects tagged with it are excluded. Excluded tags take precedense over included ones.
    [void] Select ([string]$tagsFilter) {
        sf-select-project -tagsFilter $tagsFilter
    }

    # ::Shows all projects managed by the tool.
    [void] ShowAll () {
        $this.ShowAll('')
    }
    
    # ::Shows all projects managed by the tool filtered by their tags. If tagsFilter is equal to '+' only untagged projects are shown. Tags in tag filter are delimited by space. If a tag is prefixed with '-' projects tagged with it are excluded. Excluded tags take precedense over included ones.
    [void] ShowAll ([string]$tagsFilter) {
        $sfs = sf-get-allProjects -tagsFilter $tagsFilter
        sf-show-projects -sitefinities $sfs
    }

    # ::Use to create new projects. The user will be prompted for parameters.
    [void] Create () {
        $selectFrom = $null
        while ($selectFrom -ne 1 -and $selectFrom -ne 2) {
            $selectFrom = Read-Host -Prompt "Create from?`n1.Branch`n2.Build"
        }

        $sourcePath = $null
        if ($selectFrom -eq 1) {
            $sourcePath = prompt-predefinedBranchSelect
        }
        else {
            $sourcePath = prompt-predefinedBuildPathSelect
        }

        $this.Create($sourcePath)
    }

    # ::Use to create new projects. The path can be either TFS branch path or file system location to Sitefinity Build (containing licence file and SitefinityWebApp.zip file)
    [void] Create ([string]$path) {
        $name = Read-Host -Prompt "Enter name"
        $this.Create($name, $path)
    }

    # ::Use to create new projects. The path can be either TFS branch path or file system location to Sitefinity Build (containing licence file and SitefinityWebApp.zip file)
    [void] Create ([string]$name, [string]$sourcePath) {
        sf-new-project -displayName $name -sourcePath $sourcePath
    }

    # ::Use to import existing sitefinity projects to be managed by the tool. $name - the name of the imported project. $path - the directory of the Sitefinity web app
    [void] Import ([string]$name, [string]$path) {
        sf-import-project -displayName $name -path $path
    }

    # ::Use to clone the current project. Will create a copy of everything - site, database and map into a new workspace
    [void] Clone() {
        sf-clone-project -context $this.GetProject()
    }
    
    # ::Delete the current project
    [void] Delete() {
        sf-delete-project -context $this.GetProject() -noPrompt
        set-currentProject -newContext $null
    }

    # ::Batch delete projects
    [void] DeleteMany() {
        sf-delete-projects
        [SfProject[]]$sitefinities = @(sf-get-allProjects)
        $currentProjectWasDeleted = @($sitefinities | where { $_.id -eq $this.project.id }).Count -eq 0

        if ($currentProjectWasDeleted) {
            $this.Select()
        }
    }

    # ::Rename the current project
    [void] Rename([string]$newName) {
        sf-rename-project -newName $newName -project $this.GetProject()
    }

    # ::Display details about the current project
    [void] Details() {
        sf-show-currentProject -detail -context $this.GetProject()
    }
}

# class::IIS operations
class IISFluent : FluentBase {
    IISFluent([SfProject]$project) : base($project) { }

    # ::Setups the current project as a sub application in IIS
    [void] SetupSubApp($subAppName) {
        sf-setup-asSubApp -subAppName $subAppName -project $this.GetProject()
    }

    # ::Reverts the sub application mode in IIS of the current project if it was enabled
    [void] RemoveSubApp() {
        sf-remove-subApp -project $this.GetProject()
    }

    # ::Resets the website ApplicationPool
    [void] ResetApplicationPool () {
        sf-reset-pool -project $this.GetProject()
    }

    # ::Resets just the threads of the website application but leaves the ApplicationPool intact, useful if you need to restart the app domain but leave the debugger attached for startup debugging
    [void] ResetApplicationThreads() {
        sf-reset-thread -project $this.GetProject()
    }
    
    # ::Opens the configured web browser with the url of the project
    [void] BrowseWebsite () {
        sf-browse-webSite -project $this.GetProject()
    }
}

# class::Web Application operations
class WebAppFluent : FluentBase {
    WebAppFluent([SfProject]$project) : base($project) { }
    
    # ::Resets and reinitializes the web application. This will delete database and restore AppData folder to original state, before initiating a Sitefinity startup
    [void] ResetApp () {
        $this.ResetApp($false)
    }

    # ::Resets and reinitializes the web application. This will delete database and restore AppData folder to original state, before initiating a Sitefinity startup. Params: $force - forces the cleanup of App_Data folder - kills locking processes
    [void] ResetApp ([bool]$force) {
        sf-reset-app -start -project $this.GetProject() -force:$force
    }

    # ::Saves the current web application AppData and Database state for later restore. Useful when debugging tests that change the state of the system. Ex. switch from single to multilingual or delete some content items etc...
    [void] SaveDbAndConfigs([string]$stateName) {
        sf-new-appState -stateName $stateName -project $this.GetProject()
    }

    # ::Saves the current web application AppData and Database state for later restore. Useful when debugging tests that change the state of the system. Ex. switch from single to multilingual or delete some content items etc...
    [void] SaveDbAndConfigs() {
        $this.SaveDbAndConfigs("temp")
    }

    # ::Restores previously saved database and AppData folder
    [void] RestoreDbAndConfigs([string]$stateName) {
        sf-restore-appState -stateName $stateName -project $this.GetProject()
    }

    # ::Restores previously saved database and AppData folder
    [void] RestoreDbAndConfigs() {
        $stateName = select-appState
        if ($stateName) {
            $this.RestoreDbAndConfigs($stateName)
        }
    }

    # ::Opens the webapp location in windows explorer
    [void] OpenLocation () {
        ii ([SfProject]$this.GetProject()).webAppPath
    }

    # ::Precompiles all pages for faster loading
    [void] AddPrecompileTemplates () {
        sf-add-precompiledTemplates
    }

    # ::Removes any precompiled templates
    [void] RemovePrecompileTemplates () {
        sf-add-precompiledTemplates -revert
    }
}

# class::Solution operations
class SolutionFluent : FluentBase {
    SolutionFluent([SfProject]$project) : base($project) { }

    # ::Builds the solution with 3 retries. Also disables stylecop check for faster build. Uses msbuild configured for multi threaded building.
    [void] Build () {
        $this.Build(3)
    }

    # ::Builds the solution with given retries count. Also disables stylecop check for faster build. Uses msbuild configured for multi threaded building.
    [void] Build ([int]$retryCount) {
        sf-build-solution -retryCount $retryCount -project $this.GetProject()
    }

    # ::Performs a hard clean of the project before building. Deletes all bin and obj folders from all projects
    [void] ReBuild ([int]$retryCount) {
        sf-rebuild-solution -retryCount $retryCount -project $this.GetProject()
    }

    # ::Cleans downloaded packages for solution
    [void] CleanPackages () {
        sf-clean-packages -project $this.GetProject()
    }
    
    # ::Performs a hard delete of all bins and objs
    [void] Clean () {
        sf-clean-solution -project $this.GetProject()
    }

    # ::Opens the solution in the configured editor of the tool config
    [void] Open () {
        sf-open-solution -project $this.GetProject()
    }

    # ::Opens the solution location in windows explorer
    [void] OpenLocation () {
        $path = ([SfProject]$this.GetProject()).solutionPath
        if (!$path -or !(Test-Path $path)) {
            throw "No solution path or not found."
        }
        
        ii $path
    }
}
# class::Source control operations
class TfsFluent : FluentBase {
    TfsFluent ([SfProject]$project) : base($project) { }

    # ::Gets latest changes
    [void] GetLatest ([bool]$overwrite) {
        sf-get-latestChanges -overwrite:$overwrite
    }

    # ::Shows pending changes
    [void] ShowPending ([bool]$detailed) {
        sf-show-pendingChanges -detailed:$detailed
    }

    # ::Undos all pending changes
    [void] Undo () {
        sf-undo-pendingChanges
    }
}

# module startup

. "$PSScriptRoot/bootstrap/bootstrap.ps1"
$Global:sf = [MasterFluent]::new($null)

Export-ModuleMember -Function * -Alias *
