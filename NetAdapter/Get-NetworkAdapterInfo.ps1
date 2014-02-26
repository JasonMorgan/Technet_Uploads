Function Get-NetworkAdapterInfo
{
<#
.Synopsis
   Uses WMI and PSRemoting to gather detailed information about network adapters
.DESCRIPTION
   This function works by querying the registry for Network adapter bindings and then searching through
    WMI for the adapters defined by those GUIDs.  A "detailed" switch is provided so that the function 
   can, by default, omit all adapters that aren't currently enabled by the OS.
    
    The following properties are returned:

    ServiceName       - The name of the service associated with the adapter
    Enabled           - Whether the adapter is enabled
    DNSDomain         - DNS Domain for the Adapter
    BindingOrder      - the Binding order from the registry
    DeviceDescription - Description from WMI
    MAC               - MAC Address
    State             - Only 3 porperties for the connection state are listed, for more info look at the MSDN page for win32_networkadapter under NetConnectionStatus
    Name              - Name from WMI
    Description       - Friendly name for the Adapter, whatever is listed in the network adapters page under the control panel
    DefaultGateway    - Default Gateway
    IPAddress         - IP Address or Addresses
    GUID              - The GUID for the adapter

.EXAMPLE
   Get-NetworkAdapterInfo
   
    ServiceName       : ENIC
    Enabled           : True
    DNSDomain         :
    BindingOrder      : 2
    DeviceDescription : Cisco VIC Ethernet Interface #2
    MAC               : 00:11:22:33:44:55
    State             : Connected
    Name              : Cisco VIC Ethernet Interface #2
    Description       : Local Area Connection 2
    DefaultGateway    :
    IPAddress         : {169.254.71.178}
    GUID              : {503D0AEF-517B-4041-AEC3-B57F2D510ADF}

.EXAMPLE
   Get-NetworkAdapterInfo -computername $targets

   Gets Network adapter information for any number of target computers specified in the variable $targets

.INPUTS
   [string[]]

.OUTPUTS
   [PSObject]

.NOTES
   By Jason Morgan
   Created on: 12/11/2013
   LastModified: 12/11/2013

#>
[CmdletBinding(ConfirmImpact='Medium')]
Param
    (
        # Enter a computername or multiple computernames
        [Parameter( 
        ValueFromPipeline=$True, 
        ValueFromPipelineByPropertyName=$True,
        HelpMessage="Enter a ComputerName or IP Address, accepts multiple ComputerNames")]             
        [Alias("__Server")] 
        [System.Collections.ArrayList][string[]]$ComputerName = $env:COMPUTERNAME,
        # Activate switch for detailed adapter information
        [Parameter(Mandatory=$false)]
        [switch]$Detailed 
    )

Begin
    {
            if (-not($Detailed))
                {
                    Write-Warning "The detailed switch was not activated, only adapters that are currently enabled will be captured. To view information for all adapters activate the -Detailed switch"
                }
            $params = @{
                Scriptblock = {
                        $bind = 0
                        $GUIDs = (Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\services\Tcpip\Linkage -Name bind).bind | foreach {$_.split('\')[2]}
                        Foreach ($g in $GUIDs)
                            {
                                $bind ++
                                $Adapter = Get-WmiObject win32_networkadapter -filter "GUID='$g'"
                                $conf = Get-WmiObject win32_NetworkAdapterConfiguration -Filter "Index='$($Adapter.index)'"
                                $state = switch ($Adapter.NetConnectionStatus)
                                    { 
                                        0  {"Disconnected"}
                                        1  {"Connecting"}
                                        2  {"Connected"}
                                        default  {"Unknown"}
                                    }
                                $hash = @{
                                        BindingOrder = $bind
                                        IPAddress = $conf.IPAddress
                                        DefaultGateway = $conf.DefaultIPGateway
                                        DNSDomain = $conf.DNSDomain
                                        ServiceName = $conf.ServiceName
                                        DeviceDescription = $conf.Description
                                        Name = $Adapter.Name
                                        Description = $Adapter.NetConnectionID
                                        Enabled = $Adapter.NetEnabled
                                        State = $state
                                        MAC = $Adapter.MACAddress
                                        GUID = $Adapter.GUID
                                    }
                                $e = New-Object -TypeName PSObject -Property $hash
                                if ($detailed)
                                    {
                                        $e
                                    }
                                Else
                                    {
                                        $e | where {$_.Enabled}
                                    }
                        
                            }
                    }
                }
        }
Process
    {
            if ($ComputerName -contains $ENV:COMPUTERNAME)
                {
                    $ComputerName.Remove("$ENV:COMPUTERNAME")
                    $local = $True
                }
            if (($ComputerName |measure).Count -gt 0)
                {
                    $params.Add('ComputerName',$ComputerName)
                    Invoke-Command @params
                }
            if ($local)
                {
                    Try {$params.Remove('ComputerName')} Catch {}
                    Invoke-Command @params
                }    
        }
End {}
}