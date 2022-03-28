# Table of Contents

* [Development](#development)
* [Distribution](#distribution)

# Development

Debugging preference panes is complicated because they are not standalone applications. Instead, they run inside the System Preferences process.

It is not possible to connect to a running preference pane in order to pause execution at Xcode breakpoints, unless System Integrity Protection (SIP) is first disabled.

Therefore the procedure for developing ```PostgresPrefs``` is as follows:

### Disable SIP

1. Reboot your computer
2. Enter Recovery Mode by holding down Command-R
3. Click Utilities -> Terminal
4. Run ```csrutil enable --without debug```
5. Reboot

### Xcode debugging

1. In Xcode, click ```Run``` to execute a build and automatically launch ```PostgresPrefs``` in System Preferences
2. Once ```PostgresPrefs``` is visible, in Xcode click ```Debug``` -> ```Attach to Process``` -> ```legacyLoader-<platform_name>```
3. Now set breakpoints and debug as normal

### Reenable SIP

1. Reboot into Recovery Mode again
2. In Terminal run ```csrutil clear```
3. Reboot

# Distribution

In Terminal, run ```scripts/dist.sh``` in the project directory. This does the following:

1. Performs a release build to create ```build/PostgresPrefs-x.y/PostgresPrefs.prefPane```
2. Wraps this in ```build/PostgresPrefs-x.y.dmg```
3. Codesigns the ```.dmg``` file
4. Submits the ```.dmg``` file to Apple for notarization
5. Polls Apple's notarization service until done

### Note

- The Xcode project and the above script are configured to use the Apple account for Macca Tech Ltd.
- Anyone forking this project will need to configure their own account details in the code signing section in Xcode, and also change any hard-coded account details in ```scripts/*```.
- Notarization requires first configuring an App-Specific Password, which can be done at https://appleid.apple.com. The user will be prompted to enter this password when running ```scripts/dist.sh```.

