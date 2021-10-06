#####################################################################################
##### Purpose: Create Configuration.h and Configuration_Adv.h files for Marlin Builds
##### Author: James Swart (mydevpeeps)
##### Contributors: The-EG, p3p
##### Repository: https://github.com/mydevpeeps/marlin-configurator
##### Change Log:
#####    0.1 - Original PowerShell version.
#####    0.2 - Basic port from original PowerShell to Python.
#####################################################################################

#####################################################
##### LIBRARY MODULES
#####################################################
import requests
from requests.exceptions import Timeout
from requests.exceptions import HTTPError
from requests.exceptions import ConnectionError
from requests.adapters import HTTPAdapter
import datetime
from datetime import datetime, timedelta, date
#from json_checker import Checker
from jsonschema import validate, ValidationError, SchemaError
import json
import sys
import argparse
import os
#import os.path
import time
import logging
import array
import re
import subprocess

#####################################################
##### COLOR & FONT SETUP
#####################################################
from colorama import init, Fore, Back, Style
init(autoreset=True)

#####################################################
##### FRAMEWORK VARIABLES
#####################################################
debug = False						# set debug on or off
version = "0.12"	    			# set to revision # as above
ctimeout = 60						# connection timeout
dtimeout = 60						# data transfer timeout
sslverify = True					# verify ssl cert
pageDelay = 5						# seconds to delay between page requests
errDelay = 5						# seconds to delay between page requests after error
retries = 5		   					# retry a failed request this # of times (manual attempts)
sretries = 10	   					# retry a failed request this # of times (per session)
attempt = 0							# tracker for current iteration of retry
errcode = 0							# store the response error code
logfile = "marlin-configurator.log"	# log file
today = date.today()
year = today.year

#####################################################
##### CONFIGURATION VARIABLES
#####################################################
ConfigFile = '.\examples\Creality\CR10 S5\CrealityV1\cr10s5_bl_touch-btt_smart_filament-v2.2_silent_board.json'
MarlinRoot = "."
GitResetHard = False
preferargs = False
silent = False
createdir = False
useconfig = False
options = []
options_enable = []
options_disable = []
options_values = []
files = ['Configuration.h', 'Configuration_adv.h']
f_config = MarlinRoot + "/Marlin/Configuration.h"
f_config_adv = MarlinRoot + "/Marlin/Configuration_Adv.h"
path = "Creality/CR-10 S5/CrealityV1"
branch = "bugfix-2.0.x"
URL = "https://raw.githubusercontent.com/MarlinFirmware/Configurations/" + branch + "/config/examples/" + path

#####################################################
##### WEB REQUEST SETUP
#####################################################
api_adapter = HTTPAdapter(max_retries=sretries)
session = requests.Session()
session.mount(URL,api_adapter)

#####################################################
##### LOGGING
#####################################################
logging.basicConfig(filename=logfile, filemode='a', format='%(asctime)s - %(levelname)s - %(name)s - %(message)s')
logger=logging.getLogger()
logger.setLevel(logging.INFO)   #Set the initial logger threshold (values: INFO WARN ERROR CRITICAL DEBUG)

# example log messages
#logger.debug("This is just a harmless debug message") 
#logger.info("This is just an information for you") 
#logger.warning("OOPS!!!Its a Warning") 
#logger.error("Have you try to divide a number by zero") 
#logger.critical("The Internet is not working....") 
#logger.exception("This kicks out a trace for exceptions")


#####################################################
##### FUNCTIONS - MESSAGING
#####################################################

def Message(MSG):
    print(Fore.WHITE + str(MSG))
    logger.info(MSG)

def Message_Error(MSG):
    print(Style.BRIGHT + Fore.RED + str(MSG))
    logger.error(MSG)

def Message_Config(MSG):
    print(Style.BRIGHT + Fore.GREEN + str(MSG))
    logger.info(MSG)

def Message_Warning(MSG):
    print(Style.BRIGHT + Fore.YELLOW + str(MSG))
    logger.warning(MSG)

def Message_Header(MSG):
    print(Style.BRIGHT + Fore.CYAN + str(MSG))
    logger.info(MSG)

#####################################################
##### FUNCTIONS - CORE
#####################################################

def setErrCode(code):
	global errcode
	errcode = code

def getErrCode():
	return errcode

def ExitStageLeft(CODE,MSG):
    print ()
    ERRORMSG="Exit Code (" + str(CODE) + ") " + str(MSG)
    sys.exit(ERRORMSG)

