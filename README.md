# TA-CheckWindowsUpdates
Splunk app to facilitate offline checks for windows updates and report results into Splunk.  Downloads most recent wsusus, only when needed, from specified s3 bucket.

# Search Syntax:
```SPL
sourcetype="script:powershell" source=CheckWindowsUpdates
| table _time, host, source, ScanPackageDate, Title, MsrcSeverity, KBArticleIDs, RebootRequired, SecurityBulletinIDs, Description
| sort 0 - _time
```

# Sample Results:
![alt tag](https://github.com/dstaulcu/TA-CheckWindowsUpdates/blob/master/screenshots/spl_results.JPG)
