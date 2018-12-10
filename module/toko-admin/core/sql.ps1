function _sql-load-module {
    $mod = Get-Module SQLPS
    if ($null -eq $mod -or '' -eq $mod) {
        $oldLocation = Get-Location
        Import-Module SQLPS -DisableNameChecking 3>&1 | out-null
        if (Test-Path $oldLocation) {
            Set-Location $oldLocation
        }
    }
}

function sql-delete-database {
    Param (
        [Parameter(Mandatory = $true)][string] $dbName
    )

    _sql-load-module

    $Databases = Invoke-SQLcmd -ServerInstance $sqlServerInstance -Query ("SELECT * from sys.databases where NAME = '$dbName'")

    ForEach ($Database in $Databases) { 
        Invoke-SQLcmd -ServerInstance $sqlServerInstance -Query (
            "alter database [" + $Database.Name + "] set single_user with rollback immediate
            DROP DATABASE [" + $Database.Name + "]")
    }
}

function sql-rename-database {
    Param (
        [Parameter(Mandatory = $true)][string] $oldName,
        [Parameter(Mandatory = $true)][string] $newName
    )

    _sql-load-module

    $Databases = Invoke-SQLcmd -ServerInstance $sqlServerInstance -Query ("SELECT * from sys.databases where NAME = '$oldName'")

    ForEach ($Database in $Databases) { 
        Invoke-SQLcmd -ServerInstance $sqlServerInstance -Query (
            "alter database [" + $Database.Name + "] set single_user with rollback immediate
            EXEC sp_renamedb '$oldName', '$newName'
            ALTER DATABASE [$newName] SET MULTI_USER")
    }
}

function sql-get-dbs {
    _sql-load-module

    $Databases = Invoke-SQLcmd -ServerInstance $sqlServerInstance -Query ("SELECT * from sys.databases")

    return $Databases
}

function sql-get-items {
    Param($dbName, $tableName, $selectFilter, $whereFilter)

    _sql-load-module

    $result = Invoke-SQLcmd -ServerInstance $sqlServerInstance -Query ("
        SELECT $selectFilter
        FROM [${dbName}].[dbo].[${tableName}]
        WHERE $whereFilter")

    return $result
}

function sql-update-items {
    Param($dbName, $tableName, $value, $whereFilter)

    _sql-load-module

    $result = Invoke-SQLcmd -ServerInstance $sqlServerInstance -Query "
        UPDATE [${dbName}].[dbo].[${tableName}]
        SET ${value}
        WHERE $whereFilter"

    return $result
}

function sql-insert-items {
    Param($dbName, $tableName, $columns, $values)

    _sql-load-module

    $result = Invoke-SQLcmd -ServerInstance $sqlServerInstance -Query "
        INSERT INTO [${dbName}].[dbo].[${tableName}] ($columns)
        VALUES (${values})"

    return $result
}

function sql-delete-items {
    Param($dbName, $tableName, $whereFilter)

    _sql-load-module

    Invoke-SQLcmd -ServerInstance $sqlServerInstance -Query ("
        DELETE FROM [${dbName}].[dbo].[${tableName}]
        WHERE $whereFilter")
}

function sql-test-isDbNameDuplicate {
    Param($dbName)

    _sql-load-module

    $existingDbs = @(sql-get-dbs)
    $exists = $false
    ForEach ($db in $existingDbs) {
        if ($db.name -eq $dbName) {
            $exists = $true
            break;
        }
    }

    return $exists
}

function sql-copy-db ($SourceDBName, $targetDbName) {
    #import SQL Server module
    _sql-load-module

    #your SQL Server Instance Name
    $SQLInstanceName = $sqlServerInstance
    $Server = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList $SQLInstanceName

    #create SMO handle to your database
    $SourceDB = $Server.Databases[$SourceDBName]

    #create a database to hold the copy of your source database
    $CopyDBName = $targetDbName
    $CopyDB = New-Object -TypeName Microsoft.SqlServer.Management.SMO.Database -ArgumentList $Server , $CopyDBName
    $CopyDB.Create()

    #Use SMO Transfer Class by specifying source database
    #you can specify properties you want either brought over or excluded, when the copy happens
    $ObjTransfer = New-Object -TypeName Microsoft.SqlServer.Management.SMO.Transfer -ArgumentList $SourceDB
    $ObjTransfer.CopyAllTables = $true
    $ObjTransfer.CopyAllObjects = $true
    $ObjTransfer.Options.WithDependencies = $true
    $ObjTransfer.Options.ContinueScriptingOnError = $true
    $ObjTransfer.Options.Indexes = $true
    $ObjTransfer.Options.DriIndexes = $true
    $ObjTransfer.Options.DriPrimaryKey = $true
    $ObjTransfer.Options.DriUniqueKeys = $true
    $ObjTransfer.Options.Default = $true
    $ObjTransfer.Options.DriDefaults = $true
    $ObjTransfer.Options.DriAllKeys = $true
    $ObjTransfer.Options.DriAllConstraints = $true
    $ObjTransfer.Options.DriForeignKeys = $true
    $ObjTransfer.DestinationDatabase = $CopyDBName
    $ObjTransfer.DestinationServer = $Server.Name
    $ObjTransfer.DestinationLoginSecure = $true
    $ObjTransfer.CopySchema = $true

    #if you wish to just generate the copy script
    #just script out the transfer
    $ObjTransfer.ScriptTransfer()

    #When you are ready to bring the data and schema over,
    #you can use the TransferData method
    $ObjTransfer.TransferData()
}

function sql-create-login ($name) {
    _sql-load-module
    
    $sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList '.'
    $SQLWindowsLogin = [Microsoft.SqlServer.Management.Smo.Login]::New($sqlServer, $name)
    $SQLWindowsLogin.LoginType = [Microsoft.SqlServer.Management.Smo.LoginType]::WindowsUser
    $SQLWindowsLogin.Create() 
    $SQLWindowsLogin.AddToRole("sysadmin")
}

function sql-delete-login ($name) {
    _sql-load-module

    $sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList '.'
    $ToDrop = $sqlServer.Logins[$name]
    $ToDrop.Drop()
}