param([string]$VDCvweb, [string]$stopodidlist, [string] $passfiledate ,[string] $movegroup)

<#
Created by: Bob Requa
Version: 1.0
Created: 12/25/2017
Last Updated: 
Comment:  Called by AutoStopVDCSitesMigratedtoGCP.ps1 to stop sites on a vWeb.
Changed: 
#>

if(-not($VDCvweb)) {Throw "You must supply a value for -VDCvweb"}
if(-not($stopodidlist)) {Throw "You must supply a value for -vin"}
if(-not($movegroup)) {Throw "You must supply a value for -movegroup"}
if(-not($passfiledate))
{
  $passfiledate = Get-Date -Format yyyyMMdd
}

$odids = $stopodidlist -split " "
#$outputfilename = "C:\Scripts\Noctool\PowerShellScripts\Stopsites\test-$VDCvweb.txt"
#Add-Content $outputfilename "$VDCvweb,$odids,$passfiledate,$movegroup"

$s = New-PSSession -ComputerName $VDCvweb
Invoke-Command -Session $s -script {
  $checklogpath = Test-Path "c:\temp\"
  if($checklogpath -ne "True")
  {
    New-Item "c:\temp" -type directory
  }
  $vwebname = $env:computername

  foreach ($vin in $Args[0])
  {
    $newvin = "v" + $vin
    $Checksite = Get-Website $newvin
    $sitestatus = Get-Website $newvin | Select-Object -ExpandProperty State
    Write-Host "VDC Server: $vwebname Vin:$newvin Stopping IIS." -BackgroundColor White -ForegroundColor Black

    if (-not($Checksite))
    {
      Write-Warning ("$newvin,$vwebname,does not exist,$newvin on $vwebname does not exist!.")
      Add-Content "c:\temp\StopVDCSitesMigrated_$($Args[2])_$($Args[1]).txt" "$newvin,$vwebname,N/A,does not exist"
    }  else {
      if($sitestatus -eq "Started")
      {
      $runsitestop = "True"
        $x = 1
        Do {
          Write-Host "Attempt $x of 3 to Stop Website $newvin on $vwebname"
          Stop-Website $newvin
          $sitestatus = Get-Website $newvin | Select-Object -ExpandProperty State
          if($sitestatus -eq "Stopped")
          {
            $runsitestop = "False"
          }
          $x++
        } while (($runsitestop -eq "True" -or $x -eq 3))
        if($runsitestop -eq "False")
        {
          Write-Host "$newvin,$vwebname,$sitestatus,Completed website stop for $newvin on $vwebname"
          Add-Content "c:\temp\StopVDCSitesMigrated_$($Args[2])_$($Args[1]).txt" "$newvin,$vwebname,$sitestatus,stopped in IIS"
        } elseif ($x = 2) {
          Write-Host "$newvin,$vwebname,$sitestatus,Failed to stop website $newvin on $vwebname in three attempts."
          Add-Content "c:\temp\StopVDCSitesMigrated_$($Args[2])_$($Args[1]).txt" "$newvin,$vwebname,$sitestatus,Failed to stop website in IIS after three attempts"
        }
      } elseif ($sitestatus -eq "Stopped") {
        Write-Host "$newvin,$vwebname,$sitestatus,Site $newvin on $vwebname already stopped in IIS"
        Add-Content "c:\temp\StopVDCSitesMigrated_$($Args[2])_$($Args[1]).txt" "$newvin,$vwebname,$sitestatus,already stopped in IIS"
      }
    }
  }
} -Args ($odids, $passfiledate, $movegroup)

Remove-PSSession -ComputerName $VDCvweb
