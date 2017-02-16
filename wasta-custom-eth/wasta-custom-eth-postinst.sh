#!/bin/bash

# ==============================================================================
# wasta-custom-eth-postinst.sh
#
#   This script is automatically run by the postinst configure step on
#       installation of wasta-custom-eth.  It can be manually re-run, but is
#       only intended to be run at package installation.  
#
#   2014-11-06 rik: initial script
#   2015-01-26 rik: fixing LO extension install so won't have user settings
#       owned by root (will make LO not be able to open) if user hasn't
#       opened LO before the extension is installed.
#       - change to LO ODF extension
#   2015-05-12 rik: Change LO extension to "non odf" (.doc, .xls) defaults
#   2015-06-16 rik: Updating SIL Ethiopic link for wasta-resources
#   2015-07-16 rik: Adding amharic-hunspell.oxt extension
#   2015-09-09 rik: Replacing amharic-hunspell.oxt with
#       amharic-ethiopia-customization.oxt
#   2016-04-05 rik: cleaning up LO extension install
#       - symlinking usb_modeswitch.rules to higher number so not overridden
#   2016-05-06 rik: only symlinking usb_modeswitch.rules for TRUSTY 14.04
#   2016-09-17 rik: adding 'disable-vba-refactoring.oxt' LO extension
#   2016-10-05 rik: patching Bloom 3.7 for PDF display
#   2016-11-09 rik: disabling 'whoopsie' error reporting service.
#   2017-01-13 rik: adding LO 5.2 PPA, and adjusting LO launchers to force
#       input method since 5.2 bug makes kmfl not remove the surrounding text
#   2017-02-16 rik: adding LO launcher fix to /etc/skel
#
# ==============================================================================

# ------------------------------------------------------------------------------
# Check to ensure running as root
# ------------------------------------------------------------------------------
#   No fancy "double click" here because normal user should never need to run
if [ $(id -u) -ne 0 ]
then
	echo
	echo "You must run this script with sudo." >&2
	echo "Exiting...."
	sleep 5s
	exit 1
fi

# ------------------------------------------------------------------------------
# Initial Setup
# ------------------------------------------------------------------------------

echo
echo "*** Beginning wasta-custom-eth-postinst.sh"
echo

# setup directory for reference later
DIR=/usr/share/wasta-custom-eth/resources

# ------------------------------------------------------------------------------
# Create some Symlinks
# ------------------------------------------------------------------------------
echo
echo "*** Adding kmfl-sil-ethiopic-readme.htm symlink to wasta-resources"
echo

ln -sf /usr/share/doc/kmfl-keyboard-sil-ethiopic/readme.htm \
    "/usr/share/wasta-resources/Ethiopia Keyboard Charts/SIL Ethiopic Keyboard Chart.htm"

# ------------------------------------------------------------------------------
# Add LibreOffice 5.2 PPA
# ------------------------------------------------------------------------------

# get series, load them up.
SERIES=$(lsb_release -sc)
case "$SERIES" in

  trusty|qiana|rebecca|rafaela|rosa)
    #LTS 14.04-based Mint 17.x
    REPO_SERIES="trusty"
  ;;

  xenial|sarah)
    #LTS 16.04-based Mint 18.x
    REPO_SERIES="xenial"
  ;;

  *)
    # Don't know the series, just go with what is reported
    REPO_SERIES=$SERIES
  ;;
esac

APT_SOURCES=/etc/apt/sources.list

if ! [ -e $APT_SOURCES.wasta ];
then
    APT_SOURCES_D=/etc/apt/sources.list.d
