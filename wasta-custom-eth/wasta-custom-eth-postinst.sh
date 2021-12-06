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
#   2017-02-27 rik: adding ibus "standard" keyboard installs for all users
#   2017-05-04 rik: syntax fix for loop through /home folders for keyboard
#       installs.
#   2017-05-21 rik: auto install hp-plugin non-interactively
#   2017-09-29 rik: disabling apt.conf.d/99nocache apt setting so that
#       pfsense's squid cache will be used for updates
#   2017-11-16 rik: adding 'macro-medium-security.oxt' LO extension
#   2017-12-13 rik: removing LO 5.2 compatibility code
#       - Adding LO 5.3 PPA
#       - Adding skypeforlinux repo
#       - Removing LO 5.2 PPA
#   2018-01-10 rik: removing LO extensions (now installed through install-files)
#       - Adding skype gpg key
#       - if wasta-layout found, setting system default layout to "redmond7"
#   2018-01-25 rik: making sure to only install LO 5.3 PPA for trusty/xenial
#       since it doesn't exist for bionic.
#   2018-08-29 rik: adding LO 6.0 PPA
#       - adding bionic hp-plugin support
#   2018-08-29 rik: permissions cleanup for files associated with ibus setup
#       - quiet output of gpg key additions
#   2018-09-01 rik: restarting ibus in different way so as to not require
#       logout (otherwise cinnamon menu couldn't be typed in)
#   2018-09-19 rik: suppress output of hp-plugin for bionic
#       - comment out ibus and lo processing: handled by install-files
#   2018-11-08 rik: compile gschemas to apply wasta-custom-eth overrides
#       - cleanup of legacy items
#       - only run wasta-layout redmond7 IF no wasta-layout already exists
#         (so don't override user preference if they have set it differently)
#   2019-03-01 rik: adding LO 6.1 PPA
#   2020-09-02 rik: adding hplip plugin for focal
#   2020-10-02 rik: removing trusty and xenial hplip, enabling zswap
#   2021-01-20 rik: revert to LO 6.3 PPA (6.4 corrupts finance VBA macros)
#   2021-01-29 rik: LO 6.4 needed for most computers since L0 6.3 has print
#       dialog issues. SO, check hostname and do NOT update to LO 6.4 IF name
#       contains "fin" (ETB Finance computers are fin-1, fin-2, fin-3).
#   2021-12-06 rik: adding wasta LO 7.1 ppa (now works for finance computers!)
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

# get series (no longer compatible with Linux Mint)
SERIES=$(lsb_release -sc)

# ------------------------------------------------------------------------------
# Adjust Software Sources
# ------------------------------------------------------------------------------

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

# manually add Skype and LO repo keys (since wasta-offline could be active)
# apt-key add $DIR/keys/libreoffice-ppa.gpg >/dev/null 2>&1;
# apt-key add $DIR/keys/skype.gpg >/dev/null 2>&1;

#   - only if LOWERCASE hostname does NOT contain "fin"
if [ "$SERIES" == "bionic" ] || [ "$SERIES" == "focal" ];
then
    if ! [ -e $APT_SOURCES_D/wasta-linux-ubuntu-libreoffice-7-1-$SERIES.list ];
    then
        echo
        echo "*** Adding Wasta-Linux LibreOffice 7.1 $SERIES PPA"
        echo
        echo "deb http://ppa.launchpad.net/wasta-linux/libreoffice-7-1/ubuntu $SERIES main" | \
            tee $APT_SOURCES_D/wasta-linux-ubuntu-libreoffice-7-1-$SERIES.list
        echo "# deb-src http://ppa.launchpad.net/wasta-linux/libreoffice-7-1/ubuntu $SERIES main" | \
            tee -a $APT_SOURCES_D/wasta-linux-ubuntu-libreoffice-7-1-$SERIES.list
    else
        # found, but ensure LO 7.1 PPA ACTIVE (user could have accidentally disabled)
        echo
        echo "*** Wasta-Linux LibreOffice 7.1 $SERIES PPA already exists, ensuring active"
        echo
        # DO NOT match any lines ending in #wasta
        sed -i -e '/#wasta$/! s@.*\(deb http://ppa.launchpad.net\)@\1@' \
            $APT_SOURCES_D/wasta-linux-ubuntu-libreoffice-7-1-$SERIES.list
    fi
