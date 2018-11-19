param([string]$ns, [string]$nameserverset, [string]$domain, [string]$domainlist, [string]$update, [string]$getzonefrom)
<#
Created by: Bob Requa
Version: 1.1
Created: 09/14/2017
Last Updated: 
Comment:  Upload zone files from file to GCP DNS
Changed: 
#>

$ScriptStartTime=Get-Date
$filedate=Get-Date -Format yyyyMMdd
$transfiledate=Get-Date -Format yyyyMMddhhmmss

$tempzonefilepath="C:\Scripts\Noctool\PowerShellScripts\SimpleDNSFiles\addzonestoGCP\tempZoneFiles\"

$importlogpath="C:\Scripts\Noctool\PowerShellScripts\SimpleDNSFiles\addzonestoGCP\logs\"
$importlogfile="add_GCPDNSzonelog_$filedate.txt"
$importerrorlogpath="C:\Scripts\Noctool\PowerShellScripts\SimpleDNSFiles\addzonestoGCP\logs\"
$importerrorlogfile="add_GCPDNSZoneErrorlog_$filedate.txt"

$zonelistfilepath="C:\Scripts\Noctool\PowerShellScripts\SimpleDNSFiles\addzonestoGCP"
$zonelistfile="zonelist.txt"
$zonelistfilename=$zonelistfilepath + $zonelistfile

$zonecreatefile="create_zonelog_$transfiledate.txt"
$zonecreategoodfile="create_sucessfullog_$filedate.txt"
$zonecreatelogfilename=$importlogpath + $zonecreatefile
$zonecreategoodlogfilename=$importlogpath + $zonecreategoodfile

$mainlogfile="Main_AddNewGCPDNZonesLog_$filedate.txt"
$mainlogfilename=$importlogpath + $mainlogfile

$checkmainlogfile=Test-Path $mainlogfilename
if($checkmainlogfile -ne "True")
{
  Add-Content $mainlogfilename "ScriptStartTime,ScriptAction,AddedBy,googlezone,domainname,Error"
}

#Zone create log file
$summaryerrorzonecreatelogfile="error_createzone_$filedate.txt"
$summaryerrorzonecreatelogfilename=$importlogpath + $summaryerrorzonecreatelogfile

# Set path for zones files to be moved to if the zone create fails.
$error_zonecreatepath="C:\Scripts\Noctool\PowerShellScripts\SimpleDNSFiles\addzonestoGCP\errorZoneCreateZoneFiles\"

if($getzonefrom -eq "simpledns")
{
  if(-not($ns))
  {
   Write-Warning "-ns not set while -getzonefrom is set to simpledns.  Defaulting to ns4."
   $ns="ns4"
  } elseif ($ns -cnotmatch "^ns[3-4]$") {
    Write-Error "-ns must be set to ns3, or ns4. Value set to $ns.  Exiting script!"
    exit
  }
} elseif ($getzonefrom -eq "file") {
  if(-not[string]::IsNullOrEmpty($ns))
  {
    Write-Warning "-getzonefrom is set to file.  -ns is set to $ns and will be ignored."
  }
}

if(-not($nameserverset))
{
  Write-Error "-nameserverset must have a value.  Must be set to c, or d.  Exiting script!"
  exit
} else {
  if(($nameserverset -ne "c") -and ($nameserverset -ne "d"))
  {
    Write-Error "-nameserverset must be set to c, or d.  Value is set to $nameserverset.  Exiting script!"
    exit
  } elseif($nameserverset -eq "c") {
    $googleNS1 = "ns-cloud-c1.googledomains.com."
    $googleNS2 = "ns-cloud-c2.googledomains.com."
    $googleNS3 = "ns-cloud-c3.googledomains.com."
    $googleNS4 = "ns-cloud-c4.googledomains.com."
    $volusionNS1 = "ns8.volusion.com."
    $volusionNS2 = "ns7.volusion.com."
    $volusionNS3 = "ns6.volusion.com."
    $volusionNS4 = "ns5.volusion.com."
  } elseif($nameserverset -eq "d") {
    $googleNS1 = "ns-cloud-d1.googledomains.com."
    $googleNS2 = "ns-cloud-d2.googledomains.com."
    $googleNS3 = "ns-cloud-d3.googledomains.com."
    $googleNS4 = "ns-cloud-d4.googledomains.com."
    $volusionNS1 = "ns4.volusion.com."
    $volusionNS2 = "ns3.volusion.com."
    $volusionNS3 = "ns2.volusion.com."
    $volusionNS4 = "ns1.volusion.com."
  }
}


