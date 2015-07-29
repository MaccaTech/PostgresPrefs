//
//  Config.h
//  PostgreSQL
//
//  Created by Francis McKenzie on 10/7/15.
//  Copyright (c) 2015 Macca Tech Ltd. All rights reserved.
//

#ifndef PostgreSQL_Config_h
#define PostgreSQL_Config_h

// App
#define PGPrefsAppID @"org.postgresql.preferences"
#define PGServersPollTime 5
#define PGLaunchdDaemonFileBootDir @"/Library/LaunchDaemons"
#define PGLaunchdDaemonFileLoginGlobalDir @"/Library/LaunchAgents"
#define PGLaunchdDaemonFileLoginUserDir @"~/Library/LaunchAgents"
#define PGLaunchdDaemonLogRootDir @"/Library/Logs/PostgreSQL"
#define PGLaunchdDaemonLogUserDir @"~/Library/Logs/PostgreSQL"

// Debugging
#ifdef DEBUG
#
#   define LOG_FILE [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/PostgreSQL/org.postgresql.preferences.DEBUG.log"]
#   define PGPrefsMonitorServersEnabled NO
#
#else /* !DEBUG */
#
#   define PGPrefsMonitorServersEnabled YES
#
#endif /* DEBUG */

// Colours
#define PGServerStatusUnknownColor [NSColor darkGrayColor]
#define PGServerStatusProtectedColor [NSColor darkGrayColor]
#define PGServerStartingColor [NSColor orangeColor]
#define PGServerStartedColor [NSColor colorWithCalibratedRed:0 green:0.8f blue:0 alpha:1]
#define PGServerStoppingColor [NSColor orangeColor]
#define PGServerStoppedColor [NSColor redColor]
#define PGServerRetryingColor [NSColor orangeColor]
#define PGServerUpdatingColor [NSColor darkGrayColor]
#define PGServerCheckingColor [NSColor blueColor]

// Prevent naming conflicts, as described in Mac Developer Library documentation
#define PGPrefsPane ComMaccatechPostgrePrefsPane
#define PGPrefsViewController ComMaccatechPostgrePrefsViewController
#define PGPrefsController ComMaccatechPostgrePrefsController
#define PGPrefsSegmentedControl ComMaccatechPostgrePrefsSegmentedControl
#define PGPrefsRenameWindow ComMaccatechPostgrePrefsRenameWindow
#define PGPrefsServerSettingsWindow ComMaccatechPostgrePrefsServerSettingsWindow
#define PGPrefsServersCell ComMaccatechPostgrePrefsServersCell
#define PGPrefsCenteredTextFieldCell ComMaccatechPostgrePrefsCenteredTextFieldCell

#define PGServer ComMaccatechPostgreServer
#define PGServerSettings ComMaccatechPostgreServerSettings
#define PGServerController ComMaccatechPostgreServerController
#define PGServerDelegate ComMaccatechPostgreServerDelegate
#define PGServerDataStore ComMaccatechPostgreServerDataStore

#define PGSearchController ComMaccatechPostgreSearchController
#define PGSearchDelegate ComMaccatechPostgreSearchDelegate

#define PGServerDefaultName ComMaccatechPostgreServerDefaultName
#define PGServerNameKey ComMaccatechPostgreServerNameKey
#define PGServerDomainKey ComMaccatechPostgreServerDomainKey
#define PGServerUsernameKey ComMaccatechPostgreServerUsernameKey
#define PGServerBinDirectoryKey ComMaccatechPostgreServerBinDirectoryKey
#define PGServerDataDirectoryKey ComMaccatechPostgreServerDataDirectoryKey
#define PGServerLogFileKey ComMaccatechPostgreServerLogFileKey
#define PGServerPortKey ComMaccatechPostgreServerPortKey
#define PGServerStartupKey ComMaccatechPostgreServerStartupKey

#define PGServerStartup ComMaccatechPostgreServerStartup
#define PGServerStartupManualName ComMaccatechPostgreServerStartupManualName
#define PGServerStartupAtBootName ComMaccatechPostgreServerStartupAtBootName
#define PGServerStartupAtLoginName ComMaccatechPostgreServerStartupAtLoginName

#define PGServerStatus ComMaccatechPostgreServerStatus
#define PGServerStatusUnknownName ComMaccatechPostgreServerStatusUnknown
#define PGServerStartingName ComMaccatechPostgreServerStarting
#define PGServerStartedName ComMaccatechPostgreServerStarted
#define PGServerStoppingName ComMaccatechPostgreServerStopping
#define PGServerStoppedName ComMaccatechPostgreServerStopped
#define PGServerRetryingName ComMaccatechPostgreServerRetrying
#define PGServerUpdatingName ComMaccatechPostgreServerUpdating

#define PGServerDaemonContext ComMaccatechPostgreServerDaemonContext

#define PGServerAction ComMaccatechPostgreServerAction
#define PGServerCheckStatusName ComMaccatechPostgreServerCheckStatusName
#define PGServerStartName ComMaccatechPostgreServerStartName
#define PGServerStopName ComMaccatechPostgreServerStopName
#define PGServerCreateName ComMaccatechPostgreServerCreateName
#define PGServerDeleteName ComMaccatechPostgreServerDeleteName

#define PGData ComMaccatechPostgreData
#define PGLaunchd ComMaccatechPostgreLaunchd
#define PGProcess ComMaccatechPostgreProcess

#endif /* PostgreSQL_Config_h */
