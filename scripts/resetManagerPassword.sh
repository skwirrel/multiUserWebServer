#!/bin/bash

source ./multiUserWebServer.conf

password=`cat /dev/urandom | tr -dc _A-Z-a-z-0-9 | tr -d 1IlL0Oo- | head -c$PASSWORD_LENGTH`
echo "********************************************************************************"
echo "*** THE MANAGER PASSWORD HAS BEEN SET TO THE FOLLOWING - MAKE A NOTE OF THIS ***"
echo "********************************************************************************"
echo
echo $password
echo
echo "********************************************************************************"
echo -n $password | passwd --stdin $MANAGER_USER
# Write the hashed password to a php config file
export password; echo '<?php echo password_hash(getenv("password"),PASSWORD_DEFAULT);' | php > "$MANAGER_DIR/managerPassword.txt"
