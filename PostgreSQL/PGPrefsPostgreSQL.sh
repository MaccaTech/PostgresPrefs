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
#   AutoOn      - Enables automatic startup of PostgreSQL on computer bootup
#   AutoOff     - Disables automatic startup of PostgreSQL on computer bootup
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


# Utility function
trim() { 
    unset ___tmp;
    read -rd '' ___tmp <<< "$*";
    printf %s "$___tmp";
}

# Logging
unset MY_APP_NAME; MY_APP_NAME="PGPrefsPostgreSQL.sh";
unset MY_APP_LOG;  MY_APP_LOG="PostgreSQL/Helpers.log";

DEBUG=`trim "${DEBUG}" | tr "[:upper:]" "[:lower:]"`;

log() {
    # Check for logging env variable
    if [ "${DEBUG}" == "yes" ]; then
        if [ $# -ge 1 ]; then
            if [ -e "${HOME}/Library/Logs" ]; then

                # Create log dir & file if not exist
                if [ ! -e "${HOME}/Library/Logs/${MY_APP_LOG}" ]; then
                    su `stat -f "%Su" ${HOME}` -c "mkdir -p `dirname ${HOME}/Library/Logs/${MY_APP_LOG}`";
                    su `stat -f "%Su" ${HOME}` -c "echo `date` >> ${HOME}/Library/Logs/${MY_APP_LOG}";
                fi

                # Log
                dt=`date "+%F %H:%M:%S"`;
                echo "\n[$dt ${MY_APP_NAME}]\n$*" >> ${HOME}/Library/Logs/${MY_APP_LOG};
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
# 
resetVariables() {
    unset my_pg_command;         my_pg_command="";
    unset my_pg_full_command;    my_pg_full_command="";
    unset my_pg_log_arg;         my_pg_log_arg="";
    unset my_pg_result;          my_pg_result="";

    unset my_pg_bin;             my_pg_bin="";
    unset my_pg_ctl;             my_pg_ctl="";
    unset my_pg_postgres;        my_pg_postgres="";
    unset my_pg_data;            my_pg_data="";
    unset my_pg_user;            my_pg_user="";
    unset my_pg_user_check;      my_pg_user_check="";
    unset my_pg_log;             my_pg_log="";
    unset my_pg_port;            my_pg_port="";
    unset my_pg_auto;            my_pg_auto="No";

    unset my_pg_plist;           my_pg_plist="com.hkwebentrepreneurs.postgresql";
    unset my_pg_plist_path;      my_pg_plist_path="";
    unset my_pg_plist_content;   my_pg_plist_content="";
    unset my_pg_log_partA;       my_pg_log_partA="";
    unset my_pg_log_partB;       my_pg_log_partB="";
    unset my_pg_port_part;       my_pg_port_part="";
    unset my_pg_auto_bool;       my_pg_port_auto_bool="";
    unset my_pg_ctl_arg;         my_pg_ctl_arg="";
    unset my_pg_ctl_command;     my_pg_ctl_command="";
    
    unset my_pg_launchctl_user;  my_pg_launchctl_user="";
    unset my_run_user;           my_run_user="";
    unset my_real_user;          my_real_user="";

    unset my_pg_process_keyword; my_pg_process_keyword="";
    unset my_pg_processes;       my_pg_processes="";
    unset my_pg_process;         my_pg_process="";
    unset my_pg_process_pid;     my_pg_process_pid="";
    unset my_pg_process_ppid;    my_pg_process_ppid="";
    unset my_pg_process_user;    my_pg_process_user="";
    unset my_pg_process_command; my_pg_process_command="";
    unset my_pg_process_args;    my_pg_process_args="";
    unset my_pg_process_bin;     my_pg_process_bin="";
    unset my_pg_process_pg_ctl;  my_pg_process_pg_ctl="";
}

#
# VALIDATE COMMAND LINE ARGS
# 
validateCommandLineArgs() {
    for ARG in $*; do
        opt=`echo ${ARG} | tr "[:lower:]" "[:upper:]" | cut -d= -f1`;
        val=`echo ${ARG} | cut -d= -f2`;
        lval=`echo ${val} | tr "[:upper:]" "[:lower:]"`;
        larg=`echo ${ARG} | tr "[:upper:]" "[:lower:]"`;
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
    log "${MY_APP_NAME} $*";
    if [ -z "${my_pg_command}" ]; then
        error "Required args: ${MY_APP_NAME} [Options] Command";
    fi
}

#
# VALIDATE ENV VARIABLES
# 
validateEnvVariables() {
    my_real_user=`stat -f "%Su" ${HOME}`;
    my_run_user=`id -u -n`;

    log "REALUSER=${my_real_user}"\
        "\nRUNUSER=${my_run_user}"\
        "\nPGBIN=${PGBIN}"\
        "\nPGDATA=${PGDATA}"\
        "\nPGUSER=${PGUSER}"\
        "\nPGLOG=${PGLOG}"\
        "\nPGPORT=${PGPORT}"\
        "\nPGAUTO=${PGAUTO}";

    my_pg_bin=$(trim "${PGBIN}");
    if [ -z "${my_pg_bin}" ]; then
        error "PGBIN is missing!";
    else
        my_pg_ctl="${my_pg_bin}/pg_ctl";
        my_pg_postgres="${my_pg_bin}/postgres";

        if [ ! \( -e "${my_pg_ctl}" \) -o ! \( -e "${my_pg_postgres}" \) ]; then
            error "PGBIN is invalid - ${my_pg_bin}";
        fi
    fi

    my_pg_data=$(trim "${PGDATA}");
    if [ -z "${my_pg_data}" ]; then
        error "PGDATA is missing!";
    elif [ ! \( -e "${my_pg_data}" \) ]; then
        error "PGDATA is invalid - ${my_pg_data}";
    fi

    my_pg_log=$(trim "${PGLOG}");
    if [ -n "${my_pg_log}" -a ! \( -e `dirname "${my_pg_log}"` \) ]; then
        error "PGLOG is invalid - ${my_pg_log}";
    fi

    my_pg_user=$(trim "${PGUSER}");
    if [ -n "${my_pg_user}" ]; then
        my_pg_user_check=`id -u -n ${my_pg_user}`;
        if [ "${my_pg_user}" != "${my_pg_user_check}" ]; then
            error "PGUSER is invalid - ${my_pg_user}";
        fi
    else
        my_pg_user="${my_real_user}";
    fi    

    my_pg_port=$(trim "${PGPORT}");

    my_pg_auto=`echo ${PGAUTO} | tr "[:upper:]" "[:lower:]"`;
}

#
# Generate Postgre Agent Plist file, to be used with launchctl
# 
generateMyPostgreAgentPlistContent() {

    # Optional - PGPORT
    if [ -n "${my_pg_port}" ]; then

        my_pg_port_part=$(cat <<EOF

    <key>PGPORT</key>
    <string>${my_pg_port}</string>
EOF
        );

    fi

    # Optional - PGLOG
    if [ -n "${my_pg_log}" ]; then

        my_pg_log_partA=$(cat <<EOF

    <string>-r</string>
    <string>${my_pg_log}</string>
EOF
        );

        my_pg_log_partB=$(cat <<EOF

  <key>StandardErrorPath</key>
  <string>${my_pg_log}</string>
EOF
        );
    fi

    # Optional - PGAUTO
    if [ "${my_pg_auto}" == "yes" ]; then
        my_pg_auto_bool="true";
    else
        my_pg_auto_bool="false";
    fi

    # Generate Plist
    my_pg_plist_content=$(cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${my_pg_plist}</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PGDATA</key>
    <string>${my_pg_data}</string>${my_pg_port_part}
  </dict>
  <key>ProgramArguments</key>
  <array>
    <string>${my_pg_postgres}</string>${my_pg_log_partA}
  </array>
  <key>UserName</key>
  <string>${my_pg_user}</string>
  <key>WorkingDirectory</key>
  <string>${my_pg_data}</string>${my_pg_log_partB}
  <key>RunAtLoad</key>
  <${my_pg_auto_bool}/>
  <key>KeepAlive</key>
  <true/>
</dict>
</plist>
EOF
    );
}

#
# Generate pg_ctl command, to which start/stop/status can be appended
# 
generatePgCtlCommand() {
    my_pg_ctl_arg=$1;

    my_pg_ctl_command="export PGDATA=\"${my_pg_data}\"; ";
    if [ -n "${my_pg_port}" ]; then
        my_pg_ctl_command="${my_pg_ctl_command}export PGPORT=${my_pg_port}; ";
    fi
    my_pg_ctl_command="${my_pg_ctl_command}${my_pg_ctl} ";
    if [ -n "${my_pg_log}" ]; then
        my_pg_ctl_command="${my_pg_ctl_command}-l ${my_pg_log} ";
    fi
    my_pg_ctl_command="${my_pg_ctl_command}-m fast ${my_pg_ctl_arg}";

    # For start and stop, we don't want the start/stop process hanging around for ages.
    # So we get rid of STDOUT to stop it hanging.
    if [ "${my_pg_ctl_arg}" == "start" -o "${my_pg_ctl_arg}" == "stop" ]; then
        my_pg_ctl_command="${my_pg_ctl_command} >/dev/null";
    fi

    if [ "${my_pg_user}" != "${my_run_user}" ]; then
        my_pg_ctl_command="su ${my_pg_user} -c '${my_pg_ctl_command}'";
    fi
    my_pg_ctl_command="${my_pg_ctl_command} 2>&1";

    log "${my_pg_ctl_command}";
}


#
# Unload all launchctl agents with 'postgresql' in name for specified user
#
launchctlUnloadAllPostgreAgentsFor() {
    my_pg_launchctl_user=$(trim "$1");

    # Find all entries in launchctl with 'postgresql' in name
    if [ "${my_pg_launchctl_user}" == "root" ]; then
        my_pg_launchagents=$(trim `sudo launchctl list | grep postgresql | cut -f 3`);
    elif [ "${my_pg_launchctl_user}" == "${my_run_user}" ]; then
        my_pg_launchagents=$(trim `launchctl list | grep postgresql | cut -f 3`);
    else
        my_pg_launchagents=$(trim `su ${my_pg_launchctl_user} -c "launchctl list | grep postgresql | cut -f 3"`);
    fi
    
    # Unload each one
    for my_pg_launchagent in ${my_pg_launchagents}; do
        log "Unloading launchagent: ${my_pg_launchagent}...";
        if [ "${my_pg_launchctl_user}" == "root" ]; then
            my_pg_result=`sudo launchctl remove ${my_pg_launchagent}`;
        elif [ "${my_pg_launchctl_user}" == "${my_run_user}" ]; then
            my_pg_result=`launchctl remove ${my_pg_launchagent}`;
        else
            my_pg_result=`su ${my_pg_launchctl_user} -c "launchctl remove ${my_pg_launchagent}"`;
        fi
        if [ -n "${my_pg_result}" ]; then
            error "ERROR: unable to unload ${my_pg_launchagent} from launchctl!\n${my_pg_result}";
        fi
    done


    # Wait until fully unloaded - max 5 seconds
    for i in {0..50}
    do
        if [ "${my_pg_launchctl_user}" == "root" ]; then
            my_pg_launchagents=$(trim `sudo launchctl list | grep postgresql | cut -f 3`);
        elif [ "${my_pg_launchctl_user}" == "${my_run_user}" ]; then
            my_pg_launchagents=$(trim `launchctl list | grep postgresql | cut -f 3`);
        else
            my_pg_launchagents=$(trim `su ${my_pg_launchctl_user} -c "launchctl list | grep postgresql | cut -f 3"`);
        fi
        if [ -z "${my_pg_launchagents}" ]; then
            my_pg_launchagents="";
            break;
        fi
        sleep 0.1;
    done

    # Ensure fully unloaded
    if [ -n "${my_pg_launchagents}" ]; then
        error "ERROR: unable to unload existing postgresql daemons from launchctl!\n${my_pg_launchagents}"
    fi
}

#
# Unload all launchctl agents with 'postgresql' in name
#
launchctlUnloadAllPostgreAgents() {
    launchctlUnloadAllPostgreAgentsFor "root";
    launchctlUnloadAllPostgreAgentsFor "${my_real_user}";
}

#
# Delete any of my launchctl agent plist files that exist
#
deleteMyPostgreAgentPlistFilesInDir() {
    # Ensure dir exists - silently ignore if not
    my_pg_launchagent_dir=$1;
    if [ -e "${my_pg_launchagent_dir}" ]; then

        # Safety check before any delete - ensure ${my_pg_plist} is long enough
        my_pg_plist_length=$(( `echo ${my_pg_plist} | wc -c` - 1 ));
        if [ ${my_pg_plist_length} -lt 10 ]; then
            error "Program error - this tool is corrupted, please reinstall it!\nAgent name too short: '${my_pg_plist}'";
        else
            # Delete
            my_pg_result=`find ${my_pg_launchagent_dir} -name "${my_pg_plist}.plist*"`;
            if [ -n "${my_pg_result}" ]; then
                log "Deleting postgresql agent plist file(s)\n${my_pg_result} ...";

                # Check if we need to sudo
                my_pg_launchctl_user=`stat -f %Su ${my_pg_launchagent_dir}`;
                if [ "${my_pg_launchctl_user}" != "${my_run_user}" ]; then
                    `find ${my_pg_launchagent_dir} -name "${my_pg_plist}.plist*" -exec sudo rm {} \;`;
                else
                    `find ${my_pg_launchagent_dir} -name "${my_pg_plist}.plist*" -exec rm {} \;`;
                fi
            fi

            # Ensure deleted
            my_pg_result=`find ${my_pg_launchagent_dir} -name "${my_pg_plist}.plist*"`;
            if [ -n "${my_pg_result}" ]; then
                error "ERROR: Unable to delete own .plist files!\n${my_pg_result}"
            fi
        fi
    fi
}

#
# Delete any of my launchctl agent plist files that exist
#
deleteMyPostgreAgentPlistFiles() {
    deleteMyPostgreAgentPlistFilesInDir "/Library/LaunchDaemons";
    deleteMyPostgreAgentPlistFilesInDir "/Library/LaunchAgents";
    deleteMyPostgreAgentPlistFilesInDir "${HOME}/Library/LaunchAgents";
}

#
# Generate my launchctl agent plist, and save to appropriate directory
#
createMyPostgreAgentPlistFile() {
    # Generate content
    generateMyPostgreAgentPlistContent;
    
    # Check if pg_user is same as real user
    # If so, save agent in ~/Library/LaunchAgents
    if [ "${my_pg_user}" == "${my_real_user}" ]; then
        my_pg_plist_path="${HOME}/Library/LaunchAgents/${my_pg_plist}.plist";
        log "Creating ${my_pg_plist_path} ...";

        # Switch to real user if req'd
        if [ "${my_real_user}" != "${my_run_user}" ]; then
            my_pg_result=$(trim `su ${my_real_user} -c "echo \"${my_pg_plist_content}\" > ${my_pg_plist_path}" 2>&1`);
        else
            my_pg_result=$(trim `{ echo "${my_pg_plist_content}" > "${my_pg_plist_path}"; } 2>&1`);
        fi


    # Otherwise in /Library/LaunchAgents
    else
        my_pg_plist_path="/Library/LaunchAgents/${my_pg_plist}.plist";
        log "Creating ${my_pg_plist_path} ...";
        my_pg_result=$(trim `{ sudo echo "${my_pg_plist_content}" > "${my_pg_plist_path}"; } 2>&1`);
    fi

    # Throw any error returned
    if [ -n "${my_pg_result}" ]; then
        error "${my_pg_result}";
    else
        log "${my_pg_plist_path}\n${my_pg_plist_content}";
    fi
}

#
# Load my agent plist file in launchctl. Note: plist must be generated beforehand.
#
launchctlLoadMyPostgreAgent() {
    # Load
    log "Loading ${my_pg_plist_path} ...";
    if [ "${my_pg_user}" != "${my_real_user}" ]; then
        my_pg_result=$(trim `sudo launchctl load -w ${my_pg_plist_path}`);
    elif [ "${my_real_user}" != "${my_run_user}" ]; then
        my_pg_result=$(trim `su ${my_real_user} -c "launchctl load -w ${my_pg_plist_path}"`);
    else
        my_pg_result=$(trim `launchctl load -w ${my_pg_plist_path}`);
    fi

    # Throw error if returned
    if [ -n "${my_pg_result}" ]; then
        error "${my_pg_result}";

    # Otherwise, ensure now loaded - may be some delay
    else

        # Wait until fully loaded - max 5 seconds
        for i in {0..50}
        do
            if [ "${my_pg_user}" != "${my_real_user}" ]; then
                my_pg_result=`sudo launchctl list | cut -f 3 | grep ^${my_pg_plist}$`;
            elif [ "${my_real_user}" != "${my_run_user}" ]; then
                my_pg_result=`su ${my_real_user} -c "launchctl list | cut -f 3 | grep ^${my_pg_plist}$"`;
            else
                my_pg_result=`launchctl list | cut -f 3 | grep ^${my_pg_plist}$`;
            fi
            if [ -n "${my_pg_result}" ]; then
                break;
            fi
            sleep 0.1;
        done

        # Ensure fully loaded
        if [ "${my_pg_result}" != "${my_pg_plist}" ]; then
            error "Unable to load launchctl agent!";
        fi
    fi
}

#
# Disable RunAtLoad setting in all launchctl plist files with 'postgresql' in name, in specified dir
# 
disableRunAtLoadInPostgreAgentPlistFilesInDir() {
    # Ensure dir exists - silently ignore if not
    my_pg_launchagent_dir=$1;
    if [ -e "${my_pg_launchagent_dir}" ]; then

        # Find all .plist files in dir with 'postgresql' in name
        my_pg_launchagents=`find ${my_pg_launchagent_dir} -name "*postgresql*" | grep \.plist$`;

        # Loop .plist files
        for my_pg_launchagent in ${my_pg_launchagents}; do

        # Check needs disabling
        my_pg_result=$(trim `/usr/libexec/PlistBuddy ${my_pg_launchagent} -c Print:RunAtLoad 2>&1`);
        if [ "${my_pg_result}" == "true" ]; then

            # Disable
            log "Disabling RunAtLoad: for ${my_pg_launchagent}...";
            if [ `stat -f %Su ${my_pg_launchagent}` != "${my_run_user}" ]; then
                my_pg_result=$(trim `sudo /usr/libexec/PlistBuddy ${my_pg_launchagent} -c "Set:RunAtLoad false" >/dev/null 2>&1`);
            else
                my_pg_result=$(trim `/usr/libexec/PlistBuddy ${my_pg_launchagent} -c "Set:RunAtLoad false" >/dev/null 2>&1`);
            fi

            # Throw any error
            if [ -n "${my_pg_result}" ]; then
                error "${my_pg_result}";

            # Otherwise, check succeeded
            else
                my_pg_result=`/usr/libexec/PlistBuddy ${my_pg_launchagent} -c Print:RunAtLoad`;
                if [ "${my_pg_result}" == "true" ]; then
                    error "ERROR: unable to disable ${my_pg_launchagent}"
                fi
            fi
        fi
        done
    fi
}

#
# Disable RunAtLoad setting in all launchctl plist files with 'postgresql' in name
# 
disableRunAtLoadInAllPostgreAgentPlistFiles() {
    disableRunAtLoadInPostgreAgentPlistFilesInDir "/Library/LaunchDaemons"
    disableRunAtLoadInPostgreAgentPlistFilesInDir "/Library/LaunchAgents"
    disableRunAtLoadInPostgreAgentPlistFilesInDir "${HOME}/Library/LaunchAgents"
}

#
# Tries to detect running postgresql processes using 'ps', and grepping for specified keyword.
# 
# For each process returned, tries to deduce PGBIN, PGDATA and PGUSER so that it can stop
# the server cleanly.
#
# If PGBIN & PGDATA are valid, but it is not possible to stop the process cleanly,
# then it exits with an error.
#
detectAndManuallyStopRunningPostgreProcessesWithKeyword() {
    my_pg_process_keyword=$1;
    if [ -n "${my_pg_process_keyword}" ]; then
        my_pg_processes=`ps -eao pid,ppid,user,command | grep ${my_pg_process_keyword} | grep -v grep`;

        # In order to loop line-by-line (instead of word-by-word) we have to use read.
        # But any exit call within the loop will only exit the loop, not the script.
        # So we have to check the exit status after the loop, and re-throw any errors.
        my_pg_result=$(echo "${my_pg_processes}" | while read my_pg_process
        do
            my_process=$(trim "${my_pg_process}");
            if [ -n "${my_pg_process}" ]; then
                # Log
                log "Already Running: ${my_pg_process}";

                # Extract process fields
                my_pg_process_pid=`echo ${my_pg_process} | awk '{ print $1 }'`;
                my_pg_process_ppid=`echo ${my_pg_process} | awk '{ print $2 }'`;
                my_pg_process_user=`echo ${my_pg_process} | awk '{ print $3 }'`;
                my_pg_process_command=`echo ${my_pg_process} | awk '{ print $4 }'`;
                my_pg_process_args=`echo ${my_pg_process} | awk '{ for (x=5; x<=NF; x++) {  printf "%s%s", $x, FS; } print ""; }'`;

                # Try to deduce PGBIN
                my_pg_process_bin=`dirname ${my_pg_process_command}`;
                if [ -e "${my_pg_process_bin}" -a -e "${my_pg_process_bin}/postgres" -a -e "${my_pg_process_bin}/pg_ctl" ]; then
                    my_pg_process_pg_ctl="${my_pg_process_bin}/pg_ctl";

                    # Just fail with error - don't try to stop.
                    error "Another PostgreSQL instance is already running!\nUser: ${my_pg_process_user} PID: ${my_pg_process_pid}";
                fi
            fi
        done);

        # Exited with error
        if [ $? -gt 0 ]; then
            error "${my_pg_result}";
        fi
    fi
}

#
# Calls detectAndManuallyStopRunningPostgreProcesses with different keywords, e.g. 'postgres'.
#
detectAndManuallyStopRunningPostgreProcesses() {
    detectAndManuallyStopRunningPostgreProcessesWithKeyword "/postgres";
    detectAndManuallyStopRunningPostgreProcessesWithKeyword "/pg_ctl";
    detectAndManuallyStopRunningPostgreProcessesWithKeyword "/postmaster";
}

#
# Start PostgreSQL using launchctl
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
# Stop PostgreSQL using launchctl
# 
pgStop() {
    launchctlUnloadAllPostgreAgents;
}

#
# Get PostgreSQL status
# 
pgStatus() {
    generatePgCtlCommand "status";
    my_pg_result=`eval ${my_pg_ctl_command}`;
    ok "${my_pg_result}";
}

#
# Enable auto startup of PostgreSQL on computer bootup
# NOTE: this will restart PostgreSQL
# 
pgAutoOn() {
    disableRunAtLoadInAllPostgreAgentPlistFiles;
    my_pg_auto="yes";
    pgStart;
}

#
# Disable auto startup of PostgreSQL on computer bootup
# 
pgAutoOff() {
    disableRunAtLoadInAllPostgreAgentPlistFiles;
}

#
# Start PostgreSQL using pg_ctl
# 
pgStartManual() {
    generatePgCtlCommand "start";
    my_pg_result=$(trim `eval ${my_pg_ctl_command}`);
    if [ -n "${my_pg_result}" ]; then
        error "${my_pg_result}";
    else
        ok;
    fi
}

#
# Stop PostgreSQL using pg_ctl
# 
pgStopManual() {
    generatePgCtlCommand "stop";
    my_pg_result=$(trim `eval ${my_pg_ctl_command}`);
    if [ -n "${my_pg_result}" ]; then
        error "${my_pg_result}";
    else
        ok;
    fi
}

#
# Printout plist file to be used with launchctl
# 
pgPlist() {
    generateMyPostgreAgentPlistContent;
    ok "${my_pg_plist_content}";
}

#
# RUN POSTGRESQL COMMAND
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
# MAIN
#
resetVariables
validateCommandLineArgs $*
validateEnvVariables

runPostgreSQLCommand
