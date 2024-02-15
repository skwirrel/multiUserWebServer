#!/bin/bash


THIS_SCRIPT="$(realpath "$0")"
cd "$(dirname "$THIS_SCRIPT")"

source ./multiUserWebServer.conf

PASSWORD_RESET_LIST="$MANAGER_DIR/passwordReset.txt"
PASSWORD_FILE="$MANAGER_DIR/userPasswords.txt"

# Create the cron entry if it doesn't already exist
CRON_FILE="/etc/cron.d/multiUserWebServer"
if [ ! -e "$CRON_FILE" ]; then
	cat << END > "$CRON_FILE"
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=root
*/5 * * * * root $THIS_SCRIPT > /dev/null
END
fi

# Create the manager directory if it doesn't already exist
if [ ! -d "$MANAGER_DIR" ]; then
	/sbin/useradd -m --skel "$SKEL_DIR" "$MANAGER_USER" -s /sbin/nologin -G $SFTP_USER_GROUP
	touch "$PASSWORD_FILE"
	chown "$MANAGER_USER" "$PASSWORD_FILE"
	chmod 600 "$PASSWORD_FILE"
	./resetManagerPassword.sh
fi

# Get usernames for users in given group...
# If you're wondering what ":1.2.840.113556.1.4.1941:" is all about - it is apparently Microsoft magic...
# see https://stackoverflow.com/questions/6195812/ldap-nested-group-membership
ldapsearch -x -H ldap://"$ldapServer" -D "$ldapUser" -w "$ldapPassword" -b "$ldapBase" "(&(objectCategory=user)(memberOf:1.2.840.113556.1.4.1941:=$ldapGroup,$ldapBase))" -LL "$ldapAttribute" | egrep "^$ldapAttribute: " | cut -d ' ' -f 2 | tr '[:upper:]' '[:lower:]' > "$MANAGER_DIR/users.txt"

cat "$MANAGER_DIR/users.txt" | while read emailUser; do

        # skip empty usernames
        if [ -z "$emailUser" ]; then
                continue
        fi

        user=`echo -n "$emailUser" | tr -dc '[a-z0-9_\-]' | sed  's/^[0-9-]/user&/'`

        homeDir="/home/$user"
        # skip users that already exist
        if [ -d "$homeDir" ]; then

                # but touch their home directories to show they are still alive
                touch "$homeDir"

                # See if a password reset has been requested
                if [ -e "$PASSWORD_RESET_LIST" ]; then
                        if ( ! egrep -q "^$user\$" "$PASSWORD_RESET_LIST" ); then
                                continue;
                        fi
                        echo Resetting password for user: $user
                else
                        continue
                fi
        else
                echo Creating user: $user
                # In some cases the user might exist, but their home directory might not
                # in this case we delete the user so that they will get recreated AND their
                # home directory will also be created at the same time
                # If the user doesn't exist then calling userdel won't do any harm
                userdel $user 2> /dev/null
        fi


        # Create the user and their home directory
        if [ ! -d "$homeDir" ]; then
                useradd -m --skel "$SKEL_DIR" "$user" -s /sbin/nologin -G $SFTP_USER_GROUP
        fi

        password=`cat /dev/urandom | tr -dc _A-Z-a-z-0-9 | tr -d 1IlL0Oo_- | head -c$PASSWORD_LENGTH`
        echo -n $user:$password | chpasswd

        # Remove any existing entry for this user from the password list file
        sed -i "/^$user /d" "$PASSWORD_FILE"

        # Add the new password into the password list file
        echo $user $password >> "$PASSWORD_FILE"
        sort -o "$PASSWORD_FILE" "$PASSWORD_FILE"

        # Make all the permissions right on their home directory
        touch "$homeDir/$AUTO_GENERATED_FLAG"
        chmod 600 "$homeDir/$AUTO_GENERATED_FLAG"
        chown root "$homeDir"
        chown root "$homeDir/$AUTO_GENERATED_FLAG"
        chmod 750 "$homeDir"
        chmod 700 "$homeDir/$WEB_DIR"
        # restorecon -Rv /home/*

        # Set them up a database
        echo "CREATE DATABASE IF NOT EXISTS \`$user\`;" | mysql -u root
        echo "CREATE USER '$user'@'localhost' IDENTIFIED BY '$password';" | mysql -u root 2>/dev/null
        echo "SET PASSWORD FOR '$user'@'localhost' = PASSWORD('$password');" | mysql -u root
        echo "GRANT ALL PRIVILEGES ON \`$user\`.* TO '$user'@'localhost';" | mysql -u root

        # Send an email to the user
        export user password emailUserDomain emailFromAddress baseDomain
        ##### N.B. THE EMAIL TEMPLATE **MUST** USE DOS LINE ENDINGS (use ":set ff=dos" in vim)
        envsubst < emailTemplate_accountReady.txt | curl -s --url "smtp://$smtpServerAddress:25" --ssl-reqd --insecure --mail-from "$emailFromAddress" --mail-rcpt "$emailUser@$emailUserDomain" --upload-file -

done

# Empty the password reset file
echo -n > "$PASSWORD_RESET_LIST"

# move any directories that haven't been touched in the last week - these will be users who are no longer in the group
mkdir -p "$OLD_USER_DIR"
find /home -mindepth 1 -maxdepth 1 -type d -mtime +30 -printf '%f\n' | while IFS= read -r user; do
        if [ ! -e "/home/$user/$AUTO_GENERATED_FLAG" ]; then
                continue
        fi
        echo "Removing user: $user"
        # Remove the entry for this user from the password list file
        sed -i "/^$user /d" "$PASSWORD_FILE"
        # Remove any old backup of this user just in case
        rm -rf "$OLD_USER_DIR/$user"
        mv "/home/$user" "$OLD_USER_DIR/"
        /sbin/userdel $user
done

# delete any archived user directories over a year old

# SAFETY CHECK - don't run this if OLD_USER_DIR doesn't start with /home

if [[ "$OLD_USER_DIR/" =~ /home/.+ ]]; then
        find "$OLD_USER_DIR/" -type d -mtime +365 | xargs rm -rf
fi

