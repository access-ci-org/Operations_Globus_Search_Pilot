#!/bin/sh 
#
# Installation script for the RSA Authentication Agent 7.1 for PAM.
#
#
#********************************************************************************
#* COPYRIGHT (C) 2007-2010 by EMC Corporation.
#*	---ALL RIGHTS RESERVED---
#********************************************************************************
#

############################################################
# Set default values and commands for the shell script.
############################################################
UNAME=`uname`
UNAMER=`uname -r`
HOSTNAME=`hostname`
USER_NAME=""
GREP=`which grep`
ECHO=`which echo`

HERE=`dirname $0` 
THEPWD=`/bin/pwd`

if [ "$HERE" = "." ]; then
	HERE="$THEPWD"
else
#if $HERE isn't absolute path add `pwd` to it

	cd "$HERE"
	HERE=`/bin/pwd`
	cd "$THEPWD"
fi

########################
########################
CONFIG_FILE=""
PAM_AGENT="/tmp/toto"
PAM_AGENT_TAR="sd_pam_agent.tar"
PAM_AGENT_MODULE="pam_securid"
#PAM_AGENT_DOC="doc"
PAM_AGENT_README="readme.html"
PAM_AGENT_TAR_GZ="$PAM_AGENT_TAR.gz"
PAM_CONFIG="/etc/sd_pam.conf"
LICENSE="$HERE/6072A0_End User License Agreement April 2011.txt"
MODULE_DIR_PRIMARY="/usr/lib/security"
MODULE_DIR_SECONDARY="/usr/lib/security/64"
ARCH=""
PATH_ROOT=""
PREV_INSTL=FALSE
myVersion=""
PAM_CONFIG_SAVE=""
PAM_CONFIG_SOMEHOW_DELETED=FALSE
systemSEstatus=""
RHEL_OSversion=""
setVARACEcontext=FALSE
PAM_POLICY_DIR=/etc/selinux/targeted/modules
SELINUX_POLICY_MAKEFILE="/usr/share/selinux/devel/Makefile"
CREATE_POLICYFILE_OS_VERSION="create_policyfile_5"
PAM_POLICY_FILE=rsapolicy.te
PAM_POLICY_FILE_pp=rsapolicy.pp
echo_no_nl_mode="unknown"


##############################################################################
# Trap 
#	this will trap any escape characters, and allow the program to abort normally 
#	by calling abort_installation
##############################################################################
trap 'trap "" 1 2 15; abort_installation' 1 2 15

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
# getAcceptDecline()
# Gets either a "Accept" or a "Decline" in the traditional (a/d) pattern 
#               $1      The default value if user hits <Enter> (TRUE/FALSE)
#               $2      The string to print to prompt the user
# The variable $AORD is set in accordance to what the user entered.
##############################################################################
getAcceptDecline()
{
#####################################################
# Set up line parameters as $1 and $2 are overwritten
#####################################################
  AorDdef=$1
  AorDprompt=$2
 
  AORD=""
  until [ -n "$AORD" ] ;
  do
    echo ""
    echo_no_nl $AorDprompt
    read AORD
 
    AORD=`echo $AORD | tr '[a-z]' '[A-Z]'`

    case "$AORD"
    in
      A|ACCEPT )  AORD=TRUE;;
      D|DECLINE )  AORD=FALSE;;
      ''  )  AORD=$AorDdef;;
      *   )  echo ""
             echo "Please enter 'A', 'D' or '<return>' "
             AORD="";;
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


##############################################################################
# abort_installation()
# This subroutine removes files that were recently installed and restores
# the previous installation files, if they existed.
##############################################################################
abort_installation()
{
#CP__need to fix this when done. Make sure to set values for each file placed somewhere
echo ""
  echo "Aborting Installation..."
  exit 1
}


