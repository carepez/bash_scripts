#!/bin/ksh
#set -x


BASE_DIR=`dirname $0`
BASE_DIR_ABS=`cd "${BASE_DIR}"; pwd -P`

JVM_TOP_OUTPUT_FILE="${BASE_DIR_ABS}/tmp/jvm_top_output_$$.tmp"
JVM_PIDSTAT_OUTPUT_FILE="${BASE_DIR_ABS}/tmp/jvm_pidstat_output_$$.tmp"
JSTAT_OUTPUT_FILE="${BASE_DIR_ABS}/tmp/jstat_output_$$.tmp"
JSTACK_THREAD_DUMP="${BASE_DIR_ABS}/tmp/jstack_thread_dump_$$.tmp"

typeset -A SNAPSHOT_ARRAY
AGENT_MESSAGE=""
AGENT_STATUS="OK"

datediff() {
    d1=$(date -d "$1 $2" +%s)
    d2=$(date -d "$3 $4" +%s)
    echo $(( (d1 - d2) ))
}

initializeArray() {
   appendToArray "AGENT_DURATION" "nil"
   appendToArray "AGENT_MESSAGE" "nil"
   appendToArray "AGENT_STATUS" "nil"
   appendToArray "APPLICATION_NAME" "nil"
   appendToArray "APPLICATION_SERVER_HOSTNAME" "nil"
   appendToArray "JVM_CONNECTIONS_ESTABLISHED" "nil"
   appendToArray "JVM_FGC_AVG_DURATION" "nil"
   appendToArray "JVM_FGC_FREQUENCY" "nil"
   appendToArray "JVM_FGC_TOTAL" "nil"
   appendToArray "JVM_FGC_TOTAL_DURATION" "nil"
   appendToArray "JVM_HEAP_MAX" "nil"
   appendToArray "JVM_HEAP_USED" "nil"
   appendToArray "JVM_HEAP_USED_PERC" "nil"
   appendToArray "JVM_IO_RDS" "nil"
   appendToArray "JVM_IO_WRS" "nil"
   appendToArray "JVM_JAVA_BIN" "nil"
   appendToArray "JVM_JAVA_VERSION" "nil"
   appendToArray "JVM_PID" "nil"
   appendToArray "JVM_PROCESS_CPU_USED" "nil"
   appendToArray "JVM_PROCESS_ELAPSED_TIME" "nil"
   appendToArray "JVM_PROCESS_LAST_STARTUP" "nil"
   appendToArray "JVM_PROCESS_MEMORY_USED" "nil"
   appendToArray "JVM_PROCESS_STATUS" "nil"
   appendToArray "JVM_THREADS_BLOCKED" "nil"
   appendToArray "JVM_THREADS_RUNNABLE" "nil"
   appendToArray "JVM_THREADS_TIMED_WAITING" "nil"
   appendToArray "JVM_THREADS_WAITING" "nil"
   appendToArray "TIMESTAMP" "nil"
}

getPid() {
   SEARCH_KEY="$1"
   MY_USER="$2"
   MY_PID=`/bin/ps axww -u $MY_USER 2>/dev/null | grep -v grep | grep "$SEARCH_KEY" | grep -v grep | head -1 | tr -s " " | awk '{ print $1 }'`
   echo "$MY_PID"
}

getJavaBinPath() {
   SEARCH_KEY="$1"
   MY_USER="$2"
   #JVM_JAVA_BIN=`/bin/ps -u $USER -o pid,cmd |grep "^$JVM_PID" |  grep java | awk '{print $2}' | sed 's/\/java$//'`
   JVM_JAVA_BIN=`/bin/ps -u $MY_USER -o pid,cmd |grep "$SEARCH_KEY" | grep java | awk '{print $2}' | sed 's/\/java$//'`
   echo "$JVM_JAVA_BIN"
}

getJavaVersion() {
   JVM_JAVA_VERSION=`$JVM_JAVA_BIN/java -version  2>&1 | head -1 | awk ' { print $NF }' | sed -e 's/,/-/g' -e 's/\"/ /g'`
   JVM_VERSION=`$JVM_JAVA_BIN/java -version  2>&1 | tail -1 | sed -e 's/,/-/g' -e 's/\"/ /g'`
   echo "${JVM_JAVA_VERSION}${JVM_VERSION}"
}


