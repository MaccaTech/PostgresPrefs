#!/bin/sh
#
#  PGPrefsPostgreSQL.sh
#  PostgreSQL
#
#  Created by Francis McKenzie on 26/12/11.
#  Copyright (c) 2015 Macca Tech Ltd. All rights reserved.
#
# ==============================================================
#
# OVERVIEW:
# ---------
#
# Tool for simplifying administration of PostgreSQL database server.
#
# Available Commands:
#
#   Start        - Starts PostgreSQL using launchctl
#   Stop         - Stops PostgreSQL using launchctl
#   Create       - Creates launchd agent file (replaces existing)
#   Delete       - Deletes launchd agent file (stops server first)
#   Status       - Gets running status of PostgreSQL using launchctl
#   StatusManual - Gets running status of PostgreSQL using pg_ctl
#   StartManual  - Starts PostgreSQL using pg_ctl
#   StopManual   - Stops PostgreSQL using pg_ctl
#   Plist        - Generates plist file for use with launchctl
#
# USAGE:
# ------
#
# PGPrefsPostgreSQL.sh [--PGNAME=value] [--PGBIN=value] [--PGDATA=value]
#                      [--PGUSER=value] [--PGLOG=value] [--PGPORT=value]
#                      [--PGSTART=Login|Boot] [--DEBUG=Yes|No] Command
#
# Command - Start|Stop|Create|Delete|Status|StartManual|StopManual|Plist
#
# ENVIRONMENT VARIABLES:
# ----------------------
#
# Mandatory:
#
# PGNAME  - Name for server instance, e.g. "org.postgresql.Postgres Dev"
# PGBIN   - Directory containing pg_ctl executable
# PGDATA  - Picked up automatically by pg_ctl
#
# Optional:
#
# PGUSER  - Will su to this user if necessary  (Default: current user)
# PGLOG   - Server log file                    (Default: none)
# PGPORT  - Server port                        (Default: none)
# PGSTART - Startup server at boot/login       (Default: manual)
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
to_string()
{
    local return_code=$? # Pass-through nested return code
    local args
    read -rd '' args <<< "$*"
    printf "%s" "${args}"
    return "${return_code}"
}
# To string with all variables substituted
to_absolute()  { eval to_string "$*"; }
# To lowercase string
to_lowercase() { to_string $(echo "$*" | tr "[:upper:]" "[:lower:]"); }
# To uppercase string
to_uppercase() { to_string $(echo "$*" | tr "[:lower:]" "[:upper:]"); }
# Get user that owns file
file_owner()   { to_string `stat -f "%Su" "$*"`; }
# Check string is non-blank
non_blank()    { local val=$(to_string "$*") && [ -n "${val}" ] && printf "%s" "${val}" || return $?; }
# Check for substring
contains()     { [ -n "$1" ] && [ -n "$2" ] && [[ "$1" == *"$2"* ]] || return $?; }

# Print a message to debug log
debug()
{
    if [ "${DEBUG}" == "yes" ]; then
        local msg=$(to_string "$*")
        if [ -n "${msg}" ] && [ -n "${APP_LOG}" ]; then
            local file="${HOME}/Library/Logs/${APP_LOG}"
            local dir=`dirname "${file}" 2>/dev/null`
            if [ -d "${dir}" ]; then
                local timestamp=`date "+%F %H:%M:%S"`
                printf "
---------------------------------------------------------------------------------
[${timestamp} ${APP_NAME}]
---------------------------------------------------------------------------------

${msg}
" >> "${file}" 2>/dev/null
            fi
        fi
    fi
}
DEBUG=$(to_lowercase "${DEBUG}")

# Exit with $? and print message to stdout or stderr
finished()
{
    if [ $? -ne 0 ]; then
        fatal "$*"
    else
        if [ -n "$*" ]; then
            debug "$*\n\n[OK]"
            echo "$*"
        fi
        exit 0
    fi
}

# Print error message and exit 1
fatal()
{
    if [ -n "$*" ]; then
        debug "$*\n\n[FATAL]"
        >&2 echo "$*"
    fi
    exit 1
}

