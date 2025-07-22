#!/bin/bash
# Simple timeout wrapper for macOS
# Usage: ./timeout_wrapper.sh <seconds> <command>

TIMEOUT=$1
shift
COMMAND="$@"

# Use perl to implement timeout
perl -e '
    eval {
        local $SIG{ALRM} = sub { die "timeout" };
        alarm shift;
        system(@ARGV);
        alarm 0;
    };
    if ($@) {
        if ($@ =~ /timeout/) {
            print "Command timed out after $TIMEOUT seconds\n";
            exit 124;
        } else {
            die $@;
        }
    }
' $TIMEOUT $COMMAND 