############################################################
# Display the License and Copyright files.
############################################################
startup_screen()
{

    # Changed so that we could have both license files shown
    if [ -f "$LICENSE" ] ; then
	    more "$LICENSE" 
    else
	    echo "The License Agreement text file could not be found in the current directory."
	    echo "Installation is aborting..."
            abort_installation
    fi
 
     getAcceptDecline FALSE "Do you accept the License Terms and Conditions stated above? (Accept/Decline) [D]"
    if [ "$AORD" = FALSE ] ; then
	abort_installation;
    fi
    echo ""
    echo ""
    echo ""
}

############################################################
# Check to see if the environment variable VAR_ACE is
# defined and sdconf.rec exists
############################################################
check_sdconf()
{
noerror=0
#Removing  VAR_ACE check from environment  
VAR_ACE="/var/ace"
theans=""
while [ "$theans" = "" ] 
do
    getfilename "Enter Directory where sdconf.rec is located" $VAR_ACE DIRECTORY
    if [ ! -f "$theans/sdconf.rec" ]; then 
	echo file "$theans/sdconf.rec" not found
	theans=""
    elif [ ! -r "$theans/sdconf.rec" ]; then
	echo file "$theans/sdconf.rec" not readable: change protection if needed
    	VAR_ACE="$theans"
	theans=""
    else
	if [ "$theans" != "" ]; then
    		VAR_ACE="$theans"
	fi
	break
    fi
	
done

}

############################################################
# Check to see if this is a supported platform.
############################################################
check_platform()
{
#echo "check_platform: uname is [$UNAME]"
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
			# Solaris 11 doesn't have /usr/ucb/ 
			if [ "$WHOAMISOL" = "" ] ; then
			     WHOAMISOL=`/usr/bin/whoami`
			fi
                    OS_DIR="sol_x86" 
		    OS_EXT="so"
		    #
		    # Need this so grep handles extended expressions like '[[:space:]]'.
		    #
		    GREP="/usr/xpg4/bin/grep -E"

		    USER_NAME=`echo $WHOAMISOL`;;
		'sparc' )
		    WHOAMISOL=`/usr/xpg4/bin/id -un`
			if [ "$WHOAMISOL" = "" ] ; then
			    WHOAMISOL=`/usr/ucb/whoami`
			fi
			# Solaris 11 doesn't have /usr/ucb/
			if [ "$WHOAMISOL" = "" ] ; then
			    WHOAMISOL=`/usr/bin/whoami` 
			fi	
                    OS_DIR="sparc" 
		    OS_EXT="so"
		    #
		    # Need this so grep handles extended expressions like '[[:space:]]'.
		    #
		    GREP="/usr/xpg4/bin/grep -E"

		    USER_NAME=`echo $WHOAMISOL`;;
                esac;;

     'Linux' ) LNX_VERS=`uname -i`
		if [ `getconf LONG_BIT` = "32" ] ; then
			ARCH=32bit
			MODULE_DIR_PRIMARY="/lib/security"
			MODULE_DIR_SECONDARY=""
		else
			ARCH=64bit
			MODULE_DIR_PRIMARY="/lib/security"
			MODULE_DIR_SECONDARY="/lib64/security/"
		fi
		OS_DIR="lnx"
		WHOAMILNX=`/usr/bin/whoami`
		OS_EXT="so"

                # Need to check SELINUX status with RHEL version
                if [ -f /etc/redhat-release ]; then
			LINUX_TYPE=RHEL
		else
			LINUX_TYPE=SUSE
		fi

                if  [ $LINUX_TYPE = "RHEL" ]; then
                    systemSEstatus=`sestatus | sed -n -e 's/SELinux status:[ 	]*\(.*\)/\1/p'`
                    if [ "$systemSEstatus"  != "disabled" ] ; then
                        RHEL_OSversion=`sed -n -e 's/^Red Hat .*\([0-9][0-9]*\)[.][0-9][0-9]*.*/\1/p' -e 's/^CentOS .*\([0-9][0-9]*\)[.][0-9][0-9]*.*/\1/p' </etc/redhat-release`
                        if [ "$RHEL_OSversion" -ge "5" ]; then
				setVARACEcontext=TRUE
                        fi
                        if [ "$RHEL_OSversion" -ge "6" ]; then
                               CREATE_POLICYFILE_OS_VERSION="create_policyfile_6"
                        fi
                    fi
                    if [ "${setVARACEcontext}" = "TRUE" ]
                    then
                        ########################################################
                        # If SELinux is enabled,
                        # then the installation configures SELinux
                        # which includes creating a policy file.
                        # However, this cannot be done
                        # unless some optional packages are installed.
                        # The exact package containing these files
                        # appears to vary between major releases.
                        # For example, /usr/share/selinux/devel/Makefile
                        # appears in selinux-policy-devel in Release 5 and 7
                        # but appears in selinux-policy in Release 6.
                        ########################################################
                        if [ ! -f "${SELINUX_POLICY_MAKEFILE}" ]
                        then
                            echo "${SELINUX_POLICY_MAKEFILE} is not present."
                            echo "You may need to install additional packages such as"
                            echo "selinux-policy-devel and policycoreutils-devel"
                            echo "to allow this installation to create the policy file."
                            getyesorno TRUE "Would you like to continue anyway? (y/n) [y]"
                            if [ "$YESORNO" = TRUE ]
                            then
                                setVARACEcontext=FALSE
                            else
                                abort_installation
                            fi
                        fi
                    fi
                fi
		#
	        # Need this so that echo does the right thing with newlines.
	        #
	        ECHO="$ECHO -e"
                USER_NAME=`echo $WHOAMILNX`
                case "$LNX_VERS" in
                'x86_64' ) 
                    echo "";;
                 'i386' ) 
                    echo "";;
		    
               *   )  echo ""
                    echo "Sorry, this is not a supported configureation"
                    echo ""
                    abort_installation ;;
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
		   PAM_AGENT_MODULE="pam_securid"
		   USER_NAME=`echo $WHOAMIHP11`;;

               * )
		   WHOAMIHP11=`/bin/whoami`
		           echo ""
                   echo "Sorry, this is not a supported configureation"
                    echo ""
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
		    OS_DIR="aix"
                    OS_EXT="so"
                    USER_NAME=`/usr/bin/whoami`
       		esac;; 
     *   )  echo ""
            echo "Sorry, $UNAME is not currently supported."
            echo ""
            abort_installation ;;
