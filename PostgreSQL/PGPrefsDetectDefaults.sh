#!/bin/sh

#  PGPrefsDetectDefaultCmd.sh
#  PostgreSQL
#
#  Created by Francis McKenzie on 21/12/11.
#  Copyright (c) 2011 HK Web Entrepreneurs. All rights reserved.
# ==============================================================
#
# OVERVIEW:
# ---------
#
# Tries to find PostgreSQL installation and deduce following environment variables:
#
#   PGBIN   - Directory containing pg_ctl & postgres executables
#   PGDATA  - Data directory for postgresql server
#   PGUSER  - User that will run postgresql server
#   PGLOG   - Log file for postgresql server
#   PGPORT  - Port for postgresql server
#   PGAUTO  - Whether or not postgresql server starts automatically on computer bootup
#
#
# LOGIC:
# ------
#
# 1. LAUNCH AGENT
# ---------------
#
# A) Search /Library/LaunchDaemons, /Library/LaunchAgents & ~/Library/LaunchAgents for .plist file called *postgresql*
# B) If found, deduce PGBIN, PGDATA, PGUSER, PGLOG from .plist file
# C) If we have everything we need, then stop here
#
# 2. ENVIRONMENT
# --------------
#
# A) Get PGUSER, PGDATA, PGPORT, PGLOG from environment
# B) Get pg_ctl from path - use its dir as PGBIN
# C) If we have everything we need, then stop here
#
# 3. HOMEBREW
# -----------
#
# A) Search spotlight for Cellar directory
# B) If found, search for org.postgresql.postgres.plist below this.
# C) If found, deduce PGBIN, PGDATA, PGUSER, PGLOG from .plist file
# D) If we have everything we need, then stop here
#
# 4. .DMG INSTALL
# ---------------
#
# A) Search spotlight for pg_env.sh
# B) If found, execute this file. Hopefully now have PGDATA, PGUSER, PGPORT
# C) Set PGBIN to bin subdirectory relative to pg_env.sh file
# D) Assume no logging
#
# 5. POSTGRES.APP
# ---------------
#
# A) Search spotlight for Postgres.app in /Applications
# B) If found, search for pg_ctl below this - if found, set PGBIN to parent dir.
# C) If com.postgresapp.Postgres.plist exists, deduce PGDATA.
# D) Assume no logging
#
# 6. LAST RESORT!
# ---------------
#
# A) Search spotlight for pg_ctl - use its dir as PGBIN
# B) If dir PGBIN/../data exists, then use this as PGDATA
# C) Set PGUSER to owner of PGDATA (if exists), otherwise use current user
# D) Leave PGPORT, PGLOG blank
#
#
# RESULT
# ------
# PGBIN=${PGBIN}
# PGDATA=${PGDATA}
# PGUSER=${PGUSER}
# PGLOG=${PGLOG}
# PGPORT=${PGPORT}
# PGAUTO=${PGAUTO}
#
# ==============================================================

# To plain, trimmed string
to_string() {
    unset ___tmp;
    read -rd '' ___tmp <<< "$*";
    printf %s "$___tmp";
}
# To string with all variables substituted
to_absolute() {
    eval to_string "$*";
}
# To lowercase string
to_lowercase() {
    to_string $(echo "$*" | tr "[:upper:]" "[:lower:]");
}
# To uppercase string
to_uppercase() {
    to_string $(echo "$*" | tr "[:lower:]" "[:upper:]");
}

# Logging
unset MY_APP_NAME; MY_APP_NAME="PGPrefsDetectDefaultCmd.sh";
unset MY_APP_LOG;  MY_APP_LOG="PostgreSQL/Helpers.log";

DEBUG=$(to_lowercase "${DEBUG}");

