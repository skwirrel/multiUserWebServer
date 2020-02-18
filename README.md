# MUWS - MultiUserWebServer 

Author: Ben Jefferson
Copyright: Huddersfield New College 2019 <http://huddnewcoll.ac.uk/>

MUWS is provided freely as open source software, under the GNU AFFERO GENERAL PUBLIC LICENSE (see LICENSE.txt)

## Introduction
MUWS (pronounced "muse") is the result of a commission by [New College Huddersfield](http://huddnewcoll.ac.uk). Their requirements were as follows:
* A Linux server offer users the following services:
    * Apache
    * PHP (>7)
    * MySQL
    * phpMyAdmin
    * Access via SFTP
* Automatic creation of users (Linux user and MySQL user) based on an LDAP group
* Automatic password generation and emailing this to users on account creation
* Securing the server as much as possible - especially to prevent one user from impacting on others. This means things like...
    * Preventing one user's web scripts from accessing/modifying another user's files
    * Using chrooted sftp so that users cannot access/modify another user's files via sftp
* A password-protected management interface to
    * Allow an administrator to trigger password resets for individual users
    * View/download all of the current passwords for all users
* Automatic deletion of users who are absent from the specified LDAP group for a period of time
* Some sort of web interface to provide a management overview of the server ( [Cockpit Project](https://cockpit-project.org/) was selected to provide this)

## Status
The code provided here is far from "plug and play" - at present it should be considered more as guidance notes than a finished solution. However we are sharing this code because there is a chance that others may still find it useful and may even then contribute towards improving it.

## Components

The project currently comprises 3 core components:
1. `setupNotes.txt` - Notes describing how to configure a vanilla "minimal" CentOS 7 server. This largely consists of Bash command and might eventually be converted to a Bash script.
1. `manager/public_html/index.php` - a very basic web interface for managing users (downloading passwords of existing users and triggering password resets)
1. `scripts/makeUsers.sh` - A bash script to be run from Cron which handles the automatic creation of users (both Linux system users and MySQL users) as well as other ancillary actions such as...
    - Handling password resets
    - Archiving/deleting home directories of old users
    - Installing the Cron file ( `/etc/cron.d/multiUserWebServer` ) if it doesn't exist
    - Installing the necessary Apache configuration file in ( `/etc/httpd/conf.d//multiUserWebServer.conf` ) if it doesn't exist
    - Creating user home directories for new users if they don't exist
    - Creating a databases for new users

## Installation
1. Start with a clean "minimal" CentOS 7 install
2. Work through the instructions in `setupNotes.txt`
3. Copy `scripts/multiUserWebServer.conf.default` to `scripts/multiUserWebServer.conf` and then edit `scripts/multiUserWebServer.conf` to contain appropriate values
4. Run `makeUsers.sh` from the command line - this will finish off the installation by installing the neccessary Cron and Apache configuration files
5. Configure your DNS server so that `*.<baseDomain>` is directed to the IP address of the server you have installed MUWS on.

## Using MUWS
Once MUWS has been configured any users in the specified LDAP group (see the LDAP section of `scripts/multiUserWebServer.conf` ) will be automatically created as new users.

### User functionality
Users can...  
* Connect via SFTP using the credentials sent to them in the welcome email
* View their webspace by pointing their browser at:
    * http://\<username\>.\<baseDomain\>/
* Execute PHP scripts in their web space - these scripts have read and write permissions to their webspace so can create and read files anywhere under the public_html directory. If there is a requirement to read/write private data (e.g. configuration files), then these can be put in a subdirectory whose name starts with a dot (e.g. `.private`) - the web server is configured to deny access to any files in any folder whose name starts with a dot.
* Access their database via the phpmyadmin gui by going to:
    * http://phpmyadmin.\<baseDomain\>/
    * Users log in with the MySQL same username and password as they use for SFTP access
    * N.B. Users can use this interface to change their MySQL password - but if a password reset is later triggered through MUWS then both the Linux and MySQL passwords will be reset to the same new value.

### Administrator functionality
Administrators can...
* Connect to the administration interface:
    * http://manager.\<baseDomain\>/
    * The "manager" subdomain is configurable (see `MANAGER_USER` in `scripts/multiUserWebServer.conf`)
    * The password is provided when `scripts/makeUsers.sh` is run for the first time, or when `scripts/resetManagerPassword.sh` is run.
* Request to view (onscreen) a list of all users and their current passwords
* Request to download a list of all users and their current passwords
* Request to reset the password of any given user (by specifying the username)
    * The user will be sent a new welcome email containing the new password
    * The password reset is not immediate and will take place when `makeUser.sh` is next run by Cron (every 5 minutes by default)
    * Both the Linux and MySQL passwords are reset for the specified user
* Run `scripts/resetManagerPassword.sh` to reset the password for administration interface
* Connect to the Cockpit server management interface by going to:
    * http://\<serverIpAddress\>:9090/
    * This requires creating a user on the server command line thus:
        1. Create the user: `useradd <username> -aG`
        1. Set their password: `passwd <username>`
        1. Make them a server administrator: `usermod -aG wheel <username>`

## A Note About Passwords
Whilst this system has several security safeguards built in, these are designed to avoid the inconvenience of one student messing with another student's work. However this system is only intended to be used in low-security applications. The ability for a manager to quickly and easily view existing passwords was a specific client requirement. Under any other circumstances the storage of passwords in plain text would be totally unacceptable.

In particular this system should never be used where the server will hold any personal data about students, administrators or anyone else. This system must not be hosted on a server which also holds sensitive or personal data or other important systems. 

## TODO
- Fully automating the install process i.e. converting `setupNotes.txt` to `setup.sh`
- Enabling and reporting on user disk quota ([This page](https://www.linuxtechi.com/enable-user-group-disk-quota-on-centos-7-rhel-7/) describes this nicely).
- Support for HTTPS (in the original designed use case this was for deployment only on an internal server and will hold no personal or important data, so HTTPS was not required)
- Provide an interface for users to change their own password
- Add support for a user-specified password in the `resetManagerPassword.sh` script
- Support for editing email template in management interface
- Incremental point-in-time backups using rsync
