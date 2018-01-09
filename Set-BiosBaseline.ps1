<#
.Synopsis
   Update HP BIOS
.DESCRIPTION
   This script works with 'HP BIOS Configuration Utility (BCU)'. The purpose of this script is too use 'BiosConfigUtility.exe' to check settings 
   that are passed via CSV file and correct settings as per desired values in CSV. The CSV file is used to make the script flexiable to pass BIOS
   settings at ease for required settings and HP Models.
   The CSV file that is passed to this script is formatted like:

   "Name","Value"
   "Asset Tracking Number",$env:COMPUTERNAME
   "After Power Loss","Previous State"
   "UEFI Boot Options","Disable"
   "Legacy Boot Order","'HDD:USB:1,CDROM:SATA:1,HDD:SATA:1,NETWORK:EMBEDDED:1'"
   "Configure Legacy Support and Secure Boot","Legacy Support Enable and Secure Boot Disable"
   "Virtualization Technology (VTx)","Enable"
   "Virtualization Technology for Directed I/O (VTd)","Enable"
   "Wake On LAN","Boot to Hard Drive"
   "Video Memory Size","256 MB"
   "Network (PXE) Boot","Enable"

   The 'BiosConfigUtility.exe' utility can be sensitive to case so would recommand using the 'BiosConfigUtility.exe /get:sometextfile.txt' to look
   and copy the required names and values to the CSV file.

.EXAMPLE
   Main use of script:
   Set-BiosBaseline.ps1 -HPModel 'HP EliteDesk 800 G2 SFF' -DesiredSettingCSV 'D:\hp\BIOS Configuration Utility\BiosSettingsToCheck.csv'
.EXAMPLE
   For testing use the custom Verbose switch, 'Logging'
   Set-BiosBaseline.ps1 -HPModel "HP EliteDesk 800 G2 SFF" -BiosEncrytedPW "HPBiosPWEncryped.txt" -flag HP800G2_131216 -logging
   Set-BiosBaseline.ps1 -HPModel "HP EliteDesk 800 G2 SFF" -BiosEncrytedPW "HPBiosPWEncryped.txt" -flag HP800G2_131216 -logging -CopyLogToRepository
.EXAMPLE
    Add a flag for SCCM Detection method
    NOTE: .flg is append to the flag specfied automatically in the script
    Set-BiosBaseline.ps1 -HPModel "HP EliteDesk 800 G2 SFF" -BiosEncrytedPW "HPBiosPWEncryped.txt" -flag HP800G2_131216
.EXAMPLE
    Pass an encrypted HP Bios Password file 
    Set-BiosBaseline.ps1 -HPModel "HP EliteDesk 800 G2 SFF" -BiosEncrytedPW "HPBiosPWEncryped.txt" -flag HP800G2_131216 -logging
.INPUTS
    inputs available:
   -HPModel : Pass model of machine so script is not run on incorrect model
   -DesiredSettingCSV : Set path for CSV location ## Currently a default is set ##
   -BiosEncrytedPW : Add an encrypted HP Bios Password file.
   -Logging : Custom Logging switch to output install information
   -CopyLogToRepository : Use a remote location to copy log files. ## Currently set on line 346 'Destination = "\\JERSEY\Log_repository\BIOS Upgrade\$HPModel"' Change destination string ##
   -SuppressReboot : Prevent reboot from happening
.OUTPUTS
   If set to 'Logging' the following could be displayed in the Log file:

    START: For HP EliteDesk 800 G2 SFF

    SUCCESS: This Computer matches model HP EliteDesk 800 G2 SFF..

    SETTING: 'TPM Device'
    SETTING: 'TPM State'
    SETTING: 'UEFI Boot Options'
    SUCCESS: Setting 'TPM State' is correct, No Action Required

    SUCCESS: Setting 'TPM Device' is correct, No Action Required

    INFO: UEFI Boot Options is set incorrectly..will change setting to desired configuration value..

    Name              Value  
    ----              -----  
    UEFI Boot Options Disable

    SUCCESS: Bios value UEFI Boot Options successfully updated

    INFO: Hardware Inventory triggered Successfully
    INFO: Machine Policy Retrieval & Evaluation cycle triggered Successfully
    INFO: Script took 00:01:24 to run.

    END: 1/3 BIOS settings have been corrected
     Script Completed

