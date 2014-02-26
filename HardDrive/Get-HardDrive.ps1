Function Get-HardDrive
{ 
<# 
 
.SYNOPSIS 
A function to grab hard drive information from local and remote computers 
 
.DESCRIPTION 
Get-ISDHardDrive uses win32_volume to list the drives on a local or remote computer and stores that data in a custom object. 
Get-ISDHardDrive can be paired with other cmdlets to format the output 
 
.EXAMPLE
Get-HardDrive 
 
Runs the function locally, produces output like: 
 
FreeSpace    : 102.69 GB 
Drive        : C: 
ComputerName : Computer1 
PercentFree  : 52.60 % 
Size         : 195.21 GB 
 
FreeSpace    : 709.40 GB 
Drive        : D: 
ComputerName : Computer1 
PercentFree  : 47.89 % 
Size         : 1,481.42 GB 
 
.EXAMPLE  
Get-HardDrive -computername Computer2 | Format-table -auto 
 
Get's info from a remote computer named computer 2 
 
FreeSpace Drive ComputerName PercentFree Size     
--------- ----- ------------ ----------- ----     
9.42 GB   C:    Computer2    15.70 %     60.00 GB 
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
        $Params = @{
                'Class' = 'Win32_Volume' 
                'Filter' = "DriveType=3 and Label!='System Reserved'"
            }
        If ($credential) {$Params.Add('Credential',$credential)}

    } 
Process  
    {
        Foreach ($Computer in $ComputerName)
            {
                If ($Ping) 
                    {
                        Write-Verbose "Testing connection to $Computer"
                        if (-not(Test-Connection -ComputerName $Computer -Quiet)) 
                            {
                                Write-Warning "Could not ping $Computer" ; $Problem = $true
                            }
                    }
                Write-Verbose "Beginning operation on $Computer"
                If (-not($Problem))
                    {
                        Try 
                            { 
                                Write-Verbose "Collecting Drives on $Computer"
                                $drives = Get-WmiObject @params -ComputerName $Computer
                                foreach ($drive in $drives) 
                                    { 
                                        Write-Verbose "Creating Object for $Computer"
                                        New-Object PSobject -Property @{ 
                                                ComputerName = $Drive.__Server 
                                                Drive = $Drive.DriveLetter 
                                                FreeSpace = "$([Math]::Round(($Drive.freespace /1GB), 2))GB"
                                                Size = "$([Math]::Round(($Drive.Capacity /1GB), 2))GB" 
                                                PercentFree = "$([Math]::Round((($Drive.Freespace/$Drive.Capacity)), 2)*100)%" 
                                            } 
                                    }
                            }
                        Catch
                            {
                                Write-Warning $_.exception.message
                                $Problem = $True
                            }     
                    }
                if ($Problem) {$Problem = $false}
            }
        }    
End {} 
}