#!/bin/sh

#written by Todd Houle
#15May2014
# to deploy pwpolicy to the currently logged in user, not all users or global 'cause that screws up other stuff

#get list of users who are logged in
currentLoggedInUsers=$(w -h | grep console| sort -u -t' ' -k1,1|awk '{print $1}')

currentLoggedInUsersCR="$currentLoggedInUsers
" #to add CR

#loop through each user who is logged in
printf %s "$currentLoggedInUsersCR" | while IFS=$'\n' read -r currentLoggedInUser
#for currentLoggedInUser in $currentLoggedInUsersCR
do

    echo "begining run on $currentLoggedInUser user"
    if [ "$currentLoggedInUser" == "root" ] ||  [ "$currentLoggedInUser" == "PHS Admin" ] ||  [ "$currentLoggedInUser" == "daemon" ]; then
	exit
    fi

#create user storage dir if not exists
    if [[ ! -d /Library/Application\ Support/JAMF/Partners/Library/passwordPolicyPerUser ]]; then
        mkdir /Library/Application\ Support/JAMF/Partners/Library
	mkdir /Library/Application\ Support/JAMF/Partners/Library/passwordPolicyPerUser
	echo "pwpolicyPerUser.sh will create one file per user so pwpolicy is set only once for each user" > /Library/Application\ Support/JAMF/Partners/Library/passwordPolicyPerUser/readme.txt
	pwpolicy -setglobalpolicy "usingHistory=4"
    fi

#run only once per user
    if [[ -f /Library/Application\ Support/JAMF/Partners/Library/passwordPolicyPerUser/$currentLoggedInUser ]]; then
	echo "policy exists for $currentLoggedInUser"
    else
	echo "setting $currentLoggedInUser policy"
        pwpolicy -u $currentLoggedInUser -setpolicy "requiresAlpha=1 requiresNumeric=1 minChars=8 usingHistory=4"
        touch /Library/Application\ Support/JAMF/Partners/Library/passwordPolicyPerUser/$currentLoggedInUser
    fi
done
