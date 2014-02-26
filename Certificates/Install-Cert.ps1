Function Install-Cert 
{
<#
.SYNOPSYS 
Install-Cert will install a specified certificate on a specified computer or computers 
 
.DESCRIPTION 
Install-Cert uses the System.Security.Cryptography.X509Certificates.X509Certificate2 class and Invoke-Command to load and install certificates on local or remote machines.

.EXAMPLE 
Get-content .\names.txt | Install-Cert -path .\rootca.cer -store root

Installs the Rootca.cer certificate in the root store on all computers listed in names.txt file

.Notes
Requires the Powershell version to be at least 3.0
Must be run from an administrative prompt
PSRemoting must be enabled
Author: Jason Morgan
Last modified 5/10/2013
#>
[CmdletBinding()]
Param 
    (
        [Parameter( 
        ValueFromPipeline=$True, 
        ValueFromPipelineByPropertyName=$True)] 
        [String[]]$ComputerName = "$env:COMPUTERNAME" ,
        [Parameter(Mandatory=$True)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [String]$path,
        [Parameter(Mandatory=$True)]
        [string]$store,
        [System.Management.Automation.PSCredential]$credential 
    )
Begin 
    {
        $param = @{ScriptBlock = {
                $ErrorActionPreference = "stop"
                $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromCertFile($Path)
                $store = New-Object System.Security.Cryptography.X509Certificates.X509Store($store,"LocalMachine")
                $store.Open("ReadWrite")
                $store.Add($cert)
                $store.Close()
            }
            }
    }
Process 
    {
        If (Test-Connection $ComputerName -Quiet -Count 2) { 
            If ($ComputerName -ne $env:COMPUTERNAME) {$param.Add("ComputerName",$ComputerName)}
            if ($credential) { $param.Add("Credential", $credential) }
            Try {Invoke-Command @param }
            Catch 
                { 
                    Write-Warning "The command failed on $ComputerName"
                    Write-Warning $_.exception.message
                }
        } Else { Write-Warning "The Computer, $ComputerName, is not online" }
    }
End {}
} 

