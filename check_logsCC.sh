#!/bin/sh
# ./check_logsCC  -F /tmp/icinga2.log -O /tmp/temporalIcinga2log -q warning -e PerfdataWriter
 
SCRIPT_NAME=`basename $0`
PLUGING_PERF_DATA="0"
PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"
export PATH
SCRIPT_PATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
REVISION="0.1"

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

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
if [ $# -lt 6 ]; then
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
        --critical)
            critical=$2
            shift
            ;;
        -c)
            critical=$2
            shift
            ;;
        --critExcept)
            critExcept=$2
            shift
            ;;
        -ce)
            critExcept=$2
            shift
            ;;
        --warning)
            warning=$2
            shift
            ;;
        -w)
            warning=$2
            shift
            ;;
        --warnExcept)
            warnExcept=$2
            shift
            ;;
        -we)
            warnExcept=$2
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


CheckCrit(){
countCrit=`grep -c "$critical" $tempdiff`
if [ $countCrit -gt 0 ];then
    while read line
    do
        IsCrit=`echo "$line" | grep -c "$critical"`
        if [ "$IsCrit" -eq 1 ];then
            echo "$line" >> $tempCrit
        fi
    done < $tempdiff
fi
}

CheckWarn(){
countWarn=`grep -c "$warning" $tempdiff`
if [ $countWarn -gt 0 ];then
    while read line
    do
        IsWarn=`echo "$line" | grep -c "$warning"`
        if [ "$IsWarn" -eq 1 ];then
            echo "$line" >> $tempWarn
        fi
    done < $tempdiff
fi
}


CheckExceptionsOnCritLogLines(){
for i in $(echo `seq 1 $countCrit`)
do
        line=`sed -n ''"$i"'p' $tempCrit`
        HasCExcept=`echo "$line" | grep -c "${critExcept}" || true`
        if [ "$HasCExcept" = 0 ];then
            echo "$line" >> $CriticalAfterExcept
        fi
done
}

CheckExceptionsOnWarnLogLines(){
for i in $(echo `seq 1 $countWarn`)
do
        line=`sed -n ''"$i"'p' $tempWarn`
        HasWExcept=`echo "$line" | grep -c "${warnExcept}" || true`
        if [ "$HasWExcept" = 0 ];then
            echo "$line" >> $WarningAfterExcept
        fi
done
}

ExitCritState(){
NumberCritFound=`wc -l ${CriticalAfterExcept} | awk '{print $1}'`
EchoCLines="$(cat "${CriticalAfterExcept}" )"
PLUGING_PERF_DATA="$NumberCritFound"
if [ $NumberCritFound -ne 0 ];then
    PLUGIN_OUTPUT_MSG="[$NumberCritFound] lines match critical pattern after exceptions [$EchoCLines]"
    echo "$PLUGIN_OUTPUT_MSG | $PLUGING_PERF_DATA" && exit $STATE_CRITICAL
fi
}

ExitWarnState(){
NumberWarnFound=`wc -l ${WarningAfterExcept} | awk '{print $1}'`
EchoWLines="$(cat "${WarningAfterExcept}" )"
PLUGING_PERF_DATA="$NumberWarnFound"
if [ $NumberWarnFound -ne 0 ];then
    PLUGIN_OUTPUT_MSG="[$NumberWarnFound] lines match warning pattern after exceptions [$EchoWLines]"
    echo "$PLUGIN_OUTPUT_MSG | $PLUGING_PERF_DATA" && exit $STATE_WARNING
fi
}


CheckIfSourceLogExists
CheckIfOldLogExists
trap DeleteTmpFilesAndUpdOldLog EXIT
CreateTempFiles
CheckCrit
CheckWarn
if [ "$countWarn" = 0 ] && [ "$countCrit" = 0 ];then
    echo "OK | $PLUGING_PERF_DATA" && exit $STATE_OK
else
    if [ -z "${critExcept}" ];then 
        cp $tempdiff $CriticalAfterException
    elif [ -z "${warnExcept}" ];then 
        cp $tempdiff $WarningAfterExcept
    else 
        CheckExceptionsOnCritLogLines
        CheckExceptionsOnWarnLogLines
    fi
fi

ExitCritState
ExitWarnState
