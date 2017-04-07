
# Description
Modification of check_log.sh monitoring-plugins script, to allow exceptions on patterns, plus a sticky time

# Motivation
Check_log script from the monitoring-plugins package does not handle exceptions on patterns.
It only searches for one pattern (-q query). 
I need the exit code other than OK to mantain same exit code for a fixed period of time, so Operators be aware of the problem enough time on alert console - IcingaWeb2, which is a state console, not an event console.

# Features
* More than one pattern can be defined which again can be classified as warning patterns and critical patterns.
* Exceptions - If a pattern matches, the matched line could be a very special case which should not be counted as an error. You can define exception patterns which are more specific versions of your critical/warning patterns. Such a match would then cancel an alert.
* Performance data - The number of lines scanned and the number of warnings/criticals is output.
* Triggered actions - The script return just an exit code and a line of text, describing the result of the check. But we want to have the same exit code for a period of time even if the scripts exits with OK.

# Examples
``` 
 icinga$ ./check_logsCC  -F /tmp/icinga2.log -O /tmp/temporalIcinga2log -q warning -e PerfdataWriter
 ``` 
 
