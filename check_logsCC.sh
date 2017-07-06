#!/bin/sh
# ./check_logsCC  -F /tmp/messages -O /tmp/temporalmessages -c criticalpattern -w warningpattern -ce criticalexception -we warningexception

SCRIPT_NAME=`basename $0`
PLUGING_PERF_DATA="0"
PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"
export PATH
SCRIPT_PATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
REVISION="0.3"

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

print_usage() {
    echo "Usage: $SCRIPT_NAME -F logfile -O oldlog -c CriticalPattern -ce Criticalexception -w WarningPattern -we WarningException"
    echo "Usage: $SCRIPT_NAME -h"
    echo "Usage: $SCRIPT_NAME -V"
}

print_help() {
    print_revision $SCRIPT_NAME $REVISION
    echo ""
    print_usage
    echo ""
    echo "Log file pattern detector plugin for monitoring that handles exceptions"
    echo ""
    support
}

# Make sure the correct number of command line
# arguments have been supplied
if [ $# -lt 3 ]; then
    print_usage
    exit $STATE_UNKNOWN
fi

# Grab the command line arguments
while test -n "$1"; do
    case "$1" in
        -h)
            print_help
            exit $STATE_OK
            ;;
        -V)
            print_revision $SCRIPT_NAME $REVISION
            exit $STATE_OK
            ;;
        -F)
            logfile=$2
            shift
            ;;
        -O)
            oldlog=$2
            shift
            ;;
        -c)
            critical=$2
            shift
            ;;
        -ce)
            critExcept=$2
            shift
            ;;
        -w)
            warning=$2
            shift
            ;;
        -we)
            warnExcept=$2
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            print_usage
            exit $STATE_UNKNOWN
            ;;
    esac
    shift
done


CheckIfSourceLogExists(){
if [ ! -e $logfile ]; then
    echo "Log check error: Log file $logfile does not exist!"
    exit $STATE_UNKNOWN
elif [ ! -r $logfile ] ; then
    echo "Log check error: Log file $logfile is not readable!"
    exit $STATE_UNKNOWN
fi
}

CheckIfOldLogExists(){
if [ ! -e $oldlog ]; then
    cat $logfile > $oldlog
    echo "Log check data initialized..."
    exit $STATE_OK
fi
}

CreateTempFiles(){
if [ -x /bin/mktemp ]; then
    tempdiff=`/bin/mktemp /tmp/check_log.XXXXXXXXXX`
else
    tempdiff=`/bin/date '+%H%M%S'`
    tempdiff="/tmp/check_log.${tempdiff}"
    touch $tempdiff
    chmod 600 $tempdiff
fi
diff $logfile $oldlog | grep -v "^>" > $tempdiff
CriticalAfterExcept=$tempdiff.NumberCritFound
WarningAfterExcept=$tempdiff.NumberWarnFound
tempCrit=${tempdiff}.Crit
tempWarn=${tempdiff}.Warn
touch $tempCrit
touch $tempWarn
touch $CriticalAfterExcept
touch $WarningAfterExcept
}

DeleteTmpFilesAndUpdOldLog(){
        cat $logfile > $oldlog
        rm -f "$tempdiff"
        rm -f "$tempCrit"
        rm -f "$tempWarn"
        rm -f "$CriticalAfterExcept"
        rm -f "$WarningAfterExcept"
}

CheckSeverity(){
count=`grep -c "$pattern" $tempdiff`
if [ $count -gt 0 ];then
    while read line
    do
        FoundLine=`echo "$line" | grep -c "$pattern"`
        if [ "$FoundLine" -eq 1 ];then
            echo "$line" >> $tempSeverity
        fi
    done < $tempdiff
fi
}

CheckException(){
for i in $(echo `seq 1 $count`)
do
        line=`sed -n ''"$i"'p' $tempSeverity`
        HasExcept=`echo "$line" | grep -c "${Except}" || true`
        if [ "$HasExcept" = 0 ];then
            echo "$line" >> $AfterExcept
        fi
done
}

ExitState(){
NumberLinesFound=`wc -l ${AfterExcept} | awk '{print $1}'`
EchoLines="$(cat "${AfterExcept}" )"
PLUGING_PERF_DATA="$NumberLinesFound"
if [ $NumberLinesFound -ne 0 ];then
    PLUGIN_OUTPUT_MSG="[$NumberLinesFound] lines match severity pattern after exceptions [$EchoLines]"
    echo "$PLUGIN_OUTPUT_MSG | $PLUGING_PERF_DATA" && exit $STATE_SEVERITY
fi
}

CheckIfSourceLogExists
CheckIfOldLogExists
CreateTempFiles
trap DeleteTmpFilesAndUpdOldLog EXIT

if [ ! -z "$critical" ]; then
        pattern=$critical
        tempSeverity=$tempCrit
        CheckSeverity
        if [ "$count" != 0 ]; then
                Except=$critExcept
                AfterExcept=$CriticalAfterExcept
                STATE_SEVERITY=$STATE_CRITICAL
                if [ -z "${critExcept}" ];then
                        cp $tempdiff $CriticalAfterException
                else
                        CheckException
                        ExitState
                fi
        fi
fi

if [ ! -z "$warning" ]; then
        pattern=$warning
        tempSeverity=$tempWarn
        CheckSeverity
        if [ "$count" != 0 ]; then
                Except=$warnExcept
                AfterExcept=$WarningAfterExcept
                STATE_SEVERITY=$STATE_WARNING
                if [ -z "${warnExcept}" ];then
                        cp $tempdiff $WarningAfterException
                else
                        CheckException
                fi
        else 
                exit $STATE_OK
        fi
fi

ExitState