getWaitingThreads() {
   JSTACK_THREAD_DUMP=$1
   JVM_THREADS_WAITING=`/bin/cat $JSTACK_THREAD_DUMP | grep -c "java.lang.Thread.State: WAITING"`
   echo "$JVM_THREADS_WAITING"
}

getRunnableThreads() {
   JSTACK_THREAD_DUMP=$1
   JVM_THREADS_RUNNABLE=`/bin/cat $JSTACK_THREAD_DUMP | grep -c "java.lang.Thread.State: RUNNABLE"`
   echo "$JVM_THREADS_RUNNABLE"
}

getTimedWaitingThreads() {
   JSTACK_THREAD_DUMP=$1
   JVM_THREADS_TIMED_WAITING=`/bin/cat $JSTACK_THREAD_DUMP | grep -c "java.lang.Thread.State: TIMED_WAITING"`
   echo "$JVM_THREADS_TIMED_WAITING"
}

getBlockedThreads() {
   JSTACK_THREAD_DUMP=$1
   JVM_THREADS_BLOCKED=`/bin/cat $JSTACK_THREAD_DUMP | grep -c "java.lang.Thread.State: BLOCKED"`
   echo "$JVM_THREADS_BLOCKED"
}

getFGCFrequency(){
#/opt/SP/gdsp/home/java/jdk1.7.0_75/bin/jstat -gc -t 49926 2>/dev/null
# S0C    S1C    S0U    S1U      EC       EU        OC         OU       PC     PU    YGC     YGCT    FGC    FGCT     GCT
#97344.0 97344.0 81466.1  0.0   486848.0 392615.5 2484672.0  1050271.2  524288.0 127315.4   3772  335.009 83933 20558.502 20893.511
#echo "" | awk 'END{ printf "%.2f",(83985/352809.1)*60 }'
   JSTAT_OUTPUT_FILE=$1
   JVM_FGC_FREQUENCY=`/bin/cat $JSTAT_OUTPUT_FILE | awk 'NR==1{for(i=1;i<=NF;i++){ix[$i]=i}}NR==2{if ($ix["Timestamp"]==0){print "0"} else {printf "%.2f",($ix["FGC"]/$ix["Timestamp"])*60}}'`
   echo "$JVM_FGC_FREQUENCY"
}

getFGCTotalDuration() {
   JSTAT_OUTPUT_FILE=$1
   JVM_FGC_TOTAL_DURATION=`/bin/cat $JSTAT_OUTPUT_FILE | awk 'NR==1{for(i=1;i<=NF;i++){ix[$i]=i}}NR==2{printf "%d",$ix["FGCT"]}'`
   echo "$JVM_FGC_TOTAL_DURATION"
}

getFGCTotal() {
   JSTAT_OUTPUT_FILE=$1
   JVM_FGC_TOTAL=`/bin/cat $JSTAT_OUTPUT_FILE | awk 'NR==1{for(i=1;i<=NF;i++){ix[$i]=i}}NR==2{printf "%d",$ix["FGC"]}'`
   echo "$JVM_FGC_TOTAL"
}



getFGCAvgDuration() {
   JSTAT_OUTPUT_FILE=$1
   JVM_FGC_AVG_DURATION=`/bin/cat $JSTAT_OUTPUT_FILE | awk 'NR==1{for(i=1;i<=NF;i++){ix[$i]=i}}NR==2{if ($ix["FGC"]==0){print "0"} else {printf "%.2f",$ix["FGCT"]/$ix["FGC"]}}'`
   echo "$JVM_FGC_AVG_DURATION"
}


