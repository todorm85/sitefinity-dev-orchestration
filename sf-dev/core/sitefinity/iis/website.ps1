
function sf-iis-site-rename {
    Param(
        [string]$newName
    )

    $context = sf-proj-getCurrent
    try {
        iis-sf-iis-site-rename $context.websiteName $newName
    }
    catch {
        throw "Error renaming site in IIS. Message: $_.Message"
    }
    
    $context.websiteName = $newName
    _saveSelectedProject $context

}

<#
    .SYNOPSIS 
    Opens the current sitefinity webapp in the browser.
    .DESCRIPTION
    If an existing sitefinity web app without a solution was imported nothing is done.
    .PARAMETER useExistingBrowser
    If switch is passed the last browser that was on focus is used, otherwise a new browser instance is launched.
    .OUTPUTS
    None
#>
function sf-iis-site-open {
    Param(
        [switch]$useExistingBrowser
    )

    $browserPath = $GLOBAL:Sf.Config.browserPath;
    $appUrl = _getAppUrl
    if (!(Test-Path $browserPath)) {
        throw "Invalid browser path configured ($browserPath). Configure it in $Script:userConfigPath -> browserPath"
    }

    if (-not $useExistingBrowser) {
        execute-native "& Start-Process `"$browserPath`"" -successCodes @(100)
    }
    
    execute-native "& `"$browserPath`" `"${appUrl}/Sitefinity`" -noframemerging" -successCodes @(100)
}

<#
.SYNOPSIS
Creates a website for the given project or currently selected one.

.PARAMETER context
The project for which to create a website.

.NOTES
General notes
#>
function sf-iis-site-new {
    Write-Information "Creating website..."

    $context = sf-proj-getCurrent

    $port = 2111
    while (!(os-test-isPortFree $port) -or !(iis-test-isPortFree $port)) {
        $port++
    }

    while ([string]::IsNullOrEmpty($context.id) -or (iis-test-isSiteNameDuplicate $context.id)) {
        throw "Website with name $($context.id) already exists or no name provided:"
    }

    if (!$context.websiteName) {
        $context.websiteName = $context.id
    }
    
    $newAppPath = $context.webAppPath
    $newAppPool = $context.id
    $domain = _generateDomainName -context $context
    try {
        iis-create-website -newWebsiteName $context.websiteName -domain $domain -newPort $port -newAppPath $newAppPath -newAppPool $newAppPool > $null
    }
    catch {
        throw "Error creating site: $_"
    }

    _saveSelectedProject $context

    try {
        if ($domain) {
            Add-ToHostsFile -address "127.0.0.1" -hostname $domain
        }
    }
    catch {
        Write-Error "Error adding domain to hosts file."
    }
}

function _sf-iis-site-delete ($websiteName) {
    if (!$websiteName) {
        throw "Website name not set."
    }
    
    $appPool = @(iis-get-siteAppPool $websiteName)
    $domain = (iis-get-binding $websiteName).domain
    $errors = ''
    try {
        Remove-Item ("iis:\Sites\${websiteName}") -Force -Recurse -ErrorAction SilentlyContinue -ErrorVariable +errors
    }
    catch {
        $errors += "Error deleting website ${websiteName}: $_"
    }

    try {
        Remove-Item ("iis:\AppPools\$appPool") -Force -Recurse -ErrorAction SilentlyContinue -ErrorVariable +errors
    }
    catch {
        $errors += "Error removing app pool $appPool Error: $_"
    }

    try {
        if ($domain) {
            Remove-FromHostsFile -hostname $domain > $null
        }
    }
    catch {
        $errors += "Error removing domain from hosts file. Error $_"        
    }

    if ($errors) {
        throw $errors
    }
}

function _changeDomain {
    param (
        $domainName
    )

    $context = sf-proj-getCurrent
    $websiteName = $context.websiteName
    if (!$websiteName) {
        return
    }

    $oldDomain = (iis-get-binding $websiteName).domain
    if ($oldDomain) {
        try {
            Remove-FromHostsFile -hostname $oldDomain > $null
        }
        catch {
            Write-Error "Error cleaning previous domain not found in hosts file."            
        }
    }

    $port = (iis-get-binding $websiteName).port
    if ($port) {
        iis-set-binding $websiteName $domainName $port
        Add-ToHostsFile -address 127.0.0.1 -hostname $domainName
    }
    else {
        throw "No binding found for site $websiteName"
    }
}
