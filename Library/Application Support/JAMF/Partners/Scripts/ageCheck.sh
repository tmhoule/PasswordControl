#!/bin/bash

###
#
#            Name:  ageCheck.sh
#     Description:  This script looks at the age of a password and warns user
#                   based on daysToGiveNotice. A password older than maxage will
#                   return a more stern message.
#          Author:  Todd Houle
#                   with revisions by Elliot Jordan <elliot@lindegroup.com>
#         Created:  2014-05-07
#   Last Modified:  2015-04-14
#         Version:  1.1
#
###

# After a password this old, a more stern warning will be displayed.
# Note, 90 days is hard coded as the max age. Variable here is only about when to give messages- don't change it.
maxage=7776000 #about 90 days

# Password age should be in range of number below plus 86400 (one day) to cause warning alert.
daysToGiveNotice=( 5184000 6480000 6912000 7344000 7430400 7516800 7603200 7689600 )

# Don't change below this line.
################################################################################

currentUser=$(/usr/bin/stat -f%Su /dev/console)

if [ "$currentUser" = "root" ]; then
    echo "This tool cannot run as root. Execute as admin or standard user."
    exit
fi

# Determine OS version.
OS_major=$(/usr/bin/sw_vers -productVersion | awk -F . '{print $1}')
OS_minor=$(/usr/bin/sw_vers -productVersion | awk -F . '{print $2}')

# Get last change of password date.
if [[ "$OS_major" -eq 10 && "$OS_minor" -ge 8 ]]; then
    lastChangePW=$(dscl . -read "/Users/$currentUser" PasswordPolicyOptions |grep passwordLastSetTime -A1 |tail -1|awk -F T '{print $1}'|awk -F \> '{print $2}')
elif [[ "$OS_major" -eq 10 && "$OS_minor" -eq 7 ]]; then
    lastChangePW=$(dscl . -read "/Users/$currentUser" PasswordPolicyOptions |grep passwordTimestamp -A1 |tail -1|awk -F T '{print $1}'|awk -F \> '{print $2}')
else
    echo "Unsupported OS version."
    exit
fi

# If Terminal Notifier is installed, then use it.
if [[ -f "/Library/Application Support/JAMF/Partners/PEAS-Notifier.app/Contents/MacOS/PEAS-Notifier" ]] && [[ "$OS_major" -eq 10 && "$OS_minor" -ge 8 ]]; then
    termNotifierExists="true"
    termNotifierPath="/Library/Application Support/JAMF/Partners/PEAS-Notifier.app/Contents/MacOS/PEAS-Notifier"
fi

# Get current date and convert it to seconds.
DateNowSecs=$(date "+%s")

userID=$(id -u "$currentUser")  # For local accounts only.
if [ "$userID" -lt 500 ] || [ "$userID" -gt 1000 ]; then
    echo "This tool is for local accounts only."
    exit
fi


# If no last change date available (new account).
if [ -z "$lastChangePW" ]; then
    echo "$currentUser has no lastChangePW date"

	/usr/bin/osascript <<-EOF3
        tell application "System Events"
            activate
            display dialog "Partners Warning: The password for account $currentUser needs to be changed. You must change it immediately using System Preferences, 'Users & Groups' button." buttons "OK" default button 1 with icon 2
        end tell
        tell application "System Preferences"
            activate
            set the current pane to pane id "com.apple.preferences.users"
        end tell
EOF3
else   # Checking the age of password here against limits.
    lastChangePWSeconds=$(date -j -f "%Y-%m-%d" "$lastChangePW" "+%s")
    secondsSinceChanged=$(( DateNowSecs - lastChangePWSeconds ))
    daysSinceChanged=$(( secondsSinceChanged / 60 / 60 / 24 ))

    for dayToCheck in "${daysToGiveNotice[@]}"; do
    	if [ $secondsSinceChanged -ge "$dayToCheck" ] && [ $secondsSinceChanged -lt $(( dayToCheck + 86400 )) ]; then
            secsTillExpire=$(( maxage - secondsSinceChanged ))
        	daysTillExpire=$(( secsTillExpire / 60 / 60 / 24 ))
            if [ "$termNotifierExists" != "true" ]; then
        	    /usr/bin/osascript <<-EOF
                    tell application "System Events"
                        activate
                        set doTask to button returned of (display dialog "Partners Warning: The password for account $currentUser needs to be changed. You must change it immediately using System Preferences, 'Users & Groups' button." buttons {"Change Now","OK"} default button 2 with icon 2)
                    end tell
                    if doTask is "Change Now" then
                        tell application "System Preferences"
                            activate
                            set the current pane to pane id "com.apple.preferences.users"
                        end tell
                    end if
EOF
        	else
        	    "$termNotifierPath" -title "Your password will expire soon" -activate "com.apple.systempreferences" -message "Your Mac’s local password will expire in $daysTillExpire days. Please change your local password at your earliest convenience."
        	fi
        fi
    done

    if [ $secondsSinceChanged -gt $maxage ]; then
	    /usr/bin/osascript <<-EOF2
            tell application "System Events"
                activate
                display dialog "Partners Warning: The password for account $currentUser is $daysSinceChanged days old and has expired. You must change it immediately using System Preferences, 'Users & Groups' button." buttons "OK" default button 1 with icon 2
            end tell
            tell application "System Preferences"
                activate
                set the current pane to pane id "com.apple.preferences.users"
            end tell
EOF2
        /usr/bin/osascript <<-EOF4
        tell application "System Preferences"
            activate
            set the current pane to pane id "com.apple.preferences.users"
        end tell
EOF4
    fi
fi

exit 0