esac
}


############################################################
# Ask the user for the destination of the Agent files and
# other installation information, documentation
############################################################
setup_paths()
{
###########################################
# Get the Agent directory path
###########################################
theans=""
newtheans=""
DEFAULT_AGENT_ROOT="/opt"
AGENT_ROOT=""

echo ""
getfilename "Please enter the root path for the RSA Authentication Agent for PAM directory" $DEFAULT_AGENT_ROOT DIRECTORY
if [ "$theans" = "" ]; then
    theans="$DEFAULT_AGENT_ROOT"
fi
while [ -d "$theans/pam" ] 
do
    newtheans=$theans
    echo PAM Agent is already installed in the "$theans/pam"
    getyesorno TRUE "Would you like to Upgrade/overwrite  it? (y/n) [y]"
    if [ "$YESORNO" = FALSE ] ; then
        getfilename "Please enter the root path for the new RSA Authentication Agent for PAM directory" $DEFAULT_AGENT_ROOT DIRECTORY
        if [ "$theans" = "$newtheans" ]; then
                echo ""
        	echo "Installation is aborting.....Both Exisitng PAM Agent and New PAM Agent installation directory are same"
                abort_installation
        fi
    else
        AGENT_ROOT="$theans"
	PREV_INSTL=TRUE
        break
    fi
done
if [ "$AGENT_ROOT" = "" ]; then
    AGENT_ROOT="$theans"
fi

echo ""
if [ "$PREV_INSTL" = TRUE ] ; then
        if [ -f "$PAM_CONFIG" ]; then
                PAM_CONFIG_SAVE="$PAM_CONFIG."`date +%D%T | sed "s/\//-/g" `
				cp "$PAM_CONFIG" "$PAM_CONFIG_SAVE"
	    else
				PAM_CONFIG_SOMEHOW_DELETED=TRUE
		fi
		if [ "$OS_DIR" = "lnx" ]; then
		     if  [ $ARCH = "64bit" ]; then
			      myVersion=`strings "$MODULE_DIR_SECONDARY/$PAM_AGENT_MODULE.$OS_EXT"  | grep "@(#)RSA" | awk '{print $4}'`
			 fi
		else
		     myVersion=`strings "$MODULE_DIR_PRIMARY/$PAM_AGENT_MODULE.$OS_EXT"  | grep "@(#)RSA" | awk '{print $4}'`
		fi
		myVersion=`echo $myVersion | awk '{print $1}'`
        echo "The RSA Authentication Agent is upgraded to PAM 7.1 will be upgraded in the $AGENT_ROOT directory."
else
    echo "The RSA Authentication Agent for PAM 7.1 will be installed in the $AGENT_ROOT directory."
fi

}

