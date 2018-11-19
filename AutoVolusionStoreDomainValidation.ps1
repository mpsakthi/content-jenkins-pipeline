param([string]$inputfile, [string]$inputpath, [string]$outputfile, [string]$outputpath, [string]$entrytype, [string]$domains, [string]$checkvweb, [string]$prod="False")
<#
Created by: Bob Requa
Version: 1.0
Created: 10/28/2017
Last Updated: New
Comment:  Verify domains through the use of dig command.  Script made to be ran with a scheduled task.
Changed: 
#>

$ScriptStartTime=Get-Date
$filedate=Get-Date -Format yyyyMMddhhmmss

if(-not($entrytype))
{
  if(-not($inputfile))
  {
    #Write-Host "Default entrytype: manual"
    $zoneinput="manual"
    if(-not($domains))
    {
      Write-Error "No options chosen.  Default -entrytype manual chosen, must enter at least one domain to verify.  Exiting script!"
      exit
    }
  } else {
    #Write-Warning "-inputfile overriding default manual entrytype.  Setting -entrytype to: fromfile"
    $entrytype="fromfile"
    $zoneinput="fromfile"
  }
} elseif ($entrytype -eq "fromfile") {
  $zoneinput="fromfile"
} elseif ($entrytype -eq "manual") {
  if(-not($inputfile))
  {
    if(-not($domains))
    {
      Write-Error "-entrytype manual chosen, must enter at least one domain to verify.  Exiting script!"
    }
    $zoneinput="manual"
  } else {
    if(-not($domains))
    {
      Write-Error "-inputfile set to $inputfile while -entrytype set to $entrytype and -domains not set.  Ignoring -inputfile parameter.  Expecting a value for -domains.  Exiting script!"
      exit
    } else {
      Write-Host "Domains:$domains`:END"
      Write-Warning "-inputfile set to $inputfile while -entrytype set to $entrytype.  Overriding -inputfile, script will not run from file.  Using -domains: $domains."
      $zoneinput="manual"
    }
  }
} elseif ($entrytype -eq "fromDB") {
  $zoneinput="fromDB"
  if(-not($checkvweb))
  {
    Write-Warning "-entrytype set to fromDB and -vweb not set.  Defaulting to all vwebs"
    $checkvweb = "all"
  }
} else {
  Write-Error "Invalid option!  Valid options for -entrytype are manual, fromfile, or fromDB. Alternatively do not use this option to default to manual use."
  exit
}
if (($entrytype -eq "fromfile") -and (-not[string]::IsNullOrEmpty($domains)))
{
  Write-Warning "-entrytype fromfile chosen with and -domains has a value!  Ignoring -domains.  Continuing script." 
}

if(($entrytype -ne "fromDB") -and ($entrytype -ne "manual"))
{
  if(-not($inputfile))
  {
    Write-Host "Default input filename: zonelist.txt"
    $zonelistfilename="zonelist.txt"
  } else {
    $zonelistfilename=$inputfile
    if($zonelistfilename -cmatch '\.txt')
    {
      $entrytype="fromfile"
    } else {
      $zonelistfilename="$zonelistfilename.txt"
    }
  }

  if(-not($inputpath))
  {
    #Write-Host "Default input filepath: file path C:\Scripts\Noctool\PowerShellScripts\SimpleDNSFiles\domainvalidation\"
    $zonelistpath="C:\Scripts\Noctool\PowerShellScripts\SimpleDNSFiles\domainvalidation\$zonelistfilename"
    $defaultzonelistpathforerrormsg="C:\Scripts\Noctool\PowerShellScripts\SimpleDNSFiles\domainvalidation\"
  } else {
    if($inputpath -cnotmatch '\\$')
    {
      $inputpath="$inputpath\"
    }
    $zonelistpath=$inputpath + $zonelistfilename
  }
  $checkzonelistpath=Test-Path $zonelistpath
  if($checkzonelistpath -ne "True")
  {
    if([string]::IsNullOrEmpty($inputpath))
    {
      Write-Error "Invalid path specified:$defaultzonelistpathforerrormsg, or input file $inputfile does not exist.  Exiting script!"
    } else {
      Write-Error "Invalid path specified:$inputpath, or input file $inputfile does not exist.  Exiting script!"
    }
    exit
  }

}

