Function Import-EWSManagedAPI {
[CmdletBinding()]
Param(
)

    If (Get-Module Microsoft.Exchange.WebServices -ListAvailable) {
        Write-Verbose "Attempting automatic import of EWS Managed API..."
        Import-Module Microsoft.Exchange.WebServices -ErrorAction Stop
    } Elseif (Test-Path "$env:ProgramFiles\Microsoft\Exchange\Web Services\") {
        Write-Verbose "Searching for EWS Managed API Versions..."
        Get-ChildItem -Directory "$env:ProgramFiles\Microsoft\Exchange\Web Services\" | Sort -Property @{Expression = {$_.BaseName -as [version]}; Descending = $true} | ForEach-Object {
            $EWSApiVersion = $_.BaseName
            Write-Verbose "Attempting to import EWS Managed API version $EWSApiVersion..."
            $SuccessfulImport = $false
            try {
                Import-Module "$($_.FullName)\Microsoft.Exchange.WebServices.dll" -ErrorAction Stop
                $SuccessfulImport = $true
                Write-Verbose "Imported EWS Managed API version $EWSApiVersion successfully."
                Return
            } catch {
                Write-Warning "Import of EWS Managed API version $_ failed."
            }

        }
    } Else {
        throw "EWS Managed API not found. Run `"Install-Package Microsoft.Exchange.WebServices`" as local administrator to install via NuGet."
    }

}

Function Get-EWSMailboxDelegates {
[CmdletBinding()]
Param (
    [Parameter(
        Mandatory=$true
    )]
    [pscredential]$EWSCredential,

    [String]$Mailbox = $EWSCredential.Username,

    [Switch]$AllowAllRedirects
)

    if (Get-Module Microsoft.Exchange.WebServices) {
        Write-Verbose "EWS Managed API available. Continuing..."
    } Else {
        Import-EWSManagedAPI
    }


    $ExchSvc = [Microsoft.Exchange.WebServices.Data.ExchangeService]::new()

    $ExchSvc.UseDefaultCredentials = $false

    $ExchSvc.Credentials = $EWSCredential.GetNetworkCredential()

    Write-Verbose "Performing Autodiscover for $Mailbox as $($EWSCredential.UserName)..."
    If ($AllowAllRedirects) {
        $ExchSvc.AutodiscoverUrl($Mailbox, {return $true})
        Write-Verbose "Autodiscover complete. EWS URL: $($Exchsvc.Url)"    
    } Else {
        try {
            $ExchSvc.AutodiscoverUrl($Mailbox)
            Write-Verbose "Autodiscover complete. EWS URL: $($Exchsvc.Url)"
        }
        catch [Microsoft.Exchange.WebServices.Data.AutodiscoverLocalException] {
            throw "Autodiscover attempted to redirect connection. Use the -AllowAllRedirects parameter to allow this."
        }
       
                
    }

    Write-Verbose "Retrieving Delegates for $Mailbox..."
    $Delegates = $ExchSvc.GetDelegates([Microsoft.Exchange.WebServices.Data.Mailbox]::new($Mailbox), $true)

    return $Delegates
}