If((-not[string]::IsNullOrEmpty($domain)) -and (-not[string]::IsNullOrEmpty($domainlist)))
{
  Write-Error "-domain and -domainlist parameters are set.  Only use one, or the other, not both.  Exiting script!"
  exit
} elseif (([string]::IsNullOrEmpty($domain)) -and ([string]::IsNullOrEmpty($domainlist))) {
  Write-Warning "-domain and -domainlist parameters not set.  Defaulting to -domainlist fromfile"
  $domainlist="fromfile"
} elseif (([string]::IsNullOrEmpty($domain)) -and (-not[string]::IsNullOrEmpty($domainlist))) {
  if(($domainlist -ne "fromfile") -and ($domainlist -ne "fromdir"))
  {
    Write-Error "-domainlist must be set to fromfile or fromdir.  Value set to $domainlist.  Exiting script!"
    exit
  } else {
    if(($domainlist -eq "fromdir") -and ($getzonefrom -ne "file"))
    {
      Write-Error "-domainlist is set to fromdir, -getzonefrom must be set to file.  Exiting script"
      exit
    } elseif (($domainlist -eq "fromdir") -and (-not($getzonefrom))) {
      Write-Warning "-domainlist set to $domainlist and -getzonefrom not set.  Setting -getzonefrom to file."
      $getzonefrom="file"
    } elseif (($domainlist -eq "fromfile") -and (-not($getzonefrom))) {
      Write-Warning "-domainlist set to $domainlist and -getzonefrom not set.  Setting -getzonefrom to simpledns."
      $getzonefrom="simpledns"
    }
  }
}

if(-not($update))
{
  Write-Warning "-update not set.  Defaulting to new."
  $update="new"
} elseif (($update -ne "replace") -and ($update -ne "new")) {
  Write-Error "-update must be set to replace, or new.  Value set to $update.  Exiting script!"
  exit
}

if(-not($getzonefrom))
{
  Write-Warning "-getzonefrom not set.  Defaulting to simpledns"
  $getzonefrom="simpledns"
  if(-not($ns))
  {
    Write-Warning " -getzonefrom file set to simpledns and -ns not set.  Deafulting to ns4"
    $ns = "ns4"
  }
} elseif (($getzonefrom -ne "simpledns") -and ($getzonefrom -ne "file")) {
  Write-Error "-getzonefrom must be set to simpledns, or file.  Exiting script!"
  exit
}

if($getzonefrom -eq "file")
{
  $DNSZonefilepath="C:\Scripts\Noctool\PowerShellScripts\SimpleDNSFiles\addzonestoGCP\addZoneFiles\"
} else {
  $DNSZonefilepath=$tempzonefilepath
}


# Used to pass a list of domains to simplednsextract.ps1 script.
if($domainlist -eq "fromfile")
{
  $tempzonelist = Get-Content -Path $zonelistfilename
} elseif ($domainlist -eq "fromdir") {
  $tempzonelist = Get-ChildItem -Path $DNSZonefilepath
} else {
  $tempzonelist=$domain -csplit '\s'
}