def intro():
    # intro
    print ()
    msg = "marlin-configurator v" + str(version) + " - Copyright DevPeeps " + str(year)
    logger.info(msg); Message_Header(msg)

    # display debug state
    if debug:
        logger.setLevel(logging.DEBUG)   #Set the threshold of logger to DEBUG 
        print (f'  ** DEBUG ENABLED** Check {logfile} for details')
        print ()

def outro():
    ExitStageLeft(0,"Done")

def rmFile(filepath):
    try:
        if os.path.exists(filepath):
            os.remove(filepath)
            msg = 'removed ' + str(filepath)
            logger.debug(msg)
            #Message('    ' + msg)
    except:
        Message_Error('Error removing ' + str(filepath))
        logger.error(msg)

def isFile(f):
    return os.path.isfile(f)

def isDir(d):
    return os.path.isdir(d)

def pathExists(p):
    return os.path.exists(p)

def getFileList(p):
    return os.listdir(p)

def getPlatform():
    return os.name

def getUName():
    return os.uname()

def getCWD():
    return os.getcwd()

def chDir(d):
    os.chdir(d)

def mkDir(d):
    os.mkdir(d)

def rmDir(d):
    os.rmdir(d)

def rmFile(f):
    os.remove(f)

def exec(cmd):
    # os.system(cmd)
    # subprocess.run(["ping","-c 3", "example.com"])
    subprocess.run(cmd)

def rename(old,new):
    os.rename(old,new)

#####################################################
##### FUNCTIONS - JSON PARSING
#####################################################

# validate the JSON config file against the schema
# https://techtutorialsx.com/2020/03/05/python-json-schema-validation/
def validateJSON(JFILE):
    schema = {
        "type" : "object",
        "properties" : {
            "name" : {"type" : "string"},
            "age" : {
                "type" : "number",
            }
        },
        "required": ["age","name"]
    }

# get and store the settings from the JSON file
def getJSONSettings():
    logger.debug("getJSONSettings()")
    Message_Header("Processing Settings from JSON")
    global GitResetHard
    global silent
    global createdir
    global MarlinRoot
    global ConfigFile
    global f_config
    global f_config_adv

    try:
        with open(ConfigFile,encoding="utf8") as r:
            rdata = json.load(r)
            if "settings" in rdata:
                with open(ConfigFile,encoding="utf8") as f:
                    sdata = json.load(f)['settings']
                    if "gitreset" in sdata:
                        if not (sdata.get('gitreset') is None):
                            GitResetHard = sdata['gitreset']
                            Message_Config("  GitResetHard: " + str(GitResetHard))
                        else:
                            Message_Error("JSON setting gitreset is missing a value")
                    if "silent" in sdata:
                        if not (sdata.get('silent') is None):
                            silent = sdata['silent']
                            Message_Config("  silent: " + str(silent))
                        else:
                            Message_Error("JSON setting silent is missing a value")
                    if "createdir" in sdata:
                        if not (sdata.get('createdir') is None):
                            createdir = sdata['createdir']
                            Message_Config("  createdir: " + str(createdir))
                        else:
                            Message_Error("JSON setting createdir is missing a value")
                    if "marlinroot" in sdata:
                        if not (sdata.get('marlinroot') is None):
                            MarlinRoot = sdata['marlinroot']
                            Message_Config("  MarlinRoot: " + str(MarlinRoot))
                            f_config = MarlinRoot + "/Marlin/Configuration.h"
                            f_config_adv = MarlinRoot + "/Marlin/Configuration_Adv.h"
                        else:
                            Message_Error("JSON setting marlinroot is missing a value")
    except IOError as ioe: ##error message
        Message_Error("IOError Occured in getJSONSettings")
        print(ioe)
    except Exception as e: ##error message
        Message_Error("Exception Occured in getJSONSettings")
        print(e)

