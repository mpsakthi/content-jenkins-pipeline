param([Int]$Stage)

Write-Host "Starting record add for Stage $stage"
gcloud dns record-sets import C:\Scripts\Noctool\PowerShellScripts\SimpleDNSFiles\gcpimport\Servertrust\servertrustbatch$stage\servertrust.com.txt --zone-file-format -z v-servertrust-com

Write-Host "Added records from file: C:\Scripts\Noctool\PowerShellScripts\SimpleDNSFiles\gcpimport\Servertrust\servertrustbatch$stage\servertrust.com.txt"
Write-Host "Script Completed for stage $stage"