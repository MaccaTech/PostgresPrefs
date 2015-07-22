#!/bin/sh

#  PGPrefsPostgreSQL.sh
#  PostgreSQL
#
#  Created by Francis McKenzie on 26/12/11.
#  Copyright (c) 2011 HK Web Entrepreneurs. All rights reserved.
# ==============================================================
#
# OVERVIEW:
# ---------
#
# Tool for simplifying administration of PostgreSQL database server.
# Environment variables PGBIN and PGDATA must be set before calling this script
# (unless passed as args).
# 
# Available Commands:
#
#   Start       - Starts PostgreSQL using launchctl
#   Stop        - Stops PostgreSQL using launchctl
#   Status      - Gets running status of PostgreSQL
#   AutoOn      - Enables automatic startup of PostgreSQL on user login
#   AutoOff     - Disables automatic startup of PostgreSQL on user login
#   StartManual - Starts PostgreSQL using pg_ctl
#   StopManual  - Stops PostgreSQL using pg_ctl
#   Plist       - Generates plist file for use with launchctl
#
# USAGE:
# ------
#
# PGPrefsPostgreSQL.sh [--PGBIN=value] [--PGDATA=value] [--PGUSER=value] [--PGLOG=value]
#                      [--PGPORT=value] [--PGAUTO=YesOrNo] [--DEBUG=YesOrNo] Command
#
# Command - Start|Stop|Status|AutoOn|AutoOff|StartManual|StopManual|Plist
#
# ENVIRONMENT VARIABLES:
# ----------------------
#
# Mandatory:
#
# PGBIN   - Directory containing pg_ctl executable
# PGDATA  - Picked up automatically by pg_ctl
#
# Optional:
#
# PGUSER  - Will su to this user if necessary  (Default: current user)
# PGLOG   - Will be passed as arg to pg_ctl    (Default: none)
# PGPORT  - Picked up automatically by pg_ctl. (Default: 5432)
# PGAUTO  - Will be set in launchctl agent.    (Default: No)
#
# ==============================================================


#
# ==============================================================
#
# Utility functions
#
# ==============================================================
#