.NOTES
   Written by Graham Beer
.COMPONENT
   'BiosConfigUtility.exe'
.ROLE
   To be used within SCCM to correct settings remotely
.FUNCTIONALITY
   Remote Configuration tool
#>
   
[Cmdletbinding()]
param ( 
    [Parameter()]
    [string] $DesiredSettingCSV = "HP800BiosTemplate.csv",

    [Parameter()]
    [string] $HPModel,

    [Parameter()]
    [string] $BiosEncrytedPW,

    [Parameter()]
    [string] $Flag,

    [Parameter()]
    [switch] $logging,

    [Parameter()]
    [switch] $CopyLogToRepository,
     
    # Suppress reboot. Mainly for Testing.
    [Parameter()]
    [switch] $SupressReboot
)

begin {
    #######################
    ## Pre Script Checks ##
    #######################
 
    # Check for 'BIOSConfigUtility.exe before starting'
    $HPTools = 'C:\Program Files (x86)\HP\BIOS Configuration Utility' # Set directory
 
    if (-not((Get-ChildItem $HPTools).name.Contains('BiosConfigUtility.exe'))) {
        "Bios tools do not exist on machine. Script will terminate" | 
            Out-File $LogFile -Encoding ascii -Append -Force ; Break
    }

    # Check for log directory and create if does not exist
    if ($logging) {
        $logDirectory = 'C:\Program Files (x86)\HP\BIOS Update Logs'
        if (-not(test-path $logDirectory)) { $null = mkdir $logDirectory }
        # Set log variable
        $LogFile = "C:\Program Files (x86)\HP\BIOS Update Logs\$($env:COMPUTERNAME + '_' + [datetime]::now.ToString("ddMMyy-hhmmtt")).log"
    }
 
    ####################
    ## Model specific ##
    ####################

    # !! This is for script is for..
    if ($logging) { "START: For $HPModel`n" | Out-File $LogFile -Encoding ascii -Append -Force } 
 
    # Set Model variable as read-only 
    Set-Variable -Name Model -Value $HPModel -Option ReadOnly
 
    # Check machine model
    if ((Get-CimInstance win32_computersystem).Model -ne $HPModel) {
        "!!ERROR: This is for $HPModel ONLY !!`n" | 
            Out-File $LogFile -Encoding ascii -Append -Force ; break
    }
    else {
        if ($logging) { "SUCCESS: This Computer matches model $HPModel..`n" | Out-File $LogFile -Encoding ascii -Append -Force }    
    }
       
    ###############################################################################
    ## Amend settings after reset to required values in 'BiosSettingsToCheck.csv ##
    ###############################################################################
 
    # Get script duration. Start the clock !
    $Start = [System.Diagnostics.Stopwatch]::StartNew()

    # Create 'hashtable' and add Desired settings 
    $hash = @{}
    $Settings = Import-Csv $DesiredSettingCSV -Header Name, Value
 
    # If setting 'Asset Tracking Number' in CSV, then update Hash with correct value
    if ($($settings.name) -contains 'Asset Tracking Number') {
        ($Settings | Where-Object name -eq 'Asset Tracking Number').value = $env:COMPUTERNAME
    }
    # Add to Hashtable    
    $hash.Add("Desired", $Settings) 

    # BIOSConfigUtility.exe location
    $BIOSConfigUtilityexe = 'C:\Program Files (x86)\HP\BIOS Configuration Utility\BiosConfigUtility.exe'

    # Empty array to capture PC Settings
    $PCSettings = @{}
     
    # Get required Values from current device
    $Names = $hash.Values.name
 
    # Starting note
    if ($logging) {
        "STARTING: Collecting current BIOS configuration for: `n" + $($names | ForEach-Object {"SETTING: '$_''"}) -split "[\n]|'\s+" |
            Out-File $LogFile -Encoding ascii -Append -Force
    }
    
    $names | ForEach-Object {
        $Result = & $BIOSConfigUtilityexe /getvalue:"$_"
     
        # Convert to XML 
        $BiosSettings = [xml]$Result
        if ($BiosSettings.BIOSCONFIG.SETTING.VALUE.InnerText -match '\*') {
            $PCSettings.Add( $($BiosSettings.BIOSCONFIG.SETTING.name), $(($BiosSettings.BIOSCONFIG.SETTING.VALUE.InnerText -split "," | 
                            select-string -SimpleMatch '*') -replace '[*?\{]', '' ) )
        } 
        else {
            $PCSettings.Add( $($BiosSettings.BIOSCONFIG.SETTING.name), $($BiosSettings.BIOSCONFIG.SETTING.VALUE.InnerText) )
        }
    }

} # End of Begin block

