param([string] $movegroup)

if(-not($movegroup))
{
  Write-Error "-movegroup not set.  Must have a value.  Exiting script!"
  exit
}

$filedate=Get-Date -Format yyyyMMddhhmmss
$filedate2=Get-Date -Format yyyyMMddhhmm
$vinlist = "C:\Scripts\Noctool\PowerShellScripts\Stopsites\stoplist.txt"

$Database = "DataCenters"
$DBserver = "sqlinst13.db.vdc.volusion.com"

#Create your SQL connection string, and then a connection to DataCenters
$ServerConnectionString = "Data Source=$DBserver;Initial Catalog=$Database;Integrated Security=SSPI;"
$ServerConnection = new-object system.data.SqlClient.SqlConnection($ServerConnectionString);

#Create a Dataset to hold the DataTable from DataCenters for Vweblist
$dataSet = new-object "System.Data.DataSet" "vweblist"
$query = "SET NOCOUNT ON;"

$query = $query + "SELECT distinct Replace(Replace(t2.Server_Name,'.vdc.volusion.com',''),'v1-prod-','sim01xp') as vweb "
$query = $query + "FROM "
$query = $query + "MoveForSAN t1 with (nolock) "
$query = $query + "left join tbl_servers t2 with (nolock) "
$query = $query + "on t1.MoveFromIISServerID = t2.ServerID "
#$query = $query + "where Status like '%group 1%' "
$query = $query + "where Status like '%complete%' "
$query = $query + "and "
$query = $query + "t2.Server_name not like '%sim01%' "
$query = $query + "order by vweb "

#Create a Dataset to hold the DataTable from DataCenters for Vweblist
$dataSet2 = new-object "System.Data.DataSet" "orderdetailidlist"
$query2 = "SET NOCOUNT ON;"
$query2 = $query2 + "SELECT t1.OrderDetailId, Replace(Replace(t2.Server_Name,'.vdc.volusion.com',''),'v1-prod-','sim01xp') as vweb "

$query2 = $query2 + "FROM "
$query2 = $query2 + "MoveForSAN t1 with (nolock) "
$query2 = $query2 + "left join tbl_servers t2 with (nolock) "
$query2 = $query2 + "on t1.MoveFromIISServerID = t2.ServerID "
#$query2 = $query2 + "where Status like '%group 1%' "
$query2 = $query2 + "where Status like '%complete%' "
$query2 = $query2 + "and "
$query2 = $query2 + "t2.Server_name not like '%sim01%' "
$query2 = $query2 + "order by vweb, OrderDetailId "

#Create a DataAdapter which you'll use to populate the DataSet with the results
$dataAdapter = new-object "System.Data.SqlClient.SqlDataAdapter" ($query, $ServerConnection)
$vweblistcount = $dataAdapter.Fill($dataSet)

$dataAdapter2 = new-object "System.Data.SqlClient.SqlDataAdapter" ($query2, $ServerConnection)
$odidlistcount = $dataAdapter2.Fill($dataSet2)


#Close the connection as soon as you are done with it
$ServerConnection.Close()
$DataTable = new-object "System.Data.DataTable" "vweblistresults"
$DataTable2 = new-object "System.Data.DataTable" "odidlistresults"
$DataTable = $dataSet.Tables[0]
$DataTable2 = $dataSet2.Tables[0]

#Convert database output to an array of orderdetailids.
$vweblist = $DataTable | Select-Object -ExpandProperty vweb
$odidlist = $DataTable2 | Select-Object -ExpandProperty OrderDetailId

<#
foreach($vweb in $vweblist)
{
  $vwebodidlist = $DataTable2.select("vweb='$vweb'") | Select-Object -ExpandProperty orderdetailid
  Write-Host $vweb
  Write-Host $vwebodidlist
}

exit
#>

# $orderdetailids = Get-Content $vinlist

if(-not($odidlist))
{
  Write-Error "No sites found in list.  Exiting script!"
  exit
}

$maxConcurrentJobs = 15
if ($vweblist.count -gt $maxConcurrentJobs)
{
  Write-Warning "Number of Vwebs is greater than max current background jobs allowed.  Only $maxConcurrentJobs background jobs will run at any given time."
}

