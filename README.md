# SF-DEV PowerShell Module

## Description

Manage Sitefinity instances on local machine.

## Installation

To install see: [PowerShell Gallery](https://www.powershellgallery.com/packages/sf-dev/). If problems see [How-To-Update-Powershell get](https://docs.microsoft.com/en-us/powershell/gallery/installing-psget)

## QuickStart

1. Run powershell as Administrator and load module. DO NOT USE ~~Import-Module~~, USE `Using module` instead
    ```powershell
    Using module sf-dev
    ```

    _After first run you might get asked to setup paths to external tools. Config is at `%userprofile%\Documents\sf-dev\config.ps1.`. After modification restart powershell session_

2. Start typing
    ```powershell
    $sf.
    ```
    Assuming you are using standard Windows PowerShell console, press __LEFTCTRL+SPACE__ to see a list of available categories of operations. Or start typing and press __TAB__ for autocomplete.

3. First, you need to create a project.
    ```powershell
    $sf.project.Create()
    ```
    Choose branch to map from and the name of your Sitefinity instance.

    A project is a Sitefinity instance that is managed by the tool. To select from all created and imported projects use
    ```powershell
    $sf.project.Select()
    ```

4. To build the currently selected project use:
    ```powershell
    $sf.solution.Build()
    ```

5. Initialise Sitefinity with database. Default credentials in config `%userprofile%\Documents\sf-dev\config.ps1.`:
    ```powershell
    $sf.webApp.ResetApp()
    ```

6. Open website
    ```powershell
    $sf.iis.BrowseWebsite()
    ```

## Requirements

- Powershell 5.1
- MSBuild.exe and TF.exe (Come with Visual Studio 2015 or later)
- SQL Server PowerShell Module (SQLPS) (Comes with SQL Server Management Studio)
- First run of internet explorer to have completed (this is required for the WebClient in .NET)
- WebAdministration module (this should already be installed if IIS is enabled)

## Links

[Docs](./docs.md)

[Release Notes](./sf-dev/sf-dev.psd1)

## Tips & Tricks

- Function to load module into powershell sessions

  Create file `%userprofile%\documents\WindowsPowerShell\profile.ps1` if it does not exist already.

  Insert the following function in the file. Now every powershell session will contain that function which can be used to load the module. 
  This way you can create alias and simply type 'sf' instead of 'Using module sf-dev' every time you want to use the module.

  ```powerShell
  function sf() {
      $script = [ScriptBlock]::Create("using module sf-dev")
      . $script
  }
  ```

- aliases for commonly used commands

  ```powerShell
  # instead of typing $sf.solution.Build() each time simply use sfbuild
  function sfbuild() {
      $sf.solution.Build()
  }
  ```
  
- use the module API to create your automation scripts

- iterate through all projects and perform operations
    ```PowerShell
    # this function comes from the module and can be used to iterate and perform operations on each project managed by the module
    sf-start-allProjectsBatch {
        Param([SfProject]$project)
        if ($project.displayName -eq 'myProject' -or $project.branch.StartsWith("Fixes_")) {
            $sf.solution.Build()
        }
    }
    ```

    
