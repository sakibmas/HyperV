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
  $InsFeature = Get-WindowsFeature | Where-Object {$_.InstallState -eq 'Installed' -AND $_.Name -eq 'Hyper-V'}
  $SrvInv = get-wmiobject Win32_ComputerSystem | select Name,Model,@{name="TotalPhysicalMemory(GB)";expression={[math]::Ceiling($_.TotalPhysicalMemory/1Gb)}},NumberOfProcessors,NumberOfLogicalProcessors;
  $DiskInv = Get-WmiObject -Class win32_logicaldisk | where-object {$_.Name -eq "D:"} | select Name,  @{name="Size";expression={[math]::Round($_.Size/1GB,2)}}
  $SrvInv | Add-Member -MemberType NoteProperty -Name 'DiskSize(GB)' -Value $DiskInv.Size
  $BiosInv = Get-WmiObject win32_bios | select SerialNumber
  $SrvInv | Add-Member -MemberType NoteProperty -Name SerialNumber -Value $BiosInv.SerialNumber
  $CpuInv = Get-WmiObject Win32_Processor | select Name
  $SrvInv | Add-Member -MemberType NoteProperty -Name Processor -Value $CpuInv[0].Name
  $SrvInv | select Name,Model,Processor,NumberOfProcessors,NumberOfLogicalProcessors,SerialNumber,'TotalPhysicalMemory(GB)','DiskSize(GB)' | fl

  if($InsFeature)
  {
   $vmlist = get-vm
   $vmlist | %{
     $vmname=$_.Name
     $vmstat=Get-VM $vmname | Select-Object Name, Generation, DynamicMemoryEnabled, MemoryMinimum, MemoryMaximum, MemoryAssigned, ProcessorCount
     $vmcpustat=Get-VMProcessor $vmname | Select-Object Reserve
     $vmdiskstat=Get-VM $vmname | Select-Object VMId | Get-VHD | Select-Object Path, Size
     $TotalFileSize=0
     foreach ($disk in $vmdiskstat) {$TotalFileSize+=$disk.Size}

     $OutputItem = New-Object PSObject;
     $OutputItem | Add-Member NoteProperty "Name" $vmstat.Name;
     $OutputItem | Add-Member NoteProperty "Generation" $vmstat.Generation;
     if ($vmstat.DynamicMemoryEnabled -eq $true)
     {
      $OutputItem | Add-Member NoteProperty "MemoryMinimum(GB)" ($vmstat.MemoryMinimum/1024/1024/1024);
      $OutputItem | Add-Member NoteProperty "MemoryMaximum(GB)" ($vmstat.MemoryMaximum/1024/1024/1024); 
     }
     else
     {
      $OutputItem | Add-Member NoteProperty "MemoryMinimum(GB)" ($vmstat.MemoryAssigned/1024/1024/1024);
      $OutputItem | Add-Member NoteProperty "MemoryMaximum(GB)" ($vmstat.MemoryAssigned/1024/1024/1024); 
     }
     $OutputItem | Add-Member NoteProperty "ProcessorCount" ($vmstat.ProcessorCount);
     $OutputItem | Add-Member NoteProperty "ProcessorReserve" $vmcpustat.Reserve;
     $OutputItem | Add-Member NoteProperty "TotalDiskSize(GB)" ($TotalFileSize/1024/1024/1024);
     $Output += $OutputItem;
   }
   $Output | ft
  }
  else
  {
    write-host Hyper-V is not installed.
  }
   write-host $dsep 
  }
 }
}
