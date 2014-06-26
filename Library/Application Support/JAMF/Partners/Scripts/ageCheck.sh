#!/bin/sh
#written by Todd Houle
#7May2014
#revised 26June2014

#This script looks at the age of a password and warns if based on daysToGiveNotice.  A password older than maxage will return a more stern message.

#after a password this old, a more stern warning will be displayed.
#note, 90 days is hard coded as the max age.  variable here is only about when to give messages- dont change it.
maxage=7776000 #about 90 days

#password age should be in range of number below plus 86400 (one day) to cause warning alert.
daysToGiveNotice=( 5184000 6480000 6912000 7344000 7430400 7516800 7603200 7689600 )

#Dont change below this line
################################################################

currentUser=`whoami | xargs echo -n`   #remove newline char from currentUser

if [ "$currentUser" = "root" ]; then
    echo "This tool cannot run as root.  Execute as admin or standard user."
    exit
fi

#get last change of password date
OSVers=`sysctl -n kern.osrelease | cut -d . -f 1`
if [ $OSVers -gt 11 ]; then   #for os 10.8+ 
    lastChangePW=`dscl . -read "/Users/$currentUser" PasswordPolicyOptions |grep passwordLastSetTime -A1 |tail -1|awk -F T '{print $1}'|awk -F \> '{print $2}'`
elif [ $OSVers -eq 11 ]; then     #for os 10.7
    lastChangePW=`dscl . -read "/Users/$currentUser" PasswordPolicyOptions |grep passwordTimestamp -A1 |tail -1|awk -F T '{print $1}'|awk -F \> '{print $2}'`
else
    echo "Unsupported OS Version"
    exit
fi

#if Terminal Notifier is installed, then use it
if [ -f /Library/Application\ Support/JAMF/Partners/PEAS-Notifier.app/Contents/MacOS/PEAS-Notifier ] && [ $OSVers -gt 11 ]; then
    termNotifierExists="true"
    termNotifierPath="/Library/Application Support/JAMF/Partners/PEAS-Notifier.app/Contents/MacOS/PEAS-Notifier"
fi

#get current date and convert it to seconds
DateNow=`date +%Y-%m-%d`
DateNowSecs=`date -j -f "%Y-%m-%d" $DateNow "+%s"`

userID=`id -u "$currentUser"`  #for local accounts only
if [ "$userID" -lt "500" ] || [ "$userID" -gt 1000 ] ;then
    echo "This tool is for local accounts only."
    exit
fi


#If no last change date available (new account)
if [ -z "$lastChangePW" ];then
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
else   #checking the age of password here againts limits
    lastChangePWSeconds=`date -j -f "%Y-%m-%d" $lastChangePW "+%s"`
    secondsSinceChanged=$(( $DateNowSecs - $lastChangePWSeconds))
    daysSinceChanged=$(( $secondsSinceChanged/60/60/24 ))	
    daysOverExpired=$((90-$daysSinceChanged))
     for dayToCheck in "${daysToGiveNotice[@]}"
     do
	if [ $secondsSinceChanged -ge $dayToCheck ] && [ $secondsSinceChanged -lt $(($dayToCheck + 86400)) ] ;then
        secsTillExpire=$(( $maxage - secondsSinceChanged ))
	daysTillExpire=$(( $secsTillExpire/60/60/24 ))
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
	    `"$termNotifierPath"  -title "Your password will expire soon" -activate "com.apple.systempreferences" -message "Your Mac’s local password will expire in $daysTillExpire days. Please change your local password at your earliest convenience."`
	fi
	   fi
      done

    if [ $secondsSinceChanged -gt $maxage ] ;then
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


