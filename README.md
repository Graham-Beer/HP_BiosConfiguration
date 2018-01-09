# HP_BiosConfiguration
Code to automate the update of a Bios on an HP device

#### Description ####
This script works with 'HP BIOS Configuration Utility (BCU)'. The purpose of this script is too use 'BiosConfigUtility.exe' to check settings that are passed via CSV file and correct settings as per desired values in CSV. The CSV file is used to make the script flexiable to pass BIOS settings at ease for required settings and HP Models.

#### Examples of usage ####
Set-BiosBaseline.ps1 -HPModel 'HP EliteDesk 800 G2 SFF' -DesiredSettingCSV 'D:\hp\BIOS Configuration Utility\BiosSettingsToCheck.csv'

For testing use the custom Verbose switch, 'Logging'
Set-BiosBaseline.ps1 -HPModel "HP EliteDesk 800 G2 SFF" -BiosEncrytedPW "HPBiosPWEncryped.txt" -flag HP800G2_131216 -logging
Set-BiosBaseline.ps1 -HPModel "HP EliteDesk 800 G2 SFF" -BiosEncrytedPW "HPBiosPWEncryped.txt" -flag HP800G2_131216 -logging -CopyLogToRepository

##### Add a flag for SCCM Detection method #####
NOTE: .flg is append to the flag specfied automatically in the script
Set-BiosBaseline.ps1 -HPModel "HP EliteDesk 800 G2 SFF" -BiosEncrytedPW "HPBiosPWEncryped.txt" -flag HP800G2_131216

##### Pass an encrypted HP Bios Password file ######
Set-BiosBaseline.ps1 -HPModel "HP EliteDesk 800 G2 SFF" -BiosEncrytedPW "HPBiosPWEncryped.txt" -flag HP800G2_131216 -logging

##### Called via a application i.e. SCCM #####
powershell.exe -ExecutionPolicy bypass -command "& { .\Set-Bios.ps1 -HPModel 'HP EliteDesk 800 G2 SFF' -BiosEncrytedPW HPBiosPWEncryped.txt -flag HP800G2_071016 -logging }"
