<#
.Synopsis
   Copying tool - in this instance for HP BIOS Configuration Utility  
   Also contains a remove 'Switch' to delete files and Directory.
.EXAMPLE
   ./HP_BIOSConfig_Setup.ps1
.COMPONENT
   The component this cmdlet belongs to SCCM
.CREATOR
   By Graham Beer
   DTLK Ltd 
#>
    [cmdletbinding()]
    Param (
        # Parameter help description
        [Parameter()]
        [switch]$Removal,
        
        [Parameter()]
        [string]$Path = 'C:\Program Files (x86)\HP'
    )

# Set Copy Location
$CopyItem = "$ScriptPath\BIOS Configuration Utility"

# If 'Removal' Switch
if ($Removal) {
    if (Test-Path $path) {
        try {
            remove-item -Path $path -Recurse -Force -ErrorAction Stop
            write-verbose "Directory '$Path' and containing files have been removed"
        }
        catch [System.Exception] {
            Write-Warning $_.exception.message
        }
    }
}
Else { # Create folder and files 
        # Check for path and create if does not exist
    if (-not(Test-Path $path)) {
        try {
            [void](mkdir -Path $path -Force -ErrorAction Stop)
            write-verbose "successfully created directory '$path'"
        }
        catch [System.Exception] {
            Write-Warning $_.exception.message
        }
    } 
    Else {
        write-verbose "Directory '$path' already exists"
    }
    # Perform copy 
    if  ((Get-Childitem $path -Recurse | measure).count -ne [int]6) {
        try {
            # Set location of items to copy
            $CopyItem = "$(Split-Path $MyInvocation.MyCommand.Path)\BIOS Configuration Utility"
            
            Copy-Item $CopyItem -Destination $path -Recurse -Force -ErrorAction Stop 
            write-verbose "'$CopyItem' successfully copied to '$path'"
        }
        catch [System.Exception] {
            Write-Warning $_.exception.message
        }
    }
    Else {
        write-verbose "Directory contains the correct amount of files, '6'"
    }
}
# End Script