# get and store the example config settings from the JSON file
def getJSONConfig():
    logger.debug("getJSONConfig()")
    Message_Header("Processing Example Marlin Configuration from JSON")
    global branch
    global path
    global files
    global URL
    global ConfigFile

    try:
        with open(ConfigFile,encoding="utf8") as r:
            rdata = json.load(r)
            if "useExample" in rdata:
                with open(ConfigFile,encoding="utf8") as f:
                    sdata = json.load(f)['useExample']
                    if "branch" in sdata:
                        if not (sdata.get('branch') is None):
                            branch = sdata['branch']
                            Message_Config("  branch: " + str(branch))
                        else:
                            Message_Error("JSON useExample branch is missing a value")
                    if "path" in sdata:
                        if not (sdata.get('path') is None):
                            path = sdata['path']
                            Message_Config("  path: " + str(path))
                        else:
                            Message_Error("JSON useExample path is missing a value")
                    if "files" in sdata:
                        if not (sdata.get('files') is None):
                            files = sdata['files']
                            for name in files:
                                Message_Config("     downloading " + str(name) + " from " + URL)
                                furl = URL + "/" + name
                                lfilename = MarlinRoot + "/Marlin/" + name
                                rmFile(lfilename) # remove old file first .. NO CACHING!
                                lfile=open(lfilename, mode="w", encoding="utf-8")
                                lfile.write(getWebFile(furl))
                                lfile.close()
                        else:
                            Message_Error("JSON useExample files is missing a value")
    except IOError as ioe: ##error message
        Message_Error("IOError Occured in getJSONConfig")
        print(ioe)
    except Exception as e: ##error message
        Message_Error("Exception Occured in getJSONConfig")
        print(e)

def sort_by_key(list):
    return pprint.pprint(sorted(list))

# get and store the directives (options) from the JSON file
def getJSONOptions():
    logger.debug("getJSONOptions()")
    Message_Header("Processing Directives from JSON")
    global MarlinRoot
    global path
    global files
    global URL
    global ConfigFile
    global f_config
    global f_config_adv
    global options
    global options_enable
    global options_disable
    global options_values

    f_config = MarlinRoot + "/Marlin/Configuration.h"
    f_config_adv = MarlinRoot + "/Marlin/Configuration_Adv.h"
    Message_Config("   Using " + f_config)
    Message_Config("   Using " + f_config_adv)

    try:
        with open(ConfigFile,encoding="utf8") as r:
            rdata = json.load(r)
            if "options" in rdata:
                with open(ConfigFile,encoding="utf8") as f:
                    options = json.load(f)['options']
                    if "enable" in options:
                        if (len(options['enable']) > 0):
                            options_enable = json.loads(json.dumps(options['enable'], sort_keys=True))
                    if "disable" in options:
                        if (len(options['disable']) > 0):
                            options_disable = json.loads(json.dumps(options['disable'], sort_keys=True))
                    if "values" in options:
                        if (len(options['values']) > 0):
                            options_values = json.loads(json.dumps(options['values'], sort_keys=True))
                    logger.debug("Enabled:" + str(options_enable))
                    logger.debug("Disabled:" + str(options_disable))
                    logger.debug("Values:" + str(options_values))
    except IOError as ioe: ##error message
        Message_Error("IOError Occured in getJSONOptions")
        print(ioe)
    except Exception as e: ##error message
        Message_Error("Exception Occured in getJSONOptions")
        print(e)


#####################################################
##### FUNCTIONS - WEB REQUESTS
#####################################################

def getWebFile(URL):
    errorCode = 0

    for rt in range(1,retries+1):
        try: 
            r = session.get(url = URL, verify=sslverify, timeout=(ctimeout,dtimeout))
            r.encoding = 'utf-8'
            r.raise_for_status()
        except Timeout as t:
            errorCode = 997
            logger.exception(t)
            logger.critical('Query Timed Out')
        except HTTPError as e:
            errorCode = r.status_code
            logger.critical('Query Error')
            logger.error("Received Response code " + str(errorCode) + " from "  + str(URL))
            logger.exception(e)
            logger.debug("Request URL: " + str(r.request.url))
            logger.debug("Request Headers: " + str(r.request.headers))
            logger.debug("Response Code: " + str(r.status_code))
            logger.debug("Response Headers: " + str(r.headers))
        except ConnectionError as cerr:
            errorCode = 998
            logger.critical('Connection Error')
            logger.exception(cerr)
        except Exception as err:
            errorCode = 999
            logger.critical('General Error')
            logger.exception(err)
        else:
            errorCode = 0
            logger.debug("Request URL: " + str(r.request.url))
            logger.debug("Request Headers: " + str(r.request.headers))
            logger.debug("Response Code: " + str(r.status_code))
            logger.debug("Response Headers: " + str(r.headers))

        # check to see if we errored out or were successful
        if errorCode == 0:
            attempt = 1
            break # success so break out of the retry loop
        else:
            msg = "attempt " + str(rt) + " of " + str(retries) + " for initial request failed with response code " + str(getErrCode())
            logger.warning(msg)
            attempt += 1
            logger.info("sleeping for " + str(errDelay) + "seconds")
            time.sleep(errDelay)

        # error out if there was a problem with the initial request
        if attempt == retries:
            msg = "All request attempts for " + str(URL) + " failed. Please try again."
            logger.critical(msg)
            print (msg)
            setErrCode(0)
            attempt=1
            sys.exit(msg)

    return str(r.text)