#################
# Check PAM_CONFIG to see if it has a line that defines VARIABLE.
# If so, do nothing.  If not, append ENTRY to the end of PAM_CONFIG.
#################
check_config_line()
{
VARIABLE=$1
ENTRY=$2

if $GREP "^[[:space:]]*$VARIABLE[[:space:]]*=" $PAM_CONFIG > /dev/null; then
    echo "$VARIABLE exists - entry will not be updated"
else
    echo "$VARIABLE does not exist - entry will be appended"
    $ECHO "$ENTRY" >> "$PAM_CONFIG"
    echo "" >> "$PAM_CONFIG"
    echo "" >> "$PAM_CONFIG"
fi
}

#################
# Create PAM config file
#################

create_conf()
{

touch "$PAM_CONFIG"

$ECHO "\nChecking $PAM_CONFIG:\n"

check_config_line VAR_ACE \
"#VAR_ACE ::  the location where the sdconf.rec, sdstatus.12 and securid files will go\n\
# default value is /var/ace\n\
VAR_ACE=$VAR_ACE"

check_config_line RSATRACELEVEL \
"#RSATRACELEVEL :: To enable logging in UNIX for securid authentication\n\
#                   :: 0 Disable logging for securid authentication\n\
#                   :: 1 Logs regular messages for securid authentication\n\
#                   :: 2 Logs function entry points for securid authentication\n\
#                   :: 4 Logs function exit points for securid authentication\n\
#                   :: 8 All logic flow controls use this for securid authentication\n\
# NOTE              :: For combinations, add the corresponding values\n\
# default value is 0\n\
RSATRACELEVEL=0"

check_config_line RSATRACEDEST \
"#RSATRACEDEST :: Specify the file path where the logs are to be redirected for securid authentication.\n\
#                   :: If this is not set, by default the logs go to Error output.\n\
RSATRACEDEST="

check_config_line ENABLE_USERS_SUPPORT \
"#ENABLE_USERS_SUPPORT :: 1 to enable; 0 to disable users support\n\
# default value is 0\n\
ENABLE_USERS_SUPPORT=0"

check_config_line INCL_EXCL_USERS \
"#INCL_EXCL_USERS :: 0 exclude users from securid authentication\n\
#                   :: 1 include users for  securid authentication\n\
# default value is 0\n\
INCL_EXCL_USERS=0"

check_config_line LIST_OF_USERS \
"#LIST_OF_USERS :: a list of users to include or exclude from SecurID Authentication...Example:\n\
LIST_OF_USERS=user1:user2"

check_config_line PAM_IGNORE_SUPPORT_FOR_USERS \
"#PAM_IGNORE_SUPPORT_FOR_USERS :: 1 to return PAM_IGNORE if a user is not SecurID authenticated due to user exclusion support\n\
#                   :: 0 to UNIX authenticate a user that is not SecurID authenticated due to user exclusion support\n\
# default value is 0\n\
PAM_IGNORE_SUPPORT_FOR_USERS=0"

check_config_line ENABLE_GROUP_SUPPORT \
"#ENABLE_GROUP_SUPPORT :: 1 to enable; 0 to disable group support\n\
# default value is 0\n\
ENABLE_GROUP_SUPPORT=0"

check_config_line INCL_EXCL_GROUPS \
"#INCL_EXCL_GROUPS :: 1 to always prompt the listed groups for securid authentication (include)\n\
#                 :: 0 to never prompt the listed groups for securid authentication (exclude)\n\
# default value is 0\n\
INCL_EXCL_GROUPS=0"

check_config_line LIST_OF_GROUPS \
"#LIST_OF_GROUPS :: a list of groups to include or exclude...Example\n\
LIST_OF_GROUPS=other:wheel:eng:othergroupnames "

check_config_line PAM_IGNORE_SUPPORT \
"#PAM_IGNORE_SUPPORT :: 1 to return PAM_IGNORE if a user is not SecurID authenticated due to their group membership\n\
#                   :: 0 to UNIX authenticate a user that is not SecurID authenticated due to their group membership\n\
# default value is 0\n\
PAM_IGNORE_SUPPORT=0"

check_config_line AUTH_CHALLENGE_USERNAME_STR \
"#AUTH_CHALLENGE_USERNAME_STR :: prompt message to ask user for their username/login id\n\
AUTH_CHALLENGE_USERNAME_STR=Enter USERNAME :"

check_config_line AUTH_CHALLENGE_RESERVE_REQUEST_STR \
"#AUTH_CHALLENGE_RESERVE_REQUEST_STR :: prompt message to ask administrator for their System password\n\
AUTH_CHALLENGE_RESERVE_REQUEST_STR=Please enter System Password for root :"

check_config_line AUTH_CHALLENGE_PASSCODE_STR \
"#AUTH_CHALLENGE_PASSCODE_STR :: prompt message to ask user for their Passcode\n\
AUTH_CHALLENGE_PASSCODE_STR=Enter PASSCODE :"

check_config_line AUTH_CHALLENGE_PASSWORD_STR \
"#AUTH_CHALLENGE_PASSWORD_STR :: prompt message to ask user for their Password\n\
AUTH_CHALLENGE_PASSWORD_STR=Enter your PASSWORD :"

check_config_line BACKOFF_TIME_FOR_RSA_EXCLUDED_UNIX_USERS \
"#BACKOFF_TIME_FOR_RSA_EXCLUDED_UNIX_USERS :: 0  Disable retry UNIX authentication after failed login attempt \n\
#                   :: 1  Enable retry UNIX authentication after failed login attempt but treated setting as pow(3, failattempts) sec delay\n\
#                   :: 2  Enable retry UNIX authentication after failed login attempt but treated setting as pow(3, failattempts) sec delay\n\
#                   :: 3  Enable retry UNIX authentication after failed login attempt with pow(3, failattempts) sec delay\n\
#                   :: 4  Enable retry UNIX authentication after failed login attempt with pow(4, failattempts) sec delay\n\
#                   :: 5/Above  Enable retry UNIX authentication after failed login attempt with pow(5/Above, failattempts) sec delay\n\
#                   :: If no BACKOFF_TIME_FOR_RSA_EXCLUDED_UNIX_USERS setting is present, then  treated as pow(4, failattempts) sec delay\n\
# default value is 4\n\
BACKOFF_TIME_FOR_RSA_EXCLUDED_UNIX_USERS=4"

chmod 644 "$PAM_CONFIG" 
}


