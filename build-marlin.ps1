if ($host.version.major -lt 6) {
    throw "This script requires PowerShell version 6.0 or higher"
}

$GitResetHard=$false
$upgradeio = $false
$configonly = $false
$useconfig = $false
$silent = $false
$MarlinRoot = "."
$ConfigFile=""
$buildargs = "--silent"
$PIOVENV = "$env:USERPROFILE\.platformio\penv"

. "$PIOVENV\scripts\Activate.ps1"

function Get-MarlinExampleConfig {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ExamplePath,
        [Parameter(Mandatory=$false)]
        [string]$Branch="bugfix-2.0.x",
        [Parameter(Mandatory=$false)]
        [string[]]$Files=@("Configuration.h","Configuration_adv.h","_Bootscreen.h","_Statusscreen.h"),
        [Parameter(Mandatory=$false)]
        [string]$MarlinRoot = "."
    )

    foreach($file in $Files) {
        Write-Output "Using $file from $Branch example $ExamplePath"
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest `
         -Uri "https://raw.githubusercontent.com/MarlinFirmware/Configurations/$Branch/config/examples/$ExamplePath/$file" `
         -OutFile "$MarlinRoot\Marlin\$file" 
         $ProgressPreference = 'Continue'
    }
}

function Enable-MarlinConfigOption {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Option,
        [Parameter(Mandatory=$false)]
        [string]$MarlinRoot = ".",
        [Parameter(Mandatory=$false)]
        [bool]$silent = $false
    )
    $Conf = Get-Content "$MarlinRoot\Marlin\Configuration.h"    

    if ( ($Conf -match "^(\s*)(\/\/)?(\s*)#define $Option(\s*\/\/.*)?$").Length -ne 0 ) {
        if (-not $silent) {Write-Output "Configuration option enabled: $Option"}
        $NewConf = $Conf -replace "^(\s*)(\/\/)?(\s*)#define $Option(\s*\/\/.*)?$", "`$1`$3#define $Option`$4"
        Set-Content -Path "$MarlinRoot\Marlin\Configuration.h" -Value $NewConf
        return
    }

    $Conf = Get-Content "$MarlinRoot\Marlin\Configuration_adv.h"

    if ( ($Conf -match "^(\s*)(\/\/)?(\s*)#define $Option(\s*\/\/.*)?$").Length -ne 0 ) {
        if (-not $silent) {Write-Output "Advanced configuration option enabled: $Option"}
        $NewConf = $Conf -replace "^(\s*)(\/\/)?(\s*)#define $Option(\s*\/\/.*)?$", "`$1`$3#define $Option`$4"
        Set-Content -Path "$MarlinRoot\Marlin\Configuration_adv.h" -Value $NewConf
        return
    }

    throw "Option not found: $Option"
}

function Disable-MarlinConfigOption {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Option,
        [Parameter(Mandatory=$false)]
        [string]$MarlinRoot = ".",
        [Parameter(Mandatory=$false)]
        [bool]$silent = $false
    )
    $Conf = Get-Content "$MarlinRoot\Marlin\Configuration.h"    

    if ( ($Conf -match "^(\s*)(\/\/)?(\s*)#define $Option(\s*\/\/.*)?$").Length -ne 0 ) {
        if (-not $silent) { Write-Output "Configuration option disabled: $Option"}
        $NewConf = $Conf -replace "^(\s*)(\/\/)?(\s*)#define $Option(\s*\/\/.*)?$", "`$1//`$3#define $Option`$4"
        Set-Content -Path "$MarlinRoot\Marlin\Configuration.h" -Value $NewConf
        return
    }

    $Conf = Get-Content "$MarlinRoot\Marlin\Configuration_adv.h"

    if ( ($Conf -match "^(\s*)(\/\/)?(\s*)#define $Option(\s*\/\/.*)?$").Length -ne 0 ) {
        if (-not $silent) {Write-Output "Advanced configuration option disabled: $Option"}
        $NewConf = $Conf -replace "^(\s*)(\/\/)?(\s*)#define $Option(\s*\/\/.*)?$", "`$1//`$3#define $Option`$4"
        Set-Content -Path "$MarlinRoot\Marlin\Configuration_adv.h" -Value $NewConf
        return
    }

    throw "Option not found: $Option"
}

function Add-MarlinConfigOption {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Option,
        [Parameter(Mandatory=$true)]
        [string]$Value,
        [Parameter(Mandatory=$false)]
        [string]$MarlinRoot = "."
    )

    "`n#define $Option $Value" | Add-Content -Path $MarlinRoot\Marlin\Configuration.h
}

