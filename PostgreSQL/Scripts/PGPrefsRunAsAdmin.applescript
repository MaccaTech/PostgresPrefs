#
#  PGPrefsRunAsAdmin.applescript
#  PostgreSQL
#
#  Created by Francis McKenzie on 24/12/11.
#  Copyright (c) 2011 HK Web Entrepreneurs. All rights reserved.
#
# ==============================================================
#
# OVERVIEW:
# ---------
#
# Executes all received arguments on the shell with admin privileges
#
# ==============================================================

on run argv
    
    # Join args into single string
    set prevDelimiter to AppleScript's text item delimiters
    set AppleScript's text item delimiters to " "
    set cmd to (argv as string) as string
    set AppleScript's text item delimiters to prevDelimiter

    # Run on shell, return result
    set result to "" as string
    try
        set result to do shell script cmd with administrator privileges without altering line endings
        
        # Return error
        on error errMsg
        set result to errMsg as string
    end try
    
    return result
end run