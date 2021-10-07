#####################################################################################
##### Purpose: Create Configuration.h and Configuration_Adv.h files for Marlin Builds
##### Author: James Swart (mydevpeeps)
##### Contributors: The-EG, p3p
##### Repository: https://github.com/mydevpeeps/marlin-configurator
##### Best Regex Site EVER: https://regex101.com/
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
#from jsonschema import validate, ValidationError, SchemaError
import json
import sys
import argparse
import os
import stat
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
# globals where the settings are stored
JSONFile = 'None'
importpath = "None"
targetdir = "None"
preferargs = False
silent = False
createdir = False
useconfig = False
missing = "skip"
mode = "interactive"
prefer = "args"
validate = False
options = []
options_enable = []
options_disable = []
options_values = []
files = ['Configuration.h', 'Configuration_adv.h']
f_config = targetdir + "/Marlin/Configuration.h"
f_config_adv = targetdir + "/Marlin/Configuration_Adv.h"
path = "/config/examples/Creality/CR-10 S5/CrealityV1"
branch = "bugfix-2.0.x"
URL = "https://raw.githubusercontent.com/MarlinFirmware/Configurations/" + branch + path

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
##### FUNCTIONS - MESSAGING & LOGGING
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

def Message_Debug(MSG):
    if debug:
        print(Style.BRIGHT + Fore.MAGENTA + str(MSG))
    logger.debug(MSG)

def Message_Exception(MSG,e):
    print(Style.BRIGHT + Fore.MAGENTA + str(MSG))
    print(Style.BRIGHT + Fore.MAGENTA + str(e))
    logger.critical(MSG)
    logger.exception(e)
    ExitStageLeft(500,MSG)

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
    plat = getPlatform()
    uname = getUName()

    print()
    msg = "marlin-configurator v" + str(version) + " - Copyright DevPeeps " + str(year)
    if plat == 'Windows':
        msg += " (" + str(getPlatform()) + ")"
    else:
        msg += " (" + str(getPlatform()) + " " + str(getUName()) + ")"
    logger.info(msg); Message_Header(msg)
    
    # setup debug state
    if debug:
        logger.setLevel(logging.DEBUG)   #Set the threshold of logger to DEBUG 
        Message_Debug("** DEBUG ENABLED** Check " + logfile + " for details")
        print()

def outro():
    ExitStageLeft(0,"Done")

# https://codereview.stackexchange.com/questions/214935/python-3-6-function-to-ask-for-a-multiple-choice-answer
def multi_choice_question(options: list,msg,title):
    while True:
        print()
        Message_Header(title)
        for i, option in enumerate(options, 1):
            Message_Config(f'{i}. {option}')
        try:
            answer = int(input(msg))
            if 1 <= answer <= len(options):
                print()
                return options[answer-1]
            Message_Error("That option does not exist! Try again!")
        except ValueError:
            Message_Exception("Doesn't seem like a number! Try again!",ValueError)
        print()
    #logger.info("Question Response: " + title + "|" + msg + "|" + options[answer-1])    

def isFile(f):
    try:
        return os.path.isfile(f)
    except IOError as ioe: ##error message
        print(ioe)
        ExitStageLeft(500,"IOError occured checking for existing file  " + str(f))
    except Exception as e: ##error message
        print(e)
        ExitStageLeft(500,"Exception occured checking for existing file  " + str(f))

def isDir(d):
    try:
        return os.path.isdir(d)
    except IOError as ioe: ##error message
        print(ioe)
        ExitStageLeft(500,"IOError occured checking for existing directory  " + str(d))
    except Exception as e: ##error message
        print(e)
        ExitStageLeft(500,"Exception occured checking for existing directory  " + str(d))

def pathExists(p):
    # this seems to be broken on windows??
    try:
        return os.path.exists(p)
    except IOError as ioe: ##error message
        print(ioe)
        ExitStageLeft(500,"IOError occured checking for existing path  " + str(p))
    except Exception as e: ##error message
        print(e)
        ExitStageLeft(500,"Exception occured checking for existing path  " + str(p))

def getFileList(p):
    try:
        return os.listdir(p)
    except IOError as ioe: ##error message
        print(ioe)
        ExitStageLeft(500,"IOError occured listing directory  " + str(p))
    except Exception as e: ##error message
        print(e)
        ExitStageLeft(500,"Exception occured listing directory " + str(p))