# EXPORT ZONE FILES FROM SIMPLEDNS.
if($getzonefrom -eq "simpledns")
{
  Write-Host "Exporting zones files from SimpleDNS"
  $zoneseperator=","
  $simplednszonelist=[string]::Join($zoneseperator,$tempzonelist)
  $getzonecommand="C:\Users\xadmbrequa\Desktop\PowerShellScripts\Working\simplednsextract.ps1 -ns $ns -getfileout multiple -domainlist $simplednszonelist -updategoogledns True -onescript True -mainlog $mainlogfilename"
  Write-Host "----------- Start Export zones from SimpleDNS -----------"
  Invoke-Expression $getzonecommand #Getting Zone files
  Write-Host "----------- End Export zones from SimpleDNS -----------"
} elseif ($getzonefrom -eq "file") {
  Write-Host "Zones not exported from simpledns.  Zones will be used from $DNSZonefilepath"
}

$useradd = $env:UserName

# CREATE A NEW ZONE IN GOOGLE CLOUD DNS
Write-Host "Creating zone(s) in Google Cloud DNS"

if($getzonefrom -eq "simpledns")
{
  $ZoneFiles = Get-ChildItem -Path $DNSZonefilepath
  $googlezonelistdata=@()
} elseif ($getzonefrom -eq "file") {
  $ZoneFiles = $tempzonelist
  $googlezonelistdata=@()
}

# Create a list used for parsing zone create log for zone create errors and moving zone files to errorZoneCreateZoneFiles folder.
foreach ($ZoneFile in $ZoneFiles)
{ 
  $zonename=$zoneFile -replace "\.txt",""
  $dnsname=$zonename
  $regex='\.' #Replace all dots with a dash.

  $tempgooglezone=$zonename -replace $regex,"-"
  $tempgooglezone="v-$tempgooglezone"
  $googlezonelistdata+="$tempgooglezone,$dnsname,$Zonefile"
}

# Log zone create and call python script to create the zones.
Start-Transcript -Path $zonecreatelogfilename -Append
$zonepycreate = Python C:\Scripts\Noctool\PowerShellScripts\SimpleDNSFiles\gcpimport\Python\onescript_multi_createzone.py $nameserverset $useradd $getzonefrom
foreach ($zonepycreateline in $zonepycreate)
{
  Write-Host $zonepycreateline
}
Stop-Transcript
Add-Content $zonecreategoodlogfilename $zonepycreate

# CHECK FOR CREATE ERRORS BY PARSING ZONECREATELOG
Write-Host "Checking for create errors by parsing zone create log"
$zonecreateerrorcount=0
$createzonedata = Get-Content $zonecreatelogfilename
$regexcreateError = '<HttpError'
foreach ($createlogline in $createzonedata)
{
  if($createlogline -cmatch $regexcreateError)
  {
    foreach ($googlezonedata in $googlezonelistdata)
    {
      $tempgooglezonedata=$googlezonedata -csplit ','
      $googlezone=$tempgooglezonedata[0]
      $domainname=$tempgooglezonedata[1]
      $googlezonefilename=$DNSZonefilepath + $tempgooglezonedata[2]

      if($createlogline -cmatch $googlezone)
      {
        Add-Content $summaryerrorzonecreatelogfilename "$googlezone,$createlogline"
        Add-Content $mainlogfilename "$ScriptStartTime,CreateZone,$useradd,$googlezone,$domainname,$createlogline"
        $error_zonecreatefilename = $error_zonecreatepath + $tempgooglezonedata[1]
        $new_error_zonecreatefilename=$error_zonecreatefilename
        $rename_oldzonefile = $tempgooglezonedata[1]
        $z=1
        Do {
          $check_error_zonecreatefilename = Test-Path $new_error_zonecreatefilename
          if($check_error_zonecreatefilename -eq "True")
          {
            Write-Warning "$rename_oldzonefile exists in $error_zonecreatepath.  Renaming old zone file and trying file move again."
            $rename_oldzonefile = $tempgooglezonedata[1] -creplace '\.txt',"_$z.txt"
            $new_error_zonecreatefilename = $error_zonecreatepath + $rename_oldzonefile
            $z++
          }

        } # End of 'Do'
        While ($check_error_zonecreatefilename -eq "True")

        Rename-Item $error_zonecreatefilename $rename_oldzonefile
        Move-Item $googlezonefilename $error_zonecreatepath
        Write-Host "$tempgooglezonedata[1] successfully moved to $error_zonecreatepath."
        $zonecreateerrorcount++
        break
      }
    }
  }
}
Write-Host "There were $zonecreateerrorcount zones that failed to create.  Please review $zonecreatelogfilename."
Write-Host "-----------------------------------------------"

