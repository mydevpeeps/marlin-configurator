# build-marlin
PowerShell Build Script for Marlin Configurations

_Concept originally imagined by https://github.com/The-EG_

## Changes to Marin Configuration Directives
Marlin is constantly adding, removing, and changing directives in the configuration files. Even within the same bugfix branch between releases these can change. It is up to the user to be aware of and maintain these options. Not all of the directives are in the Marlin Configuration (.h) files and there are definately some that are valid to be added (such as a PIN reference for a feature). 

## Configurations
This code will pull an example from the live Marlin Configurations Repo:
https://github.com/MarlinFirmware/Configurations

## Examples
There is an example.json included in this repo. Eventually we will write a parser to automatically traverse the Marlin Configurations Repo and kick out a series of example json files that are identical to the stock examples from Marlin. From there you can add/remove as you see fit.

## Pre-tested Configurations for Marlin Firmware
The _intent_ is to have the user community contribute their .json files to the repo. The directory structure will mimick that of the Marlin Configurations repo.

## Command-Line Parameters
- `--git-reset` _Performs **git reset --hard** before running. Default is false._
- `--configonly` _Runs the configuration modifications but does not compile it. Default is false._
- `--upgradeio` _Runs the 'upgrade' and 'update' options for PlatformIO prior to compiling. Default is false. **NOT Recommended**_
- `--silent` _Supresses all of the noise during the configuration phase. Default is false._
- `--config <file>` _JSON configuration file to use. Default is none which uses what is in Marlin-Root._
- `--marlin-root <path>` _Path where your Marlin Root Repo exists for this build. Default is local directory._
- `--buildargs arguments` _Additional arguments to pass to the PlatformIO build. **This should always be the last parameter sent.**_

## JSON File Sections
- `settings` _not used yet. will replace defaults.._
- `useExample` _which example configuration to use and which files to copy._
- `options` _directives adjusted in Configuration.h and Configuration_Adv.h._
  
## Requirements
- Windows Computer Running PowerShell 6.0 or higher.
- PlatformIO already installed and configured. 
- Marlin Repo downloaded.

## Troubleshooting & Help
Ideally you should be have already downloaded Marlin and PlatformIO, and have successfully compiled Marin. Please do not reach out to The-EG for assistance with this project. Use the Issues section if you run into problems.