getMaxHeapSize() {
   JSTAT_OUTPUT_FILE=$1
   #JVM_HEAP_MAX=`/bin/cat $JSTAT_OUTPUT_FILE | awk 'NR==1{for(i=1;i<=NF;i++){ix[$i]=i}}NR==2{printf "%.1f",($ix["S0C"]+$ix["S1C"]+$ix["EC"]+$ix["OC"]+$ix["PC"])}'`
   JVM_HEAP_MAX=`/bin/cat $JSTAT_OUTPUT_FILE | awk 'NR==1{for(i=1;i<=NF;i++){ix[$i]=i}}NR==2{printf "%.1f",($ix["S0C"]+$ix["S1C"]+$ix["EC"]+$ix["OC"])}'`
   echo "$JVM_HEAP_MAX"
}

#getCommitedHeap() {
#
#}

getUsedHeap() {
   JSTAT_OUTPUT_FILE=$1
   #JVM_HEAP_USED=`/bin/cat $JSTAT_OUTPUT_FILE | awk 'NR==1{for(i=1;i<=NF;i++){ix[$i]=i}}NR==2{printf "%.1f",($ix["S0U"]+$ix["S1U"]+$ix["EU"]+$ix["OU"]+$ix["PU"])}'`
   JVM_HEAP_USED=`/bin/cat $JSTAT_OUTPUT_FILE | awk 'NR==1{for(i=1;i<=NF;i++){ix[$i]=i}}NR==2{printf "%.1f",($ix["S0U"]+$ix["S1U"]+$ix["EU"]+$ix["OU"])}'`
   echo "$JVM_HEAP_USED"
}

getCPUTimeUtilization() {
   JVM_PID="$1"
   JVM_CPU_TIME_USE=`/bin/ps -p $JVM_PID -o %cpu | tail -1`
   echo "$JVM_CPU_TIME_USE"
}

getCPUServerUtilization() {
#$/usr/bin/top -p 49926 - b -n 1 | tail -3 | head -2
#   PID USER      PR  NI  VIRT  RES  SHR S %CPU %MEM    TIME+  COMMAND
# 49926 gdsp      20   0 25.0g 3.6g  21m S 39.9  1.4   5740:56 java
   JVM_TOP_OUTPUT_FILE="$1"
   JVM_PROCESS_CPU_USED=`/bin/cat $JVM_TOP_OUTPUT_FILE | awk 'NR==1{for(i=1;i<=NF;i++){ix[$i]=i}}NR==2{printf "%.1f",$ix["%CPU"]}'`
   echo "$JVM_PROCESS_CPU_USED"
}


getMemoryUtilization() {
   JVM_TOP_OUTPUT_FILE="$1"
   JVM_PROCESS_MEMORY_USED=`/bin/cat $JVM_TOP_OUTPUT_FILE | awk 'NR==1{for(i=1;i<=NF;i++){ix[$i]=i}}NR==2{printf "%.1f",$ix["%MEM"]}'`
   echo "$JVM_PROCESS_MEMORY_USED"
}

getProcessStatus() {
   JVM_TOP_OUTPUT_FILE="$1"
   JVM_PROCESS_STATUS=`/bin/cat $JVM_TOP_OUTPUT_FILE | awk 'NR==1{for(i=1;i<=NF;i++){ix[$i]=i}}NR==2{printf "%s",$ix["S"]}'`
   case "$JVM_PROCESS_STATUS" in
      "S" ) echo "sleeping" ;;
      "R" ) echo "running" ;;
      "T" ) echo "traced or stopped" ;;
      "Z" ) echo "zombie" ;;
      "D" ) echo "uninterruptible sleep" ;;
      * ) echo "unknown" ;;
   esac
}


getEstablishedConnections() {
   JVM_PID="$1"
   #JVM_CONNECTIONS_ESTABLISHED=`/bin/netstat -anp 2>/dev/null | grep "${PID}" 2>/dev/null | grep ESTABLISHED | awk '{ print $5 }' | sort -n | uniq -c | awk '{ print $1"x"$2 }' | paste -d"|" -s`
   JVM_CONNECTIONS_ESTABLISHED=`/bin/netstat -anp 2>/dev/null | grep "${JVM_PID}" 2>/dev/null | grep -c ESTABLISHED | tail -1`
   echo "$JVM_CONNECTIONS_ESTABLISHED"
}

