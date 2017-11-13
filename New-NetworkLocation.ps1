Function New-NetworkLocation {
Param(

    [Parameter(
        Position = 0,
        Mandatory = $true
    )]
    [String]$Name,

    [Parameter(
        Position = 1,
        Mandatory = $true,
        ValueFromPipeline = $true
    )]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [String]$TargetPath,

    [Switch]$Force

)

    If ($Force -and (Test-Path (Join-Path "$env:APPDATA\Microsoft\Windows\Network Shortcuts" $Name))) {
    
        Remove-Item -Path (Join-Path "$env:APPDATA\Microsoft\Windows\Network Shortcuts" $Name) -Recurse -Force
    
    }

	$DesktopINIData = @"
[.ShellClassInfo]
CLSID2={0AFACED1-E828-11D1-9187-B532F1E9575D}
Flags=2
"@

    $Folder = New-Item -ItemType Directory -Path (Join-Path "$env:APPDATA\Microsoft\Windows\Network Shortcuts" $Name)

    $INIFile = New-Item -ItemType File -Path (Join-Path $Folder.FullNAme "desktop.ini")

    $INIFile.Attributes = "" # Clear Archive Flag

    $INIFile.Attributes = "Hidden, System"

    $INIFile | Set-Content -Value $DesktopINIData

    $WshShell = New-Object -ComObject WScript.Shell

    $Shortcut = $WshShell.CreateShortcut((Join-Path $Folder.FullName "target.lnk"))

    $Shortcut.TargetPath = $TargetPath

    $Shortcut.Description = $TargetPath

    $Shortcut.Save()

    $Folder.Attributes = "ReadOnly"

    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($WshShell) | Out-Null
    
}