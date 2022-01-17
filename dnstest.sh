#!/usr/bin/env bash

command -v bc > /dev/null || { echo "bc was not found. Please install bc."; exit 1; }
command -v datamash > /dev/null || { echo "datamash was not found. Please install datamash."; exit 1; }
{ command -v drill > /dev/null && dig=drill; } || { command -v dig > /dev/null && dig=dig; } || { echo "dig was not found. Please install dnsutils."; exit 1; }

NAMESERVERS=$(grep ^nameserver /etc/resolv.conf | cut -d " " -f 2 | sed 's/\(.*\)/&#&/')

PROVIDERS=(
    "1.1.1.1#cloudflare"
    "103.247.36.36#dnsfilter1"
    "103.247.37.37#dnsfilter2"
    "208.67.222.222#cisco1"
    "208.67.220.220#cisco2"
    "64.6.64.6#neustar1"
    "64.6.65.6#neustar2"
    "8.8.8.8#google1"
    "8.8.4.4#google2"
    "77.88.8.8#yandex1"
    "77.88.8.1#yandex2"
)

NS=( $NAMESERVERS ${PROVIDERS[@]} )

# Domains to test. Duplicated domains are ok
DOMAINS2TEST="www.google.com avito.ru facebook.com www.youtube.com vk.com ya.ru gmail.com"

declare -a total_avg
function print_winner {
    winner=none
    result=1000
    for i in ${!total_avg[@]}; do
        readarray -d : -t avga <<<"${total_avg[$i]}"
        median=$(printf "%s\n" ${avga[*]} | datamash median 1)
        if (( $(bc <<< "$median<$result") > 0 )); then
	    result=$median
	    winner=${NS[$i]##*#}
        fi
    done
    echo ""
    echo "## The Winner is $winner with a median time of $result ms ##"
    exit 0
}
trap print_winner INT

# sets default 1 second if the argument is not set
RUNTIME=${1:-1}
endtime=$(date --utc --date="$RUNTIME seconds" +%s)
waittime=10

while [[ $(date -u +%s) -le $endtime ]]; do
    clear

    # header
    totaldomains=0
    printf "%-18s" ""
    for d in $DOMAINS2TEST; do
        totaldomains=$((totaldomains + 1))
        printf "%-8s" "test$totaldomains"
    done
    printf "%-8s" "Avg"
    printf "%-8s" "Median"
    echo ""

    n=0
    # body
    for p in ${NS[@]}; do
        pip=${p%%#*}
        pname=${p##*#}
        ftime=0

        printf "%-18s" "$pname"
        for d in $DOMAINS2TEST; do
            ttime=$($dig +tries=1 +time=2 +stats @$pip $d |grep "Query time:" | cut -d : -f 2- | cut -d " " -f 2)
            if [ -z "$ttime" ]; then
                #let's have time out be 1s = 1000ms
                ttime=1000
            elif [ "x$ttime" = "x0" ]; then
                ttime=1
            fi

            printf "%-8s" "$ttime ms"
            ftime=$((ftime + ttime))
        done
        avg=$(bc -lq <<< "scale=2; $ftime/$totaldomains")
        total_avg[$n]="${total_avg[$n]}:$avg"

	readarray -d : -t avga <<<"${total_avg[$n]}"
	median=$(printf "%s\n" ${avga[*]} | datamash median 1)

        printf "%-8s" "$avg"
        printf "%-8s\n" "$median"
        n=$((n + 1))
    done
    sleep $waittime
done

echo "The script successfuly ran for $RUNTIME seconds with sleep time $waittime"
print_winner

exit 0