def getPlatform():
    try:
        plat = os.name
        if plat == "nt":
            return "Windows"
        else:
            return os.name
    except IOError as ioe: ##error message
        print(ioe)
        ExitStageLeft(500,"IOError occured getting operating system information.")
    except Exception as e: ##error message
        print(e)
        ExitStageLeft(500,"Exception occured getting operating system information.")

def getUName():
    try:
        if not getPlatform() == "Windows":
            return os.uname()
        else:
            return ""
    except IOError as ioe: ##error message
        print(ioe)
        ExitStageLeft(500,"IOError occured getting operating system information.")
    except Exception as e: ##error message
        print(e)
        ExitStageLeft(500,"Exception occured getting operating system information.")

def getCWD():
    try:
        return os.getcwd()
    except IOError as ioe: ##error message
        print(ioe)
        ExitStageLeft(500,"IOError occured getting current working directory.")
    except Exception as e: ##error message
        print(e)
        ExitStageLeft(500,"Exception occured getting current working directory.")

def chDir(d):
    try:
        os.chdir(d)
    except IOError as ioe: ##error message
        print(ioe)
        ExitStageLeft(500,"IOError occured changing directory to " + str(d))
    except Exception as e: ##error message
        print(e)
        ExitStageLeft(500,"Exception occured changing directory to " + str(d))

def removeROFlag(t):
    try:
        os.chmod(t,stat.S_IWRITE)
    except IOError as ioe: ##error message
        print(ioe)
        ExitStageLeft(500,"IOError occured removing read-only flag for  " + str(t))
    except Exception as e: ##error message
        print(e)
        ExitStageLeft(500,"Exception occured removing read-only flag for " + str(t))

def mkDir(d):
    try:
        os.makedirs(d)
        removeROFlag(d)
    except IOError as ioe: ##error message
        print(ioe)
        ExitStageLeft(500,"IOError occured making directory " + str(d))
    except Exception as e: ##error message
        print(e)
        ExitStageLeft(500,"Exception occured making directory " + str(d))

def rmDir(d):
    try:
        removeROFlag(d)
        os.rmdir(d)
    except IOError as ioe: ##error message
        print(ioe)
        ExitStageLeft(500,"IOError occured removing directory " + str(d))
    except Exception as e: ##error message
        print(e)
        ExitStageLeft(500,"Exception occured Removing Directory " + str(d))

def rmFile(f):
    try:
        os.remove(f)
    except IOError as ioe: ##error message
        print(ioe)
        ExitStageLeft(500,"IOError occured removing file " + str(f))
    except Exception as e: ##error message
        print(e)
        ExitStageLeft(500,"Exception occured removing file " + str(f))

def exec(cmd):
    # os.system(cmd)
    # subprocess.run(["ping","-c 3", "example.com"])
    try:
        subprocess.run(cmd)
    except Exception as e: ##error message
        print(e)
        ExitStageLeft(500,"Exception occured running command " + str(cmd))

def rename(old,new):
    try:
        removeROFlag(old)
        os.rename(old,new)
    except IOError as ioe: ##error message
        print(ioe)
        ExitStageLeft(500,"IOError occured renaming " + str(old) + " to " + str(new))
    except Exception as e: ##error message
        print(e)
        ExitStageLeft(500,"Exception occured renaming " + str(old) + " to " + str(new))

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

def getDefaults():
    # defaults to be used for comparison during setting resolutions
    # pull defaults from json file
    logger.debug("getJSONSettings()")
    print()
    global defaults
    Message_Header("Processing Default Settings from inc/defaults.json")
    try:
         if isFile('inc/defaults.json'):
            with open('inc/defaults.json',encoding="utf8") as r:
                defaults = json.load(r)
                #for key in defaults:
                #    directive = str(key)
                #    value = str(options_values[key])
                #    Message_Config("   " + directive + " = " + value)
    except IOError as ioe: ##error message
        Message_Exception("IOError Occured in getDefaults",ioe)
        print(ioe)
    except Exception as e: ##error message
        Message_Exception("Exception Occured in getDefaults",e)
        print(e)
    
    print()

