Function Edit-LiteTouchBootstrap {
[CmdletBinding()]
Param(
    [Parameter(
        Mandatory = $true,
        Position = 0,
        ParameterSetName = "FullMedia",
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true
    )]
    [Alias(
        "Path",
        "Location",
        "FullName"
    )]
    [String[]]$MediaPath,

    [Parameter(
        Mandatory = $true,
        Position = 0,
        ParameterSetName = "WimOnly"
    )]
    [String[]]$WimPath,

    [System.Management.Automation.CredentialAttribute()]
    [pscredential]$DeploymentShareCredential,

	[System.Management.Automation.CredentialAttribute()]
    [pscredential]$DomainJoinCredential,
	
    [hashtable]$DefaultParameters,

    [ValidateScript({
        if (-not (Test-Path $_)) {
            throw "Scratch directory does not exist. Specify a valid directory."
        } else {
            return $true
        }
    })]
    [String]$ScratchDirectory = $env:TEMP,

    [Switch]$PassThru
)

Begin {
    $GUID = New-Guid

    $StagingFolder = "$env:TEMP\Edit-LiteTouchBootStrap_$GUID"

    New-Item -ItemType Directory -Path $StagingFolder | Out-Null

    Write-Verbose "Staging LiteTouch Bootstrap.ini modifications into $StagingFolder"
}

Process {

    foreach ($Item in (@{"FullMedia" = $MediaPath; "WimOnly" = $WimPath}[$PSCmdlet.ParameterSetName])) {

        $ItemGUID = New-GUID

        Switch ($PSCmdlet.ParameterSetName) {
            "FullMedia" {            
                Write-Verbose "Processing LiteTouch media at $Item"
                $BootWimPath = Join-Path $item "\Sources\boot.wim"    
            }

            "WimOnly" {
                Write-Verbose "Processing LiteTouch WIM at $item"

                $BootWimPath = $item

            }
        }

        $ItemStagingDir = Join-Path $StagingFolder $ItemGUID

        Write-Verbose "Mounting $BootWimPath to $ItemStagingDir..."

        New-Item -ItemType Directory -Path $ItemStagingDir | Out-Null

        Mount-WindowsImage -ImagePath $BootWimPath -Path $ItemStagingDir -Index 1 | Out-Null

        Push-Location $ItemStagingDir

        $IniFile = Get-IniContent -FilePath .\Deploy\Scripts\Bootstrap.ini
        $IniDefaultSection = $IniFile["Default"]


        If ($DeploymentShareCredential) {


            $DeploymentShareNetCredential = $DeploymentShareCredential.GetNetworkCredential()
            Write-Verbose "Injecting credentials for $($DeploymentShareNetCredential.Domain)\$($DeploymentShareNetCredential.UserName)..."

            $IniDefaultSection["UserID"] = $DeploymentShareNetCredential.UserName
            $IniDefaultSection["UserPassword"] = $DeploymentShareNetCredential.Password
            $IniDefaultSection["UserDomain"] = $DeploymentShareNetCredential.Domain

        }
		
		If ($DomainJoinCredential) {


            $DomainJoinNetCredential = $DomainJoinCredential.GetNetworkCredential()
            Write-Verbose "Injecting domain credentials for $($DomainJoinNetCredential.Domain)\$($DomainJoinNetCredential.UserName)..."

            $IniDefaultSection["DomainAdmin"] = $DomainJoinNetCredential.UserName
            $IniDefaultSection["DomainAdminPassword"] = $DomainJoinNetCredential.Password
            $IniDefaultSection["DomainAdminDomain"] = $DomainJoinNetCredential.Domain

        }
		
        If ($DefaultParameters) {

            Write-Verbose "Injecting parameters into section [Default]..."

            foreach ($Param in $DefaultParameters.GetEnumerator()) {
                Write-Verbose "Setting parameter $($Param.Key)=$($Param.Value)"
                $IniDefaultSection[$Param.Key] = $Param.Value
            }
        }

        $IniFile["Default"] = $IniDefaultSection

        Write-Verbose "Flushing Bootstrap.ini changes to disk..."

        $IniFile | Out-IniFile -FilePath .\Deploy\Scripts\Bootstrap.ini -Encoding ASCII -Force

        Pop-Location

        Write-Verbose "Dismounting WIM..."

        Dismount-WindowsImage -Path $ItemStagingDir -Save | Out-Null

        Write-Verbose "Removing item staging folder..."

        Remove-Item $ItemStagingDir -Recurse -Force

        Write-Verbose "Done processing $item."

        if ($PassThru) {
        
            Write-Output (Get-item $Item)
        
        }
    }

    





    
}

End {
    Write-Verbose "Removing staging folder $StagingFolder..."

    Remove-Item $StagingFolder -Recurse -Force
}

}