else
    # wasta-offline active: adjust apt file locations
    echo
    echo "*** wasta-offline active, applying repository adjustments to /etc/apt/sources.list.wasta"
    echo
    APT_SOURCES=/etc/apt/sources.list.wasta
    if [ "$(ls -A /etc/apt/sources.list.d)" ];
    then
        echo
        echo "*** wasta-offline 'offline and internet' mode detected"
        echo
        # files inside /etc/apt/sources.list.d so it is active
        # wasta-offline "offline and internet mode": no change to sources.list.d
        APT_SOURCES_D=/etc/apt/sources.list.d
    else
        echo
        echo "*** wasta-offline 'offline only' mode detected"
        echo
        # no files inside /etc/apt/sources.list.d
        # wasta-offline "offline only mode": change to sources.list.d.wasta
        APT_SOURCES_D=/etc/apt/sources.list.d.wasta
    fi
fi

# first backup $APT_SOURCES in case something goes wrong
# delete $APT_SOURCES.save if older than 30 days
find /etc/apt  -maxdepth 1 -mtime +30 -iwholename $APT_SOURCES.save -exec rm {} \;

if ! [ -e $APT_SOURCES.save ];
then
    cp $APT_SOURCES $APT_SOURCES.save
fi

if ! [ -e $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-5-2-$REPO_SERIES.list ];
then
    echo
    echo "*** Adding LibreOffice 5.2 $REPO_SERIES PPA"
    echo
    echo "deb http://ppa.launchpad.net/libreoffice/libreoffice-5-2/ubuntu $REPO_SERIES main" | \
        tee $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-5-2-$REPO_SERIES.list
    echo "# deb-src http://ppa.launchpad.net/libreoffice/libreoffice-5-2/ubuntu $REPO_SERIES main" | \
        tee -a $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-5-2-$REPO_SERIES.list
else
    # found, but ensure Wasta-Linux PPA ACTIVE (user could have accidentally disabled)
    echo
    echo "*** LibreOffice 5.2 $REPO_SERIES PPA already exists, ensuring active"
    echo
    sed -i -e '$a deb http://ppa.launchpad.net/libreoffice/libreoffice-5-2/ubuntu '$REPO_SERIES' main' \
        -i -e '\@deb http://ppa.launchpad.net/libreoffice/libreoffice-5-2/ubuntu '$REPO_SERIES' main@d' \
        $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-5-2-$REPO_SERIES.list
fi

# ------------------------------------------------------------------------------
# LibreOffice 5.2 FIX for ibus/kmfl not working correctly
# ------------------------------------------------------------------------------

for USER_HOME in /home/*;
do
    USER_HOME_NAME=$(basename $USER_HOME)

    # only process if "real user" (so not for wasta-remastersys, etc.)
    if id "$USER_HOME_NAME" >/dev/null 2>&1;
    then
        echo
        echo "*** ensuring LO ibus/kmfl functionality for $USER_HOME_NAME"
        echo

        # ensure user applications folder exists
        mkdir -p $USER_HOME/.local/share/applications

        # copy in LO desktop launchers
        cp /usr/share/applications/libreoffice-*.desktop \
            $USER_HOME/.local/share/applications

        # ensure all ownership is correct
        chown -R $USER_HOME_NAME:$USER_HOME_NAME \
            $USER_HOME/.local/share/applications

        # update LO desktop launchers to use modified env variables
        sed -i -e 's#^Exec=libreoffice#Exec=env XMODIFIERS=@im=ibus GTK_IM_MODULE=xim libreoffice#' \
            $USER_HOME/.local/share/applications/libreoffice-*.desktop
    fi
done

# /etc/skel updates:
echo
echo "*** ensuring LO ibus/kmfl functionality for default user profile"
echo

# ensure user applications folder exists
mkdir -p /etc/skel/.local/share/applications

# copy in LO desktop launchers
cp /usr/share/applications/libreoffice-*.desktop \
    /etc/skel/.local/share/applications

# update LO desktop launchers to use modified env variables
sed -i -e 's#^Exec=libreoffice#Exec=env XMODIFIERS=@im=ibus GTK_IM_MODULE=xim libreoffice#' \
    /etc/skel/.local/share/applications/libreoffice-*.desktop

# ------------------------------------------------------------------------------
# LibreOffice Preferences Extension install (for all users)
# ------------------------------------------------------------------------------

# REMOVE "Wasta-English-Intl-Defaults" extension: remove / reinstall is only
#   way to update
EXT_FOUND=$(ls /var/spool/libreoffice/uno_packages/cache/uno_packages/*/wasta-english-intl-defaults.oxt* 2> /dev/null)

