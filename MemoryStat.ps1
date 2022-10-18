[string]$Servers = $ENV:PhysicalServers
$hypervisors = $Servers.Split(",")

foreach ($hypervisor in $hypervisors)
{
 $connectTestResult=Test-Netconnection -ComputerName $hypervisor -Port 5985
 if ($connectTestResult.TcpTestSucceeded) { 
  $rs=New-PSSession -ComputerName $hypervisor
  Invoke-Command -Session $rs -ScriptBlock {
   $Output = @();
   $dsep = "==============================================================================================================="

   $SrvInv = get-wmiobject Win32_ComputerSystem | select Name,Model,@{name="TotalPhysicalMemory(GB)";expression={[math]::Ceiling($_.TotalPhysicalMemory/1Gb)}},NumberOfProcessors,NumberOfLogicalProcessors;
   
   $DiskInv = Get-WMIObject -Class Win32_DiskDrive | Where-Object{$_.Name -like "*PHYSICALDRIVE0" } | select @{name="Size";expression={[math]::Round($_.Size/1GB,2)}}
   $SrvInv | Add-Member -MemberType NoteProperty -Name 'TotalDiskSize(GB)' -Value $DiskInv.Size
   
   $BiosInv = Get-WmiObject win32_bios | select SerialNumber
   $SrvInv | Add-Member -MemberType NoteProperty -Name SerialNumber -Value $BiosInv.SerialNumber
   
   $CpuInv = Get-WmiObject Win32_Processor | select Name
   $SrvInv | Add-Member -MemberType NoteProperty -Name Processor -Value $CpuInv[0].Name
   
   $SrvInv | select Name,Model,Processor,NumberOfProcessors,NumberOfLogicalProcessors,SerialNumber,'TotalPhysicalMemory(GB)','TotalDiskSize(GB)' | fl

   $MemInv = Get-WMIObject -Class Win32_PhysicalMemory | select DeviceLocator,@{Name="Capacity(GB)";Expression={$_.Capacity/1GB}}, Manufacturer, PartNumber, SerialNumber, DataWidth, Speed
   $MemInv | ft
   
   write-host $dsep 
  }
 }
}
