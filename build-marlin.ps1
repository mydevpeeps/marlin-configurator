#
# marlin-build.ps1
# See github for info: https://github.com/mydevpeeps/build-marlin
#

# clear out all old crap first
Remove-Variable * -ErrorAction SilentlyContinue
#Remove-Module *
#$error.Clear()
#Clear-Host

# global defaults
$ConfigFile = ""
$MarlinRoot = "."
$buildargs = ""
$GitResetHard=$false
$upgradeio = $false
$configonly = $false
$useconfig = $false
$preferargs = $false
$silent = $false
$release = "0.11-alpha"
$year = get-date -f yyyy

# we require powershell 6.0 or higher to run
if ($host.version.major -lt 6) {
    Exit-Stage-Left -Code 4
}

# display a message in a specific color
function Write-Message {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Msg,
        [Parameter(Mandatory=$false)]
        [string]$Color = ""
    )
    if (-not $Color) {$Color = "White"}   # default value for $Color
    Write-Host -ForegroundColor $Color "$Msg"
}

# Exit with message based on error code
function Exit-Stage-Left {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Code,
        [Parameter(Mandatory=$false)]
        [string]$Color = "",
        [Parameter(Mandatory=$false)]
        [string]$Msg = " "
    )

    if (-not $Color) {$Color = "White"}     # default value for $Color
    if (-not $Msg) { $Msg = " " }           # default must be a space or it will break Write-Host cmdlet

    # display a message based on $Code
    # 00-09 : core errors
    # 10-29: configuration issues
    # 30-49: command-line arguement errors
    # 50-69: conflicts

    Write-Message -Msg " "
    if ($Msg -eq " ") {
        #when no $Msg is sent, use generic message
        switch ($Code) {
            #0   {Write-Message -Color $Color -Msg "Exit ($Code):  "}
            0 {Write-Message -Color $Color -Msg "Exit ($Code): Build Executed"}
            1 {Write-Message -Color $Color -Msg "Exit ($Code): Help Information Requested"}
            2 {Write-Message -Color $Color -Msg "Exit ($Code): PlatformIO Environment Not Found"}
            3 {Write-Message -Color $Color -Msg "Exit ($Code): Configuration Only"}
            4 {Write-Message -Color $Color -Msg "Exit ($Code): This script requires PowerShell version 6.0 or higher"}
            10 {Write-Message -Color $Color -Msg "Exit ($Code): Configuration Directive Not Found"}
            30 {Write-Message -Color $Color -Msg "Exit ($Code): Invalid Command-Line Option"}
            31 {Write-Message -Color $Color -Msg "Exit ($Code): You must supply a filename for --config"}
            32 {Write-Message -Color $Color -Msg "Exit ($Code): You must supply a path for --marlin-root"}
            33 {Write-Message -Color $Color -Msg "Exit ($Code): You must supply arguments for --buildargs"}
            34 {Write-Message -Color $Color -Msg "Exit ($Code): The --config parameter can only be used once"}
            35 {Write-Message -Color $Color -Msg "Exit ($Code): The --marlinroot parameter can only be used once"}
            #50 {Write-Message -Color $Color -Msg "Exit ($Code): $Msg"}
            default {Write-Message -Color $Color -Msg "Exit ($Code): Undefined Error Code"}
        }
    }
    else {
            # used when there is a $Msg to send with the error code
            Write-Message -Color $Color -Msg "Exit ($Code): $Msg"
    }
    Write-Message -Msg " "
    Exit $Code
}

# Platform IO Environment
$PIOVENV = "$env:USERPROFILE\.platformio\penv"
if ( -not (Test-Path -Path $PIOVENV\scripts)) {
    Exit-Stage-Left -Color Red -Code 2
}
else {
    . "$PIOVENV\scripts\Activate.ps1"
}

#intro
Write-Message -Msg " "