#####################################################
##### FUNCTIONS - CONFIGURATON FILE DIRECTIVES
#####################################################

# find directive to see if it exists
def findDirective(directive,test_str):
    pattern = "^(\s*)(\/\/)?(\s*)#define(\s*)" + directive + "(\s)"
    found = False
    matches = re.finditer(pattern, test_str, re.MULTILINE)
    for matchNum, match in enumerate(matches, start=1):   
        found = True
    return found

# find comment for a directive, if there is one
def getDirective(directive,test_str):
    reg_pre = "^(\s*?)(#define "
    reg_post = "\s+)(.*?)(\s*\/\/.*)?$"
    pattern = reg_pre + directive + reg_post
    results = ["","","",""]
    matches = re.finditer(pattern, test_str, re.MULTILINE)

    for matchNum, match in enumerate(matches, start=1):
        for groupNum in range(0, len(match.groups())):
            groupNum = groupNum + 1
            results[groupNum-1] = match.group(groupNum)

    return results


# enable a directive
def enableDirectives():
    logger.debug("enableDirectives()")
    Message_Config("   Enabling Directives")
    global options_enable
    global f_config
    global f_config_adv
    exists = False

    try:
        # open the two config files, read them, and close them
        f1 = open(f_config, "rt",encoding="utf8")
        f2 = open(f_config_adv, "rt",encoding="utf8")
        data1 = f1.read()
        data2 = f2.read()
        f1.close()
        f2.close()

        # enable all matching directives
        for key in options_enable:
            directive = str(key)
            disabled = "//#define " + directive
            enabled = "#define " + directive
            pattern = "^(\s*)(\/\/)(\s*)#define(\s*)" + directive + "(\s)"
            if findDirective(directive,data1):
                exists = True
                Message_Config("      " + directive + " (Configuration.h)")
                data1 = data1.replace(disabled, enabled)
                #data1 = re.sub(pattern, enabled, data1, re.MULTILINE)
            if findDirective(directive,data2):
                exists = True
                Message_Config("      " + directive + " (Configuration_adv.h)")
                data2 = data2.replace(disabled, enabled)
                #data2 = re.sub(pattern, enabled, data2, re.MULTILINE)
            if exists == False:
                Message_Warning("      " + directive + " not found. Skipping.")
            exists = False

        # reopen the files in write mode, save the changes, and close them
        f1 = open(f_config, "wt",encoding="utf8")
        f2 = open(f_config_adv, "wt",encoding="utf8")
        f1.write(data1)
        f2.write(data2)
        f1.close()
        f2.close()
    except IOError as ioe: ##error message
        Message_Error("IOError Occured in enableDirectives")
        print(ioe)
    except Exception as e: ##error message
        Message_Error("Exception Occured in enableDirectives")
        print(e)

# disable a directive
def disableDirectives():
    logger.debug("disableDirectives()")
    Message_Config("   Disabling Directives")
    global options_disable
    global f_config
    global f_config_adv
    exists = False

    try:
        # open the two config files, read them, and close them
        f1 = open(f_config, "rt",encoding="utf8")
        f2 = open(f_config_adv, "rt",encoding="utf8")
        data1 = f1.read()
        data2 = f2.read()
        f1.close()
        f2.close()

        # enable all matching directives
        for key in options_disable:
            directive = str(key)
            disabled = "//#define " + directive
            enabled = "#define " + directive
            if findDirective(directive,data1):
                exists = True
                Message_Config("      " + directive + " (Configuration.h)")
                data1 = data1.replace(enabled,disabled)
            if findDirective(directive,data2):
                exists = True
                Message_Config("      " + directive + " (Configuration_adv.h)")
                data2 = data2.replace(enabled,disabled)
            if exists == False:
                Message_Warning("      " + directive + " not found. Skipping.")
            exists = False

        # reopen the files in write mode, save the changes, and close them
        f1 = open(f_config, "wt",encoding="utf8")
        f2 = open(f_config_adv, "wt",encoding="utf8")
        f1.write(data1)
        f2.write(data2)
        f1.close()
        f2.close()
    except IOError as ioe: ##error message
        Message_Error("IOError Occured in disableDirectives")
        print(ioe)
    except Exception as e: ##error message
        Message_Error("Exception Occured in disableDirectives")
        print(e)

