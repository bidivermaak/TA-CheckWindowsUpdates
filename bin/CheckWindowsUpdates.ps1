
#Using WUA to Scan for Updates Offline with PowerShell  
#VBS version: https://docs.microsoft.com/en-us/previous-versions/windows/desktop/aa387290(v=vs.85)  

<#
$DebugPreference = "Continue"           # Debug Mode
$DebugPreference = "SilentlyContinue"   # Normal Mode
#>

# Downloaded wsusscn2.cab file from s3 bucket if needed
$BucketName = "itanalytics-software"
$Key = "windows-updates/wsusscn2.cab"
$DownloadLocation = "$($env:TEMP)\wsusscn2.cab"

# Get Metadata About the File
$s3Object = Get-S3Object -BucketName $BucketName -Key $Key

if ([string]::IsNullOrWhiteSpace($s3Object)) {
    Write-Debug "Unable to find file $($key) in bucket $($BucketName). Exiting."
    return $null
}

# Assume a download is needed
$DownloadNeeded = $true

# check to see if client copy exists and is up to date
if (Test-Path -Path $DownloadLocation) {

    # get the date of the client copy      
    $ClientLastWrite = Get-ChildItem -Path $DownloadLocation | Select-Object -ExpandProperty LastWriteTime

    # get the date of the server copy
    $ServerLastWrite = $s3Object.LastModified

    # print the respective dates when debug mode enabled
    write-debug "Last write date of server file is: $($ServerLastWrite)."
    write-debug "Last write date of client file is: $($ClientLastWrite)."

    # set DownloadNeeded flag to true if client and server file dates don't match
    if ($ServerLastWrite -lt $ClientLastWrite) { 
        write-debug "client file more recent than server file. download not needed"
        $DownloadNeeded = $false
    } else {
        write-debug "client file less recent than server file. download needed"
    }
} else {
    write-debug "client copy of file not present. download needed."
}

# If we haven't found that we don't need it, do the download.
if ($DownloadNeeded -eq $True) {
    write-debug "invoking copy-s3object to $($DownloadLocation)."
    Copy-s3Object -BucketName $BucketName -Key $Key -LocalFile $DownloadLocation -force | out-null
}

$ClientLastWrite = Get-ChildItem -Path $DownloadLocation | Select-Object -ExpandProperty LastWriteTime
$ServerLastWrite = $ServerLastWrite.ToString('yyyy-MM-ddTHH:mm:sszzz')

# Now have windows update agent check for any missing files  
$UpdateSession = New-Object -ComObject Microsoft.Update.Session  
$UpdateServiceManager  = New-Object -ComObject Microsoft.Update.ServiceManager  

if ($DownloadNeeded -eq $True) {
    Write-Debug "Integrating microsoft update scan package."
    $UpdateService = $UpdateServiceManager.AddScanPackageService("Offline Sync Service", $DownloadLocation , 1)  
    $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()   
} else {
    Write-Debug "Skip integration of microsoft update scan package."
}
  
Write-Debug "Searching for missing windows updates." 
$UpdateSearcher.ServerSelection = 3 #ssOthers 
 
$UpdateSearcher.IncludePotentiallySupersededUpdates = $true # good for older OSes, to include Security-Only or superseded updates in the result list, otherwise these are pruned out and not returned as part of the final result list 
  
$UpdateSearcher.ServiceID = $UpdateService.ServiceID.ToString()  
  
$SearchResult = $UpdateSearcher.Search("IsInstalled=0") # or "IsInstalled=0 or IsInstalled=1" to also list the installed updates as MBSA did  
  
$Updates = $SearchResult.Updates 

if ([string]::IsNullOrWhiteSpace($Updates)) {
    Write-Debug "WUA return an empty object."
    return $null
}
 
if($Updates.Count -eq 0){  
    Write-Debug "WUA returned 0 search results."
    return $null  
}  

Write-Debug "Print any missing updates in form of splunk input"

foreach($Update in $Updates){   

    # prepare a string of key-value pairs for splunk to extract nicely
	$Output = New-Object System.Collections.ArrayList

    $Date = Get-Date -format 'yyyy-MM-ddTHH:mm:sszzz'
	[void]$Output.Add($Date)

	[void]$Output.add("Title=`"$($update.Title)`"")
	[void]$Output.add("MsrcSeverity=`"$($update.MsrcSeverity)`"")
	[void]$Output.add("KBArticleIDs=`"$($update.KBArticleIDs)`"")
	[void]$Output.add("RebootRequired=`"$($update.RebootRequired)`"")
	[void]$Output.add("SecurityBulletinIDs=`"$($update.SecurityBulletinIDs)`"")
	[void]$Output.add("Description=`"$($update.Description)`"")
	[void]$Output.add("ScanPackageDate=`"$($ServerLastWrite)`"")
	
    # print output for input of splunk script-based input handler to catch
	Write-Host ($Output -join " ")

}