############################################################
# Install the RSA Authentication Agent 7.1 for PAM library and documentation.
############################################################
install_pam_agent()
{
##############
#untar the RPM file
##############

cd $AGENT_ROOT/
if [ -f "$HERE/$OS_DIR/$PAM_AGENT_TAR" ]; then
	tar xvf "$HERE/$OS_DIR/$PAM_AGENT_TAR"
elif [ -f "$HERE/$OS_DIR/$PAM_AGENT_TAR_GZ" ]; then
    tar xzvf "$HERE/$OS_DIR/$PAM_AGENT_TAR_GZ"
else
    echo Error $HERE/$OS_DIR/$PAM_AGENT_TAR or $HERE/$OS_DIR/$PAM_AGENT_TAR_GZ does not exist
    abort_installation
fi

if  [ $ARCH = "32bit" ]; then
        if [ -d "$AGENT_ROOT/pam/bin/64bit" ]; then
                rm -rf "$AGENT_ROOT/pam/bin/64bit"
        fi
        if [ -d "$AGENT_ROOT/pam/lib/64bit" ]; then
                rm -rf "$AGENT_ROOT/pam/lib/64bit"
        fi
fi

# RHEL 6.x 64 bit machine doesn't show 32bit library as shared library even for
# acetest and acestatus also OS is unable to rectify 32bit executables so removing 32bit executables
if  [ $ARCH = "64bit" ]; then
	if [ "$OS_DIR" = "lnx" ]; then
		if [ -d "$AGENT_ROOT/pam/bin/32bit" ]; then
       	    rm -rf "$AGENT_ROOT/pam/bin/32bit"
        fi
        if [ -d "$AGENT_ROOT/pam/lib/32bit" ]; then
            rm -rf "$AGENT_ROOT/pam/lib/32bit"
        fi
	fi
fi


if  [ $ARCH = "64bit" ]; then
	if [ "$OS_DIR" = "sparc" ] || [ "$OS_DIR" = "hp_itanium" ] || [ "$OS_DIR" = "lnx" ] 
	then
		if [ -f $AGENT_ROOT/pam/lib/$ARCH/$PAM_AGENT_MODULE.$OS_EXT ]; then
			cp "$HERE/"uninstall* "$AGENT_ROOT/pam"
			cp "$AGENT_ROOT/pam/lib/$ARCH/$PAM_AGENT_MODULE.$OS_EXT" "$MODULE_DIR_SECONDARY"
       		 	chmod 755 "$MODULE_DIR_SECONDARY/$PAM_AGENT_MODULE.$OS_EXT"
                        if [ "$OS_DIR" != "lnx" ]; then
							cp "$AGENT_ROOT/pam/lib/32bit/$PAM_AGENT_MODULE.$OS_EXT" "$MODULE_DIR_PRIMARY"
							chmod 755 "$MODULE_DIR_PRIMARY/$PAM_AGENT_MODULE.$OS_EXT"
                        fi
    	else
       		echo Error  Could not find $PAM_AGENT_MODULE.$OS_EXT in $AGENT_ROOT/pam/$OS_DIR directory.
        	abort_installation
		fi
	else
		if [ -f $AGENT_ROOT/pam/lib/32bit/$PAM_AGENT_MODULE.$OS_EXT ]; then
			cp "$HERE/"uninstall* "$AGENT_ROOT/pam"
			cp "$AGENT_ROOT/pam/lib/32bit/$PAM_AGENT_MODULE.$OS_EXT" "$MODULE_DIR_PRIMARY"
			chmod 755 "$MODULE_DIR_PRIMARY/$PAM_AGENT_MODULE.$OS_EXT"
		else
			echo Error  Could not find $PAM_AGENT_MODULE.$OS_EXT in $AGENT_ROOT/pam/$OS_DIR directory.
			abort_installation
		fi
	fi
else
	if [ -f $AGENT_ROOT/pam/lib/$ARCH/$PAM_AGENT_MODULE.$OS_EXT ]; then
        	cp "$HERE/"uninstall* "$AGENT_ROOT/pam"
        	cp "$AGENT_ROOT/pam/lib/$ARCH/$PAM_AGENT_MODULE.$OS_EXT" "$MODULE_DIR_PRIMARY"
			chmod 755 "$MODULE_DIR_PRIMARY/$PAM_AGENT_MODULE.$OS_EXT"
    	else
        	echo Error Could not find $PAM_AGENT_MODULE.$OS_EXT in $AGENT_ROOT/pam/$OS_DIR directory.
        	abort_installation
	fi
fi
					
cd "$HERE"
chown -R root "$AGENT_ROOT/pam"
chgrp -R 0    "$AGENT_ROOT/pam"
chmod -R 700  "$AGENT_ROOT/pam"

}