# Program error
program_error() { fatal "this tool has a bug, please install the latest version!"; }

# Execute shell command, debug results and abort on failure
do_cmd()
{
    local output
    local return_code

    debug "Running command...

$*";

    output=`set -e; eval { "$*;" } 2>&1`
    return_code=$?

    # Succeeded
    if [ "${return_code}" -eq 0 ]; then
        [ -n "${output}" ] && debug "${output}\n\n[OK]" || debug "[OK]"

    # Failed
    else
        [ -n "${output}" ] && debug "${output}\n\n[${return_code}]" || debug "[${return_code}]"
    fi

    # Trim result before printing
    to_string "${output}"
    return "${return_code}"
}

# Execute shell command as specified user, debug results and abort on failure
do_cmd_as_user()
{
    requireVars "app"

    local user=$(to_string "$1")
    shift

    local cmd="$*"
    if [ -n "${user}" ] && [ "${user}" != "${RUN_USER}" ]; then
        if [ "${user}" == "root" ]; then
            cmd="sudo ${cmd}"
        else
            cmd=${cmd//\"/\\\"};
            cmd="su ${user} -c \"${cmd}\""
        fi
    fi

    do_cmd "${cmd}"
}

# Initialize variables on-demand
requireVars()
{
    local name
    for name; do
        if ! contains "${___LOADED_VARIABLES___}" "[${name}]"; then
            initialiseVars "${name}";
            ___LOADED_VARIABLES___="${___LOADED_VARIABLES___}[${name}]"
        fi
    done
}
unset ___LOADED_VARIABLES___; ___LOADED_VARIABLES___=""


#
# ==============================================================
#
# Initialize variables
#
# ==============================================================
#
initialiseVars()
{
    case $1 in

    app)
        HOME_USER=$(non_blank $(file_owner "${HOME}")) || program_error
        HOME_USERID=$(non_blank `id -u "${HOME_USER}"`) || program_error
        RUN_USER=$(non_blank `id -u -n`) || program_error
        APP_NAME="PGPrefsPostgreSQL.sh"
        APP_LOG="PostgreSQL/org.postgresql.preferences.DEBUG-HELPER.log"
    ;;

    name)
        NAME=$(non_blank "${PGNAME}") || fatal "Name is required!"
    ;;

    startup)
        STARTUP=$(to_string "${PGSTART}")
    ;;

    user)
        requireVars "app" "startup"

        # Validate username
        USERNAME=$(to_string "${PGUSER}")
        if [ -n "${USERNAME}" ]; then
            id -u -n "${USERNAME}" >/dev/null 2>/dev/null || fatal "Username is invalid: ${USERNAME}"
            [ "${USERNAME}" != "root" ] || fatal "Cannot start PostgreSQL as root!"
        else
            USERNAME="${HOME_USER}"
        fi
    ;;

    pgctl)
        requireVars "app" "name"

        # PGBIN
        BIN_DIR=$(non_blank "${PGBIN}") || fatal "Bin Directory is required!"
        PGCTL=$(to_absolute "${BIN_DIR}/pg_ctl")
        POSTGRES="${BIN_DIR}/postgres"
        POSTGRES_ABS=$(to_absolute "${POSTGRES}")
        [ -f "${PGCTL}" ] && [ -f "${POSTGRES_ABS}" ] || fatal "Bin Directory is invalid: ${BIN_DIR}"

        # PGDATA
        DATA_DIR=$(non_blank "${PGDATA}") || fatal "Data Directory is required!"
        DATA_DIR_ABS=$(to_absolute "${DATA_DIR}")
        [ -d "${DATA_DIR_ABS}" ] || fatal "Data directory is invalid: ${DATA_DIR}"

        # PGLOG
        LOG=$(to_string "${PGLOG}")
        LOG_ABS=$(to_absolute "${LOG}")
        LOG_DIR_ABS=$(dirname "${LOG_ABS}")
        [ -z "${LOG}" ] || [ -d "${LOG_DIR_ABS}" ] || fatal "Log File is invalid: ${LOG}"

        requireVars "user" "startup"

        # PGPORT
        PORT=$(to_string "${PGPORT}")
    ;;

    agent)
        requireVars "app" "name" "startup"

        # Note: no check if user is valid. For now, user is either root or home user
        local unsafe_user=$(to_string "${PGUSER}")

        # Daemon
        if [ "${STARTUP}" == "boot" ] || ( [ -n "${unsafe_user}" ] && [ "${unsafe_user}" != "${HOME_USER}" ] ); then
            AGENT_USER="root"
            AGENT_DIR="/Library/LaunchDaemons"
            AGENT_LOG_DIR="/Library/Logs/PostgreSQL"

        # Agent
        else
            AGENT_USER="${HOME_USER}"
            AGENT_DIR="${HOME}/Library/LaunchAgents"
            AGENT_LOG_DIR="${HOME}/Library/Logs/PostgreSQL"
        fi
    ;;

    *) program_error;;

    esac
}


