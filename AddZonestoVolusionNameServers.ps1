param([string]$zonelisttype, [string]$getzones, [string]$inputfile, [string]$inputpath, [string]$zonefilepath, [string]$ns, [string]$override)
<#
Created by: Bob Requa
Version: 1.0
Created: 05/24/2017
Last Updated: 
Comment:  Get zone files from ns4 and strips out TTL, SOA, and NS records
Changed: 
#>

$ScriptStartTime=Get-Date
$filedate=Get-Date -Format yyyyMMdd

#This needs to be set for the urlencode to work
Add-Type -AssemblyName System.Web

$Logpath="C:\Scripts\Noctool\PowerShellScripts\SimpleDNSFiles\addzones\logs\"
$logfilename="Addzoneslog_$filedate.txt"
$logfilepath=$logpath + $logfilename

$checklogfilepath=Test-Path $logfilepath
if($checklogfilepath -ne "True")
{
  Add-Content $logfilepath "date,zone,status,status description,sourcens,destinationns,zonelisttype,getzones,inputfile,inputpath,zonefilepath"
}


$defaultzonefilepathused="False"
$defaultnsused="False"
$defaultinputfileused="False"
$defaultinputpathused="False"
#Check overide parameter
if(-not($override))
{
  $override="False"
} elseif (($override -ne "True") -and ($override -ne "False")) {
  Write-Error "Line:37: Override will deafult to False if not used, otherwise parmeter must be set to True, or False.  Exiting Script!"
  exit
} elseif ($override -eq "True") {
  Write-Warning "Line:40: Override parameter has been enabled.  Any zone file that exists on the destination name server will be overwritten with the new source zone!"
}

#Check zonelisttype parameter
if ((-not($zonelisttype)) -and (-not[string]::IsNullOrEmpty($zonefilepath))) {
  Write-Warning "Line:45: -zonelisttype not set and -zonefilepath is set.  Default zonelisttype to fromdir."
  $zonelisttype="fromdir"
} elseif(-not($zonelisttype)) {
  Write-Warning "Line:48: -zonelisttype not set.  Default set to fromlist"
  $zonelisttype="fromlist"
} elseif (($zonelisttype -ne "fromlist") -and ($zonelisttype -ne "fromdir")) {
  Write-Error "Line:51: zonelisttype set to $zonelisttype.  Invalid option!  Must be set to fromlist, or fromdir.  Exiting script"
  exit
}

