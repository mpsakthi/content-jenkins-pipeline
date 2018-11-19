<#
Created by: Bob Requa
Version: 1.0
Created: 01/23/2018
Last Updated: 
Comment:  Add Pingdom Checks.
Changed: 
#>

#This is need to force the use of TLSv1.2, othewise it will fail because it's using TLSv1.0
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;

$newchecklistfilename = "C:\Scripts\Noctool\PowerShellScripts\SimpleDNSFiles\Pingdom\newpingdomchecks.txt"

#example v1-prod-vweb293*www.socalsac.com

$checklist = Get-Content $newchecklistfilename


<# #For testing purposes
$checklist = @()
$checklist += "TESTAPI1-v1-prod-vweb179*www.scubascubaslothcity.com"
$checklist += "TESTAPI2-v1-prod-vweb003*www.boatownerswarehouse.com"
#>

$checkcount = $checklist.count
$domainname =@()
foreach($hostname in $checklist)
{
  $hostnamedata = $hostname -csplit '\*'
  $tempdomain = "'$($hostnamedata[1])'"
  $domainname += $tempdomain
}

$domainlist = $domainname -join ','

#Get SQL Database tag info from Database sqlproddb01 (used to be SQLDBC969)
$DBserver = "sqlproddb01.vdc.volusion.com"
$Database = "DataCenters"
$ServerAConnectionString = "Data Source=$DBserver;Initial Catalog=$Database;Integrated Security=SSPI;"
$ServerAConnection = new-object system.data.SqlClient.SqlConnection($ServerAConnectionString);

#Create a Dataset to hold the DataTable from DataCenters for odid and server
$dataSet = new-object "System.Data.DataSet" "odidandserverlist"
$query = "SET NOCOUNT ON; "
$query = $query + "select t3.Domain_Full,replace(t2.Server_Name,'.vdc.volusion.com','') as 'sqlserver' "
$query = $query + "from "
$query = $query + "dbo.tbl_IPs t1 "
$query = $query + "inner join tbl_servers t2 with(nolock) "
$query = $query + "on t1.ServerID_data = t2.ServerID "
$query = $query + "inner join WD_Corporate_Store.vMerchant.OrderDetails t3 with(nolock) "
$query = $query + "on t1.OrderDetailID = t3.orderdetailid "
$query = $query + "where t3.Domain_Full in ($domainlist);"

#Create a DataAdapter which you'll use to populate the DataSet with the results
$dataAdapter = new-object "System.Data.SqlClient.SqlDataAdapter" ($query, $ServerAConnection)
$countfromdb = $dataAdapter.Fill($dataSet)

#Close the connection as soon as you are done with it
$ServerAConnection.Close()
$DataTable = new-object "System.Data.DataTable" "sqldbservers"
$DataTable = $dataSet.Tables[0]

$filedate=Get-Date -Format yyyyMMddhhmm

# yih4vg7dt0maufaydfenmiqfybup4j0i
# pingdominternal@volusion.com
# LdQJC4rQ6zvD3!

#Setting up api access
$pingdomuser = 'noc@volusion.com'
$secpasswd = ConvertTo-SecureString 'WatChm3!' -AsPlainText -Force
$cred = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $pingdomuser, $secpasswd
$headers = @{'App-Key' = '47djh7yy7cg4h9c4k6mrrd8xqwk5l6bm'}

$uri = "https://api.pingdom.com/api/2.1/checks"

$checkaddcount = 0
$checkerrorcount = 0
$Checkadderrorlist =@()
$y = 0

foreach($check in $checklist)
{
  
  
  $checkdata = $check -csplit '\*'
  $vweb = $checkdata[0]
  $hosttocheck = $checkdata[1]
  $sqldbtag = $DataTable.select("Domain_Full='$hosttocheck'") | Select-Object -ExpandProperty sqlserver
  $vwebtag = $vweb
  
  #exmple body name=My+new+HTTP+check&type=http&host=www.mydomain.com
  # Integration IDs 60192 - Slack integration,60195 integrationids
  #$checkbody = "name=$check&type=http&host=$hosttocheck&resolution=1&tags=$sqldbtag,$vwebtag,fixslacknotify&url=/login.asp&port=80"
  $checkbody = "name=$check&type=http&host=$hosttocheck&resolution=1&tags=$sqldbtag,$vwebtag,fixslacknotify&url=/login.asp&port=80&integrationids=60192,60195"
  $pingdomapirequest = Invoke-WebRequest -Uri $uri -Credential $cred -Headers $headers -Method Post -Body $checkbody
  $pingdomresults = $pingdomapirequest.content | ConvertFrom-Json
  
  $status = $pingdomapirequest.'StatusCode'
  $checkid = $pingdomresults.'check'.'id'
  if($status -eq 200)
  {
    $checkaddcount++
  } else {
    $checkerrorcount++
    $Checkadderrorlist += "$status,$vweb,$hosttocheck"
  }
  $y++
  Write-Host "$y of $checkcount checks proccessed.  checkid: $checkid for $vweb*$hosttocheck Status code: $status"

  Start-Sleep -Milliseconds 200
}

Write-Host "Checks added: $checkaddcount"
Write-Host "Check add errors: $checkerrorcount"
Write-Host "Total checks processed: $y"
Write-Host "Script completed!"
