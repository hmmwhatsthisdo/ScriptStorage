Function New-BootableDisk {
[CmdletBinding(
    ConfirmImpact = "High",
    SupportsShouldProcess = $true
)]
Param (
    [Parameter(
        Mandatory = $true,
        Position = 0,
        ValueFromPipelineByPropertyName = $true,
        ValueFromPipeline = $true
    )]
    [Alias(
        "Number"
    )]
    [ValidateScript({
        if ((Get-Disk -Number $_) -and (Get-Disk -Number $_ | ? OperationalStatus)) {
            return $true
        } else {
            throw "Please specify a valid, online disk."
        }
    })]
    [Int32[]]$DiskNumber
)

Begin {
    If (Get-Service "Shell Hardware Detection" | ? Status -eq Running) {
        Write-Warning "Shell Hardware Detection service can cause problems with the bootdisk creation process and will be temporarily stopped."
        $ShouldRestartShellHWD = $true
        Stop-Service "Shell Hardware Detection"
    }
}

Process {

    foreach ($_DiskNumber in $DiskNumber) {
        
        Write-Verbose "Beginning work on Disk $_DiskNumber..."
        
        # Get the disk object itself
        $Disk = Get-Disk -Number $_DiskNumber
        
        if ($PSCmdlet.ShouldProcess("Disk $_DiskNumber [`"$($Disk.FriendlyName)`", $($Disk.Size / 1MB) MB]","Partition and install MBR boot sector")) {

            if ($Disk.PartitionStyle -eq "RAW") {
                
                Write-Verbose "Disk $_DiskNumber uninitialized. Applying MBR partition layout..."

                # Apply MBR partition style
                $Disk | Initialize-Disk -PartitionStyle MBR
            } else {

                Write-Verbose "Disk $_DiskNumber initialized. Repartitioning as MBR..."

                $Disk | Clear-Disk -RemoveData -RemoveOEM -Confirm:$false
                $Disk | Set-Disk -PartitionStyle MBR
            }

            Write-Verbose "Creating active partition on Disk $_DiskNumber..."

            # Make an active partition for the boot code to be applied to
            If ($Disk.Size -ge 32GB) {
                $Partition = $Disk | New-Partition -Size 32GB -IsActive -MbrType FAT32 -AssignDriveLetter
            } Else {
                $Partition = $Disk | New-Partition -UseMaximumSize -IsActive -MbrType FAT32 -AssignDriveLetter
            }
            

            Write-Verbose "Formatting $($Partition.DriveLetter)`:\ on Disk $_DiskNumber as FAT32"

            # Format FS as FAT32 to match the MBR type we specified
            $Partition | Format-Volume -FileSystem FAT32 -Confirm:$false | out-null

            Write-Verbose "Applying boot code to $($Partition.DriveLetter)`:\ using BOOTSECT.EXE..."

            # Use Bootsect to apply boot code to the freshly-minted partition
            Start-Process "bootsect.exe" -ArgumentList "/nt60","$($partition.DriveLetter):" -Wait -WindowStyle Hidden
			
			Write-Output $Partition

			Write-Verbose "Disk $_DiskNumber `[$($Partition.DriveLetter)`] complete."
			
        } Else {
			Write-Warning "Disk $_DiskNumber `[$($Partition.DriveLetter)`] skipped."
		}

        
    }
    
}
 
End {
    If ($ShouldRestartShellHWD) {
        Write-Warning "Restarting Shell Hardware Detection service..."
        Start-Service "Shell Hardware Detection"
    }

    Write-Verbose "Done."
}

}