if($zonelisttype -eq "fromdir")
{
  if(-not($zonefilepath))
  {
    if(($ns -eq "ns3") -or ($ns -eq "ns4"))
    {
      Write-Warning "Line:61: Using default zone file path:  C:\Scripts\Noctool\PowerShellScripts\SimpleDNSFiles\addzones\addto$ns\"
      $zonefilepath="C:\Scripts\Noctool\PowerShellScripts\SimpleDNSFiles\addzones\addto$ns\"
      $destns=$ns
      $defaultzonefilepathused="True"
    } elseif (-not($ns)) {
      Write-Warning "Line:66: Using default -ns ns4 destination server and default zonefilepath: C:\Scripts\Noctool\PowerShellScripts\SimpleDNSFiles\addzones\addtons4\"
      $zonefilepath="C:\Scripts\Noctool\PowerShellScripts\SimpleDNSFiles\addzones\addtons4\"
      $destns="ns4"
      $defaultnsused="True"
    } else {
      Write-Error "Line:71: -ns set to something other than ns4, or ns3.  Exiting script!"
      exit
    }
  } else {
    if($zonefilepath -cnotmatch '\\$')
    {
      $zonefilepath="$zonefilepath\"
    }
    if(($ns -eq "ns3") -or ($ns -eq "ns4"))
    {
      $destns=$ns
    } elseif (-not($ns)) {
      Write-Error "Line:83: -zonefilepath set by user and -ns parameter not set.  Must set the destination server to ns4, or ns3.   Exiting script!"
      exit 
    } else {
      Write-Error "Line:86: Invalid value for -ns.  -zonefilepath set by user and -ns parameter must be set to ns4, or ns3.  Exiting script!"
      exit
    }
  }
  if(-not($getzones))
  {
    Write-Warning "Line:92: -getzones not set.  Default to fromfile."
    $getzones="fromfile"
  } elseif ($getzones -ne "fromfile") {
    Write-Error "Line:95: Invalid value for -getzones set to $getzones.  Must be set to fromfile only when -zonelisttype is set to fromdir.  Exiting script!"
    exit
  }
} elseif ($zonelisttype -eq "fromlist") {
  if(-not($getzones))
  {
    Write-Warning "Line:101: -getzones not set.  Default set to fromdns"
    $getzones="fromdns"
  } elseif (($getzones -ne "fromdns") -and ($getzones -ne "fromfile")) {
    Write-Error "Line:104: Invalid value for -getzones set to $getzones.  Must be set to fromfile or fromdns.  Exiting script!"
    exit 
  }
  if(-not($inputfile))
  {
    Write-Warning "Line:109: -zonelisttype set to fromlist.  -inputfile not set.  Default set to inputfile default_addzonelist.txt."
    $inputfile="default_addzonelist.txt"
    $defaultinputfileused="True"
  }
  if(-not($inputpath))
  {
    Write-Warning "Line:115: -zonelisttype set to fromlist.  -inputpath not set.  Default set to input path C:\Scripts\Noctool\PowerShellScripts\SimpleDNSFiles\addzones\"
    $inputpath="C:\Scripts\Noctool\PowerShellScripts\SimpleDNSFiles\addzones\"
    $defaultinputpathused="True"
  }
  if($getzones -eq "fromfile")
  {
    if(-not($zonefilepath))
    {
      if(($ns -eq "ns3") -or ($ns -eq "ns4"))
      {
        Write-Warning "Line:125: Using default zone file path:  C:\Scripts\Noctool\PowerShellScripts\SimpleDNSFiles\addzones\addto$ns\"
        $zonefilepath="C:\Scripts\Noctool\PowerShellScripts\SimpleDNSFiles\addzones\addto$ns\"
        $destns=$ns
        $defaultzonefilepathused="True"
      } elseif (-not($ns)) {
        Write-Warning "Line:130: -zonelisttype set to fromlist.  -ns and -zonefilepath not set. Default to destination nameserver ns4 and default to zonefilepath: C:\Scripts\Noctool\PowerShellScripts\SimpleDNSFiles\addzones\addtons4\"
        $zonefilepath="C:\Scripts\Noctool\PowerShellScripts\SimpleDNSFiles\addzones\addtons4\"
        $destns="ns4"
        $defaultnsused="True"
      } else {
        Write-Error "Line:135: -ns set to something other than ns4, or ns3.  Exiting script!"
        exit
      }
    } else {
      if($zonefilepath -cnotmatch '\\$')
      {
        $zonefilepath="$zonefilepath\"
      }
      if(($ns -eq "ns3") -or ($ns -eq "ns4"))
      {
        $destns=$ns
      } elseif (-not($ns)) {
        Write-Error "Line:147: -ns parameter not set.  Must set the destination sever to ns4, or ns3.   Exiting script!"
        exit 
      } else {
        Write-Error "Line:150: -ns parameter must be set to ns4, or ns3.  Exiting script!"
        exit
      }
    }
  } elseif ($getzones -eq "fromdns") {
    if($ns -eq "ns3")
    {
      $destns=$ns
      $sourcens="ns4"
    } elseif ($ns -eq "ns4") {
      $destns=$ns
      $sourcens="ns3"
    } elseif (-not($ns)) {
      Write-Warning "Line:163: -ns not set.  Default to ns4."
      $destns="ns4"
      $sourcens="ns3"
    } else {
      Write-Error "Line:167: -ns parameter not set.  Must set the destination name server to ns4, or ns3.   Exiting script!"
      exit
    }
  }
} #End of fromlist zonelisttype if statement

