Function Get-ComputerInfo
{
<#
.SYNOPSIS 
A function to grab general system information from local and remote computers 
 
.DESCRIPTION 
Get-ComputerInfo uses win32_OperatingSystem and Win32_Computersystem to list the information about a local or remote computer and stores that data in a custom object. 
Get-ComputerInfo can be paired with other cmdlets to format the output 
 
.EXAMPLE  

Get-ComputerInfo 

Runs locally and generates output like:

ComputerName    : Test
FQDN            : Test.lab
DomainJoined    : True
DomainName      : lab
Manufacturer    : Hewlett-Packard
Model           : HP EliteBook 8440p
OperatingSystem : Microsoft Windows 7 Professional 
OSVersion       : 6.1.7601
Architecture    : 32-bit
ImageDate       : 4/2/2013 3:06:59 PM
LastBootTime    : 5/7/2013 9:29:37 AM
LocalServerTime : 5/7/2013 5:33:58 PM

.EXAMPLE 

Get-Content c:\servers.txt | Get-ComputerInfo | Export-csv -NoTypeInformation -path c:\serverinfo.csv

Returns the computerinfo for all the computers in c:\servers.txt and exports that information into a csv file

#>
[CmdletBinding()] 
Param 
    ( 
        # Enter a ComputerName or IP Address, accepts multiple ComputerNames
        [Parameter( 
        ValueFromPipeline=$True, 
        ValueFromPipelineByPropertyName=$True,
        HelpMessage="Enter a ComputerName or IP Address, accepts multiple ComputerNames")] 
        [String[]]$ComputerName = "$env:COMPUTERNAME",
        # Enter a Credential object, like (Get-credential)
        [Parameter(
        HelpMessage="Enter a Credential object, like (Get-credential)")]
        [System.Management.Automation.PSCredential]$credential,
        # Activate this switch to force the function to run an ICMP check before running
        [Parameter(
        HelpMessage="Activate this switch to force the function to run an ICMP check before running")]
        [Switch]$ping 
    ) 
Begin 
    {
        $WMIParams = @{}
        If ($credential) 
            {
                Write-Verbose "Adding Credentails"
                $WMIParams.Add('Credential', $credential)
            }
    } 
Process  
    {
        Foreach ($Computer in $ComputerName)
            {
                If ($Ping) 
                    {
                        Write-Verbose "Testing connection to $Computer"
                        if (-not(Test-Connection -ComputerName $Computer -Quiet)) {Write-Warning "Could not ping $Computer" ; $problem = $true}
                    }
                Write-Verbose "Beginning operation"
                if (-not($problem)) 
                    {
                        Try 
                            {
                                Write-Verbose "Accessing Win32_ComputerSystem on $Computer"
                                $Comp = Get-WmiObject -Class Win32_Computersystem @WMIParams -ComputerName $Computer
                            }
                        Catch
                            {
                                Write-Warning $_.exception.message 
                                $problem = $True
                            }
                        If (-not($problem))
                            {
                                Try
                                    {
                                        Write-Verbose "Accessing Win32_OperatingSystem on $Computer"
                                        $OS = Get-WmiObject -Class Win32_Operatingsystem @WMIParams -ComputerName $Computer
                                    }
                                Catch
                                    {
                                        Write-Warning $_.exception.message 
                                        $problem = $True 
                                    }
                            }
                        If (-not($problem))
                            {
                                Try
                                    {
                                        $hash = @{ 
                                                ComputerName = $Comp.Name 
                                                FQDN = "$($Comp.DNSHostName)." + "$($Comp.Domain)"
                                                DomainJoined = $comp.PartOfDomain
                                                DomainName = $Comp.Domain
                                                Manufacturer = $Comp.Manufacturer
                                                Model = $Comp.Model
                                                OperatingSystem = $OS.Caption
                                                OSVersion = $OS.Version
                                                Architecture = $OS.OSArchitecture
                                                ImageDate = $OS.ConvertToDateTime($OS.InstallDate)
                                                LastBootTime = $OS.ConvertToDateTime($OS.LastBootUpTime)
                                                LocalServerTime = $OS.ConvertToDateTime($OS.LocalDateTime)
                                            }
                                        Write-Verbose "Creating custom object"
                                        New-Object -TypeName PSObject -Property $hash
                                    }
                                Catch
                                    {
                                        Write-Warning $_.exception.message 
                                        $problem = $True
                                    }
                            } 
                }
                if ($Problem) {$Problem = $false}
            }
    } 
End {} 
}