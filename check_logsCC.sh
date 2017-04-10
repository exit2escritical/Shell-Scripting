#!/bin/sh

SCRIPT_NAME=`basename $0`
PLUGING_PERF_DATA="0"
PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"
export PATH
SCRIPT_PATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
REVISION="0.1"


. $SCRIPT_PATH/utils.sh

print_usage() {
    echo "Usage: $SCRIPT_NAME -F logfile -O oldlog -q query -e exception"
    echo "Usage: $SCRIPT_NAME --help"
    echo "Usage: $SCRIPT_NAME --version"
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
if [ $# -lt 1 ]; then
    print_usage
    exit $STATE_UNKNOWN
fi

# Grab the command line arguments
while test -n "$1"; do
    case "$1" in
        --help)
            print_help
            exit $STATE_OK
            ;;
        -h)
            print_help
            exit $STATE_OK
            ;;
        --version)
            print_revision $SCRIPT_NAME $REVISION
            exit $STATE_OK
            ;;
        -V)
            print_revision $SCRIPT_NAME $REVISION
            exit $STATE_OK
            ;;
        --filename)
            logfile=$2
            shift
            ;;
        -F)
            logfile=$2
            shift
            ;;
        --oldlog)
            oldlog=$2
            shift
            ;;
        -O)
            oldlog=$2
            shift
            ;;
        --query)
            query=$2
            shift
            ;;
        -q)
            query=$2
            shift
            ;;
        --except)
            except=$2
            shift
            ;;
        -e)
            except=$2
            shift
            ;;
        -x)
            exitstatus=$2
            shift
            ;;
        --exitstatus)
            exitstatus=$2
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

# If the source log file doesn't exist, exit
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
CriticalAfterSearchExc=$tempdiff.NumberCritFound
touch $CriticalAfterSearchExc
}

DeleteTmpFiles&UpdOldLog(){
        cat $logfile > $oldlog
        rm -f "$tempdiff"
        rm -f "$CriticalAfterSearchExc"
}


CheckCrit(){
count=`grep -c "$query" $tempdiff`
if [ "$count" = 0 ];then
    PLUGIN_OUTPUT_MSG="OK, no critical lines match pattern"
    echo "$PLUGIN_OUTPUT_MSG | $PLUGING_PERF_DATA" && exit $STATE_OK
fi
}

CheckExceptionsOnCritLogLines(){
for i in $(echo `seq 1 $count`)
do
        nextline1=`echo $(($i+1))`
        line=`sed -n ''"$nextline1"'p' $tempdiff`
        HasExcept=`echo "$line" | grep -c "$except"|| true`
        if [ "$HasExcept" = 0 ];then
            echo "$line" >> $CriticalAfterSearchExc
        fi
done
}


CheckExitState(){
NumberCritFound=`wc -l ${CriticalAfterSearchExc} | awk '{print $1}'`
EchoLines="$(cat "${CriticalAfterSearchExc}" )"
PLUGING_PERF_DATA="$NumberCritFound"
if [ $NumberCritFound -ne 0 ];then
    PLUGIN_OUTPUT_MSG="[$NumberCritFound] lines match critical pattern after exceptions [$EchoLines]"
    echo "$PLUGIN_OUTPUT_MSG | $PLUGING_PERF_DATA" && exit $STATE_CRITICAL
else echo "OK, no lines matching critical pattern | $PLUGING_PERF_DATA" && exit $STATE_OK
fi
}

CheckIfSourceLogExists
CheckIfOldLogExists
trap DeleteTmpFiles&UpdOldLog EXIT
CreateTempFiles
CheckCrit

CheckExceptionsOnCritLogLines
CheckExitState
