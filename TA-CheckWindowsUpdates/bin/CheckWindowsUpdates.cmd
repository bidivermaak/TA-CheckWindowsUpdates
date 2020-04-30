@echo off
set SplunkApp=TA-CheckWindowsUpdates
powershell.exe -command ". '%SPLUNK_HOME%\etc\apps\%SplunkApp%\bin\CheckWindowsUpdates.ps1'"