check_user()
{
#########################
# make sure user is root
#########################

if [ "$USER_NAME" != root ]; then 
    echo "You Must be ROOT to install this agent"
    abort_installation
fi
}

selinux_policy()
{
if [ "$setVARACEcontext" = TRUE ] ; then
    echo "**********************************************************************"
    echo "*         Adding label for pam_securid.so                            *" 
    if  [ $ARCH = "64bit" ]; then
         semanage fcontext -a -t textrel_shlib_t "$MODULE_DIR_SECONDARY/$PAM_AGENT_MODULE.$OS_EXT"
         restorecon  "$MODULE_DIR_SECONDARY/$PAM_AGENT_MODULE.$OS_EXT"
    else
         semanage fcontext -a -t textrel_shlib_t  "$MODULE_DIR_PRIMARY/$PAM_AGENT_MODULE.$OS_EXT"
         restorecon  "$MODULE_DIR_PRIMARY/$PAM_AGENT_MODULE.$OS_EXT"
    fi
    #securid uses /var/ace to store its authorization content, so added a label for this directory  
    echo "*         Adding label for $VAR_ACE directory                        *"
    semanage fcontext -a -t var_auth_t '$VAR_ACE(/.*)?'
    restorecon -R  $VAR_ACE
    echo "                                                                      "
    cd "$PAM_POLICY_DIR"
    
    if [ -f "$PAM_POLICY_FILE_pp" ]; then
       getyesorno TRUE "Would you like to overwrite  rsapolicy.pp policy file? (y/n) [y]"
       if [ "$YESORNO" = TRUE ] ; then
           rm -rf $PAM_POLICY_FILE
           rm -rf $PAM_POLICY_FILE_pp
           "$CREATE_POLICYFILE_OS_VERSION"
           echo "*         Creating rsapolicy.pp policy file                          *"
           make -f "${SELINUX_POLICY_MAKEFILE}" "$PAM_POLICY_FILE_pp"
           semodule -i "$PAM_POLICY_FILE_pp"
       fi
    else
      "$CREATE_POLICYFILE_OS_VERSION"
      echo "*         Creating rsapolicy.pp policy file                          *"
      make -f "${SELINUX_POLICY_MAKEFILE}" "$PAM_POLICY_FILE_pp"
      semodule -i "$PAM_POLICY_FILE_pp"     
    fi
    cd "$HERE"
    
    echo "**********************************************************************"
fi
}