if(-not($outputfile))
{
  #Write-Host "Default output file: nameserverlist_$filedate.txt"
  $outputfilename="$checkvweb`_nameserverlist_$filedate.csv"
  $outputfilename2="$checkvweb`_nameserverlist_$filedate.txt"
} else {
  if($outputfile -cmatch '\.csv')
  {
    $outputfilename=$outputfile -creplace '\.csv',"_$filedate.csv"
    $outputfilename2=$outputfile -creplace '\.csv',"_$filedate.txt"
  } else {
    $outputfilename="$outputfile`_$filedate.csv"
    $outputfilename2="$outputfile`_$filedate.txt"
  }
}

if(-not($outputpath))
{
  #Write-Host "Default output file path: C:\Scripts\Noctool\PowerShellScripts\SimpleDNSFiles\domainvalidation\storevalidation\"
  $resultpath="C:\Scripts\Noctool\PowerShellScripts\SimpleDNSFiles\domainvalidation\AutoStoreValidation\$outputfilename"
  $resultpath2="C:\Scripts\Noctool\PowerShellScripts\SimpleDNSFiles\domainvalidation\AutoStoreValidation\otherdata\"
  $resultpath3="C:\Scripts\Noctool\PowerShellScripts\SimpleDNSFiles\domainvalidation\AutoStoreValidation\"
} else {
  if($outputpath -cnotmatch '\\$')
  {
    $outputpath="$outputpath\"
  }
  $resultpath=$outputpath + $outputfilename
  $resultpath2=$outputpath + "otherdata\"
}
if (-not[string]::IsNullOrEmpty($outputpath))
{
  $checkoutputpath=Test-Path $outputpath
  if($checkoutputpath -ne "True")
  {
    Write-Error "Directory $outputpath does not exist.  Exiting script!"
    exit
  }
}

$dbimporterrorfile = "$checkvweb`_dbimporterrors_$filedate.txt"
$dbimportfilename = $resultpath2 + $dbimporterrorfile

#Counter variables
$zonesprocessed=0
$readytomovecount=0
$notreadytomovecount=0
$ArecordnotGCPIP=0
$Arecordpointedaway=0
$zonestodelete=0
$zonesnotfound=0
$zonestotaltodelete=0
$c1=0

$vwebfilenameready = "$checkvweb`_readytomove_$filedate.csv"
$vwebreadytomovefilename = $resultpath3 + $vwebfilenameready

$vwebfilenamenotready = "$checkvweb`_notreadytomove_$filedate.csv"
$vwebnotreadytomovefilename = $resultpath3 + $vwebfilenamenotready

$DBaddlogfile = "$checkvweb`_DBaddlog_$filedate.csv"
#$DBaddlogfile

#Checking if output file exists, if not create the file and add headers.
$Checkoutputfilename=Test-Path $resultpath

if($Checkoutputfilename -ne "True")
{
   Add-Content $resultpath "orderid,customerid,OrderDetailID,orderdetailstatusname,orderstatus,servertrustdomain,Website_Stopped,Config_StoreVersion,Host_Name,Server_Name,Domain_Full,ProductCode,vWeb,READYTOMOVE,DOMAINNAME,HOSTEDWITHVOLUSION,RECORDTYPE,NAMESERVERS"
}

if($Checkvwebreadytomovefilename -ne "True")
{
   Add-Content $vwebreadytomovefilename "orderid,customerid,OrderDetailID,orderdetailstatusname,orderstatus,servertrustdomain,Website_Stopped,Config_StoreVersion,Host_Name,Server_Name,Domain_Full,ProductCode,vWeb,READYTOMOVE,DOMAINNAME,HOSTEDWITHVOLUSION,RECORDTYPE,NAMESERVERS"
}

if($Checkvwebreadytomovefilename -ne "True")
{
   Add-Content $vwebnotreadytomovefilename "orderid,customerid,OrderDetailID,orderdetailstatusname,orderstatus,servertrustdomain,Website_Stopped,Config_StoreVersion,Host_Name,Server_Name,Domain_Full,ProductCode,vWeb,READYTOMOVE,DOMAINNAME,HOSTEDWITHVOLUSION,RECORDTYPE,NAMESERVERS"
}