getUptime() {
   JVM_PID="$1"
   JVM_PROCESS_ELAPSED_TIME=`/bin/ps -p $JVM_PID -o etime= | awk 'BEGIN{ FS = ":" }{if(NF == 2){print $1*60 + $2}else if(NF == 3){split($1, a, "-");if (a[2] != "" ){print ((a[1]*24+a[2])*60 + $2) * 60 + $3;} else {print ($1*60 + $2) * 60 + $3;}}}'`
   echo "$JVM_PROCESS_ELAPSED_TIME"
}

getLastStartUp() {
   JVM_PID="$1"
   JVM_PROCESS_ELAPSED_TIME=`/bin/ps -p $JVM_PID -o etime=` | awk 'BEGIN{ FS = ":" }{if(NF == 2){print $1*60 + $2}else if(NF == 3){split($1, a, "-");if (a[2] != "" ){print ((a[1]*24+a[2])*60 + $2) * 60 + $3;} else {print ($1*60 + $2) * 60 + $3;}}}'
   JVM_PROCESS_LAST_STARTUP=`/bin/date -u -d "$JVM_PROCESS_ELAPSED_TIME seconds ago" +"%Y/%m/%d %H:%M"`
   echo "$JVM_PROCESS_LAST_STARTUP"
}


getServerHostname() {
   APPLICATION_SERVER_HOSTNAME=`/bin/hostname | head  -1`
   echo "$APPLICATION_SERVER_HOSTNAME"
}


getIORead() {
   JVM_PIDSTAT_OUTPUT_FILE="$1"
   JVM_KB_READS_PER_SECOND=`/bin/cat $JVM_PIDSTAT_OUTPUT_FILE | awk '{print $3}'`
   echo "$JVM_KB_READS_PER_SECOND"

}

getIOWrite() {
   JVM_PIDSTAT_OUTPUT_FILE="$1"
   JVM_KB_WRITES_PER_SECOND=`/bin/cat $JVM_PIDSTAT_OUTPUT_FILE | awk '{print $4}'`
   echo "$JVM_KB_WRITES_PER_SECOND"
}

appendToArray() {
   KEY=$1
   VALUE=$2
   SNAPSHOT_ARRAY["$1"]="$2"
}