log() {
    # Check for logging env variable
    if [ "${DEBUG}" == "yes" ]; then
        if [ $# -ge 1 ]; then
            if [ -e "${HOME}/Library/Logs" ]; then

                # Create log dir & file if not exist
                if [ ! -e "${HOME}/Library/Logs/$MY_APP_LOG" ]; then
                    su `stat -f "%Su" ${HOME}` -c "mkdir -p `dirname ${HOME}/Library/Logs/$MY_APP_LOG`";
                    su `stat -f "%Su" ${HOME}` -c "echo `date` >> ${HOME}/Library/Logs/$MY_APP_LOG";
                fi

                # Log
                dt=`date "+%F %H:%M:%S"`;
                echo "\n[$dt $MY_APP_NAME]\n$*" >> ${HOME}/Library/Logs/$MY_APP_LOG;
            fi
        fi
    fi
}
error() {
    if [ -n "$*" ]; then
        log $*;
        echo "$*";
    fi
    exit 1;
}
ok() {
    if [ -n "$*" ]; then
        log $*;
        echo "$*";
    fi
    exit 0;
}

#
# RESET
# -----
resetPGVariables() {
    unset my_pg_user;            my_pg_user="";
    unset my_pg_bin;             my_pg_bin="";
    unset my_pg_data;            my_pg_data="";
    unset my_pg_log;             my_pg_log="";
    unset my_pg_port;            my_pg_port="";
    unset my_pg_auto;            my_pg_auto="";

    unset my_pg_bin_abs;         my_pg_bin_abs="";
    unset my_pg_data_abs;        my_pg_data_abs="";
    unset my_pg_log_abs;         my_pg_log_abs="";
}
resetVariables() {
    resetPGVariables;
    unset my_pg_cellar;          my_pg_cellar="";
    unset my_pg_postgres_app;    my_pg_postgres_app="";
    unset my_pg_plist;           my_pg_plist="";
    unset my_pg_env_sh;          my_pg_env_sh="";
    unset my_pg_home_dir;        my_pg_home_dir="";
    unset my_pg_ctl;             my_pg_ctl="";
    unset my_pg_launchagents;    my_pg_launchagents="";
    unset my_pg_launchagent;     my_pg_launchagent="";
    unset my_pg_launchagent_dir; my_pg_launchagent="";

    unset my_force_exit;         my_force_exit="No";
    unset my_all_done;           my_pg_all_done="No";

    unset my_real_user;          my_real_user="";
    unset my_run_user;           my_run_user="";
}


#
# VALIDATE COMMAND LINE ARGS
# 
validateCommandLineArgs() {
    for ARG in "$@"; do
        opt=$(to_uppercase "${ARG%%=*}");
        val=$(to_string "${ARG#*=}");
        lval=$(to_lowercase "$val");
        larg=$(to_lowercase "$ARG");
        case "${opt}" in
            --DEBUG)     export DEBUG=${lval};;
        esac
    done
    log "${MY_APP_NAME} $*";
}

#
# VALIDATE ENV VARIABLES
# 
validateEnvVariables() {
    my_real_user=`stat -f "%Su" ${HOME}`;
    my_run_user=`id -u -n`;

    log "REALUSER=${my_real_user}"\
        "\nRUNUSER=${my_run_user}";
}

# Check if have everything we need
checkAllDone() {
    if [ "$my_force_exit" == "Yes" -o \( -n "$my_pg_bin" -a -n "$my_pg_data" \) ]; then
        my_all_done="Yes";
    else
        my_all_done="No";
    fi
}

# Check if PGBIN dir contains pg_ctl and postgres
checkPGBIN() {
    if [ -n "$my_pg_bin" ]; then
        my_pg_bin_abs=$(to_absolute "${my_pg_bin}")
        if [ ! \( -e "$my_pg_bin_abs/pg_ctl" -a -e "$my_pg_bin_abs/postgres" \) ]; then
            unset my_pg_bin; my_pg_bin="";
        fi
    fi
}

# Scan plist file for PG variables
scanPlistFile() {
    resetPGVariables;
    my_pg_plist=$1;
    if [ -z "$my_pg_user" ]; then
        my_pg_user=$(to_string `/usr/libexec/PlistBuddy ${my_pg_plist} -c print:UserName 2>/dev/null`);
    fi
    if [ -z "$my_pg_bin" ]; then
        my_pg_ctl=$(to_string `/usr/libexec/PlistBuddy ${my_pg_plist} -c print:Program 2>/dev/null`);
        if [ -n "$my_pg_ctl" ]; then
            my_pg_bin=`dirname $my_pg_ctl`;
            checkPGBIN
        fi
    fi
    if [ -z "$my_pg_data" ]; then
        my_pg_data=$(to_string `/usr/libexec/PlistBuddy ${my_pg_plist} -c print:ProgramArguments 2>/dev/null | perl -0n -e 'if (/^.*-D\s*([^\n]*).*$/sg) { print $1; }'`);
    fi
    if [ -z "$my_pg_log" ]; then
        my_pg_log=$(to_string `/usr/libexec/PlistBuddy ${my_pg_plist} -c print:StandardErrorPath 2>/dev/null`);
    fi
    if [ -z "$my_pg_bin" ]; then
        my_pg_ctl=$(to_string `/usr/libexec/PlistBuddy ${my_pg_plist} -c print:ProgramArguments 2>/dev/null | perl -0n -e 'if (/^.*Array \{\s*([^\n]*).*$/sg) { print $1; }'`);
        if [ -n "$my_pg_ctl" ]; then
            my_pg_bin=`dirname $my_pg_ctl`;
            checkPGBIN
        fi
    fi
    if [ -z "$my_pg_auto" ]; then
        my_pg_auto=$(to_string `/usr/libexec/PlistBuddy ${my_pg_plist} -c print:RunAtLoad 2>/dev/null`);
    fi
}