# ADD RECORDS TO NEW ZONES
Write-Host "Adding records to new zones"
$R_recordaddlogfile = "GCPAddRecordSummary_$filedate.txt"
$R_recordaddlogfilename = $importlogpath + $R_recordaddlogfile
$R_Zonefiles = Get-ChildItem -Path $DNSZonefilepath
$R_logfile = "GCPAddRecordlog_$transfiledate.txt"
$R_logfilename = $importlogpath + $R_logfile
$R_zonefilecount=$R_Zonefiles.count
$R_zonesprocessed=0

$checkrecordaddlogfile = Test-Path $R_recordaddlogfilename
if($checkrecordaddlogfile -ne "True")
{
  Add-Content $R_recordaddlogfilename "Added_by,ScriptStartTime,importtime,googlezone,zonename,ZoneFile,zonetobeuploaded"
}

# Log record add to zones into Google Cloud DNS.
Start-Transcript -Path $R_logfilename -Append

foreach ($R_ZoneFile in $R_Zonefiles) { 
 $R_DNSZonefilename=$DNSZonefilepath + $R_Zonefile
 $R_zonename=$R_Zonefile -replace "\.txt",""
 $regex='\.' #Replace all dots with a dash.
 $R_googlezone=$R_zonename -replace $regex,"-"
 $R_googlezone="v-$R_googlezone"

 Write-Host "ImportStarted $R_googlezone,$R_zonename"

 $zonetobeuploaded=get-content $R_DNSZonefilename
 $importtime=Get-Date

 gcloud dns record-sets import $R_DNSZonefilename --zone-file-format -z $R_googlezone
 Add-Content $R_recordaddlogfilename "$useradd,$ScriptStartTime,$importtime,$R_googlezone,$R_zonename,$R_ZoneFile,$zonetobeuploaded"

 Write-Host "ImportCompleted $R_googlezone"
 $zonesprocessed++
 }

Stop-Transcript
Write-Host "------------------------ DNS Record add to Google Cloud DNS Summary ------------------------"
Write-Host "$R_zonefilecount`:Total Zones"
Write-Host "$zonesprocessed`:Total Zones Processed"
Write-Host "DNS Zone File Path:$DNSZonefilepath"
Write-Host "Record Add Summary Log Filename:$R_recordaddlogfilename"
Write-Host "Record Add Full Log Filename:$R_logfilename"
Write-Host "------------------------ End of DNS Record add to Google Cloud DNS Summary ------------------------"

# GET ERROR MESSAGES FOR ADDING RECORDS TO ZONE FILES IN GOOGLE CLOUD DNS
Write-Host "Processing record add log file for errors."

$recordzonedata = Get-Content $R_logfilename

$regexzonename='\S+$'
$regexrecordadderror='ERROR:\s+\(gcloud\.dns\.record-sets\.import\)'
$regexzoneimportcomplete='^ImportCompleted'
$rzonecount=0
$rerrorcount=0
$rgoodcount=0