check_policy_line()
{
   ENTRY=$1
   $ECHO "$ENTRY" >> "$PAM_POLICY_FILE"
   echo "" >> "$PAM_POLICY_FILE"
   echo "" >> "$PAM_POLICY_FILE"
}

create_policyfile_5()
{
rm -f "${PAM_POLICY_FILE}"
touch "$PAM_POLICY_FILE"
check_policy_line  \
"module local 1.0;

require {
  type sysctl_net_t;
  type var_t;
  type lib_t;
  type usr_t;
  type rlogind_t;
  type ftpd_t;
  type tty_device_t;
  type proc_net_t;
  class file execmod;
  class chr_file getattr;
  class capability sys_ptrace;
  class dir search;
  class dir write;
  class dir add_name;
  class dir read;
  class lnk_file read;
  class file {  getattr read create write };
  class file append;
}

allow rlogind_t self:capability sys_ptrace;
allow rlogind_t sysctl_net_t:dir search;
allow rlogind_t usr_t:lnk_file read;
allow rlogind_t var_t:file getattr;
allow rlogind_t var_t:file read;
allow rlogind_t tty_device_t:chr_file getattr;
allow rlogind_t var_t:file create;
allow rlogind_t var_t:file write;
allow rlogind_t var_t:file append;
allow rlogind_t lib_t:file execmod;
allow ftpd_t self:capability sys_ptrace;
allow ftpd_t  sysctl_net_t:dir search;
allow ftpd_t var_t:file getattr;
allow ftpd_t var_t:file read;
allow ftpd_t var_t:file create;
allow ftpd_t var_t:file write;
allow ftpd_t var_t:file append;
allow ftpd_t var_t:dir add_name;
allow ftpd_t var_t:dir write;
allow ftpd_t proc_net_t:file read;"
}