fi

# Remove older LO PPAs (NOTE: do NOT remove LO 6.2 since *fin* computers use it)
rm -rf $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-5-1*
rm -rf $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-5-2*
rm -rf $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-5-3*
rm -rf $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-5-4*
rm -rf $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-6-0*
rm -rf $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-6-1*
# rm -rf $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-6-2*
rm -rf $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-6-3*
rm -rf $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-6-4*

# Add Skype Repository
#if ! [ -e $APT_SOURCES_D/skype-stable.list ];
#then
#    echo
#    echo "*** Adding Skype Repository"
#    echo

#    echo "deb https://repo.skype.com/deb stable main" | \
#        tee $APT_SOURCES_D/skype-stable.list
#fi

# ------------------------------------------------------------------------------
# Set Wasta-Layout default
# ------------------------------------------------------------------------------
# TODO: need to NOT run if the default has already been overridden

#if [ -e "/usr/bin/wasta-layout" ];
#then
#    if [ $(find /usr/share/glib-2.0/schemas/*wasta-layout* -maxdepth 1 -type l 2>/dev/null) ];
#    then
#        echo
#        echo "*** Wasta-Layout already set: not updating"
#        echo
#    else
#        echo
#        echo "*** Setting Wasta-Layout default to redmond7"
#        echo
#        wasta-layout-system redmond7
#    fi
#fi

# ------------------------------------------------------------------------------
# Dconf / Gsettings default value adjustments
# ------------------------------------------------------------------------------
# Override files in /usr/share/glib-2.0/schemas/ folder.
#   Values in z_20_wasta-custom-eth.gschema.override will override values
#   in z_10_wasta-core.gschema.override which will override Ubuntu defaults.
echo
echo "*** Updating dconf / gsettings default values"
echo
# Sending any "error" to null (if a key isn't found it will return an error,
#   but for different version of Cinnamon, etc., some keys may not exist but we
#   don't want to error in this case: suppressing errors to not worry user.
glib-compile-schemas /usr/share/glib-2.0/schemas/ 2>/dev/null || true;

# ------------------------------------------------------------------------------
# LibreOffice Fixes
# ------------------------------------------------------------------------------
for LO_FOLDER in /home/*/.config/libreoffice;
do
    LO_OWNER=""
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
    systemctl disable whoopsie.service >/dev/null 2>&1
fi

# ------------------------------------------------------------------------------
# Set system-wide Paper Size
# ------------------------------------------------------------------------------
# Note: This sets /etc/papersize.  However, many apps do not look at this
#   location, but instead maintain their own settings for paper size :-(
paperconfig -p a4

# ------------------------------------------------------------------------------
# Install hp-plugin (non-interactive)
# ------------------------------------------------------------------------------
# Install hp-plugin automatically: needed by some HP printers such as black
#   HP m127 used by SIL Ethiopia.  Don't display output to confuse user.

case "$SERIES" in
  bionic)
    echo
    echo "*** bionic: installing hp-plugin"
    yes | hp-plugin -p $DIR/hp-plugin-bionic/ >/dev/null 2>&1
    echo "*** bionic: hp-plugin install complete"
  ;;
  focal)
    echo
    echo "*** focal: installing hp-plugin"
    yes | hp-plugin -p $DIR/hp-plugin-focal/ >/dev/null 2>&1
    echo "*** focal: hp-plugin install complete"
  ;;
esac

echo

# ------------------------------------------------------------------------------
# Disable any apt.conf.d "nocache" file (from wasta-core)
# ------------------------------------------------------------------------------
# The nocache option for apt prevents local cache from squid (used by pfsense
# at main Addis office) from being used.  Need to disable.

if [ -e /etc/apt/apt.conf.d/99nocache ];
then
    sed -i -e 's@^Acquire@#Acquire@' /etc/apt/apt.conf.d/99nocache
fi

# ------------------------------------------------------------------------------
# enable zswap (from wasta-core if found)
# ------------------------------------------------------------------------------
# Ubuntu / Wasta-Linux 20.04 swaps really easily, which kills performance.
# zswap uses *COMPRESSED* RAM to buffer swap before writing to disk.
# This is good for SSDs (less writing), and good for HDDs (no stalling).
# zswap should NOT be used with zram (uncompress/recompress shuffling).

if [ -e "/usr/bin/wasta-enable-zswap" ];
then
    wasta-enable-zswap auto
fi

# ------------------------------------------------------------------------------
# Legacy Cleanup
# ------------------------------------------------------------------------------
# Remove legacy symlinks in /usr/share/wasta-resources
# legacy locations
rm -f "/usr/share/wasta-resources/KMFL SIL Ethiopic Readme.htm"
rm -f "/usr/share/wasta-resources/Ethiopia Keyboard Charts/KMFL SIL Ethiopic Readme.htm"
rm -f "/usr/share/wasta-resources/Ethiopia Keyboard Charts/SIL Ethiopic Keyboard Chart.htm"

# 2017-12-11 rik: Remove fixes since 5.2 has been patched and newer versions
#   of LO will have trouble with kmfl IF the fix remains in place
rm -f /home/*/.local/share/applications/libreoffice*.desktop
rm -f /etc/skel/.local/share/applications/libreoffice*.desktop