# To plain, trimmed string
to_string() {
    local return_code=$?; # Pass-through nested return code
    local args;
    read -rd '' args <<< "$*";
    printf "%s" "${args}";
    return "${return_code}";
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
# Get user that owns file
file_owner() {
    to_string `stat -f "%Su" "$*"`;
}
# Print a message to debug log
debug() {
    # Check for logging env variable
    if [ "${DEBUG}" == "yes" ]; then
        local msg=$(to_string "$*");
        if [ -n "${msg}" ]; then
            if [ -d "${HOME}/Library/Logs" ]; then

                # Create debug dir & file if not exist
                if [ ! -e "${HOME}/Library/Logs/${MY_APP_LOG}" ]; then
                    su "${MY_REAL_USER}" -c "mkdir -p `dirname ${HOME}/Library/Logs/${MY_APP_LOG}`";
                    su "${MY_REAL_USER}" -c "echo `date` >> ${HOME}/Library/Logs/${MY_APP_LOG}";
                fi

                # Log
                local datestring=`date "+%F %H:%M:%S"`;
                printf "
---------------------------------------------------------------------------------
[${datestring} ${MY_APP_NAME}]
---------------------------------------------------------------------------------

${msg}
" >> ${HOME}/Library/Logs/${MY_APP_LOG};
            fi
        fi
    fi
}
# Print success message and exit 0
finished() {
    if [ -n "$*" ]; then
        debug "$*\n\n[OK]";
        echo "$*";
    fi
    exit 0;
}
# Print error message and exit 1
fatal() {
    if [ -n "$*" ]; then
        debug "$*\n\n[FATAL]";
        >&2 echo "$*";
    fi
    exit 1;
}
# Execute shell command, debug results and abort on failure
do_cmd() {
    local output;
    local return_code;

    debug "Running command...

$*";

    output=`set -e; eval { "$*;" } 2>&1`;
    return_code=$?;

    # Succeeded
    if [ "${return_code}" -eq 0 ]; then
        debug "${output}\n\n[OK]";

    # Failed
    else
        debug "${output}\n\n[FAILED]";
    fi

    # Trim result before printing
    to_string "${output}";
    return "${return_code}";
}
# Execute shell command as specified user, debug results and abort on failure
do_cmd_as_user() {
    local user=$(to_string "$1");
    if [ -z "${user}" ]; then
        user="${MY_RUN_USER}";
    fi
    shift;

    local cmd="$*";
    if [ "${user}" == "root" ]; then
        cmd="sudo ${cmd}";
    elif [ "${user}" != "${MY_RUN_USER}" ]; then
        cmd=${cmd//\"/\\\"};
        cmd="su ${user} -c \"${cmd}\"";
    fi

    do_cmd "${cmd}";
}
# Program error
program_error() {
    fatal "this tool has a bug, please install the latest version!";
}
# Program error if missing variables
assert_not_null() {
    local name;
    local value;
    for name; do
        value=$(eval "echo \$$name");
        if [ -z "${value}" ]; then
            debug "Variable is missing: \${${name}}";
            program_error;
        fi
    done
}


#
# ==============================================================
#
# Initialise Constants
#
# ==============================================================
#
resetConstants() {
    unset MY_REAL_USER; MY_REAL_USER=$(file_owner "${HOME}");
    unset MY_REAL_UID;  MY_REAL_UID=`id -u "${MY_REAL_USER}"`;
    unset MY_RUN_USER;  MY_RUN_USER=`id -u -n`;
    unset MY_APP_NAME;  MY_APP_NAME="PGPrefsPostgreSQL.sh";
    unset MY_APP_LOG;   MY_APP_LOG="PostgreSQL/Helpers.log";
    unset MY_APP_ID;    MY_APP_ID="com.hkwebentrepreneurs.postgresql";

    DEBUG=$(to_lowercase "${DEBUG}");
}


#
# ==============================================================
#
# Initialise Global Variables
#
# ==============================================================
#
resetGlobals() {
    unset my_pg_command;         my_pg_command="";

    unset my_pg_bin;             my_pg_bin="";
    unset my_pg_ctl;             my_pg_ctl="";
    unset my_pg_postgres;        my_pg_postgres="";
    unset my_pg_data;            my_pg_data="";
    unset my_pg_user;            my_pg_user="";
    unset my_pg_log;             my_pg_log="";
    unset my_pg_port;            my_pg_port="";
    unset my_pg_auto;            my_pg_auto="no";

    unset my_pg_postgres_abs;    my_pg_postgres_abs="";
    unset my_pg_data_abs;        my_pg_data_abs="";
    unset my_pg_log_abs;         my_pg_log_abs="";
    unset my_pg_log_dir_abs;     my_pg_log_dir_abs="";

    unset my_pg_plist;           my_pg_plist="";
}


#
# ==============================================================
#
# Ensure command line args are correct, or else abort
#
# ==============================================================
#
validateCommandLineArgs() {
    local ARG;
    for ARG; do
        local opt=$(to_uppercase "${ARG%%=*}");
        local val=$(to_string "${ARG#*=}");
        local lval=$(to_lowercase "$val");
        local larg=$(to_lowercase "$ARG");
        case "${opt}" in
            --PGBIN)     export PGBIN=${val};;
            --PGDATA)    export PGDATA=${val};;
            --PGUSER)    export PGUSER=${val};;
            --PGLOG)     export PGLOG=${val};;
            --PGPORT)    export PGPORT=${val};;
            --PGAUTO)    export PGAUTO=${lval};;
            --DEBUG)     export DEBUG=${lval};;
            *)           my_pg_command=${larg};;
        esac
    done

    debug "Checking command line args...

${MY_APP_NAME} $*";

    if [ -z "${my_pg_command}" ]; then
        fatal "Required args: ${MY_APP_NAME} [Options] Command";
    fi
}


