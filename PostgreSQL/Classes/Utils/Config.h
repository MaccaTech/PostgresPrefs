//
//  Config.h
//  PostgresPrefs
//
//  Created by Francis McKenzie on 10/7/15.
//  Copyright (c) 2011-2020 Macca Tech Ltd. (http://macca.tech)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

#ifndef PostgreSQL_Config_h
#define PostgreSQL_Config_h

// App
#define PGPrefsAppID @"org.postgresql.preferences"
#define PGServersPollTime 5
#define PGLaunchdDaemonForAllUsersAtBootDir @"/Library/LaunchDaemons"
#define PGLaunchdDaemonForAllUsersAtLoginDir @"/Library/LaunchAgents"
#define PGLaunchdDaemonForCurrentUserOnlyDir @"~/Library/LaunchAgents"
#define PGLaunchdDaemonLogRootDir @"/Library/Logs/PostgreSQL"
#define PGLaunchdDaemonLogUserDir @"~/Library/Logs/PostgreSQL"

// Debugging
#ifdef DEBUG
#
#   define LOG_FILE [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/PostgreSQL/org.postgresql.preferences.DEBUG.log"]
#   define PGPrefsMonitorServersEnabled NO
#   define PGPrefsRefreshServersEnabled YES
#
#else /* !DEBUG */
#
#   define PGPrefsMonitorServersEnabled YES
#   define PGPrefsRefreshServersEnabled NO
#
#endif /* DEBUG */

// Colours
#define PGServerStatusUnknownColor [NSColor darkGrayColor]
#define PGServerStartingColor [NSColor orangeColor]
#define PGServerStartedColor [NSColor colorWithCalibratedRed:0 green:0.8f blue:0 alpha:1]
#define PGServerStoppingColor [NSColor orangeColor]
#define PGServerStoppedColor [NSColor redColor]
#define PGServerDeletingColor [NSColor orangeColor]
#define PGServerRetryingColor [NSColor orangeColor]
#define PGServerUpdatingColor [NSColor orangeColor]
#define PGServerCheckingColor [NSColor orangeColor]
#define PGServerInfoColor [NSColor colorWithCalibratedRed:0 green:0.501960814f blue:1 alpha:1]

// Images
#define PGServerStatusUnknownImage @"unknown"
#define PGServerStartingImage @"changing"
#define PGServerStartedImage @"started"
#define PGServerStoppingImage @"changing"
#define PGServerStoppedImage @"stopped"
#define PGServerDeletingImage @"changing"
#define PGServerRetryingImage @"changing"
#define PGServerUpdatingImage @"changing"
#define PGServerCheckingImage @"changing"

// Prevent naming conflicts, as described in Mac Developer Library documentation
#define PG(name)                     TechMaccaPG##name

#define PGPrefsPane                  PG(PrefsPane)
#define PGPrefsViewController        PG(PrefsViewController)
#define PGPrefsController            PG(PrefsController)
#define PGPrefsSegmentedControl      PG(PrefsSegmentedControl)
#define PGPrefsRenameWindow          PG(PrefsRenameWindow)
#define PGPrefsDeleteWindow          PG(PrefsDeleteWindow)
#define PGPrefsInfoWindow            PG(PrefsInfoWindow)
#define PGPrefsServerSettingsWindow  PG(PrefsServerSettingsWindow)
#define PGPrefsServersHeaderCell     PG(PrefsServersHeaderCell)
#define PGPrefsServersCell           PG(PrefsServersCell)
#define PGPrefsCenteredTextFieldCell PG(PrefsCenteredTextFieldCell)
#define PGPrefsStoryboardTextView    PG(PrefsStoryboardTextView)
#define PGPrefsCenteredTextView      PG(PrefsCenteredTextView)
#define PGPrefsNonClickableTextField PG(PrefsNonClickableTextField)

#define PGServer                     PG(Server)
#define PGServerSettings             PG(ServerSettings)
#define PGServerController           PG(ServerController)
#define PGServerDelegate             PG(ServerDelegate)
#define PGServerDataStore            PG(ServerDataStore)

