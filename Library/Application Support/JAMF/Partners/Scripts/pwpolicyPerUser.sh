#!/bin/bash

###
#
#            Name:  pwpolicyPerUser.sh
#     Description:  This script deploys pwpolicy to the currently logged in
#                   user, not all users or global because that screws up other
#                   stuff.
#          Author:  Todd Houle <admin@peas-thoule.mgh.harvard.edu>
#                   with revisions by Elliot Jordan <elliot@lindegroup.com>
#         Created:  2014-05-15
#   Last Modified:  2015-04-14
#         Version:  1.1
#
###

# Get list of users who are logged in
currentLoggedInUsersCR="$(w -h | grep console| sort -u -t' ' -k1,1|awk '{print $1}')
" # To add CR

# Loop through each user who is logged in
printf %s "$currentLoggedInUsersCR" | while IFS=$'\n' read -r currentLoggedInUser; do

    echo "begining run on $currentLoggedInUser user"
    if [ "$currentLoggedInUser" == "root" ] ||  [ "$currentLoggedInUser" == "PHS Admin" ] ||  [ "$currentLoggedInUser" == "daemon" ]; then
	exit
    fi

# Create user storage dir if not exists
    if [[ ! -d "/Library/Application Support/JAMF/Partners/Library/passwordPolicyPerUser" ]]; then
        mkdir "/Library/Application Support/JAMF/Partners/Library"
	    mkdir "/Library/Application Support/JAMF/Partners/Library/passwordPolicyPerUser"
	    echo "pwpolicyPerUser.sh will create one file per user so pwpolicy is set only once for each user" > "/Library/Application Support/JAMF/Partners/Library/passwordPolicyPerUser/readme.txt"
        pwpolicy -setglobalpolicy "usingHistory=4"
    fi

# Run only once per user
    if [[ -f "/Library/Application Support/JAMF/Partners/Library/passwordPolicyPerUser/$currentLoggedInUser" ]]; then
    	echo "policy exists for $currentLoggedInUser"
    else
    	echo "setting $currentLoggedInUser policy"
        pwpolicy -u "$currentLoggedInUser" -setpolicy "requiresAlpha=1 requiresNumeric=1 minChars=8 usingHistory=4"
        touch "/Library/Application Support/JAMF/Partners/Library/passwordPolicyPerUser/$currentLoggedInUser"
    fi
done

exit 0