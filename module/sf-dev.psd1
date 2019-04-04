#
# Module manifest for module 'sf-dev'
#
# Generated by: Todor Mitskovski
#
# Generated on: 4/4/2019
#

@{

# Script module or binary module file associated with this manifest.
RootModule = '.\sf-dev.psm1'

# Version number of this module.
ModuleVersion = '0.1.0'

# Supported PSEditions
# CompatiblePSEditions = @()

# ID used to uniquely identify this module
GUID = '570fb657-4d88-4883-8b39-2dae4db1280c'

# Author of this module
Author = 'Todor Mitskovski'

# Company or vendor of this module
CompanyName = ' '

# Copyright statement for this module
Copyright = '(c) 2019 Todor Mitskovski. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Sitefinity core dev automation tools'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '5.1'

# Name of the Windows PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
CLRVersion = '4.0'

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
ScriptsToProcess = 'bootstrap\load-nestedModules.ps1'

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = 'sf-select-container', 'sf-create-container', 'sf-delete-container', 
               'sf-set-projectContainer', 'sf-start-allProjectsBatch', 
               'sf-start-batch', 'sf-set-description', 'sf-new-project', 
               'sf-clone-project', 'sf-import-project', 'sf-delete-projects', 
               'sf-delete-project', 'sf-rename-project', 
               'sf-update-allProjectsTfsInfo', 'sf-clean-allProjectsLeftovers', 
               'sf-reset-project', 'sf-select-project', 'sf-show-currentProject', 
               'sf-show-projects', 'sf-build-solution', 'sf-rebuild-solution', 
               'sf-clean-solution', 'sf-open-solution', 'sf-build-webAppProj', 
               'sf-unlock-allFiles', 'sf-switch-styleCop', 'sf-undo-pendingChanges', 
               'sf-show-pendingChanges', 'sf-get-hasPendingChanges', 
               'sf-get-latestChanges', 'sf-reset-thread', 'sf-reset-pool', 
               'sf-stop-pool', 'sf-change-pool', 'sf-get-poolId', 'sf-setup-asSubApp', 
               'sf-remove-subApp', 'sf-rename-website', 'sf-browse-webSite', 
               'sf-create-website', 'sf-goto', 'sf-set-storageMode', 
               'sf-get-storageMode', 'sf-get-configContentFromDb', 
               'sf-clear-configContentInDb', 'sf-insert-configContentInDb', 
               'sf-get-appDbName', 'sf-set-appDbName', 'sf-reset-app', 
               'sf-add-precompiledTemplates', 'sf-new-appState', 
               'sf-restore-appState', 'sf-delete-appState', 'sf-delete-allAppStates'

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = @()

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = '*'

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        # Tags = @()

        # A URL to the license for this module.
        # LicenseUri = ''

        # A URL to the main website for this project.
        # ProjectUri = ''

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        # ReleaseNotes = ''

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