# enable (if disabled) and then change value
def updateValues():
    logger.debug("enableDirectives()")
    Message_Config("   Updating Values")
    global options_values
    global f_config
    global f_config_adv
    exists = False

    try:
        # open the two config files, read them, and close them
        f1 = open(f_config, "rt",encoding="utf8")
        f2 = open(f_config_adv, "rt",encoding="utf8")
        data1 = f1.read()
        data2 = f2.read()
        f1.close()
        f2.close()
        reg_pre = "^(\s*?)(#define "
        reg_post = "\s+)(.*?)(\s*\/\/.*)?$"

        # enable all matching directives
        for key in options_values:
            directive = str(key)
            value = str(options_values[key])
            pattern = reg_pre + directive + reg_post
            subst = str("#define " + directive + " " + value)
            disabled = "//#define " + directive
            enabled = "#define " + directive

            if findDirective(directive,data1):
                exists = True
                Message_Config("      " + directive + " = " + value + " (Configuration.h)")
                spaces = str(getDirective(directive,data1)[0])
                comment = str(getDirective(directive,data1)[3])
                if comment != "None":
                    subst = spaces + subst + " " + comment
                data1 = data1.replace(disabled, enabled)
                data1 = re.sub(pattern,subst,data1,0,re.MULTILINE)
            
            if findDirective(directive,data2):
                exists = True
                Message_Config("      " + directive + " = " + value + " (Configuration_adv.h)")
                spaces = str(getDirective(directive,data2)[0])
                comment = str(getDirective(directive,data2)[3])
                if comment != "None":
                    subst = spaces + subst + " " + comment
                data2 = data2.replace(disabled, enabled)
                data2 = re.sub(pattern,subst,data2,0,re.MULTILINE)
            
            if exists == False:   
                Message_Warning("      " + directive + " not found. Skipping.")
            
            exists = False

        # reopen the files in write mode, save the changes, and close them
        f1 = open(f_config, "wt",encoding="utf8")
        f2 = open(f_config_adv, "wt",encoding="utf8")
        f1.write(data1)
        f2.write(data2)
        f1.close()
        f2.close()
    except IOError as ioe: ##error message
        Message_Error("IOError Occured in updateValues")
        print(ioe)
    except Exception as e: ##error message
        Message_Error("Exception Occured in updateValues")
        print(e)

#####################################################
##### MAIN
#####################################################
def main(args):
    #Hello World!
    intro()

    # parse args
    print(args)

    # get data from JSON Config
    Message_Header("Using " + ConfigFile)
    getJSONSettings()
    getJSONConfig()
    getJSONOptions()

    # Update the Configuration
    if (len(options_enable) > 0):
        enableDirectives()
    if (len(options_disable) > 0):
        disableDirectives()
    if (len(options_values) > 0):
        updateValues()

    # Exit gracefully
    outro()

# parse out the args (also create --help output) and then pass to main function
# https://docs.python.org/3/library/argparse.html
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Builds Configuration Files from the Marlin Examples Online')
    parser.add_argument('--target', type=str, help='The directory in which the files will be saved. Default is current directory.')
    parser.add_argument('--config', type=str, help='JSON Configuration File')
    parser.add_argument('--import', type=str, help='Import a local file or config example path')
    parser.add_argument('--validate', type=str, help='Validate JSON Configuration file syntax.', choices=['true','false'])
    parser.add_argument('--createdir', type=str, help='Creates the target directory if it does not exist.', choices=['true','false'])
    parser.add_argument('--silent', type=str, help='Suppress Configuration Change Information. Default: false', choices=['true','false'])
    parser.add_argument('--prefer', type=str, help='Prefer either the JSON config, or the command-line when there is a conflict.', choices=['config','args'])
    parser.add_argument('--missing', type=str, help='Add missing directives instead of skipping them. Default: skip.', choices=['add','skip'])
    parser.add_argument('--mode', type=str, help='Batch mode will skip all prompts. Interactive mode will present choices.', choices=['batch','interactive'])
    
    args = parser.parse_args()

    # Do something with it
    main(args)
    #print(args.slidesid, args.dir, args.total_slides )