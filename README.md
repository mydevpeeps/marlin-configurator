# marlin-configurator
_Concept originally imagined by [The-EG](https://github.com/The-EG) using PowerShell_

## Build Script for Marlin Configurations
The purpose of this project is to partially eliminate the most common configuration questions for compiling [Marlin](https://github.com/MarlinFirmware/Marlin) by providing a mechanism to create configuration files based on an existing Marlin Configuration example.  It can also work with local files through options. 

## Changes to Marin Configuration Directives
Marlin is constantly adding, removing, and changing directives in the configuration files. Even within the same bugfix branch between releases these can change. It is up to the user to be aware of and maintain these options. Not all of the directives are in the Marlin Configuration (.h) files and there are definately some that are valid to be added (such as a PIN reference for a feature). 

## Configurations
This code will pull an example from the live Marlin Configurations Repo:
https://github.com/MarlinFirmware/Configurations

## Included Examples
There is an _example.json_ included in this repo under the _user_ directory. Eventually we will write a parser to automatically traverse the [Marlin Configurations Repo](https://github.com/MarlinFirmware/Configurations) and kick out a series of example json files that are identical to the stock examples from Marlin. From there you can add/remove as you see fit. This directory structure will mimick that of the Marlin Configurations repo(s).

## Pre-tested Configurations for Marlin Firmware
The user community can contribute their .json files to the repo under the contrib folder. 

## Command-Line Arguments
Defer to `py marlin-configurator.py --help` for assistance with all of the command line arguments.

### Argument Configuration File
_Online Reference_: [Python Argparse](https://docs.python.org/3/library/argparse.html#fromfile-prefix-chars)

**filename**: _marlin-configurator.ini_

** USING THIS FILE WILL IGNORE ALL OTHER PASSED PARAMETERS **

This file can be used in place of using command-line arguments. The format of the file is:
```
--option
option_value
```

For example, if you wanted to enable --silent by default (the default is False) your file would look like this:
```
--silent
True
```

## JSON Configuration File
JSON Configuration File called with argument `--config [JSON_CONFIG_FILE]` or from _marlin-configurator.ini_.

Section|Subsection|Options|Purpose
---------|---------|---------|---------
settings|||_default configuration for the environment when not using command-line parameters._
||targetdir|path_to_directory|_directory where the resulting modified configuration files go_
||silent|True/False|_suppresses verbose output during configuration changes_
||prefer|args/config|_when arguements conflict, defines what source is preferred, args or config
useExample|||_which example configuration to use and which files to copy._
||branch||_which branch to pull example configuration files from_
||path||_path inside the branch_
||files||_array of the names of the files_
options|||_directives adjusted in Configuration.h and Configuration_Adv.h._
||enable||_directives to enable (if disabled)_
||disable||_directives to disable (if enabled)_
||values||_directives to enable (if disabled) and replace value_

**Example JSON Configuration**
```json
{  
  "settings": {
    "silent" : true,
    "targetdir" : "user/custom_configs",
    "prefer": "args"
  },
  "useExample": {
    "branch" : "bugfix-2.0.x",
    "path" : "Creality/CR-10 S5/CrealityV1",
    "files" : ["Configuration.h","Configuration_adv.h","_Bootscreen.h","_Statusscreen.h"]
  },
  "options": {
    "enable": {
      "SHOW_BOOTSCREEN" : true,
      "SHOW_CUSTOM_BOOTSCREEN" : true,
      "CUSTOM_STATUS_SCREEN_IMAGE" : true,
      "PID_BED_DEBUG" : true,
      "S_CURVE_ACCELERATION" : true,
      "ARC_P_CIRCLES" : true
    },
    "disable": {
      "JD_HANDLE_SMALL_SEGMENTS" : false,
      "PROBE_MANUALLY" : false,
      "G26_MESH_VALIDATION" : false,
      "LEVEL_BED_CORNERS" : false
    },
    "values": {
      "STRING_CONFIG_H_AUTHOR": "\"(devpeeps.com, James Swart)\"",
      "CUSTOM_MACHINE_NAME": "\"CR-10 S5\"",
      "MACHINE_UUID": "\"cede2a2f-41a2-4748-9b12-c55c62f367ff\"",
      "TEMP_SENSOR_BED" : "5",
      "DEFAULT_Kp" : "24.9685",
      "DEFAULT_Ki" : "2.0183",
      "DEFAULT_Kd" : "77.2068"
    }
  }
}
```

## Structure (Files & Directories)
  Name|Type|Purpose
  --------|---|-------
  contrib|Dir|_JSON Configuration files provided by the community._
  examples|Dir|_Direct extractions of the Marlin Configuration Repo(s)._
  legacy|Dir|_Legacy Code which is no longer maintained._
  user|Dir|_Your JSON Configuration files for your printers._
  README.md|File|_README for the project._
  marlin-configurator.ini|File|_Command-Line Argument Configuration File._
  marlin-configurator.py|File|_Python program for this project._

## Requirements
- Marlin Build Environment (has Python already) or python environment.

## Troubleshooting & Help
Please do not reach out to individuals for assistance with this project. Use the Issues section if you run into problems. Most likely we can be found on the [Marlin Discord](https://discord.gg/n5NJ59y) somewhere. This is not _officially_ a marlin sponsored project - yet. If it ever is, it will become it's own project/repo in Marlin and maintained there.
