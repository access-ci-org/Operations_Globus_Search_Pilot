#!/bin/sh
#
# Installation script for the RSA Authentication Agent 7.1 for PAM.
#
#
#********************************************************************************
#* COPYRIGHT (C) 2007-2010 by EMC Corporation.
#*      ---ALL RIGHTS RESERVED---
#********************************************************************************
#
echo_no_nl_mode="unknown"
UNAME=`uname`
UNAMER=`uname -r`
MODULE_DIR_PRIMARY="/usr/lib/security"
MODULE_DIR_SECONDARY="/usr/lib/security/64"
PAM_AGENT_MODULE="pam_securid"
ARCH=""

##############################################################################
# Trap
#       this will trap any escape characters, and allow the program to abort normally
#       by calling abort_installation
##############################################################################
trap 'trap "" 1 2 15; abort_installation' 1 2 15

##############################################################################
# abort_installation()
# This subroutine removes files that were recently installed and restores
# the previous installation files, if they existed.
##############################################################################
abort_installation()
{
#CP__need to fix this when done. Make sure to set values for each file placed somewhere
echo ""
  echo "Aborting Un-install"

  exit 1
}

##############################################################################
# echo_no_nl()
#       Echo a string with no carriage return (if possible).  Must set
#       $echo_no_nl to "unknown" before using for the first time.
##############################################################################
echo_no_nl()
{
  if [ "$echo_no_nl_mode" = "unknown" ] ; then
     echo_test=`echo \\\c`
     if [ "$echo_test" = "\c" ] ; then
        echo_no_nl_mode="-n"
     else
        echo_no_nl_mode="\c"
     fi
  fi

  if [ "$echo_no_nl_mode" = "\c" ] ; then
     echo $* \\c
  else
     echo -n $*
  fi
}

##############################################################################
# getfilename()
# Gets a filename
#   $1  The string to print to prompt the user
#   $2  The default value if user hits <Enter> (y/n)
#   $3  Type : DIRECTORY, EXISTINGFILE, NEWFILE, NEWDIRECTORY
# The variable $YESORNO is set in accordance to what the user entered.
##############################################################################
getfilename()
{
#####################################################
# Set up line parameters as $1 and $2 are overwritten
#####################################################
  theprompt=$1
  thedefault=$2
  thetype=$3

  theans=""
  until [ -n "$theans" ] ;
  do
    echo ""
    echo_no_nl "$theprompt [$thedefault] "
    read theans

    if [ "$theans" = "" ] ; then
      theans=$thedefault
    fi
    case $thetype in
        DIRECTORY) if [ ! -d "$theans" ]; then
                        echo Directory $theans doesn\'t exist
                        theans=""
                   fi;;
        READFILE)  if [ ! -f "$theans" ]; then
                        echo File $theans doesn\'t exist
                        theans=""
                   elif [ ! -r "$theans" ]; then
                        echo File "$theans" isn\'t readable
                        theans=""
                   fi;;
        WRITEFILE)  if [ ! -f "$theans" ]; then
                        echo File $theans doesn\'t exist
                        theans=""
                   elif [ ! -w "$theans" ]; then
                        echo File "$theans" isn\'t writable
                        theans=""
                   fi;;
        EXECFILE)  if [ ! -f "$theans" ]; then
                        echo File $theans doesn\'t exist
                        theans=""
                   elif [ ! -x "$theans" ]; then
                        echo File "$theans" isn\'t writable
                        theans=""
                   fi;;
        NEWFILE)   if [ -f "$theans" ]; then
                        echo File $theans already exist
                        theans=""
                   elif [ ! -d `dirname $theans` ]; then
                        echo Directory `dirname $theans` doesn\'t exist
                        theans=""
                   elif [ ! -w `dirname $theans` ]; then
                        echo Directory `dirname $theans` isn\'t writable
                        theans=""
                   fi;;
        *);;
    esac
  done

}

##############################################################################
# getyesorno()
# Gets either a "yes" or a "no" in the traditional (y/n) pattern
#               $1      The default value if user hits <Enter> (TRUE/FALSE)
#               $2      The string to print to prompt the user
# The variable $YESORNO is set in accordance to what the user entered.
##############################################################################
getyesorno()
{
#####################################################
# Set up line parameters as $1 and $2 are overwritten
#####################################################
  yesornodef=$1
  yesornoprompt=$2

  YESORNO=""
  until [ -n "$YESORNO" ] ;
  do
    echo ""
    echo_no_nl $yesornoprompt
    read YESORNO

    case "$YESORNO"
    in
      y|Y )  YESORNO=TRUE;;
      n|N )  YESORNO=FALSE;;
      ''  )  YESORNO=$yesornodef;;
      *   )  echo ""
             echo "Please enter 'y', 'n' or '<return>' "
             YESORNO="";;
    esac
  done

}