process {
    # Check and amend settings if incorrect
    # BIOSConfigUtility Syntax '/setvalue:"setting","value"' (Value is case sensitive!)
    # Hashtable containing required BIOS Name and Desired Value
    # Check the PC Bios Settings against desired configuration and correct if incorrect

    # Registry Path Location
    [string]$Script:path = 'HKLM:\Software\BU\HP\BiosData' 
 
    # counter
    $counter = 0
         
    # Add PC settings 'Hashtable' to create multiple hash table
    $hash.Add("CurrentConfig", $PCSettings)
 
    if ($logging) { "INFO: Checking to see if settings are correct..`n" | Out-File $LogFile -Encoding ascii -Append -Force }

    ###################################
    ## Run main 'Foreach' code block ##
    ###################################
 
    # Main Code. Check Settings and correct if incorrect       
    $hash.item("CurrentConfig").GetEnumerator() | ForEach-Object { 
     
        $CurrentConfigName = $_.name # Value Name passed from "CurrentConfig" 
     
        # Desired value matching current Config value
        $DesiredValue = ($hash.item("Desired") | Where-Object name -like "$CurrentConfigName").value
    
        # If 'CurrentConfig' is Not in 'Desired' then correct, else no action required
        If (($_.value) -notin $DesiredValue) {
            # if -notin match We must correct Bios Setting !
                   
            if ($logging) {
                "`nINFO: $($_.name) is set incorrectly..will change setting to desired configuration value.." |
                    Out-File $LogFile -Encoding ascii -Append -Force
            }
         
            # Set count for corrections
            $counter++
                                 
            # Find correct value from "Desired Configuration"
            $DesiredSetting = $hash.item("Desired") | Where-Object name -eq "$CurrentConfigName" 
         
            $DesiredSetting | Out-File $LogFile -Encoding ascii -Append -Force

            # Run Bios Configuration tool to correct key apeend to Variable for check        
            $PostCheck = & $BIOSConfigUtilityexe /cpwdfile:$BiosEncrytedPW /setvalue:"$($desiredSetting.name),$($desiredSetting.Value)"
                    
            if ( ([xml]$PostCheck).BIOSCONFIG | Get-Member | Where-Object { $_.name -eq "SUCCESS" } ) {
                if ($logging) {
                    "SUCCESS: Bios value $( ([xml]$PostCheck).BIOSCONFIG.SETTING.name ) successfully updated" |
                        Out-File $LogFile -Encoding ascii -Append -Force 
                }
            }
            else {
                "ERROR: Bios value '$CurrentConfigName' Failed, error '$(([xml]$PostCheck).BIOSCONFIG.ERROR.msg[0])'`n" |
                    Out-File $LogFile -Encoding ascii -Append -Force
            }

            $RegistryUpdate = @{
                Name         = $( ([xml]$PostCheck).BIOSCONFIG.SETTING.name )  
                Value        = $( ([xml]$PostCheck).BIOSCONFIG.SETTING.VALUE.'#cdata-section' )
                PropertyType = 'String'
            }
                   
            # Update Registry key to reflect change for Reporting
            try {
                $RegistryUpdate | ForEach-Object { New-ItemProperty -path $path @_ -Force -ea Stop } | out-null
            }
            catch {
                "ERROR: $($_.exception.message)`n" | Out-File $LogFile -Encoding ascii -Append -Force 
            }  
            #Cleanup loop
            'PostCheck', 'RegistryUpdate', 'CurrentConfigName' | ForEach-Object { Remove-Variable $_ -Force }  
        }

        else {
            if ($logging) {
                "SUCCESS: Setting '$CurrentConfigName' is correct, No Action Required`n" |
                    Out-File $LogFile -Encoding ascii -Append -Force 
            } 
        }
    }
} # End of process block

