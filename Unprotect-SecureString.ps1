function Unprotect-SecureString {
[CmdletBinding()]
Param(
    [parameter(
        Mandatory = $true,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true
    )]
    [Alias(
        "Password",
        "SS"
    )]
    [ValidateNotNull()]
    [SecureString[]]$SecureString
)

    Process {
        $SecureString | ForEach-Object {
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($_)
            
            try {
                return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR)
            } finally {
                [System.Runtime.InteropServices.Marshal]::FreeBSTR($BSTR)
            }
            
        }
    }

}