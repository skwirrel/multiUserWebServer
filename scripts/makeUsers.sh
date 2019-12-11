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

# Put the apache config in place if it isn't there already...
APACHE_CONFIG="/etc/httpd/conf.d/00multiUserWebServer.conf"
escapedDomain=`echo $baseDomain |  sed 's/\./\\\\./g'`
if [ ! -e "$APACHE_CONFIG" ]; then
	cat << END > "$APACHE_CONFIG"
<VirtualHost *:80>
        # Multiuser Web Server Config
        UseCanonicalName Off

        <Directory "/home/*/public_html">
            Require all granted
            Options -Indexes -FollowSymLinks +SymLinksIfOwnerMatch
            AllowOverride All Options=ExecCGI,Includes,IncludesNOEXEC,Indexes,MultiViews,SymLinksIfOwnerMatch
            DirectoryIndex index.html index.php _default_index.html
        </Directory>

        <FilesMatch "^\.">
            Require all denied
        </FilesMatch>
        <DirectoryMatch "/\.">
            Require all denied
        </DirectoryMatch>

        Alias "/_default_index.html" "$ALL_USER_DIR/public_html/_default_index.html"

        RewriteMap lowercase int:tolower

        RewriteEngine on
        RewriteCond "\${lowercase:%{HTTP_HOST}}" ^(.+)\.$escapedDomain\$
        RewriteCond %{REQUEST_URI} !^/_default_index\.html$
        RewriteRule "^(.*)" "/home/%1/public_html\$1" [E=StudentId:%1]

        AssignUserIDExpr %{reqenv:StudentId}
        AssignGroupIDExpr %{reqenv:StudentId}
        php_admin_value auto_prepend_file "$ALL_USER_DIR/public_html/autoPrepend.php"
</VirtualHost>

LimitUIDRange 1000 9000
EnableCapabilities On

END
	service httpd restart
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
ldapsearch -x -h "$ldapServer" -D "$ldapUser" -w "$ldapPassword" -b "$ldapBase" "(&(objectCategory=user)(memberOf:1.2.840.113556.1.4.1941:=$ldapGroup,$ldapBase))" -LL "$ldapAttribute" | egrep "^$ldapAttribute: " | cut -d ' ' -f 2 | tr '[:upper:]' '[:lower:]' > "$MANAGER_DIR/users.txt"

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
			if ( ! egrep -q	"^$user\$" "$PASSWORD_RESET_LIST" ); then
				continue;
			fi
			echo Resetting password for user: $user
		else 
			continue
		fi
	else
		echo Creating user: $user
	fi
	

	# Create the user and their home directory
	if [ ! -d "$homeDir" ]; then
		useradd -m --skel "$SKEL_DIR" "$user" -s /sbin/nologin -G $SFTP_USER_GROUP
	fi

	password=`cat /dev/urandom | tr -dc _A-Z-a-z-0-9 | tr -d 1IlL0Oo_- | head -c$PASSWORD_LENGTH`
	echo -n $password | passwd --stdin $user

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
	restorecon -Rv /home/*

	# Set them up a database
	echo "CREATE DATABASE IF NOT EXISTS \`$user\`;" | mysql -u root
	echo "CREATE USER '$user'@'localhost' IDENTIFIED BY '$password';" | mysql -u root 2>/dev/null
	echo "SET PASSWORD FOR '$user'@'localhost' = PASSWORD('$password');" | mysql -u root
	echo "GRANT ALL PRIVILEGES ON \`$user\`.* TO '$user'@'localhost';" | mysql -u root

	# Send an email to the user
	export user password emailUserDomain emailFromAddress baseDomain
	##### N.B. THE EMAIL TEMPLATE **MUST** USE DOS LINE ENDINGS (use ":set ff=dos" in vim)
	envsubst < emailTemplate_accountReady.txt | curl --url "smtp://$smtpServerAddress:25" --ssl-reqd --insecure --mail-from "$emailFromAddress" --mail-rcpt "$emailUser@$emailUserDomain" --upload-file -
done

# Empty the password reset file
echo -n > "$PASSWORD_RESET_LIST"

# move any directories that haven't been touched in the last week - these will be users who are no longer in the group
mkdir -p "$OLD_USER_DIR"
find /home -mindepth 1 -maxdepth 1 -type d -mtime +5 -printf '%f\n' | while IFS= read -r user; do
	if [ ! -e "/home/$user/$AUTO_GENERATED_FLAG" ]; then
		continue
	fi
	echo "Removing user: $user"
	# Remove the entry for this user from the password list file
	sed -i "/^$user /d" "$PASSWORD_FILE"
	mv "/home/$user" "$OLD_USER_DIR/"
	/sbin/userdel $user
done

# delete any archived user directories over a year old

# SAFETY CHECK - don't run this if OLD_USER_DIR doesn't start with /home

if [[ "$OLD_USER_DIR/" =~ /home/.+ ]]; then
	find "$OLD_USER_DIR/" -type d -mtime +365 | xargs rm -rf
fi