if($zoneinput -eq "manual")
{
  $zonestovalidate=$domains -csplit '\s'
}elseif ($zoneinput -eq "fromfile") {
  $zonestovalidate=Get-Content $zonelistpath
}elseif ($zoneinput -eq "fromDB")
{
  #Create SQL connection string, and then a connection to AdminCentral
  $DBserver = "sqldbc969.vdc.volusion.com"
  $Database = "DataCenters"
  $ServerAConnectionString = "Data Source=$DBserver;Initial Catalog=$Database;Integrated Security=SSPI;"
  $ServerAConnection = new-object system.data.SqlClient.SqlConnection($ServerAConnectionString);

  #Create a Dataset to hold the DataTable from AdminCentral
  $dataSet = new-object "System.Data.DataSet" "Storelist"
  $query = "SET NOCOUNT ON; "
  #Old SQL Query
  <#
  $query = $query + "SELECT * "
  $query = $query + "FROM dbo.Datacenters_Stores_Views "
  #>

  #New SQL Query excludes stopped stores > 45 days old, GCP servers, xsvwebs, sweb, vcorp, web1, and sim01xpqt/lb servers.
  $query = $query + "select t5.orderid,t5.customerid,t1.OrderDetailID,t1.Website_Stopped,t5.orderstatus,t1.Config_StoreVersion,t2.Host_Name,t2.Server_Name, "
  $query = $query + "t3.Domain_Full,t3.ProductCode,t4.server_name as 'vWeb',ServerTrustDomain = (t6.ServerTrustDomain + '.servertrust.com'),t7.orderdetailstatusname "
  $query = $query + "from "
  $query = $query + "dbo.tbl_IPs t1 "
  $query = $query + "inner join tbl_servers t2 with(nolock) "
  $query = $query + "on t1.ServerID_data = t2.ServerID "
  $query = $query + "inner join WD_Corporate_Store.vMerchant.OrderDetails t3 with(nolock) "
  $query = $query + "on t1.OrderDetailID = t3.orderdetailid "
  $query = $query + "Inner join tbl_servers t4 with(nolock) "
  $query = $query + "on t1.ServerID_iis = t4.ServerID "
  $query = $query + "Inner join WD_Corporate_Store.vMerchant.orders t5 with(nolock) "
  $query = $query + "on t3.orderid = t5.orderid "
  $query = $query + "left outer join ServerTrustDomains t6 with(nolock) "
  $query = $query + "on t1.OrderDetailID = t6.OrderDetailID "
  $query = $query + "Inner join WD_Corporate_Store.vMerchant.orderdetailstatus t7 with(nolock) "
  $query = $query + "on t3.orderdetailstatusid = t7.orderdetailstatusid "

  
  if($checkvweb -ne "all")
  {
    $checkvweb = $checkvweb.ToLower()
    $query = $query + "where t4.server_name like '%$checkvweb%' "
  } else {
    $query = $query + "where t4.server_name like '%web%' "
  }
  
  $query = $query + "and t4.server_name not like 'v1-prod%' "
  $query = $query + "and t4.server_name not like 'sim01xsvweb%' "
  $query = $query + "and t4.server_name not like 'sweb%' "
  $query = $query + "and t4.server_name not like 'vcorp%' "
  $query = $query + "and t4.server_name not like 'web1.%' "
  $query = $query + "and t4.server_name not like 'sim01xpqt%' "
  $query = $query + "and t4.server_name not like 'sim01xplb%' "
  $query = $query + "and (t1.Website_Stopped is null or t1.Website_Stopped >= GetDate() -45) "
  $query = $query + "order by t3.Domain_Full asc; "

  #Create a DataAdapter which you'll use to populate the DataSet with the results
  $dataAdapter = new-object "System.Data.SqlClient.SqlDataAdapter" ($query, $ServerAConnection)

  $zonecountfromdb = $dataAdapter.Fill($dataSet)

  #Close the connection as soon as you are done with it
  $ServerAConnection.Close()
  $dataTable = new-object "System.Data.DataTable" "vstorelist"
  $dataTable = $dataSet.Tables[0]

  $zonestovalidate = @()

  $dataTable | ForEach-Object {
    $zonestovalidate += $_.Domain_full
  }

}

$zonecount=$zonestovalidate.Count
$keepfirstpass="True"
$notfoundfirstpass="True"
$deleteonlyfirstpass="True"
$deleteallfirstpass="True"
$n = 0