#
# ==============================================================
#
# Ensure have PGBIN and PGDATA (either from command line or
# environment variables.
#
# Also check that these are valid, or else abort.
#
# ==============================================================
#
validateEnvVariables() {
    local check_user;

    assert_not_null "MY_APP_ID";

    debug "Checking environment variables...

REALUSER | ${MY_REAL_USER}
RUNUSER  | ${MY_RUN_USER}
PGBIN    | ${PGBIN}
PGDATA   | ${PGDATA}
PGUSER   | ${PGUSER}
PGLOG    | ${PGLOG}
PGPORT   | ${PGPORT}
PGAUTO   | ${PGAUTO}";

    # Check PGBIN
    my_pg_bin=$(to_string "${PGBIN}");
    if [ -z "${my_pg_bin}" ]; then
        fatal "PGBIN is missing!";
    else
        my_pg_ctl=$(to_absolute "${my_pg_bin}/pg_ctl");
        my_pg_postgres="${my_pg_bin}/postgres";

        my_pg_postgres_abs=$(to_absolute "${my_pg_postgres}");

        if [ ! \( -f "${my_pg_ctl}" \) ] || [ ! \( -f "${my_pg_postgres_abs}" \) ]; then
            fatal "PGBIN is invalid - ${my_pg_bin}";
        fi
    fi

    # Check PGDATA
    my_pg_data=$(to_string "${PGDATA}");
    my_pg_data_abs=$(to_absolute "${my_pg_data}");
    if [ -z "${my_pg_data}" ]; then
        fatal "PGDATA is missing!";
    elif [ ! \( -d "${my_pg_data_abs}" \) ]; then
        fatal "PGDATA is invalid - ${my_pg_data}";
    fi

    # Check PGLOG
    my_pg_log=$(to_string "${PGLOG}");
    my_pg_log_abs=$(to_absolute "${my_pg_log}");
    my_pg_log_dir_abs=$(dirname "${my_pg_log_abs}");
    if [ -n "${my_pg_log}" ] && [ ! \( -d "${my_pg_log_dir_abs}" \) ]; then
        fatal "PGLOG is invalid - ${my_pg_log}";
    fi

    # Check PGUSER
    my_pg_user=$(to_string "${PGUSER}");
    if [ -n "${my_pg_user}" ]; then
        check_user=`id -u -n ${my_pg_user}`;
        if [ "${my_pg_user}" != "${check_user}" ]; then
            fatal "PGUSER is invalid - ${my_pg_user}";
        fi
    else
        my_pg_user="${MY_REAL_USER}";
    fi    

    # Optional variables
    my_pg_port=$(to_string "${PGPORT}");
    my_pg_auto=$(to_lowercase "${PGAUTO}");

    # Plist path
    # Check if pg_user is same as real user
    # If so, agent located in ~/Library/LaunchAgents
    if [ "${my_pg_user}" == "${MY_REAL_USER}" ]; then
        my_pg_plist="${HOME}/Library/LaunchAgents/${MY_APP_ID}.plist";

    # Otherwise in /Library/LaunchAgents
    else
        my_pg_plist="/Library/LaunchAgents/${MY_APP_ID}.plist";
    fi
}


#
# ==============================================================
#
# Print Postgre Agent Plist file, to be used with launchctl
#
# ==============================================================
#
generateMyPostgreAgentPlistContent() {
    local pg_port_xml;
    local pg_log_program_args_xml;
    local pg_log_stderr_xml;
    local runatload;
    local disabled;
    local result;

    assert_not_null "my_pg_data_abs" "my_pg_postgres" "my_pg_user" "MY_APP_ID";

    # Optional - PGPORT
    pg_port_xml="";
    if [ -n "${my_pg_port}" ]; then

        pg_port_xml=$(cat <<EOF

    <key>PGPORT</key>
    <string>${my_pg_port}</string>
EOF
        );

    fi

    # Optional - PGLOG
    pg_log_program_args_xml="";
    pg_log_stderr_xml="";
    if [ -n "${my_pg_log}" ]; then

        pg_log_program_args_xml=$(cat <<EOF

    <string>-r</string>
    <string>${my_pg_log_abs}</string>
EOF
        );

        pg_log_stderr_xml=$(cat <<EOF

  <key>StandardErrorPath</key>
  <string>${my_pg_log_abs}</string>
EOF
        );
    fi

    # Optional - PGAUTO
    [ "${my_pg_auto}" == "yes" ] && runatload="true" || runatload="false";
    [ "${my_pg_auto}" == "yes" ] && disabled="false" || disabled="true";

    # Generate Plist
    result=$(cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${MY_APP_ID}</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PGDATA</key>
    <string>${my_pg_data_abs}</string>${pg_port_xml}
  </dict>
  <key>ProgramArguments</key>
  <array>
    <string>${my_pg_postgres}</string>${pg_log_program_args_xml}
  </array>
  <key>UserName</key>
  <string>${my_pg_user}</string>
  <key>WorkingDirectory</key>
  <string>${my_pg_data_abs}</string>${pg_log_stderr_xml}
  <key>Disabled</key>
  <${disabled}/>
  <key>RunAtLoad</key>
  <${runatload}/>
  <key>KeepAlive</key>
  <true/>
</dict>
</plist>
EOF
    );

    echo "${result}";
}