#
# RESULT
# ------
#
exitWithResult() {
    checkAllDone

    if [ "$my_all_done" == "Yes" ]; then
        ok "PGBIN=${my_pg_bin}"\
            "\nPGDATA=${my_pg_data}"\
            "\nPGUSER=${my_pg_user}"\
            "\nPGLOG=${my_pg_log}"\
            "\nPGPORT=${my_pg_port}"\
            "\nPGAUTO=${my_pg_auto}";
    fi
}

#
# 1. LAUNCH AGENT
# ---------------
#
detectLaunchAgentInDir() {
    if [ "$my_all_done" != "Yes" ]; then

        # Find all .plist files in dir with 'postgresql' in name
        my_pg_launchagent_dir=$1;
        my_pg_launchagents=`find ${my_pg_launchagent_dir} -name "*postgresql*" | grep \.plist$`;
        for my_pg_launchagent in ${my_pg_launchagents}; do

            # B) If found, deduce PGBIN, PGDATA, PGUSER, PGLOG from .plist file
            scanPlistFile "$my_pg_launchagent"
            checkAllDone
            if [ "$my_all_done" == "Yes" ]; then
                log "Using: $my_pg_launchagent";
                break
            fi

        done
    fi
}
detectLaunchAgent() {

    resetVariables;
    log "Detecting Launch Agents...";

    # A) Search /Library/LaunchDaemons, /Library/LaunchAgents & ~/Library/LaunchAgents for .plist file called *postgresql*
    detectLaunchAgentInDir "/Library/LaunchDaemons"
    detectLaunchAgentInDir "/Library/LaunchAgents"
    detectLaunchAgentInDir "$HOME/Library/LaunchAgents"
}

#
# 2. ENVIRONMENT
# --------------
#
detectUsingEnvironment() {

    resetVariables;

    # A) Get PGUSER, PGDATA, PGPORT from environment
    my_pg_user=$(to_string `env | grep PGUSER= | cut -d = -f 2`);
    my_pg_data=$(to_string `env | grep PGDATA= | cut -d = -f 2`);
    my_pg_port=$(to_string `env | grep PGPORT= | cut -d = -f 2`);
    my_pg_log=$(to_string `env | grep PGLOG= | cut -d = -f 2`);

    # B) Get pg_ctl from path - use its dir as PGBIN
    if [ -z "$my_pg_bin" ]; then
        if [ -z "$my_pg_ctl" ]; then
            my_pg_ctl=$(to_string `which pg_ctl`);
        fi
        if [ -n "$my_pg_ctl" ]; then
            my_pg_bin=$(to_string `dirname ${my_pg_ctl}`);
            checkPGBIN
        fi
    fi

}

#
# 3. HOMEBREW
# -----------
#
detectHomebrewInstall() {

    # Start with env variables - these will override everything else
    detectUsingEnvironment;
    log "Detecting Homebrew install..."

    # A) Search spotlight for Cellar directory
    my_pg_cellar=$(to_string `mdfind -name Cellar | grep /Cellar$ | head -1`);
    if [ -n "$my_pg_cellar" ]; then

        # B) If found, search for org.postgresql.postgres.plist below this.
        my_pg_plist=$(to_string `mdfind -name org.postgresql.postgres.plist -onlyin ${my_pg_cellar} | grep /org.postgresql.postgres.plist$ | head -1`);

        # C) If found, deduce PGBIN, PGDATA, PGUSER, PGLOG from .plist file
        if [ -n "$my_pg_plist" ]; then
            scanPlistFile $my_pg_plist
        fi
    fi

}