check_user()
{
#########################
# make sure user is root
#########################


if [ "$USER_NAME" != root ]; then
    echo "You Must be ROOT to uninstall this agent"
    abort_installation
fi
}

############################################################
# Check to see if this is a supported platform.
############################################################
check_platform()
{
case $UNAME
   in
     'SunOS'  )  SUN_HARDWARE=`uname -p`
				if [ `/usr/bin/isainfo -kv | cut -f 1 -d '-'` = "64" ] ; then
					ARCH=64bit
					MODULE_DIR_PRIMARY="/usr/lib/security"
					MODULE_DIR_SECONDARY="/usr/lib/security/64"
                else
					ARCH=32bit
					MODULE_DIR_PRIMARY="/usr/lib/security"
					MODULE_DIR_SECONDARY=""
                fi
	       case "$SUN_HARDWARE" in
		'i386' )
                    WHOAMISOL=`/usr/xpg4/bin/id -un`
					if [ "$WHOAMISOL" = "" ] ; then
					    WHOAMISOL=`/usr/ucb/whoami`
					fi
					# Solaris 11 doesn't have /usr/ucb
					if [ "$WHOAMISOL" = "" ] ; then
					    WHOAMISOL=`/usr/bin/whoami`
					fi
                    OS_DIR="sol_x86"
                    OS_EXT="so"
                    USER_NAME=`echo $WHOAMISOL`;;
                'sparc' )
                    WHOAMISOL=`/usr/xpg4/bin/id -un`
					if [ "$WHOAMISOL" = "" ] ; then
					    WHOAMISOL=`/usr/ucb/whoami`
					fi
					# Solaris 11 doesn't have /usr/ucb
					if [ "$WHOAMISOL" = "" ] ; then
					    WHOAMISOL=`/usr/bin/whoami`
					fi
                    OS_DIR="sparc"
                    OS_EXT="so"
                    USER_NAME=`echo $WHOAMISOL`;;
		esac;;

     'Linux' ) LNX_VERS=`echo $UNAMER `
				if [ `getconf LONG_BIT` = "32" ] ; then
					ARCH=32bit
					MODULE_DIR_PRIMARY="/lib/security"
					MODULE_DIR_SECONDARY=""
				else
					ARCH=64bit
					MODULE_DIR_PRIMARY="/lib/security"
					MODULE_DIR_SECONDARY="/lib64/security/"
				fi
                case "$LNX_VERS" in
                * )
                    WHOAMILNX=`/usr/bin/whoami`
                    OS_EXT="so"
		    OS_DIR="lnx"
		            USER_NAME=`echo $WHOAMILNX`;;
                esac;;

	'HP-UX' ) 
				if [ `getconf KERNEL_BITS` = "32" ] ; then
					ARCH=32bit
					MODULE_DIR_PRIMARY="/usr/lib/security/hpux32"
					MODULE_DIR_SECONDARY=""
				else
					ARCH=64bit
					MODULE_DIR_PRIMARY="/usr/lib/security/hpux32"
					MODULE_DIR_SECONDARY="/usr/lib/security/hpux64"
				fi
				if [ `uname -m | grep "ia"` ] ; then
			      HP_VERS=hp_itanium
		        else
			      HP_VERS=hp_parisc
				fi 
	case "$HP_VERS" in
		'hp_itanium' )
                   WHOAMIHP11=`/bin/whoami`
                   OS_DIR="hp_itanium"
                   OS_EXT="1"
                   MODULE_DIR="/usr/lib/security/hpux32"
                   USER_NAME=`echo $WHOAMIHP11`;;
               * )
                   WHOAMIHP11=`/bin/whoami`
                   OS_DIR="hp_parisc"
                   OS_EXT="1"
                   USER_NAME=`echo $WHOAMIHP11`;;
               esac;;

     'AIX' ) AIX_VERS=`uname -vr | awk '{print $2 * 1000 + $1}'`
				if [ `bootinfo -K` = "32" ] ; then
                   ARCH=32bit
				   MODULE_DIR_PRIMARY="/usr/lib/security"
				   MODULE_DIR_SECONDARY=""
                else
                   ARCH=64bit
				   MODULE_DIR_PRIMARY="/usr/lib/security"
				   MODULE_DIR_SECONDARY="/usr/lib/security/64"
                fi
                case "$AIX_VERS" in
                *)
                    OS_EXT="so";
		    OS_DIR="aix"
                    USER_NAME=`/usr/bin/whoami`
                esac;;
     *   )  echo ""
            echo "Sorry, $UNAME is not currently supported."
            echo ""
            abort_installation ;;