#
# ==============================================================
#
# Execute pg_ctl command using pre-prepared global variables
# and appending specified action parameter
#
# @params [start/stop/status]
#
# ==============================================================
#
pgCtl() {
    local action;
    local cmd;
    local output;
    local return_code;

    action=$(to_string "$1");
    cmd="";

    # PGDATA required
    cmd="${cmd}export PGDATA=\"${my_pg_data_abs}\"; ";

    # PGPORT optional
    if [ -n "${my_pg_port}" ]; then
        cmd="${cmd}export PGPORT=\"${my_pg_port}\"; ";
    fi

    # pg_ctl executable
    cmd="${cmd}\"${my_pg_ctl}\" ";

    # PGLOG optional
    if [ -n "${my_pg_log}" ]; then
        cmd="${cmd}-l \"${my_pg_log_abs}\" ";
    fi

    # Action param
    cmd="${cmd}-m fast ${action}";

    # For start and stop, we don't want the start/stop process hanging around for ages.
    # So we get rid of STDOUT to stop it hanging.
    if [ "${action}" == "start" ] || [ "${action}" == "stop" ]; then
        cmd="${cmd} >/dev/null";
    fi

    # Execute
    result=$(do_cmd_as_user "${my_pg_user}" "${cmd}");
    return_code=$?;

    echo "${result}";
    return "${return_code}";
}


#
# ==============================================================
#
# Enable or disable auto-startup
#
# @params [yes/no]
#
# ==============================================================
#
pgAutoStartup() {
    [ "$1" == "yes" ] && my_pg_auto="yes" || my_pg_auto="no";

    disableAutoStartupForAllPostgreAgentPlistFiles;
    refreshAutoStartupForMyPostgreAgent;
}

#
# ==============================================================
#
# Unload all launchctl agents with 'postgresql' in name for
# specified user
#
# ==============================================================
#
launchctlUnloadAllPostgreAgentsFor() {
    local user;
    local launchagents;
    local launchagent;

    user=$(to_string "$1");

    debug "Unloading launchagents for ${user} ...";

    # Find all entries in launchctl with 'postgresql' in name
    launchagents=$(do_cmd_as_user "${user}" "launchctl list | grep postgresql | cut -f 3");

    # Must have some existing agents
    if [ -n "${launchagents}" ]; then

        # Unload each one
        for launchagent in ${launchagents}; do
            debug "Unloading launchagent: ${launchagent}...";

            $(do_cmd_as_user "${user}" "launchctl remove ${launchagent}") || fatal "ERROR: unable to unload launch agent ${launchagent}";
        done


        # Wait until fully unloaded - max 5 seconds
        for i in {0..50}
        do
            launchagents=$(do_cmd_as_user "${user}" "launchctl list | grep postgresql | cut -f 3");

            if [ -z "${launchagents}" ]; then
                launchagents="";
                break;
            fi
            sleep 0.1;
        done

        # Ensure fully unloaded
        if [ -n "${launchagents}" ]; then
            debug "Loaded agents: ${launchagents}";
            fatal "ERROR: unable to unload existing postgresql agents in launchd!";
        fi
    fi
}


#
# ==============================================================
#
# Unload all launchctl agents with 'postgresql' in name for
# root user and current user
#
# ==============================================================
#
launchctlUnloadAllPostgreAgents() {
    assert_not_null "MY_REAL_USER";

    launchctlUnloadAllPostgreAgentsFor "root";
    launchctlUnloadAllPostgreAgentsFor "${MY_REAL_USER}";
}