# ------------------------------------------------------------------------------
# Finished
# ------------------------------------------------------------------------------

echo
echo "*** Finished with wasta-custom-eth-postinst.sh"
echo

exit 0

# ------------------------------------------------------------------------------
# Legacy stuff below..........
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# ibus: load up "standard" keyboards for users
# This assumes ibus 1.5+ (so doesn't work for precise)
# ------------------------------------------------------------------------------
#
# 2018-09-19: commenting out as we rely on the gschema.override to set default
#   keyboards for new users
#
#LOCAL_USERS=""
#for USER_FOLDER in $(ls -1 /home)
#do
#    # if user is in /etc/passwd then it is a 'real user' as opposed to
#    # something like wasta-remastersys
#    if [ "$(grep $USER_FOLDER /etc/passwd)" ];
#    then
#        LOCAL_USERS+="$USER_FOLDER "
#    fi
#done
#
#for CURRENT_USER in $LOCAL_USERS;
#do
#    # not sure why these are owned by root sometimes but shouldn't be
#    PERM_CHECK="/home/$CURRENT_USER/.config/ibus"
#    if [ -e "$PERM_CHECK" ];
#    then
#        echo "*** reset owner of $PERM_CHECK"
#        chown -R $CURRENT_USER:$CURRENT_USER "$PERM_CHECK"
#    fi
#
#    PERM_CHECK="/home/$CURRENT_USER/.cache/dconf"
#    if [ -e "$PERM_CHECK" ];
#    then
#        echo "*** reset owner of $PERM_CHECK"
#        chown -R $CURRENT_USER:$CURRENT_USER "$PERM_CHECK"
#    fi
#
#    # need to know if need to start dbus for user
#    # don't use dbus-run-session for logged in user or it doesn't work
#    LOGGED_IN_USER="${SUDO_USER:-$USER}"
#    if [[ "$LOGGED_IN_USER" == "$CURRENT_USER" ]];
#    then
#        #echo "login is same as current: $CURRENT_USER"
#        DBUS_SESSION=""
#    else
#        #echo "user not logged in, running update with dbus: $CURRENT_USER"
#        DBUS_SESSION="dbus-run-session --"
#    fi
#
## 2018-09-01 rik: ibus is getting 'hung' a bit so doesn't work in cinnamon menu
##   after restarted below.  wondering if need different dbus method like used
##   in wasta-login.sh??? needs testing...
#
#    IBUS_ENGINES=$(su -l "$CURRENT_USER" -c "$DBUS_SESSION gsettings get org.freedesktop.ibus.general preload-engines")
#    ENGINES_ORDER=$(su -l "$CURRENT_USER" -c "$DBUS_SESSION gsettings get org.freedesktop.ibus.general engines-order")
#
#    # remove legacy el, power-g, and sil ethiopic engines
#    # (, \)\{0,1\} removes any OPTIONAL ", " preceding the kmfl keyboard name
#    IBUS_ENGINES=$(sed -e "s@\(, \)\{0,1\}'/usr/share/kmfl/SILEthiopic-1.3.kmn'@@" <<<"$IBUS_ENGINES")
#    IBUS_ENGINES=$(sed -e "s@\(, \)\{0,1\}'/usr/share/kmfl/sil-el-ethiopian-latin.kmn'@@" <<<"$IBUS_ENGINES")
#    IBUS_ENGINES=$(sed -e "s@\(, \)\{0,1\}'/usr/share/kmfl/EL.kmn'@@" <<<"$IBUS_ENGINES")
#    IBUS_ENGINES=$(sed -e "s@\(, \)\{0,1\}'/usr/share/kmfl/sil-pwrgeez.kmn'@@" <<<"$IBUS_ENGINES")
#    IBUS_ENGINES=$(sed -e "s@\(, \)\{0,1\}'/usr/share/kmfl/sil_power_g_ethiopic.kmn'@@" <<<"$IBUS_ENGINES")
#
#    if [[ "$IBUS_ENGINES" == *"[]"* ]];
#    then
#        echo
#        echo "!!!NO ibus preload-engines found for user: $CURRENT_USER"
#        echo
#        # no engines currently: shouldn't normally happen so add en US as base
#        IBUS_ENGINES="['xkb:us::eng']"
#    fi
#
#    EL_INSTALLED=$(grep sil_el_ethiopian_latin.kmn <<<"$IBUS_ENGINES")
#    if [[ -z "$EL_INSTALLED" ]];
#    then
#        echo
#        echo "Installing sil_el_ethiopian_latin keyboard for user: $CURRENT_USER"
#        echo
#        # append engine to list
#        IBUS_ENGINES=$(sed -e "s@']@', '/usr/share/kmfl/sil_el_ethiopian_latin.kmn']@" <<<"$IBUS_ENGINES")
#    fi
#
#    POWERG_INSTALLED=$(grep sil_ethiopic_power_g.kmn <<<"$IBUS_ENGINES")
#    if [[ -z "$POWERG_INSTALLED" ]];
#    then
#        echo
#        echo "Installing sil_ethiopic_power_g keyboard for user: $CURRENT_USER"
#        echo
#        # append engine to list
#        IBUS_ENGINES=$(sed -e "s@']@', '/usr/share/kmfl/sil_ethiopic_power_g.kmn']@" <<<"$IBUS_ENGINES")
#    fi
#
#    ETBSIL_INSTALLED=$(grep etb_sil_ethiopic.kmn <<<"$IBUS_ENGINES")
#    if [[ -z "$ETBSIL_INSTALLED" ]];
#    then
#        echo
#        echo "Installing etb_sil_ethiopic keyboard for user: $CURRENT_USER"
#        echo
#        # append engine to list
#        IBUS_ENGINES=$(sed -e "s@']@', '/usr/share/kmfl/etb_sil_ethiopic.kmn']@" <<<"$IBUS_ENGINES")
#    fi
#
#    # set engines
#    su -l "$CURRENT_USER" -c "$DBUS_SESSION gsettings set org.freedesktop.ibus.general preload-engines \"$IBUS_ENGINES\"" #>/dev/null 2>&1
#
#    # restart ibus
#    ibus-daemon -xrd
#
#    #2018-09-01 rik: previously used one of below commands but they resulted
#    #   in various GUI elements needing to be restarted before keyboard would
#    #   function (such as Cinnamon Menu).
#    #su "$CURRENT_USER" -c "dbus-launch ibus-daemon -xrd" #>/dev/null 2>&1
#    #su -l "$CURRENT_USER" -c "$DBUS_SESSION ibus restart" #>/dev/null 2>&1
#    echo
#    echo "*** ibus restarted: if any keyboard issues please logout/login"
#    echo
#done

