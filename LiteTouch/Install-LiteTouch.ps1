Function Install-LiteTouch {
[CmdletBinding()]
Param (

    [Parameter(
        Mandatory = $true,
        Position = 0
    )]
    [ValidateScript({

        if (-not (Test-Path $_)) {
            throw "Unable to access deployment share using specified credentials."
        } elseif (-not (Join-Path $_ "Boot" | Test-Path)) {
            throw "Unable to locate Boot folder under path specified. Ensure the root of the MDT Deployment Share has been specified."
        } else {
            return $true
        }
    })]
    [String]$DeploymentShare,

    [Parameter(
        Mandatory = $true,
        Position = 1,
        ValueFromPipelineByPropertyName = $true
    )]
    [ValidateLength(1, 1)]
    [ValidateScript({
        $Partition = Get-Partition -DriveLetter $_
        If (-not $Partition) {
            throw "Partition with the specified drive letter does not exist."
        } elseif (($Partition | ? IsOffline)) {
            throw "Partition is not online."
        }
        return $true
    })]
    [String[]]$DriveLetter,



    [ValidateSet(
        "x64",
        "x86"
    )]
    [String]
    $Architecture = "x64",

    [Switch]$PassThru,

    
    [Switch]$Parallel
)

Begin {
    if ($Parallel) {

        Write-Verbose "-Parallel specified. Staging to temporary folder..."

        $JobDict = @{}
        $GUID = New-GUID | % ToString
        $StagingFolder = "$env:TEMP\Install-LiteTouch_$GUID"

        New-Item -ItemType Directory -Path $StagingFolder | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $StagingFolder -ChildPath "$Architecture") | Out-Null

        Write-Verbose "Staging folder: $StagingFolder"
        
        Write-Verbose "Copying boot data from $DeploymentShare\Boot..."

        Copy-Item (Join-Path $DeploymentShare "\Boot\$Architecture\*") (Join-Path $StagingFolder "$Architecture") -Recurse | Out-Null
        Copy-Item (Join-Path $DeploymentShare "\Boot\LiteTouchPE_$Architecture.wim") $StagingFolder -Recurse | Out-Null
    } Else {

        Write-Verbose "-Parallel not specified. Staging directly from Deployment Share."

        $StagingFolder = Join-Path $DeploymentShare "Boot"

        Write-Verbose "Staging folder: $StagingFolder"
    }

    

}
    
Process {
        
    foreach ($_DriveLetter in $DriveLetter) {

        Write-Verbose "Working on drive $_DriveLetter`:\..."

        # Set the partition's name.
        Get-Volume -DriveLetter $_DriveLetter | Set-Volume -NewFileSystemLabel "LiteTouch"

        # Copy files from the Deployment Share onto the volume.
        $BootFolderPattern = (Join-Path $StagingFolder "\$Architecture\*")
        $DestFolder = "$_DriveLetter`:\"
        Write-Verbose "Starting Copy job of $BootFolderPattern to $DestFolder..."
        $BootCopyJob = Start-Job {Copy-Item $args[0] $args[1] -Recurse} -ArgumentList $BootFolderPattern,$DestFolder

        # Add the Sources folder.
        New-Item -ItemType Directory -Path "$_DriveLetter`:\Sources" | Out-Null 

        $WIMLocation = (join-path $StagingFolder "\LiteTouchPE_$Architecture.wim")
        $WIMDest = "$_DriveLetter`:\Sources\boot.wim"

        Write-Verbose "Starting Copy job of $WIMLocation to $DestFolder..."
        # Copy the LiteTouch WIM into the Sources folder.
        $WIMCopyJob = Start-Job {Copy-Item $args[0] $args[1]} -ArgumentList $WIMLocation,$WIMDest

        

        If (-not $Parallel) {
            Write-Verbose "-Parallel not specified. Waiting for jobs to complete..."
            Wait-Job $WIMCopyJob,$BootCopyJob | Out-Null
            if ($PassThru) {
                Write-Verbose "Installation complete for $DestFolder."
                Write-Output (Get-Item $DestFolder)            
            }
        } Else {
            Write-Verbose "Registering install jobs..."
            $JobDict[$DestFolder] = @($BootCopyJob,$WimCopyJob)
        }

    }
}

End {

    if ($Parallel) {
        while ($JobDict.Count -gt 0) {
            $JobsToRemove = @()
            foreach ($InstallJob in $JobDict.GetEnumerator()) {
                If (-not ($InstallJob.Value | ? State -eq Running)) {
                    Write-Verbose "Install jobs for drive $($InstallJob.Key) finished."
                    if ($InstallJob.Value | ? State -eq Failed) {
                        Write-Warning "Copy operation(s) for drive $($InstallJob.Key) failed."
                    }

                    $JobsToRemove += $InstallJob
                    if ($PassThru) {
                        Write-Verbose "Finished processing install on drive $($InstallJob.Key)"
                        Write-Output (Get-Item $InstallJob.Key)
                    }
                }
            }
            Write-Verbose "$($JobsToRemove.Count) jobs have finished execution."
            $JobsToRemove | % {
                Write-Verbose "Unregistering jobs for drive $($_.Key)..."
                $JobDict.Remove($_.Key)
            }

            Write-Verbose "Waiting for jobs to complete..."
            Start-Sleep -Seconds 1
        }
        Write-Verbose "All installations complete."
        Write-Verbose "Removing staging folder $StagingFolder..."
        Remove-item $StagingFolder -Force -Recurse
    }
    
    Write-Verbose "Done."
}

}