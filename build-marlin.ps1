#
# marlin-build.ps1
# See github for info: https://github.com/mydevpeeps/build-marlin
#

# we require powershell 6.0 or higher to run
if ($host.version.major -lt 6) {
    throw "This script requires PowerShell version 6.0 or higher"
}

# Platform IO Environment
$PIOVENV = "$env:USERPROFILE\.platformio\penv"
. "$PIOVENV\scripts\Activate.ps1"

# global defaults
$ConfigFile=""
$MarlinRoot = "."
$buildargs = ""
$GitResetHard=$false
$upgradeio = $false
$configonly = $false
$useconfig = $false
$preferargs = $false
$silent = $false
$release = "0.1"
#$has_args = $false

#intro
Write-Output ""
Write-Output "marlin-build.ps1 v$release Copyright 2021"
Write-Output ""

# pulls the example marlin config
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

    if (-not $silent)  { Write-Output "   Example Config $ExamplePath from $Branch" }
    foreach($file in $Files) {
        if (-not $silent)  { Write-Output "    Downloading $file" }
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest `
         -Uri "https://raw.githubusercontent.com/MarlinFirmware/Configurations/$Branch/config/examples/$ExamplePath/$file" `
         -OutFile "$MarlinRoot\Marlin\$file" 
         $ProgressPreference = 'Continue'
    }
}

# enables boolean directive
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
        if (-not $silent)  { Write-Output "      Configuration option enabled: $Option" }
        $NewConf = $Conf -replace "^(\s*)(\/\/)?(\s*)#define $Option(\s*\/\/.*)?$", "`$1`$3#define $Option`$4"
        Set-Content -Path "$MarlinRoot\Marlin\Configuration.h" -Value $NewConf
        return
    }

    $Conf = Get-Content "$MarlinRoot\Marlin\Configuration_adv.h"

    if ( ($Conf -match "^(\s*)(\/\/)?(\s*)#define $Option(\s*\/\/.*)?$").Length -ne 0 ) {
        if (-not $silent) { Write-Output "      Advanced configuration option enabled: $Option" }
        $NewConf = $Conf -replace "^(\s*)(\/\/)?(\s*)#define $Option(\s*\/\/.*)?$", "`$1`$3#define $Option`$4"
        Set-Content -Path "$MarlinRoot\Marlin\Configuration_adv.h" -Value $NewConf
        return
    }

    throw "Option not found: $Option"
}

# disables boolean directive
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
        if (-not $silent) { Write-Output "      Configuration option disabled: $Option"}
        $NewConf = $Conf -replace "^(\s*)(\/\/)?(\s*)#define $Option(\s*\/\/.*)?$", "`$1//`$3#define $Option`$4"
        Set-Content -Path "$MarlinRoot\Marlin\Configuration.h" -Value $NewConf
        return
    }

    $Conf = Get-Content "$MarlinRoot\Marlin\Configuration_adv.h"

    if ( ($Conf -match "^(\s*)(\/\/)?(\s*)#define $Option(\s*\/\/.*)?$").Length -ne 0 ) {
        if (-not $silent) {Write-Output "      Advanced configuration option disabled: $Option"}
        $NewConf = $Conf -replace "^(\s*)(\/\/)?(\s*)#define $Option(\s*\/\/.*)?$", "`$1//`$3#define $Option`$4"
        Set-Content -Path "$MarlinRoot\Marlin\Configuration_adv.h" -Value $NewConf
        return
    }

    throw "Option not found: $Option"
}

# adds a config option if it's not there already
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

# replaces the value for a config item, enabling it if it was disabled
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
        if (-not $silent) {Write-Output "      Configuration option set: $Option -> $Value"}
        $NewConf = $Conf -replace "^(\s*)(\/\/)?(\s*)#define $Option (.*?)(\s*\/\/.*)?$", "`$1`$3#define $Option $Value`$5"
        Set-Content -Path "$MarlinRoot\Marlin\Configuration.h" -Value $NewConf
        return
    }

    $Conf = Get-Content "$MarlinRoot\Marlin\Configuration_adv.h"

    if ( ($Conf -match "^(\s*)(\/\/)?(\s*)#define $Option (.*?)(\s*\/\/.*)?").Length -ne 0 ) {
        if (-not $silent) {Write-Output "      Advanced configuration option set: $Option -> $Value"}
        $NewConf = $Conf -replace "^(\s*)(\/\/)?(\s*)#define $Option (.*?)(\s*\/\/.*)?$", "`$1`$3#define $Option $Value`$5"
        Set-Content -Path "$MarlinRoot\Marlin\Configuration_adv.h" -Value $NewConf
        return
    }

    Write-Warning "   Option not found, adding: $Option -> $Value"
    Add-MarlinConfigOption -MarlinRoot $MarlinRoot -Option $Option -Value $Value
}

# get all the command-line args
for ( $i = 0; $i -lt $args.count; $i++) {
    #$has_args = $true
    if ( $args[$i] -eq "--preferargs" ) { 
        $preferargs = $true 
        continue
    }

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
        $arg_MarlinRoot = $args[$i+1]
        $MarlinRoot = $args[$i+1]
        $i++
        continue
    }

    if ( $args[$i] -eq "--buildargs" ) {
        if ($i -gt $args.Count -1) {
            throw "You must supply arguments for --buildargs"
        }
        $arg_buildargs = $args[$i+1]
        $buildargs = $args[$i+1]
        $i++
        continue
    }

    throw "Unknown option " + $args[$i]
}