function Set-MarlinConfigOption {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Option,
        [Parameter(Mandatory=$true)]
        [string]$Value,
        [Parameter(Mandatory=$false)]
        [string]$MarlinRoot = ".",
        [Parameter(Mandatory=$false)]
        [bool]$silent = $false
    )
    $Conf = Get-Content "$MarlinRoot\Marlin\Configuration.h"    

    if ( ($Conf -match "^(\s*)(\/\/)?(\s*)#define $Option (.*?)(\s*\/\/.*)?$").Length -ne 0 ) {
        if (-not $silent) {Write-Output "Configuration option set: $Option -> $Value"}
        $NewConf = $Conf -replace "^(\s*)(\/\/)?(\s*)#define $Option (.*?)(\s*\/\/.*)?$", "`$1`$3#define $Option $Value`$5"
        Set-Content -Path "$MarlinRoot\Marlin\Configuration.h" -Value $NewConf
        return
    }

    $Conf = Get-Content "$MarlinRoot\Marlin\Configuration_adv.h"

    if ( ($Conf -match "^(\s*)(\/\/)?(\s*)#define $Option (.*?)(\s*\/\/.*)?").Length -ne 0 ) {
        if (-not $silent) {Write-Output "Advanced configuration option set: $Option -> $Value"}
        $NewConf = $Conf -replace "^(\s*)(\/\/)?(\s*)#define $Option (.*?)(\s*\/\/.*)?$", "`$1`$3#define $Option $Value`$5"
        Set-Content -Path "$MarlinRoot\Marlin\Configuration_adv.h" -Value $NewConf
        return
    }

    Write-Warning "Option not found, adding: $Option -> $Value"
    Add-MarlinConfigOption -MarlinRoot $MarlinRoot -Option $Option -Value $Value
}

for ( $i = 0; $i -lt $args.count; $i++) {
    if ( $args[$i] -eq "--git-reset" ) { 
        $GitResetHard = $true 
        continue
    }
    if ( $args[$i] -eq "--configonly" ) { 
        $configonly = $true 
        continue
    }
    if ( $args[$i] -eq "--upgradeio" ) { 
        $upgradeio = $true 
        continue
    }
    if ( $args[$i] -eq "--silent" ) { 
        $silent = $true 
        continue
    }
    if ( $args[$i] -eq "--config" ) {
        if ($i -gt $args.Count -1) {
            throw "You must supply a filename for --config"
        }
        $useconfig = $true
        $ConfigFile = $args[$i+1]
        $i++
        continue
    }
    if ( $args[$i] -eq "--marlin-root" ) {
        if ($i -gt $args.Count -1) {
            throw "You must supply a path for --marlin-root"
        }
        $MarlinRoot = $args[$i+1]
        $i++
        continue
    }
    if ( $args[$i] -eq "--buildargs" ) {
        if ($i -gt $args.Count -1) {
            throw "You must supply arguments for --buildargs"
        }
        $buildargs = $args[$i+1]
        $i++
        continue
    }

    throw "Unknown option " + $args[$i]
}

# default function parameter values
$PSDefaultParameterValues["Set-MarlinConfigOption:MarlinRoot"] = "$MarlinRoot"
$PSDefaultParameterValues["Enable-MarlinConfigOption:MarlinRoot"] = "$MarlinRoot"
$PSDefaultParameterValues["Disable-MarlinConfigOption:MarlinRoot"] = "$MarlinRoot"
$PSDefaultParameterValues["Get-MarlinExampleConfig:MarlinRoot"] = "$MarlinRoot"

# enable verbose mode for functions
if ($silent) {
    $PSDefaultParameterValues["Set-MarlinConfigOption:silent"] = $true
    $PSDefaultParameterValues["Enable-MarlinConfigOption:silent"] = $true
    $PSDefaultParameterValues["Disable-MarlinConfigOption:silent"] = $true
}

if ( $GitResetHard ) {
    Write-Warning "Resetting the Marlin sources at $MarlinRoot"
    Push-Location -Path $MarlinRoot
    git reset --hard
    Pop-Location
}

if ($useconfig) {
    if ( -not (Test-Path -Path $ConfigFile)) {
        throw "$ConfigFile not found"
    }

    $Config = (Get-Content -Path $ConfigFile | ConvertFrom-Json -AsHashtable)

    if ($Config.useExample) {
        $Branch = "bugfix-2.0.x"
        $Files = @("Configuration.h","Configuration_adv.h","_Bootscreen.h","_Statusscreen.h")
        $Path = $config.useExample.path

        if ($config.useExample.branch) { $Branch = $config.useExample.branch }
        if ($config.useExample.files) { $Files = $config.useExample.files }

        Get-MarlinExampleConfig -Branch $Branch -Files $Files -ExamplePath $Path
    }

    if ($Config.options) {
        Write-Output "Configuring from $ConfigFile"
        foreach ($Option in $Config.options.keys) {
            if ($Config.options[$Option] -is [System.Boolean]) {
                if ($Config.options[$Option] -eq $true) { Enable-MarlinConfigOption -Option $Option }
                elseif ($Config.options[$Option] -eq $false) { Disable-MarlinConfigOption -Option $Option }
            } else {
                Set-MarlinConfigOption -Option $Option -Value $Config.options[$Option]
            }
        }
    }
}

# Build Logic
if (-not $configonly) {
    if ($upgradeio) {
        # check for platform io updates
        Write-Output "PlatformIO: Checking for Updates..."
        platformio upgrade
        platformio update
    }

    if (-not $useconfig) {Write-Output "No Config Specified, Compiling in $MarlinRoot."}

    # clean
    Write-Output "PlatformIO: Cleaning..."
    platformio run --target clean --project-dir $MarlinRoot $buildargs

    # build
    Write-Output "PlatformIO: Building..."
    platformio run --project-dir $MarlinRoot $buildargs

    Write-Output "Done."
}
else {
    if ($upgradeio) {
        Write-Output "Config Only Set, Not Compiling or Upgrading IO..."
    }
    else {
        Write-Output "Config Only Set, Not Compiling..."
    }
    
}