$logfilename = "C:\Scripts\Noctool\PowerShellScripts\Stopsites\logs\StopVDCSitesMigrated_$filedate.log"

$c1=0

$vweblisttemp=@()

$addbackgroundjob = "True"
$y = 0
$z = 1
$lastvweb = $vweblist[-1]

#Stopping sites
foreach($vweb in $vweblist)
{
  $shortvwebname = $vweb -replace 'sim01',''
  While ($addbackgroundjob -eq "False")
  {
    if((Get-Job -State 'Running').Count -lt $maxConcurrentJobs)
    {
      $addbackgroundjob = "True"
      $completedjobs = (Get-Job -State 'Completed').Count
    } else {
      $completedjobs = (Get-Job -State 'Completed').Count
      Write-Host "$z-Checking background jobs, $completedjobs completed of $vweblistcount. Final Vweb is $lastvweb."
      Get-Job
      #Write-Host "$z-Checking background jobs, $completedjobs completed of $vweblistcount. Final Vweb is $lastvweb.  Pausing for 15 seconds....."
      $addbackgroundjob = "False"
      $z++
      Start-Sleep -Seconds 15
    }
  }
  $bcount=(Get-Job -State 'Running').Count
  $vwebodidlist = $DataTable2.select("vweb='$vweb'") | Select-Object -ExpandProperty orderdetailid
  Start-Job -name "$y-$shortvwebname" -ScriptBlock {C:\Users\xadmbrequa\Desktop\PowerShellScripts\AutoStopWebsiteOnly.ps1 -VDCvweb $args[0] -stopodidlist $args[1] -passfiledate $args[2] -movegroup $args[3]} -ArgumentList $vweb, $vwebodidlist, $filedate2, $movegroup
  if((Get-Job -State 'Running').Count -ge $maxConcurrentJobs)
  {
    $addbackgroundjob = "False"
    $completedjobs = (Get-Job -State 'Completed').Count
  }
  
  $y++
}

#Checking backgound Jobs

$checkbackgroundjobs = "True"
$abortcheckbackground = "False"
#$m = 0
$n = 1

Do {
  $getsatus = Get-Job | Select-Object -ExpandProperty State
  $completedjobs = (Get-Job -State 'Completed').Count
  if($getsatus -contains "Running")
  {
    $completedjobs = (Get-Job -State 'Completed').Count
    Write-Host "`n$z-Check backgroundjob status.  $completedjobs completed of $vweblistcount. Final Vweb is $lastvweb. Waiting 15 seconds to check job status..."
    Get-Job
    Start-Sleep -Seconds 15
    $m++
    $z++
  } else {
    $checkbackgroundjobs = "False"
  }
  
  $n++

  if ($m -gt 101) {
   Write-Warning "To many times, exiting script!"
   $abortcheckbackground = "True"
   break;
  }
}
Until ($checkbackgroundjobs -eq "False")

if($abortcheckbackground -eq "False")
{
  Write-Host "`nAll background jobs completed"
  Get-Job
  Get-Job | Remove-Job
  Write-Host "`nBackground Jobs completed."
} elseif ($abortcheckbackground -eq "True") {
  Write-Warning "Use Get-Job to check background job status, then Get-Job | Remove-Job to remove the back ground jobs when all completed.  Exiting Script!"
  exit
}

$vwebcount = $vweblist.count
Write-Host "$completedjobs vwebs with sites stopped of $vwebcount vwebs in list."
Write-Host "Removing background jobs"
Get-Job | Remove-Job

Write-host "Script Completed"

# $vweblist = $vweblisttemp | select -Unique


$outputfilename = "C:\Scripts\Noctool\PowerShellScripts\Stopsites\Auto_AllStopVDCSitesMigrated_$movegroup`_$filedate2.txt"

$x = 0
foreach($logfromvweb in $vweblist)
{
  $datafilename = "\\$logfromvweb\C$\temp\StopVDCSitesMigrated_$movegroup`_$filedate2.txt"
  $data = Get-Content $datafilename

  foreach($line in $data)
  {
    Add-Content $outputfilename $line
  }
  $x++
}
Write-Host "$x Logs retrieved from $vwebcount vwebs.  Output file location: $outputfilename"
Write-Host "Script completed"
