param([string]$vwebtoclean)

<#
Created by: Bob Requa
Version: 1.2.1
Created: 12/29/2017
Last Updated: 
Comment:  This script is used for NOC tools and can also be used as a standalone script.  This script deletes XML files in the Generic Folder on L Drive.
Changed: Had to remove hh from filedate variable so it will put the data into correct log file, corrected $logdate formate, and moved logging to powershell script.
#>
$trackerpath = "C:\Scripts\Noctool\ldrivecleanuptracker\"
$useradd = $env:UserName
$toolchecklist = Get-ChildItem -Path $trackerpath
$filedate = Get-Date -Format yyyyMMdd
#$logdate=Get-Date -UFormat "%a %m/%d/%Y %T"
$logdate = Get-Date -Format "ddd MM/dd/yyyy HH:mm:ss.ff"
$logpath = "C:\Scripts\Noctool\Log\"
$logfile = "nocapptool_$filedate.log"
$logfilename = $logpath + $logfile

$trackerfile = "$vwebtoclean.txt"
$checkfilename = $trackerpath + $trackerfile

$checktrackerfile = Test-Path $checkfilename

if($checktrackerfile -eq "True")
{
  $trackerdata = Get-Content $checkfilename
  $rawdata = $trackerdata -csplit ','
  $userrunning = $rawdata[0]
  $action = $rawdata[1]
  Write-Warning "User $($userrunning) is running $($action) on $vwebtoclean.  Exiting script!"
  Add-Content $logfilename "$logdate $useradd $vwebtoclean Error-PowerLDriveGenericXMLDelete-AllSites-Aborted_$userrunning`_running_$action"
  exit
} else {
  Add-Content $checkfilename "$useradd,AutoPowerLDriveGenericXMLDelete-AllSites"
}

if(-not($vwebtoclean)) {Throw "You must supply a value for -vweb"}

Write-Host "Server: $vwebtoclean begin deleteing L Drive Generic Folder XML files." -BackgroundColor White -ForegroundColor Black

$s = New-PSSession -ComputerName $vwebtoclean
$c1 = 0

Invoke-Command -Session $s -script {
 Get-ChildItem -Path L:\ |
  Where-Object {$_.Name -match '^v\d+$'} |
  ForEach-Object{
   $cutofftime = ((Get-Date).AddDays(-200))
   Get-ChildItem -Path L:\$_ -file | Where-Object{
    ($_.LastWriteTime -le $cutofftime -and $_.name -match "txt$") -or ($_.LastWriteTime -le $cutofftime -and $_.name -match "FileUpload.Log$")
    } | Remove-Item -Force
   Write-Host "$_ Processed - Cutofftime: $cutofftime"
  }

 $SiteFolders = Get-ChildItem -Path L:\  | Where-Object {$_.Name -match '^v\d+$'}

 foreach ($SiteFolder in $SiteFolders) {
  $c1++
  Write-Progress -id 0 -Activity "Checking VIN Folders on $Args" -Status "Processing $($c1) of $($SiteFolders.Count)" -currentOperation $SiteFolder -PercentComplete (($c1/$SiteFolders.Count)*100)
  $CheckFolder = "L:\$SiteFolder\dataport\dl\Generic\"
  if(Test-Path $CheckFolder.trim()) {
   Write-Host "$Args - $SiteFolder - Started delete of XML files: processing..."
   Get-ChildItem -Path $CheckFolder -ErrorAction SilentlyContinue | Where-Object {$_.Name -notmatch 'googlebase.xml' -and $_.Name -match 'xml$'} | Remove-Item -Force
   Write-Host "$Args - $SiteFolder - Completed processing $CheckFolder"
   } else {Write-Host "$Args - $SiteFolder - Completed processing: $CheckFolder does not exist"}
 }
} -Args $vwebtoclean

if($checktrackerfile -ne "True")
{
  Add-Content $logfilename "$logdate $useradd $vwebtoclean PowerLDriveGenericXMLDelete-AllSites"
}

Remove-PSSession -ComputerName $vwebtoclean
Remove-Item $checkfilename