Write-Message -Color DarkCyan -Msg "marlin-build.ps1 v$release Copyright $year"
Write-Message -Msg " "

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

    if (-not $silent)  { Write-Message -Color DarkCyan -Msg  "     Example Config $ExamplePath from $Branch" }
    foreach($file in $Files) {
        if (-not $silent)  { Write-Message -Msg "        Downloading $file" }
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
        if (-not $silent)  { Write-Message -Msg "      Configuration option enabled: $Option" }
        $NewConf = $Conf -replace "^(\s*)(\/\/)?(\s*)#define $Option(\s*\/\/.*)?$", "`$1`$3#define $Option`$4"
        Set-Content -Path "$MarlinRoot\Marlin\Configuration.h" -Value $NewConf
        return
    }

    $Conf = Get-Content "$MarlinRoot\Marlin\Configuration_adv.h"

    if ( ($Conf -match "^(\s*)(\/\/)?(\s*)#define $Option(\s*\/\/.*)?$").Length -ne 0 ) {
        if (-not $silent) { Write-Message -Msg "      Advanced configuration option enabled: $Option" }
        $NewConf = $Conf -replace "^(\s*)(\/\/)?(\s*)#define $Option(\s*\/\/.*)?$", "`$1`$3#define $Option`$4"
        Set-Content -Path "$MarlinRoot\Marlin\Configuration_adv.h" -Value $NewConf
        return
    }

    Exit-Stage-Left -Code 10 -Color Red
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
        if (-not $silent) { Write-Message -Msg "      Configuration option disabled: $Option"}
        $NewConf = $Conf -replace "^(\s*)(\/\/)?(\s*)#define $Option(\s*\/\/.*)?$", "`$1//`$3#define $Option`$4"
        Set-Content -Path "$MarlinRoot\Marlin\Configuration.h" -Value $NewConf
        return
    }

    $Conf = Get-Content "$MarlinRoot\Marlin\Configuration_adv.h"

    if ( ($Conf -match "^(\s*)(\/\/)?(\s*)#define $Option(\s*\/\/.*)?$").Length -ne 0 ) {
        if (-not $silent) {Write-Message -Msg "      Advanced configuration option disabled: $Option"}
        $NewConf = $Conf -replace "^(\s*)(\/\/)?(\s*)#define $Option(\s*\/\/.*)?$", "`$1//`$3#define $Option`$4"
        Set-Content -Path "$MarlinRoot\Marlin\Configuration_adv.h" -Value $NewConf
        return
    }

    Exit-Stage-Left -Code 10 -Color Red
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
        if (-not $silent) {Write-Message -Msg "      Configuration option set: $Option -> $Value"}
        $NewConf = $Conf -replace "^(\s*)(\/\/)?(\s*)#define $Option (.*?)(\s*\/\/.*)?$", "`$1`$3#define $Option $Value`$5"
        Set-Content -Path "$MarlinRoot\Marlin\Configuration.h" -Value $NewConf
        return
    }

    $Conf = Get-Content "$MarlinRoot\Marlin\Configuration_adv.h"

    if ( ($Conf -match "^(\s*)(\/\/)?(\s*)#define $Option (.*?)(\s*\/\/.*)?").Length -ne 0 ) {
        if (-not $silent) {Write-Message -Msg "      Advanced configuration option set: $Option -> $Value"}
        $NewConf = $Conf -replace "^(\s*)(\/\/)?(\s*)#define $Option (.*?)(\s*\/\/.*)?$", "`$1`$3#define $Option $Value`$5"
        Set-Content -Path "$MarlinRoot\Marlin\Configuration_adv.h" -Value $NewConf
        return
    }

    Write-Message -Color Yellow -Msg "   Option not found, adding: $Option -> $Value"
    Add-MarlinConfigOption -MarlinRoot $MarlinRoot -Option $Option -Value $Value
}

# get all the command-line args
if ($args.count -gt 0) {
    Write-Message -Color DarkCyan -Msg "Processing Command-Line Arguments"
}

# look for help arg and if so fire off website and ignore the rest and exit
for ( $i = 0; $i -lt $args.count; $i++) {
    if ( $args[$i] -eq "--help" ) { 
        Start-Process msedge.exe "https://github.com/mydevpeeps/build-marlin"
        Exit-Stage-Left -Code 1
        Break
    }
}

