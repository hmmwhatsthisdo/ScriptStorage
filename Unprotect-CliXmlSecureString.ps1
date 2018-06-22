function Unprotect-CliXmlSecureString {
    [CmdletBinding()]
    param (
        # Specifies a path to one or more PowerShell CLIXML files (created using Export-CLIXML). Wildcards are permitted. The current user must be the one who exported the file, and must have read/write access over the file.
        [Parameter(Mandatory=$true,
                   Position=0,
                   ParameterSetName="__AllParameterSets",
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   HelpMessage="Path to one or more locations.")]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string[]]
        $Path
    )
    
    begin {
        Add-Type -AssemblyName System.Security | Out-Null
    }
    
    process {
        Get-Item $Path | ForEach-Object {
            Write-Verbose "Processing CLIXML file `"$_`"."
            $XMLFile = $_

            Write-Verbose "Importing XML..."
            $XMLDocument = [xml](Get-Content -Path $XMLFile.FullName)

            Write-Verbose "Searching for SecureStrings..."
            Select-Xml -Xml $XMLDocument -XPath "//powershell:SS" -Namespace @{powershell = "http://schemas.microsoft.com/powershell/2004/04"} | ForEach-Object {

                # Try to avoid holding onto the unprotected data in memory as much as we can
                $_.Node.InnerText = ([System.Security.Cryptography.ProtectedData]::Protect(
                    [System.Security.Cryptography.ProtectedData]::Unprotect(
                        ($_.Node.InnerText -split '(..)' | Where-Object Length | ForEach-Object {[Convert]::ToByte($_, 16)}),
                        $null,
                        [System.Security.Cryptography.DataProtectionScope]::CurrentUser
                    ), 
                    $null, 
                    [System.Security.Cryptography.DataProtectionScope]::LocalMachine
                ) | ForEach-Object ToString 'x2') -join ''

            }
            $XMLDocument.Save($XMLFile.FullName)
            [GC]::Collect()

        }
    }
    
    end {
    }
}