#Verify inputfile, inputpath, and zonefilepath
if($zonelisttype -eq "fromlist")
{
  #verify inputfile and inputpath
  if($inputpath -cnotmatch '\\$')
    {
      $inputpath="$inputpath\"
    }
  $checkinputpath=Test-Path $inputpath
  if($checkinputpath -ne "True")
  {
    if ($defaultinputpathused -eq "True")
    {
      Write-Error "Line:186: Default path $inputpath does not exist.  Exiting script!"
      exit
    } else {
      Write-Error "Line:189: Input path $inputpath does not exist.  Exiting script!"
      exit
    }
  } else {
    if($inputfile -cnotmatch '\.txt')
    {
      $inputfile="$inputfile.txt"
    }
    $tempcheckinputfilepath=$inputpath + $inputfile
    $checkinputfile=Test-Path $tempcheckinputfilepath
    if($checkinputfile -ne "True")
    {
      if($defaultinputfileused -eq "True")
      {
        Write-Error "Line:203: Default inputfile $tempcheckinputfilepath does not exist.  Exiting script!"
        exit
      } else {
        Write-Error "Line:206: Inputfile $tempcheckinputfilepath does not exist.  Exiting script!"
        exit
      }
    }
  }
}

If($getzones -eq "fromfile")
{
  #verify zonefile path
  $checkzonefilepath=Test-Path $zonefilepath
  if($checkzonefilepath -ne "True")
  {
    if($defaultzonefilepathused -eq "True")
    {
      Write-Error "Line:221: Default zonefile path $zonefilepath does not exist.  Exiting script!"
    } else {
      Write-Error "Line:223: Zonefile path $zonefilepath does not exist.  Exiting script!"
    }
    exit
  }
  
}

#Set nameserver IP address
$ns3IP="10.10.0.99"
$ns4IP="10.10.248.213"

if(-not[string]::IsNullOrEmpty($destns))
{
  if($destns -eq "ns3")
  {
    $destnsIP=$ns3IP
  } elseif ($destns -eq "ns4") {
    $destnsIP=$ns4IP
  }
}

if(-not[string]::IsNullOrEmpty($sourcens))
{
  if($sourcens -eq "ns3")
  {
    $sourcensIP=$ns3IP
  } elseif ($sourcens -eq "ns4") {
    $sourcensIP=$ns4IP
  }
}

#Get zone list and add zone data to destination nameserver
if($zonelisttype -eq "fromlist")
{
  $inputfilepath=$inputpath + $inputfile
  $zonelist=Get-Content $inputfilepath
  $zonelistcount=$zonelist.Count
} elseif ($zonelisttype -eq "fromdir") {
  $zonelist= Get-ChildItem -Path $zonefilepath
  $zonelistcount=$zonelist.Count
}

$errorcount=0 #Initialize error counter.
$errorzonefilemissingcount=0 #Initialize missing zone file counter.
$errroraddingzonecount=0 #Initialize error adding zone counter.
$errorzonenotexistonnameserver=0 #Initialize error zone doesn't exist on source name server.
$errordestcount=0 #Initialize error destination zone file already exists, not added.
$erroroverrideaddcount=0 #Initialize override error add zone that already exists on destination server.
$addcount=0 #Initialize zones added to nameserver counter.
$c1=0 #Initialize progress bar counter.