arrayKeys(){
k=0
len=${#SNAPSHOT_ARRAY[@]}
for i in "${!SNAPSHOT_ARRAY[@]}"
do
   (( $k < $len - 1 )) && /usr/bin/printf "%s," "$i" || /usr/bin/printf "%s\n" "$i"
   k=`expr $k + 1`
done

}

arrayToCSV() {
#AAA,BBB,CCC,DDD,EEE,FFF
#10,20,30,40,50,70
k=0
len=${#SNAPSHOT_ARRAY[@]}
for i in "${!SNAPSHOT_ARRAY[@]}"
do
   (( $k < $len - 1 )) && /usr/bin/printf "%s," "$i" || /usr/bin/printf "%s\n" "$i"
   k=`expr $k + 1`
done

#/usr/bin/printf "\n"

k=0
for i in "${!SNAPSHOT_ARRAY[@]}"
do
   (( $k < $len - 1 )) && /usr/bin/printf "%s," "${SNAPSHOT_ARRAY[$i]}" || /usr/bin/printf "%s\n" "${SNAPSHOT_ARRAY[$i]}"
   k=`expr $k + 1`
done

#/usr/bin/printf "\n"
}

arrayToList() {
#AAA=10
#BBB=20
#CCC=30
#DDD=40
#EEE=50
#FFF=70

for i in "${!SNAPSHOT_ARRAY[@]}"
do
   each_element=${SNAPSHOT_ARRAY[$i]}
   if [[ ! -z `echo $each_element | tr -d "[:digit:][:punct:]"` || -z $each_element ]]; then
      each_element="\"${each_element}\""
   fi
   echo "${i}=$each_element"
   #/usr/bin/printf "%s=\"%s\"\n" "$i" "${SNAPSHOT_ARRAY[$i]}"
done

}

arrayToJSON() {
#{
#       "AAA": "10",
#       "BBB": "20",
#       "CCC": "30"
#       "DDD": "40"
#       "EEE": "50"
#       "FFF": "70"
#}
k=0
len=${#SNAPSHOT_ARRAY[@]}
echo -n "{"
for i in "${!SNAPSHOT_ARRAY[@]}"
do
   each_element=${SNAPSHOT_ARRAY[$i]}
   if [[ ! -z `echo $each_element | tr -d "[:digit:][:punct:]"` || -z $each_element ]]; then
      each_element="\"${each_element}\""
   fi
   (( $k < $len - 1 )) && echo -n "\"${i}\":$each_element," || echo -n "\"${i}\":$each_element"
   k=`expr $k + 1`
done
echo "}"
}

generateJStack() {
   JVM_PID=$1
   timeout 2s ${JVM_JAVA_BIN}/jstack ${JVM_PID} 2>/dev/null > ${JSTACK_THREAD_DUMP}
   if [[ $? -eq 127 || $? -eq 124 ]];then
      timeout 2s jstack ${JVM_PID} 2>/dev/null > ${JSTACK_THREAD_DUMP}
   fi
}

generateJStat() {
   JVM_PID=$1
   timeout 2s ${JVM_JAVA_BIN}/jstat -gc -t ${JVM_PID} 2>/dev/null  > ${JSTAT_OUTPUT_FILE}
   if [[ $? -eq 127 || $? -eq 124 ]];then
      timeout 2s jstat -gc -t ${JVM_PID} 2>/dev/null  > ${JSTAT_OUTPUT_FILE}
   fi
}

generateTop() {
   /usr/bin/top -p ${JVM_PID} - b -n 1 2>/dev/null | tail -3 | head -2 > ${JVM_TOP_OUTPUT_FILE}
}

generatePidstat() {
  /usr/bin/pidstat -d -p ${JVM_PID} -h 1 1 2>/dev/null | tail -1 > ${JVM_PIDSTAT_OUTPUT_FILE}
}

validateAndAppend() {
   KEY="$1"
   VALUE="$2"
   if [[ $VALUE == "X" ]]
   then
      REAL_VALUE=""
      MESSAGE="$MESSAGE; Could not retrieve $KEY"
      AGENT_STATUS="W"
   else
      REAL_VALUE=`echo $VALUE | sed 's/^X//'`
   fi
   appendToArray $KEY $REAL_VALUE
}

terminate() {
   [[ -z $AGENT_MESSAGE ]]  && AGENT_MESSAGE="$MSG" || AGENT_MESSAGE="$AGENT_MESSAGE; $MSG"
   #AGENT_MESSAGE="$AGENT_MESSAGE; $MSG"
   appendToArray "AGENT_MESSAGE" "$AGENT_MESSAGE"
   appendToArray "AGENT_STATUS" "$AGENT_STATUS"
   appendToArray "JVM_PROCESS_STATUS" "$JVM_PROCESS_STATUS"
   #echo $MESSAGE
   printOutput
   rm ${JVM_TOP_OUTPUT_FILE} ${JSTACK_THREAD_DUMP} ${JSTAT_OUTPUT_FILE} 2>/dev/null
   exit 0
}

usage(){
   echo "$0 -[l|c|j] -s \"Search Key\" -u \"user\" -a \"Application Name\""
   echo "-l to get output in list format"
   echo "-c to get output in csv format"
   echo "-j to get output in json format"
   echo ""
   echo "example:"
   echo "./mds_jvm_perf_snapshot.sh -s \"\-Ddomain.name\=domain3\" -u gdsp -a \"glassfish_domain3\" -c"
   echo ""
   exit 1
}

printOutput(){
   case $OUT_FORMAT in
      "csv" ) arrayToCSV
         ;;
      "list" ) arrayToList
         ;;
      "json" ) arrayToJSON
         ;;
      "keys" ) arrayKeys
         ;;
   esac
}


START_DATE=$(date -u "+%Y/%m/%d %H:%M:%S")


#SEARCH_KEY=`echo "$1" | sed -e 's/\-/\\-/g' -e 's/\=/\\=/g'`
#USER=$2
#APPLICATION_NAME=$3



