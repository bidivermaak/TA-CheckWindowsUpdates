# TA-CheckWindowsUpdates
Splunk app to invoke checks for missing windows updates and report results into Splunk.  Downloads most recent windows software update scan package (wsusscn2.cab), using BITS, from specified s3 bucket.  

## Search Syntax:
```SPL
sourcetype="script:powershell" source=CheckWindowsUpdates
| table _time, host, source, ScanPackageDate, Title, MsrcSeverity, KBArticleIDs, RebootRequired, SecurityBulletinIDs, Description
| sort 0 - _time
```

## Sample Results:
![alt tag](https://github.com/dstaulcu/TA-CheckWindowsUpdates/blob/master/screenshots/spl_results.JPG)