# get and store the settings from the requested JSON file
def getJSONSettings():
    logger.debug("getJSONSettings()")
    print()
    Message_Header("Processing Settings from JSON")
    global silent
    global createdir
    global targetdir
    global JSONFile
    global f_config
    global f_config_adv

    try:
        if isFile(JSONFile):
            with open(JSONFile,encoding="utf8") as r:
                rdata = json.load(r)
                if "settings" in rdata:
                    with open(JSONFile,encoding="utf8") as f:
                        sdata = json.load(f)['settings']
                        if "silent" in sdata:
                            if not (sdata.get('silent') is None):
                                silent = sdata['silent']
                                Message_Config("  silent: " + str(silent))
                            else:
                                Message_Error("JSON setting silent is missing a value")
                        if "prefer" in sdata:
                            if not (sdata.get('prefer') is None):
                                prefer = sdata['prefer']
                                Message_Config("  prefer: " + str(prefer))
                            else:
                                Message_Error("JSON setting createdir is missing a value")
                        if "targetdir" in sdata:
                            if not (sdata.get('targetdir') is None):
                                targetdir = sdata['targetdir']
                                Message_Config("  targetdir: " + str(targetdir))
                                f_config = targetdir + "/Marlin/Configuration.h"
                                f_config_adv = targetdir + "/Marlin/Configuration_Adv.h"
                            else:
                                Message_Error("JSON setting targetdir is missing a value")
    except IOError as ioe: ##error message
        Message_Exception("IOError Occured in getJSONSettings",ioe)
        print(ioe)
    except Exception as e: ##error message
        Message_Exception("Exception Occured in getJSONSettings",e)
        print(e)

# get and store the example config settings from the JSON file
def getJSONConfig():
    logger.debug("getJSONConfig()")
    print()
    Message_Header("Processing Example Marlin Configuration from JSON")
    global branch
    global path
    global files
    global URL
    global JSONFile
    global targetdir

    try:
        if isFile(JSONFile):
            with open(JSONFile,encoding="utf8") as r:
                rdata = json.load(r)
                if "useExample" in rdata:
                    with open(JSONFile,encoding="utf8") as f:
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
                                Message_Config("  files: " + str(files))
                            else:
                                Message_Error("JSON useExample files is missing a value")
    except IOError as ioe: ##error message
        Message_Exception("IOError Occured in getJSONConfig",ioe)
        print(ioe)
    except Exception as e: ##error message
        Message_Exception("Exception Occured in getJSONConfig",e)
        print(e)

# get and store the directives (options) from the JSON file
def getJSONOptions():
    logger.debug("getJSONOptions()")
    print()
    Message_Header("Processing Directives from JSON")
    global targetdir
    global path
    global files
    global URL
    global JSONFile
    global f_config
    global f_config_adv
    global options
    global options_enable
    global options_disable
    global options_values

    f_config = targetdir + "/Marlin/Configuration.h"
    f_config_adv = targetdir + "/Marlin/Configuration_Adv.h"
    Message_Config("   Using " + f_config)
    Message_Config("   Using " + f_config_adv)

    try:
        if isFile(JSONFile):
            with open(JSONFile,encoding="utf8") as r:
                rdata = json.load(r)
                if "options" in rdata:
                    with open(JSONFile,encoding="utf8") as f:
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
        Message_Exception("IOError Occured in getJSONOptions",ioe)
        print(ioe)
    except Exception as e: ##error message
        Message_Exception("Exception Occured in getJSONOptions",e)
        print(e)


#####################################################
##### FUNCTIONS - WEB REQUESTS
#####################################################
# goes through the list of files to request them from the internet
def getExampleFiles():
    global targetdir
    global path
    global files
    global URL

    try:
        # sanitize targetdir first
        if pathExists(targetdir):
            removeROFlag(targetdir)
        for name in files:
            Message_Config("     downloading " + str(name) + " from " + URL + " to " + str(targetdir) + "/Marlin")
            furl = URL + "/" + name
            lfilename = targetdir + "/Marlin/" + name
            #rmFile(lfilename) # remove old file first .. NO CACHING!
            lfile=open(lfilename, mode="w", encoding="utf-8")
            lfile.write(getWebFile(furl))
            lfile.close()
    except IOError as ioe: ##error message
        Message_Exception("IOError Occured in getExampleFiles",ioe)
        print(ioe)
    except Exception as e: ##error message
        Message_Exception("Exception Occured in getExampleFiles",e)
        print(e)