foreach($rline in $recordzonedata)
{
  $rline=$rline.TrimEnd()
  $radderrorcount=0
  if ($rline -cmatch '^ImportStarted')
  {
    #$zonenamecheck=$rline -cmatch $regexzonename
    #$rzonename=$matches[0] | Out-String
    $rsplitline = $rline.split(' ')
    $rgetzoneinfo = $rsplitline.split(',')
    $rzonename = $rgetzoneinfo[0]
    $rdomainname = $rgetzoneinfo[1]
    #$rzonename=$rzonename.trim()
    $errorfound="false"
    $rzonecount++
    $rerror=@()
  }
  if($rline -cmatch $regexrecordadderror)
  {
    $rerror+=$rline
    $errorfound="True"
  } elseif ($rline -cmatch $regexzoneimportcomplete) {
    if($errorfound -eq "True")
    {
      Add-Content $mainlogfilename "$ScriptStartTime,RecordAdd,$useradd,$rzonename,$rdomainname,$($rerror[-1])"
      $rerrorcount++
    } else {
      $rgoodcount++
    }
  }
}
Write-Host "Completed processing record add log file for errors."
Write-Host "Total Zones Processed: $rzonecount"
Write-Host "Zones with records added successfully: $rgoodcount"
Write-Host "Zones with errors adding records: $rerrorcount"
Write-Host "-----------------------------------------------"

# UPDATE NS AND SOA RECORDS IN GCP ZONES
Write-Host "Updating NS and SOA records."
$U_ZoneFiles = Get-ChildItem -Path $DNSZonefilepath
$U_zonecount = $U_ZoneFiles.count

$SOA_NSChangelogfile = "updategcpsoaandnsrecords_$transfiledate.txt"
$summaryChangelogfile = "summaryupdategcpsoaandnsrecords_$filedate.txt"
$SOA_NS_Changelogfilename = $importlogpath + $SOA_NSChangelogfile
$summaryChangelogfilename = $importlogpath + $summaryChangelogfile

$x=0
Start-Transcript -Path $SOA_NS_Changelogfilename -Append

foreach ($U_ZoneFile in $U_ZoneFiles)
{
  $U_dnsname = $U_ZoneFile -creplace 'txt$',''
  $U_zonename = $U_ZoneFile -creplace '\.txt$',''
  $U_regexdot = '\.'
  $U_googlezone = $U_zonename -creplace $U_regexdot,'-'
  $U_googlezone = "v-$U_googlezone"

  Write-Host "Started $U_googlezone,$U_dnsname"

  gcloud dns record-sets transaction start -z $U_googlezone
  gcloud dns record-sets transaction add --zone $U_googlezone --name $U_dnsname --ttl 900 --type SOA "$volusionNS1 admin.volusion.com. 2 900 600 86400 3600"

  gcloud dns record-sets transaction remove --zone $U_googlezone --name $U_dnsname --ttl 21600 --type NS "$googleNS1" "$googleNS2" "$googleNS3" "$googleNS4"
  gcloud dns record-sets transaction add --zone $U_googlezone --name $U_dnsname --ttl 900 --type NS "$volusionNS1" "$volusionNS2" "$volusionNS3" "$volusionNS4"

  gcloud dns record-sets transaction execute -z $U_googlezone

  gcloud dns record-sets transaction abort -z $U_googlezone

  Write-Host "Completed $U_zonename"
  Add-Content $summaryChangelogfilename "$x,$U_googlezone,$U_dnsname"
  $x++
}

Write-Host "------------------------ Update SOA and NS Record Summary ------------------------"
Write-Host "Log file location: $SOA_NS_Changelogfilename"
Write-Host "Summary Log file location: $summaryChangelogfilename"
Write-Host "Number of google zones: $U_zonecount"
Write-Host "Number of google zones processed: $x"
Write-Host "------------------------ End of Update SOA and NS Record Summary ------------------------"
Stop-Transcript

# PARSE UPDATE SOA AND NS RECORD LOG FILES FOR ERRORS
Write-Host "Parsing Update SOA and NS record log files for errors"

$SOA_NS_Changedata = Get-Content $SOA_NS_Changelogfilename

$regextransabort='ERROR:\s+\(gcloud\.dns\.record-sets\.transaction\.abort\)\s+transaction\s+not\s+found\s+at\s+\[transaction\.yaml\]'
$regexgclouderror='^gcloud\s+:\s+ERROR:'
$regexzoneimportcomplete='^Completed'
$uzonecount=0
$uerrorcount=0
$ugoodcount=0