esac
}

############################################################
# Ask the user for the PAM installation directory.
############################################################
setup_paths()
{
###########################################
# Get the Agent directory path
###########################################
theans=""
DEFAULT_AGENT_ROOT="/opt"
AGENT_ROOT=""

echo ""
getfilename "Please enter the root path for the RSA Authentication Agent for PAM directory" $DEFAULT_AGENT_ROOT DIRECTORY
if [ "$theans" = "" ]; then
    theans="$DEFAULT_AGENT_ROOT"
fi

while [ ! -d "$theans/pam" ] 
do
    echo PAM Agent is not installed in "$theans/pam"
    getyesorno FALSE  "OnceAgain you want to enter the PAM directory path? (y/n) [n]"
    if [ "$YESORNO" = FALSE ] ; then
    	abort_installation
    else
    	getfilename "Please enter the root path for the RSA Authentication Agent for PAM directory" $DEFAULT_AGENT_ROOT DIRECTORY
    	if [ "$theans" = "" ]; then
        	theans="$DEFAULT_AGENT_ROOT"
        fi
    fi
done

getyesorno FALSE "Are you sure that you would like to uninstall the RSA Authentication Agent 7.1 for PAM? (y/n) [n]"

if [ "$YESORNO" = FALSE ] ; then
    echo "Exiting without uninstalling the agent"
    abort_installation
fi

if [ "$AGENT_ROOT" = "" ]; then
    AGENT_ROOT="$theans"
fi


echo ""
getyesorno FALSE "The RSA Authentication Agent for PAM will be deleted from the $AGENT_ROOT directory.  Ok? (y/n) [n]"
if [ "$YESORNO" = FALSE ] ; then
    echo "Exiting without uninstalling the agent"
    abort_installation
fi

echo ""
getyesorno FALSE "<Warning Symbol> If you uninstall the RSA module while there are references to the RSA module in the PAM configuration file ( file pam.conf or inside the directory pam.d), you will be locked out of your system. Proceed with uninstall? 
$AGENT_ROOT directory.  Ok? (y/n) [n]"
if [ "$YESORNO" = FALSE ] ; then
    echo "Exiting without uninstalling the agent"
    abort_installation
fi

}

uninstall()
{
    cd "$AGENT_ROOT"
    rm -rf pam
    rm /etc/sd_pam.conf
if  [ $ARCH = "64bit" ]; then
    if [ "$OS_DIR" = "sparc" ] || [ "$OS_DIR" = "hp_itanium" ] || [ "$OS_DIR" = "lnx" ] 
    then
                 if [ -f  "$MODULE_DIR_SECONDARY"/"$PAM_AGENT_MODULE"."$OS_EXT" ]; then
			rm "$MODULE_DIR_SECONDARY"/"$PAM_AGENT_MODULE"."$OS_EXT"
                 fi
	fi
        if [ -f "$MODULE_DIR_PRIMARY"/"$PAM_AGENT_MODULE"."$OS_EXT" ]; then
		rm "$MODULE_DIR_PRIMARY"/"$PAM_AGENT_MODULE"."$OS_EXT"
        fi
else
	if [ -f "$MODULE_DIR_PRIMARY"/"$PAM_AGENT_MODULE"."$OS_EXT" ]; then
		rm "$MODULE_DIR_PRIMARY"/"$PAM_AGENT_MODULE"."$OS_EXT"
        fi
fi
if [ -f /etc/sd_pam.conf ] || [ -f "$MODULE_DIR_PRIMARY"/"$PAM_AGENT_MODULE"."$OS_EXT" ] || [ -f  "$MODULE_DIR_SECONDARY"/"$PAM_AGENT_MODULE"."$OS_EXT" ];then
   echo ""
   echo "Un-install is not succesfull"
   exit 1
fi
}

    check_platform
    check_user
    setup_paths
    uninstall
    echo ""
    echo "************************************************************************"
    echo "* You have successfully uninstalled RSA Authentication Agent 7.1 for PAM"
    echo "************************************************************************"
    echo ""