# process args
for ( $i = 0; $i -lt $args.count; $i++) {
    if ( $args[$i] -eq "--preferargs" ) { 
        Write-Message -Color Green -Msg "   --preferargs enabled"
        $preferargs = $true 
        continue
    }

    if ( $args[$i] -eq "--git-reset" ) { 
        Write-Message -Color Green -Msg "    --git-reset enabled"
        $GitResetHard = $true 
        continue
    }

    if ( $args[$i] -eq "--configonly" ) { 
        Write-Message -Color Green -Msg "   --configonly enabled"
        $configonly = $true 
        continue
    }

    if ( $args[$i] -eq "--upgradeio" ) { 
        Write-Message -Color Green -Msg "   --upgradeio enabled"
        $upgradeio = $true 
        continue
    }

    if ( $args[$i] -eq "--silent" ) { 
        Write-Message -Color Green -Msg "   --silent enabled"
        $silent = $true 
        continue
    }

    if ( $args[$i] -eq "--config" ) {
        if ($i -gt $args.Count -1) {
            Exit-Stage-Left -Code 31 -Color Red
            Break
        }
        if (-not $useconfig) {
            $useconfig = $true
            $ConfigFile = $args[$i+1]
            $i++
        }
        else {
            Exit-Stage-Left -Code 34 -Color Red
            Break
        }
        continue
    }

    if ( $args[$i] -eq "--marlin-root" ) {
        if ($i -gt $args.Count -1) {
            Exit-Stage-Left -Code 32 -Color Red
            Break
        }
        if(-not $arg_MarlinRoot) {
            $arg_MarlinRoot = $args[$i+1]
            $MarlinRoot = $args[$i+1]
            $i++
        }
        else {
            Exit-Stage-Left -Code 35 -Color Red
            Break
        }
        continue
    }

    # TODO: find a way to parse multiple build args (is it --build-args arg arg2 or is it --build-args arg --build-args arg?)
    # thinking about doing $buildargs += $arg_buildargs if there is more than one... 
    if ( $args[$i] -eq "--buildargs" ) {
        if ($i -gt $args.Count -1) {
            Exit-Stage-Left -Code 33 -Color Red
            Break
        }
        $arg_buildargs = $args[$i+1]
        $buildargs = $args[$i+1]
        $i++
        continue
    }
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
    Write-Message -Color Yellow -Msg "Resetting the Marlin sources at $MarlinRoot"
    Push-Location -Path $MarlinRoot
    git reset --hard
    Pop-Location
}

