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

## Status
The code provided here is far from "plug and play" - at present it should be considered more as guidance notes than a finished solution. However we are sharing this code because there is a chance that others may still find it useful and may even then contribute towards improving it.

## Components

The project currently comprises 3 core components:
1. `setupNotes.txt` - Notes describing how to configure a vanilla "minimal" CentOS 7 server. This largely consists of Bash command and might eventually be converted to a Bash script.
1. `manager/public_html/index.php` - a very basic web interface for managing users (downloading passwords of existing users and triggering password resets)
1. `scripts/makeUsers.sh` - A bash script to be run from Cron which handles the automatic creation f users as well as other ancillary actions such as...
	- Handling password resets
	- Archiving/deleting home directories of old users
	- Installing the Cron file ( `/etc/cron.d/multiUserWebServer` ) if it doesn't exist
	- Installing the necessary Apache configuration file in ( `/etc/httpd/conf.d//multiUserWebServer.conf` ) if it doesn't exist

## Installation
1. Start with a clean "minimal" CentOS 7 install
2. Work through the instructions in `setupNotes.txt`
3. Copy `scripts/multiUserWebServer.conf.default` to `scripts/multiUserWebServer.conf` and then edit `scripts/multiUserWebServer.conf_ to contain appropriate values
4. Run `makeUsers.sh` from the command line - this will finish off the installation by installing the neccessary Cron and Apache configuration files

## TODO
- Fully automating the install process i.e. converting `setupNotes.txt` to `setup.sh`
- Enabling and reporting on user disk quota ([This page](https://www.linuxtechi.com/enable-user-group-disk-quota-on-centos-7-rhel-7/) describes this nicely).

