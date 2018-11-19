param([string]$vwebtype, [string]$vwebnum, [string]$recycletype="all")

$newvwebnum=@()
$vwebname = $vwebtype + "web"
$tempvwebnum=$vwebnum -csplit '\s'
Foreach ($num in $tempvwebnum)
{
  [int]$changetointnewnum = $num
  $newnum = $changetointnewnum.ToString("000")
  $newvwebnum += $newnum
}


$vwebs = $newvwebnum | ForEach-Object {"v1-prod-$vwebname" + $_}
write-host "Recycling $recycletype application pools"
foreach ($vweb in $vwebs)
{
  #Write-Host $vweb
  
  $s = New-PSSession -ComputerName $vweb

  Invoke-Command -Session $s -script {
    Import-Module WebAdministration
    Write-Host "Recycling All App Pools for $Args"
    Get-ChildItem -Path IIS:\AppPools | Where-Object {$_.name -cmatch '#\d$'} | Restart-WebAppPool
  } -Args $vweb
  Remove-PSSession -ComputerName $vweb
}

Write-Host "Script Completed"

<#
$vweb = "v1-prod-hweb015"

$s = New-PSSession -ComputerName $vweb

Invoke-Command -Session $s -script {
  Import-Module WebAdministration
  Write-Host "Recycling All App Pools for $Args"
  Get-ChildItem -Path IIS:\AppPools | Where-Object {$_.name -cmatch '#\d$'} | Restart-WebAppPool

} -Args $vweb

# Get-ChildItem -Path IIS:\AppPools | Where-Object {$_.name -cmatch '#\d$'} | Restart-WebAppPool

Remove-PSSession -ComputerName $vweb #>