while getopts "s:a:u:cljk" Option
do
case ${Option} in
        c) if [ -z $OUT_FORMAT ]
           then
              OUT_FORMAT="csv"
           else
              usage
           fi
        ;;
        l) if [ -z $OUT_FORMAT ]
           then
              OUT_FORMAT="list"
           else
              usage
           fi
        ;;
        j) if [ -z $OUT_FORMAT ]
           then
              OUT_FORMAT="json"
           else
              usage
           fi
        ;;
        k) if [ $OUT_FORMAT=="csv" ]
           then
              OUT_FORMAT="keys"
           else
              usage
           fi
        ;;
        s) SEARCH_KEY=`echo "$OPTARG" | sed -e 's/\-/\\-/g' -e 's/\=/\\=/g'`
        ;;
        a) APPLICATION_NAME="$OPTARG"
        ;;
        u) MY_USER="$OPTARG"
        ;;
        \?) echo "Invalid option: -$OPTARG" >&2
            exit 1
        ;;
        :)  echo "Option -$OPTARG requires an argument." >&2
            exit 1
        ;;
        *) LOG_MSG="Parameter missing."
        ;;
esac
done
shift $(($OPTIND - 1))


if [[ -z $SEARCH_KEY  || -z $APPLICATION_NAME || -z $MY_USER || -z $OUT_FORMAT ]]
then
   echo "Missing Mandatory Parameter" >&2
   echo ""
   usage
fi

initializeArray

appendToArray "APPLICATION_NAME" "$APPLICATION_NAME"
appendToArray "TIMESTAMP" "$START_DATE"

APPLICATION_SERVER_HOSTNAME=`getServerHostname`
appendToArray "APPLICATION_SERVER_HOSTNAME" "$APPLICATION_SERVER_HOSTNAME"

JVM_PID=`getPid $SEARCH_KEY $MY_USER`
[[ -z $JVM_PID ]] && export MSG="Could not retrieve PID" && export AGENT_STATUS="E" && export JVM_PROCESS_STATUS="Down" && terminate
appendToArray "JVM_PID" $JVM_PID

JVM_JAVA_BIN=`getJavaBinPath $SEARCH_KEY $MY_USER`
[[ -z $JVM_JAVA_BIN ]] && export MSG="Could not retrieve Java Path" && export AGENT_STATUS="E" && terminate
appendToArray "JVM_JAVA_BIN" $JVM_JAVA_BIN


generateJStack $JVM_PID
[[ $? -ne 0 ]] && export MSG="An Error occurred generating Jstack" && export AGENT_STATUS="E" && terminate

generateJStat $JVM_PID
[[ $? -ne 0 ]] && export MSG="An Error occurred generating Jstat" && export AGENT_STATUS="E" && terminate

generateTop $JVM_PID
[[ $? -ne 0 ]] && export MSG="An Error occurred generating top" && export AGENT_STATUS="E" && terminate

generatePidstat $JVM_PID
[[ $? -ne 0 ]] && export MSG="An Error occurred generating pidstat" && export AGENT_STATUS="E" && terminate


JVM_JAVA_VERSION=`getJavaVersion`
appendToArray "JVM_JAVA_VERSION" "$JVM_JAVA_VERSION"

JVM_THREADS_WAITING=`getWaitingThreads "${JSTACK_THREAD_DUMP}"`
appendToArray "JVM_THREADS_WAITING" $JVM_THREADS_WAITING

JVM_THREADS_RUNNABLE=`getRunnableThreads "${JSTACK_THREAD_DUMP}"`
appendToArray "JVM_THREADS_RUNNABLE" $JVM_THREADS_RUNNABLE

JVM_THREADS_TIMED_WAITING=`getTimedWaitingThreads "${JSTACK_THREAD_DUMP}"`
appendToArray "JVM_THREADS_TIMED_WAITING" $JVM_THREADS_TIMED_WAITING

JVM_THREADS_BLOCKED=`getBlockedThreads "${JSTACK_THREAD_DUMP}"`
appendToArray "JVM_THREADS_BLOCKED" $JVM_THREADS_BLOCKED

