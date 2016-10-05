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

# 40- seems to be overridden by later rules, so linking to 99- to ensure always done
# 2016-05-06 rik: below seems to block functioning in Ubuntu 16.04, so only
#   doing for trusty
UBU_SERIES=$(lsb_release -sc)

if [ "$UBU_SERIES" == "trusty" ];
then
    echo
    echo "*** Ensuring USB Modem compatibility"
    echo
    ln -sf /lib/udev/rules.d/40-usb_modeswitch.rules \
        /lib/udev/rules.d/99-usb_modeswitch.rules
fi

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
# Patch Bloom 3.7 in 16.04 for PDF display
# ------------------------------------------------------------------------------
if [ -e "/usr/share/bloom-desktop-beta/environ-xulrunner" ] && [ "$(lsb_release -sc)" == "xenial" ];
then
    echo
    echo "*** Patching Bloom 3.7 for PDF display compatibilty"
    echo

    sed -i -e 's@=\(\${GECKOFX}/geckofix.so\)$@=\"\1 /usr/share/wasta-custom-eth/resources/libgeckofix.so\"@' \
        /usr/share/bloom-desktop-beta/environ-xulrunner
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