create_policyfile_6()
{
rm -f "${PAM_POLICY_FILE}"
touch "$PAM_POLICY_FILE"
check_policy_line  \
"module local 1.0;

require {
  type sysctl_net_t;
  type var_t;
  type usr_t;
  type lib_t;
  type user_devpts_t;
  type tty_device_t;
  type xdm_log_t;
  type proc_net_t;
  type admin_home_t;
  type xdm_t;
  type sshd_t;
  type telnetd_t;
  type rlogind_t;
  type ftpd_t;
  type rshd_t;
  class file execmod;
  class lnk_file read;
  class chr_file getattr;
  class capability sys_ptrace;
  class dir search;
  class dir write;
  class dir add_name;
  class dir read;
  class file { write read getattr open create };
  class file append;
}

allow sshd_t self:capability sys_ptrace;
allow sshd_t sysctl_net_t:dir search;
allow sshd_t var_t:file getattr;
allow sshd_t var_t:file read;
allow sshd_t var_t:file open;
allow sshd_t var_t:file create;
allow sshd_t var_t:file write;
allow sshd_t var_t:file append;
allow telnetd_t self:capability sys_ptrace;
allow telnetd_t sysctl_net_t:dir search;
allow rlogind_t self:capability sys_ptrace;
allow rlogind_t sysctl_net_t:dir search;
allow rlogind_t usr_t:lnk_file read;
allow rlogind_t var_t:file getattr;
allow rlogind_t var_t:file read;
allow rlogind_t tty_device_t:chr_file getattr;
allow rlogind_t user_devpts_t:chr_file getattr;
allow rlogind_t xdm_log_t:dir search;
allow rlogind_t var_t:file open;
allow rlogind_t var_t:file create;
allow rlogind_t var_t:file write;
allow rlogind_t var_t:file append;
allow rlogind_t lib_t:file execmod;
allow rshd_t self:capability sys_ptrace;
allow rshd_t sysctl_net_t:dir search;
allow rshd_t var_t:file getattr;
allow rshd_t var_t:file read;
allow rshd_t var_t:file open;
allow rshd_t var_t:file create;
allow rshd_t var_t:file write;
allow rshd_t var_t:file append;
allow ftpd_t self:capability sys_ptrace;
allow ftpd_t  sysctl_net_t:dir search;
allow ftpd_t var_t:file getattr;
allow ftpd_t var_t:file read;
allow ftpd_t var_t:file open;
allow ftpd_t var_t:file create;
allow ftpd_t var_t:file write;
allow ftpd_t var_t:file append;
allow ftpd_t var_t:dir add_name;
allow ftpd_t var_t:dir write;
allow ftpd_t proc_net_t:file open;
allow ftpd_t proc_net_t:file getattr;
allow ftpd_t proc_net_t:file read;
allow xdm_t admin_home_t:dir read;"
}

check_platform
check_user
startup_screen
check_sdconf
setup_paths
install_pam_agent
selinux_policy

if [ "$PREV_INSTL" = TRUE ] ; then
	if [ "$myVersion" = 6.0 ] ; then
        	echo "Creating Backup of /etc/sd_pam.config file to $PAM_CONFIG_SAVE so that Configuration can be used later point of time"
                echo "You need to run the Conversion Utility to change SecurID file just refer the User Manual.."
       		create_conf
        else
			if [ "$PAM_CONFIG_SOMEHOW_DELETED" = TRUE ] ; then
				echo "Somehow  /etc/sd_pam.config file has been deleted, so creating a  new /etc/sd_pam.config file."
                create_conf
            else
				rm -f $PAM_CONFIG_SAVE
			fi
			
	fi

         echo "**********************************************************************"
		 echo "* Successfully upgraded RSA Authentication Agent 7.1 for PAM"
         echo "**********************************************************************"
else
	create_conf
fi

echo ""
echo "**********************************************************************"
echo "* You have successfully installed RSA Authentication Agent 7.1 for PAM"
echo "**********************************************************************"
echo ""