JVM_FGC_FREQUENCY=`getFGCFrequency "${JSTAT_OUTPUT_FILE}"`
appendToArray "JVM_FGC_FREQUENCY" $JVM_FGC_FREQUENCY

JVM_FGC_TOTAL_DURATION=`getFGCTotalDuration "${JSTAT_OUTPUT_FILE}"`
appendToArray "JVM_FGC_TOTAL_DURATION" $JVM_FGC_TOTAL_DURATION

JVM_FGC_TOTAL=`getFGCTotal "${JSTAT_OUTPUT_FILE}"`
appendToArray "JVM_FGC_TOTAL" $JVM_FGC_TOTAL

JVM_FGC_AVG_DURATION=`getFGCAvgDuration "${JSTAT_OUTPUT_FILE}"`
appendToArray "JVM_FGC_AVG_DURATION" $JVM_FGC_AVG_DURATION

JVM_HEAP_MAX=`getMaxHeapSize "${JSTAT_OUTPUT_FILE}"`
appendToArray "JVM_HEAP_MAX" $JVM_HEAP_MAX

JVM_HEAP_USED=`getUsedHeap "${JSTAT_OUTPUT_FILE}"`
appendToArray "JVM_HEAP_USED" $JVM_HEAP_USED

JVM_HEAP_USED_PERC=`echo "scale = 2; 100 * $JVM_HEAP_USED / $JVM_HEAP_MAX" | bc`
appendToArray "JVM_HEAP_USED_PERC" $JVM_HEAP_USED_PERC

JVM_PROCESS_CPU_USED=`getCPUServerUtilization "${JVM_TOP_OUTPUT_FILE}"`
appendToArray "JVM_PROCESS_CPU_USED" $JVM_PROCESS_CPU_USED

JVM_PROCESS_MEMORY_USED=`getMemoryUtilization "${JVM_TOP_OUTPUT_FILE}"`
appendToArray "JVM_PROCESS_MEMORY_USED" $JVM_PROCESS_MEMORY_USED

JVM_PROCESS_STATUS=`getProcessStatus "${JVM_TOP_OUTPUT_FILE}"`
appendToArray "JVM_PROCESS_STATUS" $JVM_PROCESS_STATUS

JVM_KB_WRITES_PER_SECOND=`getIOWrite "${JVM_PIDSTAT_OUTPUT_FILE}"`
appendToArray "JVM_IO_WRS" $JVM_KB_WRITES_PER_SECOND

JVM_KB_READS_PER_SECOND=`getIORead "${JVM_PIDSTAT_OUTPUT_FILE}"`
appendToArray "JVM_IO_RDS" $JVM_KB_READS_PER_SECOND

JVM_CONNECTIONS_ESTABLISHED=`getEstablishedConnections ${JVM_PID}`
appendToArray "JVM_CONNECTIONS_ESTABLISHED" $JVM_CONNECTIONS_ESTABLISHED

JVM_PROCESS_ELAPSED_TIME=`getUptime ${JVM_PID}`
appendToArray "JVM_PROCESS_ELAPSED_TIME" $JVM_PROCESS_ELAPSED_TIME

JVM_PROCESS_LAST_STARTUP=`getLastStartUp ${JVM_PID}`
appendToArray "JVM_PROCESS_LAST_STARTUP" "$JVM_PROCESS_LAST_STARTUP"

END_DATE=$(date -u "+%Y/%m/%d %H:%M:%S")

AGENT_DURATION=`datediff $END_DATE $START_DATE`
appendToArray "AGENT_DURATION" $AGENT_DURATION

appendToArray "AGENT_STATUS" "$AGENT_STATUS"
appendToArray "AGENT_MESSAGE" "$AGENT_MESSAGE"

terminate

#arrayToCSV
#arrayToList

/bin/rm ${JVM_TOP_OUTPUT_FILE} ${JVM_PIDSTAT_OUTPUT_FILE} ${JSTACK_THREAD_DUMP} ${JSTAT_OUTPUT_FILE} 2>/dev/null

exit 0
