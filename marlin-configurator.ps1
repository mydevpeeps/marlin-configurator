#
# marlin-build.ps1
# See github for info: https://github.com/mydevpeeps/build-marlin
#

# clear out all old crap first
Remove-Variable * -ErrorAction SilentlyContinue
#Remove-Module *
#$error.Clear()
#Clear-Host [] # not sure if I want to use this by default. clears all history in shell terminal

# define named parameters. anything outside this is caught in $args
#param(
#    [Parameter(Mandatory=$true)]
#    [string]$targetdir
#)

# global defaults
$ConfigFile = ""
$MarlinRoot = "."
$GitResetHard=$false
$preferargs = $false
$silent = $false
$createdir = $false
$useconfig = $false
$minpsver = "6" # Test-Path has a breaking change at v6.1.2

# release info
$release = "0.11-alpha"
$year = get-date -f yyyy
if ($year -gt 2021) {$year = "2021-$year"}

# check for min powershell version
if ($host.version.major -lt $minpsver) {
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
            0 {Write-Message -Color $Color -Msg "Exit ($Code): Configuration Completed"}
            1 {Write-Message -Color $Color -Msg "Exit ($Code): Help Information Requested"}
            4 {Write-Message -Color $Color -Msg "Exit ($Code): This script requires PowerShell version 6.0 or higher"}
            10 {Write-Message -Color $Color -Msg "Exit ($Code): Configuration Directive Not Found"}
            30 {Write-Message -Color $Color -Msg "Exit ($Code): Invalid Command-Line Option"}
            31 {Write-Message -Color $Color -Msg "Exit ($Code): Target Directory Not Found. Use --createdir option to create it or set in JSON configuration to true."}
            32 {Write-Message -Color $Color -Msg "Exit ($Code): You must supply a valid path for --targetdir"}
            33 {Write-Message -Color $Color -Msg "Exit ($Code): The --config parameter requires a value"}
            34 {Write-Message -Color $Color -Msg "Exit ($Code): The --config parameter can only be used once"}
            35 {Write-Message -Color $Color -Msg "Exit ($Code): The --targetdir parameter can only be used once"}
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

#intro
Write-Message -Msg " "

Write-Message -Color DarkCyan -Msg "marlin-configurator.ps1 v$release Copyright $year"
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

    Write-Message -Color DarkCyan -Msg  "     Example Config $ExamplePath from $Branch" 
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

# sanity check the target directory and create it if it's not there
function Verify-Target-Dir {
    # test to see if target directory exists. If not and --createdir is enabled, create it.
    if ( -not (Test-Path -Path $MarlinRoot)) {
        if ( $createdir ) {
            Write-Message -Color Yellow -Msg "      Created Target Directory : $MarlinRoot" 
            $MakeDir = "$MarlinRoot\Marlin"
            New-Item -Force -ItemType Directory -Path "$MakeDir" | Out-Null
            #confirm path was created
            if ( -not (Test-Path -Path $MarlinRoot)) {
                Exit-Stage-Left -Code 32 -Color Red -Msg "** UNABLE TO CREATE TARGET DIRECTORY **"
            }
        }
        else {
            Exit-Stage-Left -Code 31 -Color Red
        }
    }

    #convert $MarlinRoot to full path in case it's a relative path
    $MarlinRoot = Resolve-Path -LiteralPath $MarlinRoot

    # set the function variables to the target directory by default
    $PSDefaultParameterValues["Set-MarlinConfigOption:MarlinRoot"] = "$MarlinRoot"
    $PSDefaultParameterValues["Enable-MarlinConfigOption:MarlinRoot"] = "$MarlinRoot"
    $PSDefaultParameterValues["Disable-MarlinConfigOption:MarlinRoot"] = "$MarlinRoot"
    $PSDefaultParameterValues["Get-MarlinExampleConfig:MarlinRoot"] = "$MarlinRoot"

    Write-Message -Msg "      Target Directory : $MarlinRoot" 
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

# process args (new method?)

# process args
for ( $i = 0; $i -lt $args.count; $i++) {
    if ( $args[$i] -eq "--createdir" ) { 
        Write-Message -Color Green -Msg "   --createdir enabled"
        $createdir = $true 
        continue
    }

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

    if ( $args[$i] -eq "--silent" ) { 
        Write-Message -Color Green -Msg "   --silent enabled"
        $silent = $true 
        continue
    }

    if ( $args[$i] -eq "--config" ) {
        if ($i -gt $args.Count -1) {
            Exit-Stage-Left -Code 33 -Color Red
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

    if ( $args[$i] -eq "--targetdir" ) {
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
}

# reset git if requested
if ( $GitResetHard ) {
    Write-Message -Color Yellow -Msg "Resetting the Marlin sources at $MarlinRoot"
    Push-Location -Path $MarlinRoot
    git reset --hard
    Pop-Location
}

# if we are using a config file than parse it for config values
if ($useconfig) {
    if (-not $ConfigFile -eq "") {
        if ( -not (Test-Path -Path $ConfigFile)) {
            Exit-Stage-Left -Code 31 -Color Red
        }
    }
    else {
        Exit-Stage-Left -Code 31 -Color Red
    }

    Write-Message -Color DarkCyan -Msg  "Configuring from $ConfigFile" 
    $Config = (Get-Content -Path $ConfigFile | ConvertFrom-Json -AsHashtable)

    if ($Config.settings) {
        #no conflicts for true/false. All default to false and any true flips to true.
        Write-Message -Color DarkCyan -Msg  "   Processing JSON Settings ..."
        
        if ($config.settings.silent -is [System.Boolean]) { 
            $json_silent = $config.settings.silent
            if ($json_silent -eq $true) {
                $silent = $true
            }
            Write-Message -Msg "      Silent Mode : $silent" 
        }

        if ($config.settings.createdir -is [System.Boolean]) { 
            $json_createdir = $config.settings.createdir
            if ($json_createdir -eq $true) {
                $createdir = $true
            }
            Write-Message -Msg "      Create Target Directory: $createdir 
        }

        if ($config.settings.gitreset -is [System.Boolean]) { 
            $json_gitreset = $config.settings.gitreset
            if ($json_gitreset -eq $true) {
                $GitResetHard = $true
            }
            Write-Message -Msg "      GIT Hard Reset : $GitResetHard" 
        }

        if ($config.settings.marlinroot) { 
            $json_marlinroot = $config.settings.marlinroot 
            Write-Message -Msg "      Target Directory [JSON]: $json_marlinroot" 
            if (-not ($json_marlinroot -eq $arg_marlinroot)) {
                if ($arg_marlinroot) {
                    Write-Message -Msg "      Target Directory [ARGS]: $arg_marlinroot" 
                    if ($preferargs) {
                        $MarlinRoot = $arg_marlinroot
                    }
                    else {
                        Exit-Stage-Left -Code 50 -Color Red -Msg "Settings Conflict -> Target Directory : Use --preferargs to override, don't use --targetdir, or change the value in the JSON config."
                    }
                }
                else {
                    $MarlinRoot = $json_marlinroot
                }
            }
        }
    }
    
    Verify-Target-Dir # logic to make sure the target dir is valid
    
    # enable silent mode for functions
    if ($silent) {
        $PSDefaultParameterValues["Set-MarlinConfigOption:silent"] = $true
        $PSDefaultParameterValues["Enable-MarlinConfigOption:silent"] = $true
        $PSDefaultParameterValues["Disable-MarlinConfigOption:silent"] = $true
    }

    if ($Config.useExample) {
        Write-Message -Color DarkCyan -Msg  "   Processing JSON Config Example ..." 
        $Branch = "bugfix-2.0.x"
        $Files = @("Configuration.h","Configuration_adv.h","_Bootscreen.h","_Statusscreen.h")
        $Path = $config.useExample.path

        if ($config.useExample.branch) { $Branch = $config.useExample.branch }
        if ($config.useExample.files) { $Files = $config.useExample.files }

        Get-MarlinExampleConfig -Branch $Branch -Files $Files -ExamplePath $Path
    }

    if ($Config.options) {
        Write-Message -Color DarkCyan -Msg  "   Processing JSON Options ..." 
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

# Execution Summary
Exit-Stage-Left -Code 0