Write-Host "zonecount:$zonecount"
$rawoutputfile="$checkvweb`_rawnsdata_$filedate.txt"
$rawoutputfilename=$resultpath2 + $rawoutputfile

#$zonestovalidate = @() #REMOVE_TESTING
#$zonestovalidate += "www.davidmannstore.com" #REMOVE_TESTING

$hash=@{}
$vipfilename = "C:\Scripts\Noctool\PowerShellScripts\SimpleDNSFiles\domainvalidation\AutoStoreValidation\config\volusionIPs.txt"
$viplist = Get-Content -Path $vipfilename

#Create hash table to look up volusion IPs
foreach ($vip in $viplist)
{
  $tempvipdata = $vip -csplit ','
  $hashkey = $tempvipdata[0]
  $hashdata = $tempvipdata[1]
  $hash.Add($hashkey, $hashdata)
}

#Beginning of loop for zone validation.
foreach($zone in $zonestovalidate) 
{
  $c1++
  Write-Progress -id 0 -Activity "Validating Zones" -Status "Processing $($c1) of $($zonestovalidate.Count)" -currentOperation $zone -PercentComplete (($c1/$zonestovalidate.Count)*100)
  Write-Host $zone
  $tempdomainname = $zone -csplit '\.'
  $checktopleveldomain = $tempdomainname[-1]
  $tempnameserverdata=@()
  $nameserverdata=""
  $checkArecord="False"
  $PointedtoServertrust="False"

  if($checktopleveldomain -eq "sandbox")
  {
    $nsdata=@()
    $nameserverdata="NOT_FOUND"
    $recordtype="NOT_FOUND"
    $status="FALSE"
  } else {
    $nsdata=C:\Windows\system32\dig.exe $zone -t NS +noall +answer
  }
  $t=0
  $tempnameserver=""
  Foreach($line in $nsdata)
  {
    $regexscrub01='^;'
    $regexNS='\S+$'
    #Write-Host "$t,$testcount,$line"
    if($line -cnotmatch $regexscrub01)
    {
      If($line -cmatch 'NS')
      {
        $recordtype="NS"
      } elseif ($line -cmatch "CNAME") {
        $recordtype="CNAME"
        if($line -cmatch 'servertrust\.com')
        {
          $PointedtoServertrust = "True"
        }
      } else {
        $recordtype="NOT_FOUND"
      }
      
      $tempnameserver=$line -cmatch $regexNS
      if($recordtype -eq "NS")
      {
        $nameserver=$matches[0] | Out-String
        $nameserver=$nameserver.trim()
        $tempnameserverdata+=$nameserver
        #Write-Host "insidens,$t,$nameserver"
      } elseif($PointedtoServertrust -eq "True") {
        $nameserver=$matches[0] | Out-String
        $nameserver=$nameserver.trim()
        $tempnameserverdata+=$nameserver
        #Write-Host "insidepintedto,$t,$nameserver"
      }

      
    }
      Add-Content $rawoutputfilename "$zone-$line" #just get all the lines
      $t++
  } #End of DIG line check

  $nscount=$tempnameserverdata.Count

  If($nscount -gt 1)
  {
    $nameserverdata=[string]::Join(':',$tempnameserverdata)
  } else {
    $nameserverdata=$tempnameserverdata[0]
  }
  #$nameserverdata="" #REMOVE_TESTING
  if($nameserverdata -match 'volusion.com')
  {
    $status="TRUE"
    $readytomove="YES"
    $readytomovecount++
  }elseif ($PointedtoServertrust -eq "True") {
    $readytomove="YES"
    $status="FALSE"
    $readytomovecount++
  }elseif ([string]::IsNullOrEmpty($nameserverdata)) {
    #$status="FALSE"
    #$readytomove="NO"
    #$recordtype="NOT_FOUND"
    #$nameserverdata="NOT_FOUND"
    $checkArecord="True"
    #$zonesnotfound++
  } else {
    #$status="FALSE"
    #$readytomove="NO"
    $checkArecord="True"
    $zonestodelete++
  }

  if($checkArecord -eq "True")
  {
    $nsAdata=C:\Windows\system32\dig.exe $zone -t A +noall +answer
    $regexscrub01='^;'
    $regexArecord='\s+A\s+'
    $regexIP='35\.190\.16\.47$'
    $regexGetIP='\S+$'
    $ArecordFound = "False"
    
    Foreach($Aline in $nsAdata)
    {
      if(($Aline -cnotmatch $regexscrub01) -and ($Aline -cmatch $regexArecord))
      {
        $tempIP=$Aline -cmatch $regexGetIP
        $IP=$matches[0] | Out-String
        $IP=$IP.trim()
        $ipfound = $hash.item($IP)

        if(($ipfound))
        {
          if($ipfound -eq "gcpvolusion")
          {
            $status="FALSE"
            $readytomove="YES"
            $recordtype="A"
            $ArecordFound="True"
            $nameserverdata="volusiongcp_IP-$IP"
            $readytomovecount++
          } elseif($ipfound -eq "volusion") {
            $status="FALSE"
            $readytomove="NO"
            $recordtype="A"
            $ArecordFound="True"
            $nameserverdata="volusion_IP-$IP"
            $ArecordnotGCPIP++
            $notreadytomovecount++
          } else {
            $status="FALSE"
            $readytomove="YES"
            $recordtype="A"
            $ArecordFound="True"
            $Arecordpointedaway++
            $nameserverdata="nonvolusion_IP_$ipfound-$IP"
            $readytomovecount++
          }
        } else {
          $status="FALSE"
          $readytomove="NO"
          $recordtype="A"
          $ArecordFound="True"
          $nameserverdata="nonvolusion_IP_ManualReviewRequired-$IP"
          $Arecordpointedaway++
          $notreadytomovecount++
        }
      }
      Add-Content $rawoutputfilename "$zone-$Aline"
    } #End of A record dig loop check

    if($ArecordFound -ne "True")
    {
      $status="FALSE"
      $readytomove="YES" #Set to YES at request of Shad
      $recordtype="NOT_FOUND"
      $nameserverdata="NOT_FOUND"
      $zonesnotfound++
      $readytomovecount++
    }
  }
  
  #Get info from store list
  $storedata = $DataTable.select("Domain_Full='$zone'")

  [int]$orderid = $storedata | Select-Object -ExpandProperty orderid
  [int]$customerid = $storedata | Select-Object -ExpandProperty customerid
  [int]$orderdetailid = $storedata | Select-Object -ExpandProperty OrderDetailID
  $website_stopped = $storedata | Select-Object -ExpandProperty Website_Stopped
  $config_storeversion = $storedata | Select-Object -ExpandProperty Config_StoreVersion
  $host_name = $storedata | Select-Object -ExpandProperty Host_Name
  $server_name = $storedata | Select-Object -ExpandProperty Server_Name
  $domain_full = $storedata | Select-Object -ExpandProperty Domain_Full
  $productcode = $storedata | Select-Object -ExpandProperty ProductCode
  $vweb = $storedata | Select-Object -ExpandProperty vWeb
  $orderdetailstatusname = $storedata | Select-Object -ExpandProperty orderdetailstatusname
  $orderstatus = $storedata | Select-Object -ExpandProperty orderstatus
  $tempservertrustdomain = $storedata | Select-Object ServerTrustDomain
  $servertrustdomain = $tempservertrustdomain -creplace '\@\{ServerTrustDomain\=',''
  $servertrustdomain = $servertrustdomain -creplace '\}',''

  $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
  $headers.Add("GCPAPI-AUTH", "9Id*S83w1*cg8aw6lMV2Xpv5!23d)sg`#")

  if($prod -eq "True")
  {
    $payload = @{  
      orderdetailid="$orderdetailid"
      orderid="$orderid"
      customerid="$customerid"
      #website_stopped="$website_stopped" #left out of Sungs API
      config_storeversion="$config_storeversion"
      host_name="$host_name"
      server_name="$server_name"
      domain_full="$domain_full"
      productcode="$productcode"
      vweb="$vweb"
      domainname="$zone"
      status="$status"
      recordtype="$recordtype"
      nameserverdata="$nameserverdata"
      readytomove="$readytomove"
    }
    $json = $payload | ConvertTo-Json
    try {
          $result = Invoke-WebRequest -Uri 'http://sim01gpxfc01.vdc.volusion.com:8080/api/GCP/UploadHostStatus' -Headers $headers -Method Post -Body $json -ContentType 'application/json'
          Write-Host $result.Content
        }
    
    catch {
            $result = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($result)
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $responseBody = $reader.ReadToEnd();
            Add-Content $dbimportfilename "Orderdetailid-$orderdetailid,domain_full-$domain_full,$responseBody"
            Write-Host $responseBody
    }
  }

  Add-Content $resultpath "$orderid,$customerid,$orderdetailid,$orderdetailstatusname,$orderstatus,$servertrustdomain,$website_stopped,$config_storeversion,$host_name,$server_name,$domain_full,$productcode,$vweb,$readytomove,$zone,$status,$recordtype,$nameserverdata"
  
  if($readytomove -eq "YES")
  {
    Add-Content $vwebreadytomovefilename "$orderid,$customerid,$orderdetailid,$orderdetailstatusname,$orderstatus,$servertrustdomain,$website_stopped,$config_storeversion,$host_name,$server_name,$domain_full,$productcode,$vweb,$readytomove,$zone,$status,$recordtype,$nameserverdata"
  } else {
    Add-Content $vwebnotreadytomovefilename "$orderid,$customerid,$orderdetailid,$orderdetailstatusname,$orderstatus,$servertrustdomain,$website_stopped,$config_storeversion,$host_name,$server_name,$domain_full,$productcode,$vweb,$readytomove,$zone,$status,$recordtype,$nameserverdata"
  }
  
  $zonesprocessed++
} #End of Zone Loop
$zonestotaltodelete=$zonestodelete + $zonesnotfound
$ScriptFinishTime=Get-Date
$ScriptRunTime=New-TimeSpan $ScriptStartTime $ScriptFinishTime
$summaryfile = "summaryAutoVolusionStoreDomainValidation_$filedate.txt"
$summaryfilename = $resultpath2 + $summaryfile