# ------------------------------------------------------------------------------
# LibreOffice Preferences Extension install (for all users)
# LEGACY: now install extensions through install-files/extensions so am removing
#   ones installed previously using unopkg
# ------------------------------------------------------------------------------

# REMOVE "Wasta-English-Intl-Defaults" extension: remove / reinstall is only
#   way to update
#EXT_FOUND=$(ls /var/spool/libreoffice/uno_packages/cache/uno_packages/*/wasta-english-intl-defaults.oxt* 2> /dev/null)
#
#if [ "$EXT_FOUND" ];
#then
#    unopkg remove --shared wasta-english-intl-defaults.oxt
#fi
#
# REMOVE "Amharic-Hunspell" extension: new name is "Amharic Ethiopia Customization"
# Send error to null so won't display
#EXT_FOUND=$(ls /var/spool/libreoffice/uno_packages/cache/uno_packages/*/amharic-hunspell.oxt* 2> /dev/null)
#
#if [ "$EXT_FOUND" ];
#then
#    unopkg remove --shared amharic-hunspell.oxt
#fi
#
# REMOVE "Amharic Ethiopia Customization" extension: only way to update is
#   remove then reinstall
#EXT_FOUND=$(ls /var/spool/libreoffice/uno_packages/cache/uno_packages/*/amharic-ethiopia-customization.oxt* 2> /dev/null)
#
#if [ "$EXT_FOUND" ];
#then
#    unopkg remove --shared amharic-ethiopia-customization.oxt
#fi
#
# REMOVE "Disable VBA Refactoring" extension: only way to update is
#   remove then reinstall
#EXT_FOUND=$(ls /var/spool/libreoffice/uno_packages/cache/uno_packages/*/disable-vba-refactoring.oxt* 2> /dev/null)
#
#if [ "$EXT_FOUND" ];
#then
#    unopkg remove --shared disable-vba-refactoring.oxt
#fi
#
# REMOVE macro-medium-security extension: only way to update is
#   remove then reinstall
#EXT_FOUND=$(ls /var/spool/libreoffice/uno_packages/cache/uno_packages/*/macro-medium-security.oxt* 2> /dev/null)
#
#if [ "$EXT_FOUND" ];
#then
#    unopkg remove --shared macro-medium-security.oxt
#fi
#
# IF user has not initialized LibreOffice, then when adding the above shared
#   extension, the user's LO settings are created, but owned by root so
#   they can't change them: solution is to just remove them (will get recreated
#   when user starts LO the first time).