# gets one file at a time from the internet
def getWebFile(URL):
    global attempt
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
                msg = "      " + directive + " (Configuration.h)"
                if silent == True:
                    logger.info(msg)
                else:
                    Message_Config(msg)
                data1 = data1.replace(disabled, enabled)
                #data1 = re.sub(pattern, enabled, data1, re.MULTILINE)
            if findDirective(directive,data2):
                exists = True
                msg = "      " + directive + " (Configuration_adv.h)"
                if silent == True:
                    logger.info(msg)
                else:
                    Message_Config(msg)
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
        Message_Exception("IOError Occured in enableDirectives",ioe)
        print(ioe)
    except Exception as e: ##error message
        Message_Exception("Exception Occured in enableDirectives",e)
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
                msg = "      " + directive + " (Configuration.h)"
                if silent == True:
                    logger.info(msg)
                else:
                    Message_Config(msg)
                data1 = data1.replace(enabled,disabled)
            if findDirective(directive,data2):
                exists = True
                msg = "      " + directive + " (Configuration_adv.h)"
                if silent == True:
                    logger.info(msg)
                else:
                    Message_Config(msg)                
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
        Message_Exception("IOError Occured in disableDirectives",ioe)
        print(ioe)
    except Exception as e: ##error message
        Message_Exception("Exception Occured in disableDirectives",e)
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
                msg = "      " + directive + " = " + value + " (Configuration.h)"
                if silent == True:
                    logger.info(msg)
                else:
                    Message_Config(msg)
                spaces = str(getDirective(directive,data1)[0])
                comment = str(getDirective(directive,data1)[3])
                if comment != "None":
                    subst = spaces + subst + " " + comment
                data1 = data1.replace(disabled, enabled)
                data1 = re.sub(pattern,subst,data1,0,re.MULTILINE)
            
            if findDirective(directive,data2):
                exists = True
                msg = "      " + directive + " = " + value + " (Configuration_adv.h)"
                if silent == True:
                    logger.info(msg)
                else:
                    Message_Config(msg)
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
        Message_Exception("IOError Occured in updateValues",ioe)
        print(ioe)
    except Exception as e: ##error message
        Message_Exception("Exception Occured in updateValues",e)
        print(e)

#####################################################
##### MAIN
#####################################################
def main(args):
    global preferargs
    global silent
    global createdir
    global useconfig
    global files
    global path
    global branch
    global URL
    global importpath
    global missing
    global mode
    global prefer
    global validate
    global JSONFile
    global targetdir
    global path # Creality/CR-10 S5/CrealityV1
    global branch # bugfix-2.0.x
    opmode = "export"

    print()

    ##### determine if we are in our own root directory. If not then error out with a message
    if not isFile('marlin-configurator.py'):
        ExitStageLeft(500,"marlin-configurator.py MUST be run from it's root directory!")

    ##### process args
    # https://realpython.com/python-namespaces-scope/
    Message_Header("Processing Command-Line Arguments")
    Message_Config(str(args))
    #logger.info("ARGS: " + str(args))

    ##### Settings from JSON Configuration File
    print()
    getDefaults()   # get default values for globals
    JSONFile = str(args.config)
    Message_Header("Using " + JSONFile)
    getJSONSettings()

    ## boolean (assign directly to globals as an override)
    validate = eval(args.validate)
    silent = eval(args.silent)
    args_force = eval(args.force)
    createdir = eval(args.createdir)

    ## strings
    args_missing = str(args.missing)
    args_mode = str(args.mode)
    args_prefer = str(args.prefer)
    args_JSONFile = str(args.config)
    args_importpath = str(args.importpath)

    # special processing for the target dir
    # default to user/branch/path(/Marlin)
    args_targetdir = str(args.target)
    if targetdir == 'None':
        targetdir = str("user/" + branch + "/" + path).replace(" ","_")
    
    ##### resolve conficts
    # if there is a mode/prefer conflict we must resolve this regardless of any setting
    # skip if --force is enabled
    if not args_force:
        if args_mode != mode:
            mode = str(multi_choice_question(['batch','interactive'],'Use interactive or batch mode ? ','Settings Conflict --mode'))
        if prefer != args_prefer:
            prefer = multi_choice_question(['args','config'],'Prefer configuration or argument values ? ','Settings Conflict --prefer')    
    else:
        mode = 'batch'
        prefer = 'args'
    
    # resolve conflicts based on the mode we are in
    if mode == "interactive":
        if missing != args_missing:
            missing = multi_choice_question(['add','skip'],'Add or Skip missing directives ? ','Settings Conflict --missing')    
        if args_targetdir != 'None':
            if targetdir != args_targetdir:
                targetdir = multi_choice_question([targetdir,args_targetdir],'Target Directory ? ','Settings Conflict --target')
                marlindir = targetdir + "/Marlin"
                if not isDir(marlindir):
                    Message_Warning('Target Directory " + marlindir + " does not exist.')
                    if not createdir:
                        Message_Warning('The --createdir option is disabled. This must be enabled to continue.')
                        createdir = eval(multi_choice_question(['True','False'],'Create Target Directory ? ','Settings Conflict --createdir'))
                    if not createdir:
                        ExitStageLeft(404,"Target Directory does not exist. Operation Cancelled by user.")
                    if createdir:
                        Message_Config("Creating Target Directory: " + str(marlindir))
                        mkDir(marlindir)
        if args_importpath != 'None':
            if importpath != args_importpath:
                importpath = multi_choice_question([importpath,args_importpath],'Import Local Configuration Path ? ','Settings Conflict --importpath')    
    else:
        # we are in batch mode so we need to force values
        # must check for preferences first (args or config)
        if args_prefer != prefer:
            if prefer == "args":
                prefer = args_prefer
        Message_Warning("Batch Mode Enabled. All Conflicts will defer to " + prefer + " if set, otherwise to default (if any).")
        
        # adjust everything that is in conflict if it doesnt match what was passed to args
        # if its prefer to config then there is nothing to set from args
        if prefer == "args":
            if args_missing != missing:
                missing = args_missing

    ##### JSON Example Configuration Information
    getJSONConfig()

    ##### Download Example Files from the Internet (if not using a local path)
    getExampleFiles()

    ##### Configuration Directives from JSON Configuration File
    getJSONOptions()

    ##### Update the Configuration
    if (len(options_enable) > 0):
        enableDirectives()
    if (len(options_disable) > 0):
        disableDirectives()
    if (len(options_values) > 0):
        updateValues()

    ##### Exit gracefully
    outro()