end {
    #update Date on when script was run
    $NewDate = @{
        Name         = 'aScript Run Date' # 'a' added to put value to top of registry list
        Value        = [datetime]::Now
        PropertyType = 'String'
    }
  
    $null = New-ItemProperty -path $Script:path @NewDate -Force

    # Set Flag
    $FlagCreator = new-item -Path 'c:\windows\temp\' -name $($flag + '.flg') -Value $([datetime]) -Force

    if (-not($FlagCreator.Exists)) {
        # error creating flag file
        break ;
        "ERROR: failed to create flag!" | Out-File $LogFile -Encoding ascii -Append -Force  
    }

    # Trigger Hardware Inventory scan before restart                  
    # WMIClass
    $SMSCli = [wmiclass]"\\$ENV:COMPUTERNAME\root\ccm:SMS_Client"
 
    # SCCM TriggerID
    $HWinv = "{00000000-0000-0000-0000-000000000001}" # HW Inventory
    $MPR = "{00000000-0000-0000-0000-000000000021}" # Machine Policy Retrieval & Evaluation cycle

    # Run Scans (Suppress output)
    $HWinv, $MPR | ForEach-Object { $SMSCli.TriggerSchedule($_) } | out-null
    "INFO: Hardware Inventory triggered Successfully" | Out-File $LogFile -Encoding ascii -Append -Force
    "INFO: Machine Policy Retrieval & Evaluation cycle triggered Successfully" | Out-File $LogFile -Encoding ascii -Append -Force

    if ($logging) {
        # Stop the clock!
        $Start.stop()
        if ($counter -eq [int]0) {
            "INFO: Script took $($start.Elapsed.ToString().substring(0,8)) to run.`n", 
            "END: No BIOS changes required from the $($Names.count) checked.`n",  
            "END: Script Completed" | 
                Out-File $LogFile -Encoding ascii -Append -Force
        }
        else {
            "INFO: Script took $($start.Elapsed.ToString().substring(0,8)) to run.`n", 
            "END: $counter/$($Names.count) BIOS settings have been corrected`n Script Completed" | 
                Out-File $LogFile -Encoding ascii -Append -Force
        }
    }
 
    # Switch: Copy "logging" files to server Repository. Folder name defined by '$HPModel' 
    if ($CopyLogToRepository) {
        $CopyArgs = @{ 
            Path        = $LogFile
            Destination = "\\JERSEY\Log_repository\BIOS Upgrade\$HPModel"
            Force       = $true
        }
        $null = Copy-Item @CopyArgs      
    }            

    # Switch: Suppress restart
    if (-not ($SupressReboot)) {   
        # Restart the machine to apply BIOS changes
        Restart-Computer -Force
    }

} # End of the end block 