# ------------------------------------------------------------------------------
# LibreOffice 5.2 FIX for ibus/kmfl not working correctly
# ------------------------------------------------------------------------------

#for USER_HOME in /home/*;
#do
#    USER_HOME_NAME=$(basename $USER_HOME)
#
#    # only process if "real user" (so not for wasta-remastersys, etc.)
#    if id "$USER_HOME_NAME" >/dev/null 2>&1;
#    then
#        echo
#        echo "*** ensuring LO ibus/kmfl functionality for $USER_HOME_NAME"
#        echo
#
#        # ensure user applications folder exists
#        mkdir -p $USER_HOME/.local/share/applications
#
#        # sleep needed to avoid race condition that was crashing cinnamon??
#        sleep 2
#
#        # copy in LO desktop launchers
#        cp /usr/share/applications/libreoffice-*.desktop \
#            $USER_HOME/.local/share/applications
#
#        # ensure all ownership is correct
#        chown -R $USER_HOME_NAME:$USER_HOME_NAME \
#            $USER_HOME/.local/share/applications
#
#        # update LO desktop launchers to use modified env variables
#        sed -i -e 's#^Exec=libreoffice#Exec=env XMODIFIERS=@im=ibus GTK_IM_MODULE=xim libreoffice#' \
#            $USER_HOME/.local/share/applications/libreoffice-*.desktop
#    fi
#done
#
## /etc/skel updates:
#echo
#echo "*** ensuring LO ibus/kmfl functionality for default user profile"
#echo
#
## ensure user applications folder exists
#mkdir -p /etc/skel/.local/share/applications
#
## copy in LO desktop launchers
#cp /usr/share/applications/libreoffice-*.desktop \
#    /etc/skel/.local/share/applications
#
## update LO desktop launchers to use modified env variables
#sed -i -e 's#^Exec=libreoffice#Exec=env XMODIFIERS=@im=ibus GTK_IM_MODULE=xim libreoffice#' \
#    /etc/skel/.local/share/applications/libreoffice-*.desktop