if [ "$EXT_FOUND" ];
then
    unopkg remove --shared wasta-english-intl-defaults.oxt
fi

# Install wasta-english-intl-defaults.oxt (Default LibreOffice Preferences)
echo
echo "*** Installing/Updating Wasta English Intl Default LO Extension"
echo
unopkg add --shared $DIR/wasta-english-intl-defaults.oxt


# LEGACY REMOVE "Amharic-Hunspell" extension: new name is "Amharic Ethiopia Customization"
# Send error to null so won't display
EXT_FOUND=$(ls /var/spool/libreoffice/uno_packages/cache/uno_packages/*/amharic-hunspell.oxt* 2> /dev/null)

if [ "$EXT_FOUND" ];
then
    echo
    echo "*** LEGACY: Removing older 'Amharic-Hunspell' LO Extension"
    echo
    unopkg remove --shared amharic-hunspell.oxt
fi

# REMOVE "Amharic Ethiopia Customization" extension: only way to update is
#   remove then reinstall
EXT_FOUND=$(ls /var/spool/libreoffice/uno_packages/cache/uno_packages/*/amharic-ethiopia-customization.oxt* 2> /dev/null)

if [ "$EXT_FOUND" ];
then
    unopkg remove --shared amharic-ethiopia-customization.oxt
fi

# Install amharic-ethiopia-customization.oxt
echo
echo "*** Installing/Upating Amharic Ethiopia Customization LO Extension"
echo
unopkg add --shared $DIR/amharic-ethiopia-customization.oxt

# IF user has not initialized LibreOffice, then when adding the above shared
#   extension, the user's LO settings are created, but owned by root so
#   they can't change them: solution is to just remove them (will get recreated
#   when user starts LO the first time).

# REMOVE "Disable VBA Refactoring" extension: only way to update is
#   remove then reinstall
EXT_FOUND=$(ls /var/spool/libreoffice/uno_packages/cache/uno_packages/*/disable-vba-refactoring.oxt* 2> /dev/null)

if [ "$EXT_FOUND" ];
then
    unopkg remove --shared disable-vba-refactoring.oxt
fi

# Install disable-vba-refactoring.oxt
echo
echo "*** Installing/Upating Disable VBA Refactoring LO Extension"
echo
unopkg add --shared $DIR/disable-vba-refactoring.oxt

# IF user has not initialized LibreOffice, then when adding the above shared
#   extension, the user's LO settings are created, but owned by root so
#   they can't change them: solution is to just remove them (will get recreated
#   when user starts LO the first time).


for LO_FOLDER in /home/*/.config/libreoffice;
do
    LO_OWNER=$(stat -c '%U' $LO_FOLDER)

    if [ "$LO_OWNER" == "root" ];
    then
        echo
        echo "*** LibreOffice settings owned by root: resetting"
        echo "*** Folder: $LO_FOLDER"
        echo
    
        rm -rf $LO_FOLDER
    fi
done

# ------------------------------------------------------------------------------
# Disable "whoopsie" if found: daisy.ubuntu.com blocked by EthioTelecom
#   so hangs shutdown
# ------------------------------------------------------------------------------
if [ -x "/usr/bin/whoopsie" ];
then
    echo
    echo "*** Disabling 'whoopsie' error reporting"
    echo
    systemctl disable whoopsie.service
fi

# ------------------------------------------------------------------------------
# Set system-wide Paper Size
# ------------------------------------------------------------------------------
# Note: This sets /etc/papersize.  However, many apps do not look at this
#   location, but instead maintain their own settings for paper size :-(
paperconfig -p a4

# ------------------------------------------------------------------------------
# Finished
# ------------------------------------------------------------------------------

echo
echo "*** Finished with wasta-custom-eth-postinst.sh"
echo

exit 0