#
# ==============================================================
#
# Delete any of my launchctl agent plist files that exist
#
# ==============================================================
#
deleteMyPostgreAgentPlistFilesInDir() {
    local plist_dir;
    local plist_name;
    local plist_name_length;
    local plist_found_files;
    local plist_user;

    assert_not_null "MY_APP_ID";

    # Ensure dir exists - silently ignore if not
    plist_dir="$1";
    if [ -d "${plist_dir}" ]; then

        # Safety-check before any delete - ensure plist name is long enough
        plist_name=$(to_string "${MY_APP_ID}");
        plist_name=${plist_name//\*/}; # Safety - remove "*" characters from filename
        plist_name_length=$(( `echo ${plist_name} | wc -c` - 1 ));
        if [ "${plist_name_length}" -lt 10 ]; then
            debug "Plist name too short: '${plist_name}'";
            program_error;

        # Plist name has at least 10 characters, so we can be sure we're not going
        # to delete everything by accident
        else
            # Delete
            plist_found_files=`find ${plist_dir} -maxdepth 1 -name "${plist_name}*.plist"`;
            if [ -n "${plist_found_files}" ]; then

                debug "Deleting postgresql agent plist file(s)...\n\n${plist_found_files}";

                # May need to execute delete as a different user
                plist_user=$(file_owner "${plist_dir}");
                do_cmd_as_user "${plist_user}" "find ${plist_dir} -maxdepth 1 -name \"${plist_name}*.plist\" -exec rm {} \;";

                # Ensure deleted
                plist_found_files=`find ${plist_dir} -maxdepth 1 -name "${plist_name}*.plist"`;
                if [ -n "${plist_found_files}" ]; then
                    plist_found_files=(${plist_found_files}); # Convert to array
                    debug "Failed to delete postgresql agent plist file:\n\n${plist_found_files}";
                    fatal "ERROR: unable to delete ${plist_found_files[0]}";
                fi
            fi
        fi
    fi
}


#
# ==============================================================
#
# Delete any of my launchctl agent plist files that exist
#
# ==============================================================
#
deleteMyPostgreAgentPlistFiles() {
    deleteMyPostgreAgentPlistFilesInDir "/Library/LaunchDaemons";
    deleteMyPostgreAgentPlistFilesInDir "/Library/LaunchAgents";
    deleteMyPostgreAgentPlistFilesInDir "${HOME}/Library/LaunchAgents";
}


#
# ==============================================================
#
# Generate my launchctl agent plist, and save to appropriate
# directory
#
# ==============================================================
#
createMyPostgreAgentPlistFile() {
    local plist_xml;

    assert_not_null "my_pg_plist" "my_pg_user";

    debug "Creating ${my_pg_plist} ...";

    plist_xml=$(generateMyPostgreAgentPlistContent);
    $(do_cmd_as_user "${my_pg_user}" "echo \"${plist_xml}\" > \"${my_pg_plist}\"") || fatal "unable to create launch agent ${my_pg_plist}";

    [ -f "${my_pg_plist}" ] || fatal "unable to create launch agent ${my_pg_plist}";
}


#
# ==============================================================
#
# Load my agent plist file in launchctl.
#
# Note: plist must be generated beforehand.
#
# ==============================================================
#
launchctlLoadMyPostgreAgent() {
    local result;

    assert_not_null "my_pg_plist" "my_pg_user" "my_pg_auto" "MY_APP_ID";

    debug "Loading ${my_pg_plist} ...";

    # Load
    result=$(do_cmd_as_user "${my_pg_user}" "launchctl load -F ${my_pg_plist}") || fatal "${result}";

    # Wait until fully loaded - max 5 seconds
    for i in {0..50}
    do
        result=$(do_cmd_as_user "${my_pg_user}" "launchctl list | cut -f 3 | grep ^${MY_APP_ID}$");

        if [ $? -eq 0 ] && [ -n "${result}" ]; then
            break;
        fi
        sleep 0.1;
    done

    # Ensure fully loaded
    if [ "${result}" != "${MY_APP_ID}" ]; then
        fatal "Unable to load launchd agent!";
    fi
}


#
# ==============================================================
#
# Removes any entries for this tool in specified launchd
# overrides dir below /var/db, with specified plist name
# pattern.
#
# @params [overrides_dir] [plist_name_pattern]
#
# ==============================================================
#
launchctlDeleteDisabledOverrideForMyPostgreAgentInOverridesDir() {
    local dir;
    local name;
    local result;

    assert_not_null "MY_APP_ID";

    dir="/var/db/$1";
    name="$2.plist";

    # Overrides directory must exist - silently ignore if not
    if [ -d "${dir}" ]; then

        debug "Checking for launchd overrides for ${MY_APP_ID} in ${dir} ...";

        # Check if any overrides exist
        result=$(do_cmd_as_user "root" "find ${dir} -name \"${name}\" -exec /usr/libexec/Plistbuddy {} -c Print:${MY_APP_ID} \; 2>/dev/null | grep -v \"Error\"");
        if [ -n "${result}" ]; then

            debug "Removing launchd overrides for ${MY_APP_ID} in ${dir} ...";

            # Remove overrides
            $(do_cmd_as_user "root" "find ${dir} -name \"${name}\" -exec /usr/libexec/Plistbuddy {} -c Delete:${MY_APP_ID} \; 2>/dev/null | grep -v \"Error\"");

            # Check removed successfully
            result=$(do_cmd_as_user "root" "find ${dir} -name \"${name}\" -exec /usr/libexec/Plistbuddy {} -c Print:${MY_APP_ID} \; 2>/dev/null | grep -v \"Error\"");
            if [ -n "${result}" ]; then
                debug "Launchd overrides still exist after removing!\n\n${result}";
                fatal "Unable to remove launchd overrides for ${MY_APP_ID}";
            fi
        fi
    fi
}


#
# ==============================================================
#
# On Yosemite, once permanent disabled override is in place,
# impossible to remove. So always set it.
#
# ==============================================================
#
launchctlAddDisabledOverrideForMyPostgreAgentOnYosemite() {
    local result;
    local disabled;
    local enableOrDisable;

    assert_not_null "my_pg_plist" "my_pg_auto" "MY_REAL_UID";

    debug "Checking if launchctl supports enable/disable ...";

    # Check if launchctl supports enable/disable (i.e. on Yosemite)
    result=$(do_cmd_as_user "root" "launchctl print-disabled user/0");
    if [ $? -eq 0 ]; then

        # Calculate desired value
        [ "${my_pg_auto}" == "yes" ] && disabled="false" || disabled="true";
        [ "${my_pg_auto}" == "yes" ] && enableOrDisable="enable" || enableOrDisable="disable";

        debug "Checking if ${MY_APP_ID} is already ${enableOrDisable}d in launchd ...";

        # Check if need to change
        result=$(do_cmd_as_user "root" "launchctl print-disabled user/${MY_REAL_UID} | grep ${MY_APP_ID} | cut -d\  -f3");
        if [ "${result}" != "${disabled}" ]; then

            debug "Changing ${MY_APP_ID} to ${enableOrDisable}d in launchd ...";

            # Enable/disable
            $(do_cmd_as_user "root" "launchctl ${enableOrDisable} user/${MY_REAL_UID}/${MY_APP_ID}");

            # Check if need to change
            result=$(do_cmd_as_user "root" "launchctl print-disabled user/${MY_REAL_UID} | grep ${MY_APP_ID} | cut -d\  -f3");
            if [ "${result}" != "${disabled}" ]; then
                debug "After running ${enableOrDisable} command, launchd disabled override is ${result}";
                fatal "unable to ${enableOrDisable} ${MY_APP_ID} in launchd";
            fi
        fi
    fi
}


#
# ==============================================================
#
# Removes any entries for this tool in launchd overrides dirs
# underneath /var/db
#
# ==============================================================
#
refreshAutoStartupForMyPostgreAgent() {
    assert_not_null "my_pg_plist" "my_pg_auto";

    # Enable / disable the plist
    if [ -f "${my_pg_plist}" ]; then
        enableAutoStartupForPlistFile "${my_pg_plist}" "${my_pg_auto}";

    # Plist doesn't exist yet - so create it
    else
        createMyPostgreAgentPlistFile;
    fi

    # Handle permanent disabled override:

    # OS X 10.9 - remove the permanent override
    launchctlDeleteDisabledOverrideForMyPostgreAgentInOverridesDir "launchd.db" "overrides";

    # OS X 10.10 - set the permanent override, since removing is impossible
    launchctlAddDisabledOverrideForMyPostgreAgentOnYosemite;
}


#
# ==============================================================
#
# Set value in plist file
#
# @params [plist-file] [key] [type] [value]
#
# ==============================================================
#
setValueForKeyInPlistFile() {
    local plist_file;
    local plist_key;
    local plist_type;
    local plist_value;
    local plist_value_lc;
    local current_value;
    local current_value_lc;
    local current_value_return_code;
    local plist_buddy_user;
    local plist_buddy_cmd;

    plist_file=$(to_absolute $1);
    plist_key=$(to_string $2);
    plist_type=$(to_string $3);
    plist_value=$(to_string $4);
    plist_value_lc=$(to_lowercase "${plist_value}");

    # Invalid args
    if [ ! -f "${plist_file}" ] || [ -z "${plist_key}" ] || [ -z "${plist_type}" ] || [ -z "${plist_value}" ]; then
        fatal "ERROR: unable to set ${plist_key}=${plist_value} in ${plist_file}";

    # Args are valid
    else

        # Ensure needs changing
        current_value=`/usr/libexec/PlistBuddy ${plist_file} -c Print:${plist_key} 2>/dev/null`;
        current_value_return_code=$?; # Exit status is 1 if the key doesn't exist
        current_value_lc=$(to_lowercase "${current_value}");
        if [ "${current_value_return_code}" -eq 1 ] || [ "${current_value_lc}" != "${plist_value_lc}" ]; then

            # Detect plist file owner
            plist_buddy_user=$(file_owner "${plist_file}");

            # Key doesn't exist - use 'Add' command
            if [ ${current_value_return_code} -eq 1 ]; then
                plist_buddy_cmd="Add:${plist_key} ${plist_type} ${plist_value}";

            # Key exists - use 'Set' command
            else
                plist_buddy_cmd="Set:${plist_key} ${plist_value}";
            fi

            # Execute
            $(do_cmd_as_user "${plist_buddy_user}" "/usr/libexec/PlistBuddy ${plist_file} -c \"${plist_buddy_cmd}\"") || fatal "ERROR: unable to set ${plist_key}=${plist_value} in ${plist_file}";

            # Check succeeded
            current_value=`/usr/libexec/PlistBuddy ${plist_file} -c Print:${plist_key} 2>/dev/null`;
            current_value_return_code=$?; # Exit status is 0 if the key exists
            current_value_lc=$(to_lowercase "${current_value}");
            if [ "${current_value_return_code}" -eq 1 ] || [ "${current_value_lc}" != "${plist_value_lc}" ]; then
                fatal "ERROR: unable to set ${plist_key}=${plist_value} in ${plist_file}";
            fi
        fi
    fi
}


#
# ==============================================================
#
# Enable auto-startup for specified launchctl plist file.
#
# @params [plist] [yes=enable/no=disable]
#
# ==============================================================
#
enableAutoStartupForPlistFile() {
    local plist_file;
    local auto_startup;
    local runatload;
    local disabled;

    plist_file="$1";
    auto_startup=$(to_lowercase "$2");

    # Ensure plist exists - else abort
    [ -f "${plist_file}" ] || fatal "unable to set autostartup=${auto_startup}, file not found: ${plist_file}";

    # Calculate values
    [ "${auto_startup}" == "yes" ] && runatload="true" || runatload="false";
    [ "${auto_startup}" == "yes" ] && disabled="false" || disabled="true";

    # Update .plist file
    setValueForKeyInPlistFile "${plist_file}" "RunAtLoad" "bool" "${runatload}";
    setValueForKeyInPlistFile "${plist_file}" "Disabled" "bool" "${disabled}";
}


#
# ==============================================================
#
# In specified dir:
#
# Disable auto-startup for all launchctl plist files with
# 'postgresql' in name
#
# ==============================================================
#
disableAutoStartupForAllPostgreAgentPlistFilesInDir() {
    local plist_dir;
    local plist_files;
    local plist_file;

    # Ensure dir exists - silently ignore if not
    plist_dir=$1;
    if [ -d "${plist_dir}" ]; then

        # Find all .plist files in dir with 'postgresql' in name
        plist_files=`find ${plist_dir} -name "*postgresql*" | grep \.plist$`;

        # Disable autostartup for each .plist file
        for plist_file in ${plist_files}; do
            enableAutoStartupForPlistFile "${plist_file}" "no";
        done
    fi
}


#
# ==============================================================
#
# In all relevant launchagent dirs:
#
# Disable auto-startup for all launchctl plist files with
# 'postgresql' in name
#
# ==============================================================
#
disableAutoStartupForAllPostgreAgentPlistFiles() {
    disableAutoStartupForAllPostgreAgentPlistFilesInDir "/Library/LaunchDaemons";
    disableAutoStartupForAllPostgreAgentPlistFilesInDir "/Library/LaunchAgents";
    disableAutoStartupForAllPostgreAgentPlistFilesInDir "${HOME}/Library/LaunchAgents";
}


#
# ==============================================================
#
# Tries to detect running postgresql processes using 'ps', and
# grepping for specified keyword.
# 
# For each process returned, tries to deduce PGBIN, PGDATA
# and PGUSER so that it can stop the server cleanly.
#
# If PGBIN & PGDATA are valid, but it is not possible to stop
# the process cleanly, then it exits with an error.
#
# ==============================================================
#
detectAndManuallyStopRunningPostgreProcessesWithKeyword() {
    local keyword;
    local processes;
    local process;
    local process_pid;
    local process_ppid;
    local process_user;
    local process_cmd;
    local process_args;
    local process_dir;
    local pg_ctl;
    local output;

    keyword=$1;
    if [ -n "${keyword}" ]; then
        processes=`ps -eao pid,ppid,user,command | grep ${keyword} | grep -v grep`;

        # In order to loop line-by-line (instead of word-by-word) we have to use read.
        # But any exit call within the loop will only exit the loop, not the script.
        # So we have to check the exit status after the loop, and re-throw any errors.
        output=$(echo "${processes}" | while read process
        do
            process=$(to_string "${process}");
            if [ -n "${process}" ]; then
                # Log
                debug "Already Running: ${process}";

                # Extract process fields
                process_pid=`echo ${process} | awk '{ print $1 }'`;
                process_ppid=`echo ${process} | awk '{ print $2 }'`;
                process_user=`echo ${process} | awk '{ print $3 }'`;
                process_cmd=`echo ${process} | awk '{ print $4 }'`;
                process_args=`echo ${process} | awk '{ for (x=5; x<=NF; x++) {  printf "%s%s", $x, FS; } print ""; }'`;

                # Look for Postgres scripts in process directory
                process_dir=`dirname ${process_cmd}`;
                if [ -d "${process_dir}" ] && [ -f "${process_dir}/postgres" ] && [ -f "${process_dir}/pg_ctl" ]; then

                    pg_ctl="${process_dir}/pg_ctl";

                    # Just fail with error - don't try to stop.
                    fatal "Another PostgreSQL instance is already running!\nUser: ${process_user} PID: ${process_pid}";
                fi
            fi
        done);

        # Exited with error
        if [ $? -gt 0 ]; then
            fatal "${output}";
        fi
    fi
}


#
# ==============================================================
#
# Calls detectAndManuallyStopRunningPostgreProcesses with
# different keywords, e.g. 'postgres'.
#
# ==============================================================
#
detectAndManuallyStopRunningPostgreProcesses() {
    detectAndManuallyStopRunningPostgreProcessesWithKeyword "/postgres";
    detectAndManuallyStopRunningPostgreProcessesWithKeyword "/pg_ctl";
    detectAndManuallyStopRunningPostgreProcessesWithKeyword "/postmaster";
}


#
# ==============================================================
#
# Start PostgreSQL using launchctl
#
# ==============================================================
#
pgStart() {
    launchctlUnloadAllPostgreAgents;

    # Other postgresql instances may have been started manually
    detectAndManuallyStopRunningPostgreProcesses;

    deleteMyPostgreAgentPlistFiles;
    createMyPostgreAgentPlistFile;

    launchctlLoadMyPostgreAgent;
}


#
# ==============================================================
#
# Stop PostgreSQL using launchctl
#
# ==============================================================
#
pgStop() {
    launchctlUnloadAllPostgreAgents;
}


#
# ==============================================================
#
# Get PostgreSQL status
#
# ==============================================================
#
pgStatus() {
    pgCtl "status";
}


#
# ==============================================================
#
# Enable auto startup of PostgreSQL on user login
#
# ==============================================================
#
pgAutoOn() {
    pgAutoStartup "yes";
}


#
# ==============================================================
#
# Disable auto startup of PostgreSQL on user login
#
# ==============================================================
#
pgAutoOff() {
    pgAutoStartup "no";
}


#
# ==============================================================
#
# Start PostgreSQL using pg_ctl
#
# ==============================================================
#
pgStartManual() {
    pgCtl "start";
}


#
# ==============================================================
#
# Stop PostgreSQL using pg_ctl
#
# ==============================================================
#
pgStopManual() {
    pgCtl "stop";
}


#
# ==============================================================
#
# Printout plist file to be used with launchctl
#
# ==============================================================
#
pgPlist() {
    generateMyPostgreAgentPlistContent;
}


#
# ==============================================================
#
# Runs PostgreSQL command as specified on command line
#
# ==============================================================
#
runPostgreSQLCommand() {
    case ${my_pg_command} in
        start)       pgStart;;
        stop)        pgStop;;
        status)      pgStatus;;
        autoon)      pgAutoOn;;
        autooff)     pgAutoOff;;
        startmanual) pgStartManual;;
        stopmanual)  pgStopManual;;
        plist)       pgPlist;;
        *)           error "Unrecognised command: ${my_pg_command}";;
    esac
}


#
# ==============================================================
#
# Main
#
# ==============================================================
#
resetConstants;
resetGlobals;
validateCommandLineArgs "$@";
validateEnvVariables;

runPostgreSQLCommand;