#define PGSearchController           PG(SearchController)
#define PGSearchDelegate             PG(SearchDelegate)

#define PGServerDefaultName          PG(ServerDefaultName)
#define PGServerNameKey              PG(ServerNameKey)
#define PGServerDomainKey            PG(ServerDomainKey)
#define PGServerUsernameKey          PG(ServerUsernameKey)
#define PGServerBinDirectoryKey      PG(ServerBinDirectoryKey)
#define PGServerDataDirectoryKey     PG(ServerDataDirectoryKey)
#define PGServerLogFileKey           PG(ServerLogFileKey)
#define PGServerPortKey              PG(ServerPortKey)
#define PGServerStartupKey           PG(ServerStartupKey)

#define PGServerStartup              PG(ServerStartup)
#define PGServerStartupManual        PG(ServerStartupManual)
#define PGServerStartupAtBoot        PG(ServerStartupAtBoot)
#define PGServerStartupAtLogin       PG(ServerStartupAtLogin)
#define PGServerStartupManualName    PG(ServerStartupManualName)
#define PGServerStartupAtBootName    PG(ServerStartupAtBootName)
#define PGServerStartupAtLoginName   PG(ServerStartupAtLoginName)

#define PGServerStatus               PG(ServerStatus)
#define PGServerStatusUnknown        PG(ServerStatusUnknown)
#define PGServerStarting             PG(ServerStarting)
#define PGServerStarted              PG(ServerStarted)
#define PGServerStopping             PG(ServerStopping)
#define PGServerStopped              PG(ServerStopped)
#define PGServerDeleting             PG(ServerDeleting)
#define PGServerRetrying             PG(ServerRetrying)
#define PGServerUpdating             PG(ServerUpdating)
#define PGServerStatusUnknownName    PG(ServerStatusUnknownName)
#define PGServerStartingName         PG(ServerStartingName)
#define PGServerStartedName          PG(ServerStartedName)
#define PGServerStoppingName         PG(ServerStoppingName)
#define PGServerDeletingName         PG(ServerDeletingName)
#define PGServerStoppedName          PG(ServerStoppedName)
#define PGServerRetryingName         PG(ServerRetryingName)
#define PGServerUpdatingName         PG(ServerUpdatingName)

#define PGServerAction               PG(ServerAction)
#define PGServerCheckStatus          PG(ServerCheckStatus)
#define PGServerStart                PG(ServerStart)
#define PGServerStop                 PG(ServerStop)
#define PGServerDelete               PG(ServerDelete)
#define PGServerCreate               PG(ServerCreate)
#define PGServerCheckStatusName      PG(ServerCheckStatusName)
#define PGServerStartName            PG(ServerStartName)
#define PGServerStopName             PG(ServerStopName)
#define PGServerCreateName           PG(ServerCreateName)
#define PGServerDeleteName           PG(ServerDeleteName)
#define PGServerCheckStatusVerb      PG(ServerCheckStatusVerb)
#define PGServerStartVerb            PG(ServerStartVerb)
#define PGServerStopVerb             PG(ServerStopVerb)
#define PGServerCreateVerb           PG(ServerCreateVerb)
#define PGServerDeleteVerb           PG(ServerDeleteVerb)

#define PGAuth                       PG(Auth)
#define PGAuthDelegate               PG(AuthDelegate)
#define PGAuthReasonKey              PG(AuthReasonKey)
#define PGAuthReasonAction           PG(AuthReasonAction)
#define PGAuthReasonTarget           PG(AuthReasonTarget)
#define PGData                       PG(Data)
#define PGFile                       PG(File)
#define PGLaunchd                    PG(Launchd)
#define PGProcess                    PG(Process)
#define PGRights                     PG(Rights)
#define PGUser                       PG(User)
#define PGFileType                   PG(FileType)
#define PGFileNone                   PG(FileNone)
#define PGFileFile                   PG(FileFile)
#define PGFileDir                    PG(FileDir)

#endif /* PostgreSQL_Config_h */