#
# 4. .DMG INSTALL
# ---------------
#
detectDmgInstall() {

    # Start with env variables - these will override everything else
    detectUsingEnvironment;
    log "Detecting Dmg install...";

    # A) Search spotlight for pg_env.sh
    my_pg_env_sh=$(to_string `mdfind -name pg_env.sh | grep /pg_env.sh$ | head -1`);

    # B) If found, execute this file. Hopefully now have PGUSER, PGDATA, PGPORT
    if [ -n "$my_pg_env_sh" ]; then

        if [ -z "$my_pg_user" ]; then
            my_pg_user=$(to_string `. $my_pg_env_sh; env | grep PGUSER= | cut -d = -f 2`);
        fi
        if [ -z "$my_pg_data" ]; then
            my_pg_data=$(to_string `. $my_pg_env_sh; env | grep PGDATA= | cut -d = -f 2`);
        fi
        if [ -z "$my_pg_port" ]; then
            my_pg_port=$(to_string `. $my_pg_env_sh; env | grep PGPORT= | cut -d = -f 2`);
        fi
        if [ -z "$my_pg_log" ]; then
            my_pg_log=$(to_string `. $my_pg_env_sh; env | grep PGLOG= | cut -d = -f 2`);
        fi

        # C) Set PGBIN to bin subdirectory relative to pg_env.sh file
        if [ -z "$my_pg_bin" ]; then
            my_pg_home_dir=$(to_string `dirname ${my_pg_env_sh}`);
            if [ -n "$my_pg_home_dir" ]; then
                my_pg_bin=`stat -f "%N" ${my_pg_home_dir}/bin 2>/dev/null`;
            fi
        fi

        # D) Assume no logging
    fi

}

#
# 5. POSTGRES.APP INSTALL
# -----------------------
#
detectPostgresAppInstall() {

    # Start with env variables - these will override everything else
    detectUsingEnvironment;
    log "Detecting Postgres.app install...";

    # A) Search spotlight for Postgres.app in /Applications
    my_pg_postgres_app=$(to_string `mdfind -onlyin /Applications Postgres.app | grep Postgres.app | head -1`);

    # B) If found, search for pg_ctl below this - if found, set PGBIN to parent dir.
    if [ -n "${my_pg_postgres_app}" ]; then
        my_pg_ctl=$(to_string `find "${my_pg_postgres_app}" -name "pg_ctl" | head -1`);

        if [ -n "${my_pg_ctl}" -a -e "${my_pg_ctl}" ]; then
            my_pg_bin=$(to_string `dirname "${my_pg_ctl}"`);
            checkPGBIN;
        fi

        # C) If com.postgresapp.Postgres.plist exists, deduce PGDATA.
        if [ -e "${HOME}/Library/Preferences/com.postgresapp.Postgres.plist" ]; then
            my_pg_data=$(to_string `/usr/libexec/PlistBuddy ${HOME}/Library/Preferences/com.postgresapp.Postgres.plist -c print:DataDirectory 2>/dev/null`);
        fi

        # D) Assume no logging
    fi
}

#
# 6. LAST RESORT!
# ---------------
#
detectLastResort() {

    # Start with env variables - these will override everything else
    detectUsingEnvironment;
    log "Detecting last resort...";

    # A) Search spotlight for pg_ctl - use its dir as PGBIN
    if [ -z "${my_pg_bin}" ]; then
        my_pg_ctl=$(to_string `mdfind -name pg_ctl | grep /pg_ctl$ | head -1`);
        if [ -n "$my_pg_ctl" ]; then
            my_pg_bin=$(to_string `dirname ${my_pg_ctl}`);
            checkPGBIN
        fi
    fi

    # B) If dir PGBIN/../data exists, then use this as PGDATA
    if [ -z "${my_pg_data}" -a -n "${my_pg_bin}" ]; then
        my_pg_data="${my_pg_bin}/../data";
        my_pg_data_abs=$(to_absolute "${my_pg_data}")
        if [ ! -e "${my_pg_data_abs}" ]; then
            unset my_pg_data; my_pg_data="";
            unset my_pg_data_abs; my_pg_data_abs="";
        fi
    fi

    # C) Set PGUSER to owner of PGDATA (if exists), otherwise use current user
    if [ -e "${my_pg_data}" ]; then
        my_pg_user=`stat -f %Su ${my_pg_data}`;
    elif [ -z "${my_pg_user}" ]; then
        my_pg_user=$my_real_user;
    fi

    # D) Leave PGPORT, PGLOG blank

}


#
# MAIN
#
resetVariables;
validateCommandLineArgs "$@";
validateEnvVariables;

detectLaunchAgent;
exitWithResult;
detectUsingEnvironment;
exitWithResult;
detectHomebrewInstall;
exitWithResult;
detectDmgInstall;
exitWithResult;
detectPostgresAppInstall;
exitWithResult;
detectLastResort;
my_force_exit="Yes";
exitWithResult;