# set the default marlin root build path for functions
$PSDefaultParameterValues["Set-MarlinConfigOption:MarlinRoot"] = "$MarlinRoot"
$PSDefaultParameterValues["Enable-MarlinConfigOption:MarlinRoot"] = "$MarlinRoot"
$PSDefaultParameterValues["Disable-MarlinConfigOption:MarlinRoot"] = "$MarlinRoot"
$PSDefaultParameterValues["Get-MarlinExampleConfig:MarlinRoot"] = "$MarlinRoot"

# enable silent mode for functions
if ($silent) {
    $PSDefaultParameterValues["Set-MarlinConfigOption:silent"] = $true
    $PSDefaultParameterValues["Enable-MarlinConfigOption:silent"] = $true
    $PSDefaultParameterValues["Disable-MarlinConfigOption:silent"] = $true
}

# reset git if requested
if ( $GitResetHard ) {
    Write-Warning "Resetting the Marlin sources at $MarlinRoot"
    Push-Location -Path $MarlinRoot
    git reset --hard
    Pop-Location
}

# if we are using a config file than parse it for config changes
if ($useconfig) {
    if ( -not (Test-Path -Path $ConfigFile)) {
        throw "$ConfigFile not found"
    }

     if (-not $silent) { Write-Output "Configuring from $ConfigFile" }
    $Config = (Get-Content -Path $ConfigFile | ConvertFrom-Json -AsHashtable)

    if ($Config.settings) {
        if (-not $silent) { Write-Output "   Processing JSON Settings ..." }
        #no conflicts for true/false. All default to false and any true flips to true.
        if ($config.settings.silent -is [System.Boolean]) { 
            $json_silent = $config.settings.silent
            if ($json_silent -eq $true) {
                $silent = $true
                $PSDefaultParameterValues["Set-MarlinConfigOption:silent"] = $true
                $PSDefaultParameterValues["Enable-MarlinConfigOption:silent"] = $true
                $PSDefaultParameterValues["Disable-MarlinConfigOption:silent"] = $true
            }
            if (-not $silent) { Write-Output "      Silent Mode : $silent" }
        }
        if ($config.settings.upgradeio -is [System.Boolean]) { 
            $json_upgradeio = $config.settings.upgradeio
            if ($json_upgradeio -eq $true) {
                $upgradeio = $true
            }
            if (-not $silent) { Write-Output "      Upgrade IO : $upgradeio" }
        }
        if ($config.settings.gitreset -is [System.Boolean]) { 
            $json_gitreset = $config.settings.gitreset
            if ($json_gitreset -eq $true) {
                $GitResetHard = $true
            }
            if (-not $silent) { Write-Output "      GIT Hard Reset : $GitResetHard" }
        }
        if ($config.settings.configonly -is [System.Boolean]) { 
            $json_configonly = $config.settings.configonly
            if ($json_configonly -eq $true) {
                $configonly = $true
            }
            if (-not $silent) { Write-Output "      Config Only : $configonly" }
        }
        if ($config.settings.buildargs) { 
            $json_buildargs = $config.settings.buildargs 
            if (-not $silent) { Write-Output "      PlatformIO Build Args [JSON]: $json_buildargs" }
            if (-not $silent) { Write-Output "      PlatformIO Build Args [ARGS]: $arg_buildargs" }
        }
        if ($config.settings.marlinroot) { 
            $json_marlinroot = $config.settings.marlinroot 
            if (-not $silent) { Write-Output "      Marlin Root Path [JSON]: $json_marlinroot" }
            if (-not $silent) { Write-Output "      Marlin Root Path [ARGS]: $arg_marlinroot" }
            if (-not $json_marlinroot -eq $arg_marlinroot) {
                if ($preferargs) {
                    $MarlinRoot = $arg_marlinroot
                    $PSDefaultParameterValues["Set-MarlinConfigOption:MarlinRoot"] = "$MarlinRoot"
                    $PSDefaultParameterValues["Enable-MarlinConfigOption:MarlinRoot"] = "$MarlinRoot"
                    $PSDefaultParameterValues["Disable-MarlinConfigOption:MarlinRoot"] = "$MarlinRoot"
                    $PSDefaultParameterValues["Get-MarlinExampleConfig:MarlinRoot"] = "$MarlinRoot"
                }
                else {
                    throw "Settings Conflict: JSON [marlinroot = $json_marlinroot]; ARGS [--marlin=root $arg_marlinroot]. Use --perferargs to override, don't use --marlinroot, or change the value in the JSON config."
                }
            }
        }
    }
    
    if ($Config.useExample) {
        if (-not $silent) { Write-Output "   Processing JSON Config Example ..." }
        $Branch = "bugfix-2.0.x"
        $Files = @("Configuration.h","Configuration_adv.h","_Bootscreen.h","_Statusscreen.h")
        $Path = $config.useExample.path

        if ($config.useExample.branch) { $Branch = $config.useExample.branch }
        if ($config.useExample.files) { $Files = $config.useExample.files }

        Get-MarlinExampleConfig -Branch $Branch -Files $Files -ExamplePath $Path
    }

    if ($Config.options) {
        if (-not $silent) { Write-Output "   Processing JSON Options ..." }
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