if(($zonelisttype -eq "fromdir") -or (($zonelisttype -eq "fromlist") -and ($getzones -eq "fromfile")))
{
  If($zonelisttype -eq "fromdir")
  {
    $inputfile="N/A"
    $inputpath="N/A"
  }
  foreach ($zone in $zonelist)
  {
    $c1++
    Write-Progress -id 0 -Activity "Adding Zones" -Status "Processing $($c1) of $($zonelistcount)" -currentOperation $zone -PercentComplete (($c1/$zonelistcount)*100)
    $addcounter="True"
    $zoneondestination="True" #Set to True if not found on name server will set to False
    if($zonelisttype -eq "fromlist")
    {
      $zonedatafile="$zone.txt"
      $destzonecheck=$zone
      $zonename=$zone
    } else {
      $zonedatafile=$zone
      $destzonecheck=$zone -creplace '\.txt',''
      $zonename=$destzonecheck
    }
    $zonedatafilename=$zonefilepath + $zonedatafile
    $checkzonedatapath=Test-Path $zonedatafilename
    Write-Host "$zonename" #Display zone to be added to screen.
    try {$zonedestcheckdata=Invoke-WebRequest -Uri ("http://$destnsIP`:8053/getzone?zone=$destzonecheck") -ErrorAction Continue}
    catch
    {
        $zoneondestination="False"
    }
    if(($zoneondestination -eq "False") -or (($zoneondestination -eq "True") -and ($override -eq "True")))
    {
      if($checkzonedatapath -ne "True")
      {
        Write-Warning "Line:312: $zone data file does not exist on $zonedatafilename.  Zone not added!  Continuing script."
        Add-Content $logfilepath "$ScriptStartTime,$zone,NOTADDED,zone data file does not exist,$sourcens,$destns,$zonelisttype,$getzones,$inputfile,$inputpath,$zonefilepath"
        $addcounter="False"
        $errorzonefilemissingcount++
        $errorcount++
      } else {
        $zonedata=Get-Content $zonedatafilename -raw
        $zonedata=[System.Web.HttpUtility]::URLEncode($zonedata)
        $zonename=[System.Web.HttpUtility]::URLEncode($zonename)
        if($destns -eq "ns3")
        {
          $addurl="http://$destnsIP`:8053/updatezone?zone=$zonename&masterip=69.49.191.247&data=$zonedata"
        } elseif ($destns -eq "ns4") {
          $addurl="http://$destnsIP`:8053/updatezone?zone=$zonename&data=$zonedata"
        }
        try {$zoneadd=Invoke-WebRequest -Uri ("$addurl") -ErrorAction Continue}
        catch
        {
          Write-Warning "Line:330: Unknown error adding zone $zone to $destns!  Continuing script."
          Add-Content $logfilepath "$ScriptStartTime,$zone,NOTADDED,Error adding zone to destination,$sourcens,$destns,$zonelisttype,$getzones,$inputfile,$inputpath,$zonefilepath"
          $addcounter="False"
          $errroraddingzonecount++
          $errorcount++
        }
      }
    } else {
      Write-Warning "Line:338: $zone already exists on destination server!  Not adding zone to destination name server $destns"
      Add-Content $logfilepath "$ScriptStartTime,$zone,NOTADDED_DESTEXISTS,not added - zone file exists on $destns,$sourcens,$destns,$zonelisttype,$getzones,$inputfile,$inputpath,$zonefilepath"
      $addcounter="False"
      $errorcount++
      $errordestcount++
    }
    If(($addcounter -eq "True") -and ($override -eq "True") -and ($zoneondestination -eq "True"))
      {
        Add-Content $logfilepath "$ScriptStartTime,$zone,ADDED_OVERRIDE,zone override added to $destns,$sourcens,$destns,$zonelisttype,$getzones,$inputfile,$inputpath,$zonefilepath"
        $addcount++
        $erroroverrideaddcount++
      } elseif(($addcounter -eq "True") -and ($zoneondestination -eq "False")) {
        Add-Content $logfilepath "$ScriptStartTime,$zone,ADDED,zone added to $destns,$sourcens,$destns,$zonelisttype,$getzones,$inputfile,$inputpath,$zonefilepath"
        $addcount++
      }
  }  
} elseif (($zonelisttype -eq "fromlist") -and ($getzones -eq "fromdns")) {
  foreach ($zone in $zonelist)
  {
    $c1++
    Write-Progress -id 0 -Activity "Adding Zones" -Status "Processing $($c1) of $($zonelistcount)" -currentOperation $zone -PercentComplete (($c1/$zonelistcount)*100)
    Write-Host $zone
    $zonefilepath="N/A"
    $zoneondestination="True"
    $addzone="True"
    $addcounter="True"

    try {$zonedestcheckdata=Invoke-WebRequest -Uri ("http://$destnsIP`:8053/getzone?zone=$zone") -ErrorAction Continue}
    catch
    {
      $zoneondestination="False"
    }
    if(($zoneondestination -eq "False") -or (($zoneondestination -eq "True") -and ($override -eq "True")))
    {
      try {$zonedata=Invoke-WebRequest -Uri ("http://$sourcensIP`:8053/getzone?zone=$zone") -ErrorAction Continue} # CURL to SimpleDNS to retrieve DNS records from a Zone.
      catch
      {
        Write-Warning "Line:377: Zone does not exist in source name server $sourcens.  Script will not add zone to destination name server $destns.  Script continuing"
        Add-Content $logfilepath "$ScriptStartTime,$zone,NOTADDED,zone data does not exist in source name server,$sourcens,$destns,$zonelisttype,$getzones,$inputfile,$inputpath,$zonefilepath"
        $addcounter="False"
        $errorzonenotexistonnameserver++
        $errorcount++
        $addzone="False"
      }
      
      if($addzone -eq "True")
      {
        $zonedata=[System.Web.HttpUtility]::URLEncode($zonedata)
        $zone=[System.Web.HttpUtility]::URLEncode($zone)
        if($destns -eq "ns3")
        {
          $addurl="http://$destnsIP`:8053/updatezone?zone=$zone&masterip=69.49.191.247&data=$zonedata"
        } elseif ($destns -eq "ns4") {
          $addurl="http://$destnsIP`:8053/updatezone?zone=$zone&data=$zonedata"
        }
        try {$zoneadd=Invoke-WebRequest -Uri ("$addurl") -ErrorAction Continue}
        catch
        {
          Write-Warning "Line:397: Error adding zone $zone!  Continuing script."
          Add-Content $logfilepath "$ScriptStartTime,$zone,NOTADDED,Error adding zone to destination,$sourcens,$destns,$zonelisttype,$getzones,$inputfile,$inputpath,$zonefilepath"
          $addcounter="False"
          $errroraddingzonecount++
          $errorcount++
        }
      }
      If(($addcounter -eq "True") -and ($override -eq "True") -and ($zoneondestination -eq "True"))
      {
        Add-Content $logfilepath "$ScriptStartTime,$zone,ADDED_OVERRIDE,zone override added to $destns,$sourcens,$destns,$zonelisttype,$getzones,$inputfile,$inputpath,$zonefilepath"
        $addcount++
        $erroroverrideaddcount++
      } elseif(($addcounter -eq "True") -and ($zoneondestination -eq "False")) {
        Add-Content $logfilepath "$ScriptStartTime,$zone,ADDED,zone added to $destns,$sourcens,$destns,$zonelisttype,$getzones,$inputfile,$inputpath,$zonefilepath"
        $addcount++
      }
    } else {
      Write-Warning "Line:414: $zone already exists on destination server!  Not adding zone to destination name server $destns"
      Add-Content $logfilepath "$ScriptStartTime,$zone,NOTADDED_DESTEXISTS,not added - zone file exists on $destns,$sourcens,$destns,$zonelisttype,$getzones,$inputfile,$inputpath,$zonefilepath"
      $errorcount++
      $errordestcount++
    }
  }
}

