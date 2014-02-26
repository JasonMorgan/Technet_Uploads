Function Disable-RDP
{
<#
.SYNOPSYS
Disable RDP on a local or remote workstation
 
.DESCRIPTION
Uses the Win32_TerminalServiceSetting class to Disable RDP on a remote computer
 
.EXAMPLE
Disable-RDP -ComputerName TestVM

Disables RDP on the remote workstation TestVM, produces not output by default

.EXAMPLE
Get-Content .\Servers.txt | Disable-RDP -DCOM

Disables RDP on a list of remote servers contained in Services
 
.NOTES
Requires PowerShell Version 3
#>
[CmdletBinding()]
Param
    (
        # Specify a ComputerName or IP Address.  Can accept multiple entries
        [Parameter(
        ValueFromPipeline=$True,
        ValueFromPipelineByPropertyName=$True)]
        [String[]]$ComputerName = "$env:COMPUTERNAME",
        # Specify a set of credentials for executing the command
        [System.Management.Automation.PSCredential]$credential,
        # Force the Function to use DCOM, good for systems that you know don't accept CIM connections over WSMan or if you just prefer DCOM.
        [Switch]$DCOM
    )
Begin
    {
        $params = @{}
        Write-Verbose "Setting Parameters for New-Cimsession"
        Write-Verbose "Setting Parameters for New-Cimsession"
        $CimParams = @{}
        if ($Credential) {$CimParams.Add("Credential",$Credential)}
        $opt = New-CimSessionOption -Protocol Dcom
    }
Process 
    {
        Foreach ($Computer in $ComputerName) # Needed to add this because Test-WSMan won't accept a String[] :(
            {
                Write-Verbose "Testing connection to $Computer"
                If (Test-Connection -ComputerName $Computer -Quiet -Count 2)
                {
                    Write-Verbose "Determining connection protocol for $Computer"
                    Try
                        {
                            If ($DCOM -or (-not(Test-WSMan -ComputerName $Computer -ErrorAction stop).ProductVersion.split(':')[-1] -eq '3.0'))
                                {
                                    $CimParams.Add("SessionOption",$Opt)
                                }
                        }
                    Catch { Write-Warning "Function will not run on $computer" ; Write-Warning $_.exception.message ; break }
                    Write-Verbose "Beginning operation"
                    Try
                        {
                            $result = Get-CimInstance -Namespace root\cimv2\TerminalServices -ClassName Win32_TerminalServiceSetting -CimSession (New-CimSession -ComputerName $Computer @CimParams) -ErrorAction Stop |
                            Invoke-CimMethod -MethodName SetAllowTSConnections -Arguments @{AllowTSConnections=0;ModifyFirewallException=0}
                            If ($result.ReturnValue -ne 0) {Throw "Operation failed on $Computer"}
                        }
                    Catch
                        {
                            Try
                                {
                                    If ($_.exception.message -match 'Invalid Class')
                                        {
                                            $result = Get-CimInstance -Namespace root\cimv2\TerminalServices -ClassName Win32_TerminalServiceSetting -CimSession (New-CimSession -ComputerName $Computer @CimParams) -ErrorAction Stop |
                                            Invoke-CimMethod -MethodName SetAllowTSConnections -Arguments @{AllowTSConnections=0;ModifyFirewallException=0}
                                            If ($result.ReturnValue -ne 0) {Throw "Operation failed on $Computer"}
                                            Write-Verbose "The operation returned $result.ReturnValue, only a value of 0 indicates success"
                                        }
                                    Else
                                        {
                                            Write-Warning "Failed to set RDP on $Computer"
                                            Write-Warning $_.exception.message
                                        }
                                }
                            Catch
                                {
                                    Write-Warning $_.exception.message
                                }
                        }
                }
                Else {Write-Warning "The computer, $Computer, is not online please verify connectivity and try again"}
            }
    }
End
    {
    Write-Verbose "Removing CIMSessions"
    Get-CimSession | Remove-CimSession
    }
}