#
# ==============================================================
#
# Print Postgre Agent Plist file, to be used with launchctl
#
# ==============================================================
#
generatePostgreAgentPlistContent()
{
    requireVars "pgctl" "agent"

    local user_xml=""
    local port_xml=""
    local log_xml=""
    local runatload=""
    local disabled=""
    local result=""

    # Optional - PGUSER
    if [ -n "${USERNAME}" ] && [ "${USERNAME}" != "${AGENT_USER}" ]; then

        user_xml=$(cat <<EOF


  <key>UserName</key>
  <string>${USERNAME}</string>
EOF
        );
    fi

    # Optional - PGPORT
    if [ -n "${PORT}" ]; then

        port_xml=$(cat <<EOF

    <string>-p</string>
    <string>${PORT}</string>
EOF
        );
    fi

    # Optional - PGLOG
    if [ -n "${LOG}" ]; then

        log_xml=$(cat <<EOF

    <string>-r</string>
    <string>${LOG_ABS}</string>
EOF
        );
    fi

    # Optional - PGSTART
    if [ "${STARTUP}" == "boot" ] || [ "${STARTUP}" == "login" ]; then
        runatload="true"
        disabled="false"
    else
        runatload="false"
        disabled="true"
    fi

    # Generate Plist
    result=$(cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${NAME}</string>${user_xml}

  <key>ProgramArguments</key>
  <array>
    <string>${POSTGRES}</string>
    <string>-D</string>
    <string>${DATA_DIR_ABS}</string>${port_xml}${log_xml}
  </array>

  <key>WorkingDirectory</key>
  <string>${DATA_DIR_ABS}</string>

  <key>StandardOutPath</key>
  <string>${AGENT_LOG_DIR}/${NAME}.log</string>

  <key>StandardErrorPath</key>
  <string>${AGENT_LOG_DIR}/${NAME}.log</string>

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

    echo "${result}"
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
pgCtl()
{
    requireVars "pgctl"

    local action=$(to_lowercase "$1")
    local cmd=""
    local result

    # PGDATA environment variable
    cmd="${cmd}export PGDATA=\"${DATA_DIR_ABS}\"; "
    # PGPORT environment variable
    [ -n "${PORT}" ] && cmd="${cmd}export PGPORT=\"${PORT}\"; "
    # PGCTL executable
    cmd="${cmd}\"${PGCTL}\" "
    # PGLOG arg
    [ -n "${LOG}" ] && cmd="${cmd}-l \"${LOG_ABS}\" "
    # ACTION arg
    cmd="${cmd}-m fast ${action}";

    # For start and stop, we don't want the start/stop process hanging around for ages.
    # So we get rid of STDOUT to stop it hanging.
    if [ "${action}" == "start" ] || [ "${action}" == "stop" ]; then
        cmd="${cmd} >/dev/null";
    fi

    # Execute
    result=$(do_cmd_as_user "${USERNAME}" "${cmd}");
    finished "${result}";
}


#
# ==============================================================
#
# Load agent plist file in launchctl
#
# @params [agent_name] [agent_plist_dir] [agent_user]
#
# ==============================================================
#
launchctlLoadAgentWithNameAndDirForUser()
{
    local name
    local dir
    local user
    local path
    local check
    local update
    local result
    local succeeded

    name=$(non_blank "$1") || program_error
    dir=$(non_blank "$2") || program_error
    user=$(non_blank "$3") || program_error
    path="${dir}/${name}.plist"

    debug "Loading launchagent [${name}] with path ${path} ..."

    [ -f "${path}" ] || fatal "File not found: ${path}"

    # Prepare cmds
    check="launchctl list \"${name}\""
    update="launchctl load -F \"${path}\""

    # Ensure not already loaded
    result=$(do_cmd_as_user "${user}" "${check}") && fatal "Already loaded in launchd: ${name}"

    # Load
    result=$(do_cmd_as_user "${user}" "${update}") || fatal "Unable to load launchd agent ${name} - ${result}"

    # Wait until fully loaded - max 5 seconds
    for i in {0..25}
    do
        result=$(do_cmd_as_user "${user}" "${check}")

        if [ $? -eq 0 ] && [ -n "${result}" ]; then
            succeeded="yes"
            break
        fi
        sleep 0.2 # Sleep 200ms
    done

    # Ensure fully loaded
    [ "${succeeded}" == "yes" ] || fatal "Unable to load launchd agent: ${name}"
}


#
# ==============================================================
#
# Unload agent plist file from launchctl
#
# @params [agent_name] [user]
#
# ==============================================================
#
launchctlUnloadAgentWithNameForUser()
{
    local name
    local user
    local check
    local update
    local result
    local succeeded

    name=$(non_blank "$1") || program_error
    user=$(non_blank "$2") || program_error

    # Prepare cmds
    check="launchctl list \"${name}\""
    update="launchctl remove \"${name}\""

    # Check if loaded
    result=$(do_cmd_as_user "${user}" "${check}")
    if [ $? -eq 0 ]; then

        debug "Unloading launchagent ${name} ..."

        # Unload
        result=$(do_cmd_as_user "${user}" "${update}") || fatal "Unable to unload launchd agent ${name} - ${result}"

        # Wait until fully unloaded - max 5 seconds
        for i in {0..25}
        do
            result=$(do_cmd_as_user "${user}" "${check}")

            if [ $? -ne 0 ]; then
                succeeded="yes"
                break
            fi
            sleep 0.2 # Sleep 200ms
        done

        # Ensure succeeded
        if [ "${succeeded}" != "yes" ]; then
            debug "Loaded agent: ${result}"
            fatal "Unable to unload launchd agent ${name}"
        fi
    fi
}


#
# ==============================================================
#
# Unload agent plist file from launchctl for current user
# and root
#
# @params [agent_name]
#
# ==============================================================
#
launchctlUnloadAgentWithNameForAllUsers()
{
    requireVars "app"

    local name="$1"

    launchctlUnloadAgentWithNameForUser "${name}" "${HOME_USER}"
    launchctlUnloadAgentWithNameForUser "${name}" "root"
}


#
# ==============================================================
#
# Runs launchctl list for my postgre agent
#
# ==============================================================
#
launchctlListPostgreAgent()
{
    requireVars "app" "name" "agent"

    local result

    result=$(do_cmd_as_user "${AGENT_USER}" "launchctl list \"${NAME}\"")
    finished "${result}"
}


#
# ==============================================================
#
# Delete launchctl agent plist file with specified name in
# specified dir, if exists
#
# @params [dir] [agent_name]
#
# ==============================================================
#
deleteAgentPlistFileInDirWithName()
{
    local dir
    local dir_owner
    local name
    local name_length
    local check
    local update
    local result

    # Ensure dir exists - silently ignore if not
    dir=$(non_blank "$1") || program_error
    if [ -d "${dir}" ]; then

        # Illegal name
        name=$(non_blank "$2") || program_error
        contains "${name}" "*" && program_error
        name_length=$(( `echo ${name} | wc -c` - 1 ))
        [ "${name_length}" -lt 10 ] && program_error

        # Prepare cmds
        check="find \"${dir}\" -maxdepth 1 -type f -name \"${name}*.plist\" 2>/dev/null"
        update="find \"${dir}\" -maxdepth 1 -type f -name \"${name}*.plist\" -exec rm {} \; 2>/dev/null"

        # Check if files to delete
        result=$(do_cmd "${check}")
        if [ -n "${result}" ]; then

            debug "Deleting postgresql agent plist file(s)...\n\n${result}"

            # Delete
            dir_owner=$(file_owner "${dir}")
            do_cmd_as_user "${dir_owner}" "${update}"

            # Check succeeded
            result=$(do_cmd "${check}")
            if [ -n "${result}" ]; then
                result=(${result}) # Convert to array
                debug "Delete failed:\n\n${result}";
                fatal "ERROR: unable to delete ${result[0]}";
            fi
        fi
    fi
}


#
# ==============================================================
#
# Delete any launchctl agent plist files that exist with
# specified name
#
# @params [agent_name]
#
# ==============================================================
#
deleteAgentPlistFileInAllDirsWithName()
{
    local name
    name=$(non_blank "$1") || program_error

    deleteAgentPlistFileInDirWithName "/Library/LaunchDaemons" "${name}"
    deleteAgentPlistFileInDirWithName "/Library/LaunchAgents" "${name}"
    deleteAgentPlistFileInDirWithName "${HOME}/Library/LaunchAgents" "${name}"
}


#
# ==============================================================
#
# Ensures agent's STDOUT/STDERR logfile exists with correct
# permissions
#
# ==============================================================
#
createLogWithNameAndDirAndDirOwnerForUser()
{
    local name
    local dir
    local dir_owner
    local user
    local log
    local log_owner
    local result

    name=$(non_blank "$1") || program_error
    dir=$(non_blank "$2") || program_error
    dir_owner=$(non_blank "$3") || program_error
    user=$(non_blank "$4") || program_error
    log="${dir}/${name}.log"

    # Ensure dir exists
    if [ ! \( -d "${dir}" \) ]; then
        # Make the dir
        result=$(do_cmd_as_user "${dir_owner}" "mkdir -p \"${dir}\" 2>/dev/null")

        # Check succeeded
        [ -d "${dir}" ] || fatal "unable to create dir ${dir}"
    fi

    # Ensure file exists
    if [ ! \( -f "${log}" \) ]; then
        # Make the file
        result=$(do_cmd_as_user "${dir_owner}" "echo > \"${log}\" 2>/dev/null")

        # Check succeeded
        [ -f "${log}" ] || fatal "unable to create file ${log}"
    fi

    # Ensure file owner is correct
    log_owner=$(file_owner "${log}")
    if [ "${log_owner}" != "${user}" ]; then
        # Change owner
        result=$(do_cmd_as_user "root" "chown ${user} \"${log}\"")

        # Check succeeded
        log_owner=$(file_owner "${log}")
        [ "${log_owner}" == "${user}" ] || fatal "unable to make ${user} owner of ${log}"
    fi
}


#
# ==============================================================
#
# Unload launchd agent for PostgreSQL
#
# ==============================================================
#
unloadPostgreAgent()
{
    requireVars "name"

    launchctlUnloadAgentWithNameForAllUsers "${NAME}"
}


#
# ==============================================================
#
# Load launchd agent for PostgreSQL
#
# ==============================================================
#
loadPostgreAgent()
{
    requireVars "agent" "user"

    createLogWithNameAndDirAndDirOwnerForUser "${NAME}" "${AGENT_LOG_DIR}" "${AGENT_USER}" "${USERNAME}"
    launchctlLoadAgentWithNameAndDirForUser "${NAME}" "${AGENT_DIR}" "${AGENT_USER}"
}


#
# ==============================================================
#
# Delete launchd agent plist file for PostgreSQL
#
# ==============================================================
#
deletePostgreAgent()
{
    requireVars "name"

    deleteAgentPlistFileInAllDirsWithName "${NAME}"
}


#
# ==============================================================
#
# Save launchd agent plist file for PostgreSQL
#
# ==============================================================
#
createPostgreAgent()
{
    requireVars "agent"

    local plist="${AGENT_DIR}/${NAME}.plist"

    debug "Creating launchagent ${plist} ..."

    # Must not already exist
    [ -f "${plist}" ] && fatal "Launch agent already exists: ${plist}"

    # Create
    xml=$(generatePostgreAgentPlistContent) || fatal "${xml}"
    $(do_cmd_as_user "${AGENT_USER}" "echo \"${xml}\" > \"${plist}\"") || fatal "unable to create launch agent ${plist}"

    [ -f "${plist}" ] || fatal "unable to create launch agent ${plist}"
}


#
# ==============================================================
#
# Start PostgreSQL using launchctl
#
# ==============================================================
#
pgStart()
{
    unloadPostgreAgent
    deletePostgreAgent
    createPostgreAgent
    loadPostgreAgent
}


#
# ==============================================================
#
# Stop PostgreSQL using launchctl
#
# ==============================================================
#
pgStop()
{
    unloadPostgreAgent
}


#
# ==============================================================
#
# Creates agent .plist file
#
# ==============================================================
#
pgCreate()
{
    deletePostgreAgent
    createPostgreAgent
}


#
# ==============================================================
#
# Stops PostgreSQL using launchctl and deletes agent .plist file
#
# ==============================================================
#
pgDelete()
{
    unloadPostgreAgent
    deletePostgreAgent
}


#
# ==============================================================
#
# Get PostgreSQL status in launchd
#
# ==============================================================
#
pgStatus()
{
    launchctlListPostgreAgent
}


#
# ==============================================================
#
# Get PostgreSQL status using pg_ctl
#
# ==============================================================
#
pgStatusManual()
{
    pgCtl "status"
}


#
# ==============================================================
#
# Start PostgreSQL using pg_ctl
#
# ==============================================================
#
pgStartManual()
{
    pgCtl "start"
}


#
# ==============================================================
#
# Stop PostgreSQL using pg_ctl
#
# ==============================================================
#
pgStopManual()
{
    pgCtl "stop"
}


#
# ==============================================================
#
# Printout plist file to be used with launchctl
#
# ==============================================================
#
pgPlist()
{
    generatePostgreAgentPlistContent
}


#
# ==============================================================
#
# Log command line args
#
# ==============================================================
#
logCommand()
{
    requireVars "app"

    debug "${APP_NAME} $*

HOMEUSER | ${HOME_USER}
RUNUSER  | ${RUN_USER}
PGNAME   | ${PGNAME}
PGBIN    | ${PGBIN}
PGDATA   | ${PGDATA}
PGUSER   | ${PGUSER}
PGLOG    | ${PGLOG}
PGPORT   | ${PGPORT}
PGSTART  | ${PGSTART}"
}

#
# ==============================================================
#
# Main
#
# ==============================================================
#
main()
{
    # Parse command line
    local command=""
    local arg
    for arg; do
        local opt=$(to_uppercase "${arg%%=*}");
        local val=$(to_string "${arg#*=}");
        local lval=$(to_lowercase "$val");
        local larg=$(to_lowercase "$arg");
        case "${opt}" in
            --PGNAME)    PGNAME="${val}";;
            --PGBIN)     PGBIN="${val}";;
            --PGDATA)    PGDATA="${val}";;
            --PGUSER)    PGUSER="${val}";;
            --PGLOG)     PGLOG="${val}";;
            --PGPORT)    PGPORT="${val}";;
            --PGSTART)   PGSTART="${lval}";;
            --DEBUG)     DEBUG="${lval}";;
            *)           command="${larg}";;
        esac
    done

    # Log
    logCommand "$*"

    # Execute command
    case ${command} in
        start)        pgStart;;
        stop)         pgStop;;
        create)       pgCreate;;
        delete)       pgDelete;;
        status)       pgStatus;;
        statusmanual) pgStatusManual;;
        startmanual)  pgStartManual;;
        stopmanual)   pgStopManual;;
        plist)        pgPlist;;
        *)            fatal "Command not recognized!";;
    esac
}
main "$@"