$ScriptEndTime=Get-Date
$ScriptRunTime=New-TimeSpan $ScriptStartTime $ScriptEndTime
Write-Host "------------------Script Summary------------------"
Write-Host "$zonelistcount`:Number of zones to be processed"
Write-Host "$addcount`:Number of zones added"
if($override -eq "True") {Write-Host "$erroroverrideaddcount`:Over zone added"}
Write-Host "$errorzonefilemissingcount`:zone data does not exist"
Write-Host "$errroraddingzonecount`:Error adding zone to destination"
Write-Host "$errorzonenotexistonnameserver`:zone data does not exist in source name server $sourcens"
Write-Host "$errordestcount`:Zone already exists on destination name server $destns, not added"
Write-Host "$errorcount`:Total errors"
$totaladded=$addcount + $erroroverrideaddcount + $errorcount
$totalonlyadd=$addcount + $erroroverrideaddcount
if($totaladded -ne $zonelistcount)
{
  Write-Warning "$totaladded <> `:Zones added ($totalonlyadd) + Total Errors($errorcount) does not equal number of zones processed ($zonelistcount)!"
} else {
  Write-Host -ForegroundColor Green "Zones added + Total Errors equals number of zones processed!"
}
Write-Host "$ScriptStartTime`:Script Start time"
Write-Host "$ScriptEndTime`:Script End time"
Write-Host "$ScriptRunTime`:Script Run time"
Write-Host "--------------Detailed Script Completed Time--------------"
New-TimeSpan $ScriptStartTime $ScriptEndTime
Write-Host "End of Script"