Add-Content $summaryfilename "-------------------Summary-------------------"
Add-Content $summaryfilename "Output File:$resultpath"
Add-Content $summaryfilename "Raw dig output file:$rawoutputfilename"
Add-Content $summaryfilename "$zonecount`:Number of Stores"
Add-Content $summaryfilename "$zonesprocessed`:Stores processed"
Add-Content $summaryfilename "$readytomovecount`:Stores ready to move"
Add-Content $summaryfilename "$notreadytomovecount`:Stores not ready to move"
Add-Content $summaryfilename "$ArecordnotGCPIP`:Stores pointed to Volusion with A-record not set to GCP IP"
Add-Content $summaryfilename "$Arecordpointedaway`:Stores pointed away from Volusion with A-record not set to GCP IP"
Add-Content $summaryfilename "$zonestodelete`:Stores pointed to non-Volusion nameservers"
Add-Content $summaryfilename "$zonesnotfound`:Stores without nameservers(NOT_FOUND: Not registered or expired)"
Add-Content $summaryfilename "$zonestotaltodelete`:Total stores not ready to move"
Add-Content $summaryfilename "Total time script ran:$ScriptRunTime"
Add-Content $summaryfilename "--------------Detailed Script Completed Time--------------"

Write-Host""
Write-Host "-------------------Summary-------------------"
write-Host "Output File:$resultpath"
Write-Host "Raw dig output file:$rawoutputfilename"
Write-Host "$zonecount`:Number of Stores"
Write-Host "$zonesprocessed`:Stores processed"
Write-Host "$readytomovecount`:Stores ready to move"
Write-Host "$notreadytomovecount`:Stores not ready to move"
Write-Host "$ArecordnotGCPIP`:Stores pointed to Volusion with A-record not set to GCP IP"
Write-Host "$Arecordpointedaway`:Stores pointed away from Volusion with A-record not set to GCP IP"
Write-Host "$zonestodelete`:Stores pointed to non-Volusion nameservers"
Write-Host "$zonesnotfound`:Stores without nameservers(NOT_FOUND: Not registered or expired)"
Write-Host "$zonestotaltodelete`:Total stores not ready to move"
Write-Host "Total time script ran:$ScriptRunTime"
Write-Host "--------------Detailed Script Completed Time--------------"
New-TimeSpan $ScriptStartTime $ScriptFinishTime
Write-Host "End of Script"