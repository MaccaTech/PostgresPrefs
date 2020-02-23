# Postgres Prefs

<a href="https://www.postgresql.org"><img height="64px" src="https://raw.github.com/MaccaTech/PostgresPrefs/master/PostgreSQL/Images/elephant.png" /></a>
<a href="https://www.postgresql.org"><img height="40px" src="https://raw.github.com/MaccaTech/PostgresPrefs/master/PostgreSQL/Images/logo.png" /></a>
<a href="http://mac.softpedia.com/get/Internet-Utilities/PostgresPrefs.shtml#status"><img align="right" height="112px" src="http://s1.softpedia-static.com/_img/sp100clean.png?1" /></a>

[![build](https://travis-ci.org/MaccaTech/PostgresPrefs.svg?branch=master)](https://travis-ci.org/MaccaTech/PostgresPrefs)

## Contents

* [Overview](#Overview)
* [Install Instructions](#Install-Instructions)
* [Uninstall Instructions](#Uninstall-Instructions)
* [FAQ](#FAQ)
* [Version History](#Version-History)
* [Contact](#Contact)
* [Licence](#Licence)
* [Links](#Links)

## Overview

A Mac OS X System Preferences pane for controlling the PostgreSQL Database Server.
    
Features include:

* **Compatible** with all PostgreSQL installations - including [Homebrew](http://www.russbrooks.com/2010/11/25/install-postgresql-9-on-os-x) and [One click installer](http://www.postgresql.org/download/macosx/)
* Start and stop PostgreSQL Servers at the **click of a button** - no need for obscure commands
* Set PostgreSQL to **start automatically** on computer bootup or user login
* Easily change PostgreSQL **settings** in the GUI
* Control **multiple** PostgreSQL servers in the same window

### Main Screen

![alt text](https://raw.github.com/MaccaTech/PostgresPrefs/master/PostgreSQL/Images/screenshot_v2_main.png "Main Screen")

### Change Settings

![alt text](https://raw.github.com/MaccaTech/PostgresPrefs/master/PostgreSQL/Images/screenshot_v2_settings.png "Settings Screen")

### Log

![alt text](https://raw.github.com/MaccaTech/PostgresPrefs/master/PostgreSQL/Images/screenshot_v2_log.png "Log Screen")

## Install Instructions

1. Download the latest release version [here](https://github.com/MaccaTech/PostgresPrefs/releases)
2. Once downloaded, open the `.dmg` file by double-clicking it, and then either double-click the contained `PostgreSQL.prefPane` file, or drag it to System Preferences to install it.
3. When installing, you will be asked if you want to install it for this user only, or for all users. Choose this user only (either option is fine however).

![alt text](https://raw.github.com/MaccaTech/PostgresPrefs/master/PostgreSQL/Images/screenshot_install.png "Install Screen")

## Uninstall Instructions

1. Stop any running PostgreSQL servers:
    * Open System Preferences, click <img height="24px" src="https://raw.github.com/MaccaTech/PostgresPrefs/master/PostgreSQL/Images/elephant.png" />, select each running server in turn and click the `Stop PostgreSQL` button

2. Remove PostgresPrefs from System Preferences:
    * Right-click <img height="24px" src="https://raw.github.com/MaccaTech/PostgresPrefs/master/PostgreSQL/Images/elephant.png" /> in System Preferences, and click `Remove`
    
3. Delete the PostgresPrefs configuration file, if it exists:
```
     rm ~/Library/Preferences/org.postgresql.preferences.servers.plist
sudo rm  /Library/Preferences/org.postgresql.preferences.servers.plist
```
4. Delete any configuration files for starting/stopping individual PostgreSQL servers, if they exist:
```
     rm ~/Library/LaunchAgents/org.postgresql.preferences.*.plist
sudo rm  /Library/LaunchAgents/org.postgresql.preferences.*.plist
sudo rm  /Library/LaunchDaemons/org.postgresql.preferences.*.plist
```
5. Delete the log directories containing log files for your PostgreSQL servers, if they exist:
```
     rm -rf ~/Library/Logs/PostgreSQL
sudo rm -rf  /Library/Logs/PostgreSQL
```

## FAQ

* **In a nutshell, what does this tool do and what does it not do?**
    
    It can start and stop PostgreSQL servers, show their running status, and schedule auto-startup at boot/login. It cannot install PostgreSQL, create database clusters, create databases or run SQL.

* **Can I run multiple instances of PostgreSQL on the same machine?**

    Yes - this is new with Version 2! Note that each separate instance of PostgreSQL _must have its own data directory and port_. It is easy to specify a different port using the settings popup. But to create a separate data directory you must run the `initdb` command to create a new database cluster, as described in the [PostgreSQL documentation](http://www.postgresql.org/docs/manuals).

* **PostgreSQL does not start up.**

    If you clicked `Start PostgreSQL`, and the server is stuck with status `Retrying...`, the first step is to click the `View Log` button. This will open the default log for the server in Mac OS X's `Console` log-viewing application. From the log messages, it should be clear what the problem is. For example, the PostgreSQL data directory or port may already be in use by another server.

* **I have selected startup at Login/Boot, but PostgreSQL still does not startup automatically.**

    First, make sure you can start the server manually using the `Start PostgreSQL` button. If this works ok, then please file an issue on github and we will investigate.

* **Does this tool affect my existing installations?**

    The short answer is: no, Postgre Preferences creates its own configuration files for starting/stopping servers, separate from any existing installations.
However, from version 2.1 onwards, Postgre Preferences automatically detects and displays already-running servers _that were started/configured elsewhere_. Any such 'external' servers can be started and stopped like normal servers (if a configuration file is found). If you click the `-` button to delete one of the external servers, you will be prompted whether you also want to delete the server's configuration file, or leave it untouched.

* **Who is Macca Tech, and why did you make this tool?**

    At the moment, [Macca Tech](http://macca.tech) consists of just me, a developer who enjoys creating tools and apps on macOS and iOS. I created this tool partly for fun, and partly because I was using PostgreSQL and found it far too complicated to do something as simple as starting and stopping a database server!

## Version History

<table>
<thead>
<tr>
    <th>Version</th>
    <th>Date</th>
    <th>Comments</th>
</tr>
</thead>
<tbody>
<tr>
    <td>v2.6</td>
    <td>28-Feb 2020</td>
    <td>Enhancement release
        <ul>
        <li>Start/stop PostgreSQL without a password</li>
        </ul>
    </td>
</tr>
<tr>
    <td>v2.5</td>
    <td>12-Feb 2020</td>
    <td>Bugfix release
        <ul>
        <li>Fix start/stop errors on Catalina</li>
        <li>Improve detection of existing PostgreSQL installations</li>
        <li>Support dark mode</li>
        <li>Automate releases using Github & Travis</li>
        </ul>
    </td>
</tr>
<tr>
    <td>v2.4.3</td>
    <td>20-Jan 2020</td>
    <td>Bugfix release
        <ul>
        <li>64-bit build for MacOS Catalina</li>
        </ul>
    </td>
</tr>
<tr>
    <td>v2.4.2</td>
    <td>8-Feb 2016</td>
    <td>Bug-fix release
        <ul>
        <li>Fixed error if user's default shell is fish</li>
        <li>Improved server status icons</li>
        </ul>
    </td>
</tr>
<tr>
    <td>v2.4.1</td>
    <td>10-Nov 2015</td>
    <td>Bug-fix release
        <ul>
        <li>Fixed unable to start server because username incorrectly marked as invalid</li>
        <li>Fixed unable to start server after clicking 'Duplicate Server'</li>
        <li>Fixed server settings not saved after clicking 'Duplicate Server'</li>
        </ul>
    </td>
</tr>
<tr>
    <td>v2.4</td>
    <td>30-Aug 2015</td>
    <td>Bug-fix release
        <ul>
        <li>Automatically detect all PostgreSQL processes running on system, not just daemons</li>
        <li>Fixed leaving 'ghost' process running after stopping Postgresapp.com server</li>
        <li>Fixed background thread for detecting running servers could stop unintentionally</li>
        <li>Fixed View Log becoming disabled if change startup setting for running server</li>
        </ul>
    </td>
</tr>
<tr>
    <td>v2.3</td>
    <td>28-Aug 2015</td>
    <td>Enhancement release
        <ul>
        <li>Improved speed/security: replaced external shell script with native code</li>
        <li>Invalid server settings now highlighted more clearly</li>
        <li>Changing startup does not affect running server</li>
        <li>Startup-at-login supported for all users, not just current</li>
        <li>Fixed briefly showing server as started even though failed to start</li>
        </ul>
    </td>
</tr>
<tr>
    <td>v2.2.1</td>
    <td>22-Aug 2015</td>
    <td>Bug-fix release
        <ul>
        <li>Automatically detect running Postgresapp.com server</li>
        </ul>
    </td>
</tr>
<tr>
    <td>v2.2</td>
    <td>9-Aug 2015</td>
    <td>Enhancement release
        <ul>
        <li>See status of all servers without entering password</li>
        </ul>
    </td>
</tr>
<tr>
    <td>v2.1</td>
    <td>30-Jul 2015</td>
    <td>Enhancement release
        <ul>
        <li>Automatically detect already-running servers configured elsewhere</li>
        <li>Start/stop these 'external' servers like any others</li>
        <li>New 'Duplicate Server' function</li>
        </ul>
    </td>
</tr>
<tr>
    <td>v2.0</td>
    <td>22-Jul 2015</td>
    <td>Major release
        <ul>
        <li>Control multiple servers from a single window</li>
        <li>Start servers at computer bootup (previously only at login)</li>
        <li>Easily debug problems using default server logs</li>
        <li>See running status of servers without entering a password</li>
        <li>Starting/stopping still password-protected</li>
        <li>More code is pure Objective-C, less reliance on shell scripts</li>
        </ul>
    </td>
</tr>
<tr>
    <td>v1.4.1</td>
    <td>22-Jul 2015</td>
    <td>Bug-fix release
        <ul>
        <li>Fixed error message being shown if username setting is non-blank.</li>
        </ul>
    </td>
</tr>
<tr>
    <td>v1.4</td>
    <td>03-Jul 2015</td>
    <td>Bug-fix release
        <ul>
        <li>Fixed auto-start on login if upgrading from older version of pref pane</li>
        <li>Clicking auto-start no longer causes Postgre to startup straightaway</li>
        </ul>
    </td>
</tr>
<tr>
    <td>v1.3</td>
    <td>30-Jun 2015</td>
    <td>Bug-fix release
        <ul>
        <li>Fixed auto-start PostgreSQL on login (OS X 10.10+)</li>
        <li>Fixed description of auto-start function in interface</li>
        <li>Detect errors relating to auto-start and show in interface</li>
        </ul>
    </td>
</tr>
<tr>
    <td>v1.2</td>
    <td>30-Jun 2015</td>
    <td>Bug-fix release
        <ul>
        <li>Fixed auto-start PostgreSQL on login (OS X 10.9)</li>
        </ul>
    </td>
</tr>
<tr>
    <td>v1.1</td>
    <td>17-Oct 2014</td>
    <td>Bug-fix release
        <ul>
        <li>Fixed errors caused by spaces or ~ in paths</li>
        <li>Auto-detect Postgres.app install</li>
        <li>Fixed incompatibility with latest XCode (ARC now mandatory)</li>
        <li><b>Note:</b> requires Mac OS X Lion or newer</li>
        </ul>
    </td>
</tr>
<tr>
    <td>v1.0.1</td>
    <td>10-Mar 2012</td>
    <td>Bug-fix release
        <ul>
        <li>Fixed hard-coded username in start/stop script</li>
        <li>Fixed bug where settings were getting cleared when user re-authorized</li>
        </ul>
    </td>
</tr>
<tr>
    <td>v1.0</td>
    <td>29-Dec 2011</td>
    <td>Initial release</td>
</tr>
</tbody>
</table>

## Contact

Please email any feedback to [info@macca.tech](mailto:info@macca.tech)

## Licence

This project is covered by the [MIT Licence](https://github.com/MaccaTech/PostgresPrefs/blob/master/LICENCE.txt)

## Links

* [www.postgresql.org](https://www.postgresql.org)
* [macca.tech](http://macca.tech)