# if we are using a config file than parse it for config changes
if ($useconfig) {
    if (-not $ConfigFile -eq "") {
        if ( -not (Test-Path -Path $ConfigFile)) {
            Exit-Stage-Left -Code 31 -Color Red
        }
    }
    else {
        Exit-Stage-Left -Code 31 -Color Red
    }

    if (-not $silent) { Write-Message -Color DarkCyan -Msg  "Configuring from $ConfigFile" }
    $Config = (Get-Content -Path $ConfigFile | ConvertFrom-Json -AsHashtable)

    if ($Config.settings) {
        if (-not $silent) { Write-Message -Color DarkCyan -Msg  "   Processing JSON Settings ..." }
        #no conflicts for true/false. All default to false and any true flips to true.
        if ($config.settings.silent -is [System.Boolean]) { 
            $json_silent = $config.settings.silent
            if ($json_silent -eq $true) {
                $silent = $true
                $PSDefaultParameterValues["Set-MarlinConfigOption:silent"] = $true
                $PSDefaultParameterValues["Enable-MarlinConfigOption:silent"] = $true
                $PSDefaultParameterValues["Disable-MarlinConfigOption:silent"] = $true
            }
            if (-not $silent) { Write-Message -Msg "      Silent Mode : $silent" }
        }
        if ($config.settings.upgradeio -is [System.Boolean]) { 
            $json_upgradeio = $config.settings.upgradeio
            if ($json_upgradeio -eq $true) {
                $upgradeio = $true
            }
            if (-not $silent) { Write-Message -Msg "      Upgrade IO : $upgradeio" }
        }
        if ($config.settings.gitreset -is [System.Boolean]) { 
            $json_gitreset = $config.settings.gitreset
            if ($json_gitreset -eq $true) {
                $GitResetHard = $true
            }
            if (-not $silent) { Write-Message -Msg "      GIT Hard Reset : $GitResetHard" }
        }
        if ($config.settings.configonly -is [System.Boolean]) { 
            $json_configonly = $config.settings.configonly
            if ($json_configonly -eq $true) {
                $configonly = $true
            }
            if (-not $silent) { Write-Message -Msg "      Config Only : $configonly" }
        }
        if ($config.settings.buildargs) { 
            $json_buildargs = $config.settings.buildargs 
            if (-not $silent) { Write-Message -Msg "      PlatformIO Build Args [JSON]: $json_buildargs" }
            if (-not ($json_buildargs -eq $arg_buildargs)) {
                if ($arg_buildargs) {
                    if (-not $silent) { Write-Message -Msg "      PlatformIO Build Args [ARGS]: $arg_buildargs" }
                    if ($preferargs) {
                        $buildargs = $arg_buildargs
                    }
                    else {
                        $ErrorMsg = "Settings Conflict -> Platform IO Build Args: Use --preferargs to override, don't use --buildargs, or change the value in the JSON config."
                        Exit-Stage-Left -Code 51 -Color Red -Msg $ErrorMsg
                    }
                }
                else {
                    $buildargs = $json_buildargs
                }
            if (-not $silent) { Write-Message -Msg "      Platform IO Build Args : $buildargs" }
            }
        }
        if ($config.settings.marlinroot) { 
            $json_marlinroot = $config.settings.marlinroot 
            if (-not $silent) { Write-Message -Msg "      Marlin Root Path [JSON]: $json_marlinroot" }
            if (-not ($json_marlinroot -eq $arg_marlinroot)) {
                if ($arg_marlinroot) {
                    if (-not $silent) { Write-Message -Msg "      Marlin Root Path [ARGS]: $arg_marlinroot" }
                    if ($preferargs) {
                        $MarlinRoot = $arg_marlinroot
                    }
                    else {
                        $ErrorMsg = "Settings Conflict -> Marlin Root Path: Use --preferargs to override, don't use --marlnroot, or change the value in the JSON config."
                        Exit-Stage-Left -Code 50 -Color Red -Msg $ErrorMsg
                    }
                }
                else {
                    $MarlinRoot = $json_marlinroot
                }
            $PSDefaultParameterValues["Set-MarlinConfigOption:MarlinRoot"] = "$MarlinRoot"
            $PSDefaultParameterValues["Enable-MarlinConfigOption:MarlinRoot"] = "$MarlinRoot"
            $PSDefaultParameterValues["Disable-MarlinConfigOption:MarlinRoot"] = "$MarlinRoot"
            $PSDefaultParameterValues["Get-MarlinExampleConfig:MarlinRoot"] = "$MarlinRoot"
            if (-not $silent) { Write-Message -Msg "      Marlin Root : $MarlinRoot" }
            }
        }
    }
    
    if ($Config.useExample) {
        if (-not $silent) { Write-Message -Color DarkCyan -Msg  "   Processing JSON Config Example ..." }
        $Branch = "bugfix-2.0.x"
        $Files = @("Configuration.h","Configuration_adv.h","_Bootscreen.h","_Statusscreen.h")
        $Path = $config.useExample.path

        if ($config.useExample.branch) { $Branch = $config.useExample.branch }
        if ($config.useExample.files) { $Files = $config.useExample.files }

        Get-MarlinExampleConfig -Branch $Branch -Files $Files -ExamplePath $Path
    }

    if ($Config.options) {
        if (-not $silent) { Write-Message -Color DarkCyan -Msg  "   Processing JSON Options ..." }
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
        Write-Message -Color DarkCyan -Msg "PlatformIO: Checking for Updates..."
        platformio upgrade
        platformio update
    }

    if (-not $useconfig) {Write-Message -Color Yellow -Msg "No Config Specified, Compiling in $MarlinRoot."}

    # clean
    Write-Message -Color DarkCyan -Msg -Output "PlatformIO: Cleaning..."
    platformio run --target clean --project-dir $MarlinRoot $buildargs

    # build
    Write-Message -Color DarkCyan -Msg  "PlatformIO: Building..."
    platformio run --project-dir $MarlinRoot $buildargs
    Exit-Stage-Left -Code 0
}
else {
    if ($upgradeio) {
        Write-Message -Color Yellow -Msg "Config Only Set, Not Compiling or Upgrading IO..."
    }
    else {
        Write-Message -Color Yellow -Msg "Config Only Set, Not Compiling..."
    }
    Exit-Stage-Left -Code 3 -Color Yellow
}