#####################################################
##### SETUP COMMAND-LINE ARGUMENTS & HELP
#####################################################

# parse out the args (also create --help output) and then pass to main function
# https://docs.python.org/3/library/argparse.html
if __name__ == "__main__":
    intro()
    parser = argparse.ArgumentParser(description='Builds Configuration Files from Marlin Examples', conflict_handler='resolve', fromfile_prefix_chars='@')

    # files
    parser.add_argument('--importpath', type=str, metavar="SOURCE_CONFIG_PATH", help='Import a local config example path',default='None')
    parser.add_argument('--config', type=str, metavar="JSON_CONFIG_FILE", help='JSON Configuration File',default='None',required=True)
    parser.add_argument('--target', type=str, metavar="MARLIN_ROOT_DIR", help='The directory in which the files will be saved. Default is current directory. Usually this is the directory platformio.ini is in.',default='None')
    
    # boolean
    parser.add_argument('--argsfile', type=str, help='Uses marlin-configurator.ini. !! Using this file overrides all other args on the command-line !!', choices=['True','False'], default='False')
    parser.add_argument('--force', type=str, help='Forces running in batch mode, removing all prompts & preferring args over configuration values', choices=['True','False'],default='False')
    parser.add_argument('--validate', type=str, help='Validate JSON Configuration file syntax.', choices=['True','False'],default='False')
    parser.add_argument('--createdir', type=str, help='Creates the target directory if it does not exist.', choices=['True','False'],default='False')
    parser.add_argument('--silent', type=str, help='Suppress Configuration Change Information. Default: false', choices=['True','False'],default='False')

    # behavioral preferences
    parser.add_argument('--prefer', type=str, help='Prefer either the JSON config, or the command-line when there is a conflict.', choices=['config','args'],default='args')
    parser.add_argument('--missing', type=str, help='Add missing directives instead of skipping them. Default: skip.', choices=['add','skip'], default='skip')
    parser.add_argument('--mode', type=str, help='Batch mode will skip all prompts except preference. Interactive mode will present choices when conflicts arise.', choices=['batch','interactive'], default='interactive')
    
    # process args & read from conf file if set
    args = parser.parse_args()
    if (eval(args.argsfile)):
        Message_Warning("Using marlin-configurator.ini. All other passed arguments ignored.")
        args = parser.parse_args(['@marlin-configurator.ini'])

    # pass to main function
    main(args)