foreach($uline in $SOA_NS_Changedata)
{
  $uline=$uline.TrimEnd()
  $radderrorcount=0
  if ($uline -cmatch '^Started')
  {
    #$uzonenamecheck=$uline -cmatch $regexzonename
    #$uzonename=$matches[0] | Out-String
    $ulinegetinfo = $uline.split(' ')
    $uzoneanddnsname = $ulinegetinfo[1].split(',')
    $uzonename = $uzoneanddnsname[0]
    $udomainname = $uzoneanddnsname[1]
    #$uzonename=$uzonename.trim()
    $uerrorfound="false"
    $uzonecount++
    $uerror=@()
  }
  if(($uline -cmatch $regexgclouderror) -and ($uline -cnotmatch $regextransabort))
  {
    $uerror+=$uline
    $uerrorfound="True"
  } elseif ($uline -cmatch $regexzoneimportcomplete) {
    if($errorfound -eq "True")
    {
      if($uerror.count -eq 1)
      {
        Add-Content $mainlogfilename "$ScriptStartTime,UpdateSOA_NS,$useradd,$uzonename,$udomainname,CHECK LOG $SOA_NSChangelogfile FOR ERRORS LAST ERROR FOUND WAS: $($uerror[0])"
      } else {
        Add-Content $mainlogfilename "$ScriptStartTime,UpdateSOA_NS,$useradd,$uzonename,$udomainname,CHECK LOG $SOA_NSChangelogfile FOR ERRORS LAST ERROR FOUND WAS: $($uerror[-1])"
      }
      $uerrorcount++
    } else {
      $ugoodcount++
    }
  }
}
Write-Host "Completed processing SOA_NS_Change log file for errors."
Write-Host "Total Zones Processed: $uzonecount"
Write-Host "Zones with SOA and NS records updated successfully: $ugoodcount"
Write-Host "Zones with SOA and NS record update errors: $uerrorcount"
Write-Host "-----------------------------------------------"

# MOVE ALL COMPLETED ZONE FILES TO COMPLETEDZONEFILES FOLDER
Write-Host "Starting move files to completed zone files folder"
$completedzonepath = "C:\Scripts\Noctool\PowerShellScripts\SimpleDNSFiles\addzonestoGCP\completedZoneFiles\"
$allzones="*.txt"
$C_DNSZonefilename = $DNSZonefilepath + $allzones
Move-Item $C_DNSZonefilename $completedzonepath
Write-Host "Completed with adding new zone(s) to Google Cloud DNS.  Files moved to $completedzonepath."
Write-Host "Script completed"

exit

# This was supposed to be for updating records, but may remove this.  Not using currently.
$importscript="C:\Users\xadmbrequa\Desktop\PowerShellScripts\Working\VDC_GCPDNSImport.ps1"

if($update -eq "new")
{
  $importcommandoptions=" -DNSZonefilepath $DNSZonefilepath -importlogpath $importlogpath -importlogfile $importlogfile -importerrorlogpath $importerrorlogpath -importerrorlogfile $importerrorlogfile"
} elseif($update -eq "replace") {
  $importcommandoptions=" -DNSZonefilepath $DNSZonefilepath -importlogpath $importlogpath -importlogfile $importlogfile -importerrorlogpath $importerrorlogpath -importerrorlogfile $importerrorlogfile -updategoogledns True"
}

$importcommand=$importscript + $importcommandoptions

#Invoke-Expression $importcommand

$updatedzonefilename="C:\Scripts\Noctool\PowerShellScripts\SimpleDNSFiles\updategcpzones\updatedZones\"
$allzones="*.txt"
$updatedzonefilename=
$DNSZonefilename = $DNSZonefilepath + $allzones
Move-Item $DNSZonefilename $updatedzonefilename
Write-Host $importcommand
Write-Host "End"
exit


Write-Host "End of update_GCPDNSZone.ps1 script"