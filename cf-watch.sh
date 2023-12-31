#!/bin/sh


archAffix(){
    os='';
    arch='';
    case "$(uname)" in
        Linux)
            os='linux';
            case "$(uname -m)" in
                i386 | i686) arch='386' ;;
                x86_64 | amd64) arch='amd64' ;;
                armv8 | arm64 | aarch64) arch='arm64' ;;
                s390x) arch='s390x' ;;
                *) echo 'unsupported CPU' && exit 1 ;;
            esac;
            ;;
        Darwin)
            os='darwin';
            case "$(uname -m)" in
                x86_64 | amd64) arch='amd64' ;;
                armv8 | arm64 | aarch64) arch='arm64' ;;
                *) echo 'unsupported CPU' && exit 1 ;;
            esac;
            ;;
        *)
            echo 'unsupported OS' && exit 1;
            ;;
    esac;
    echo $os-$arch;
};

get_rnd_dec(){
    echo $(od -An -N2 -i /dev/random);
};

get_rnd_hex(){
    echo $(od -An -N2 -x /dev/random);
};

get_ping_loss(){
    if [ $DRY_RUN == 'true' ]; then
        echo 100;
        exit;
    fi;
    loss_percent=$(ping -c 10 -qn $1 | awk '/packet loss/{for(i=6;i<=NF;i++)if($i ~ /packet/)print $((i-1))}');
    loss=${loss_percent%?};
    echo ${loss%.*};
};

cf_v4(){
    set -- '188.114.96.' \
    '188.114.97.' \
    '188.114.98.' \
    '188.114.99.' \
    '162.159.192.' \
    '162.159.193.' \
    '162.159.195.' \
    '162.159.204.';
    index=$((($(get_rnd_dec) % 8) + 1));
    echo $(eval "echo \$$index")$((($(get_rnd_dec) % 253) + 1));
};

cf_v6(){
    echo "[2606:4700:d$(($(get_rnd_dec) % 2))::$(get_rnd_hex):$(get_rnd_hex):$(get_rnd_hex):$(get_rnd_hex)]";
};


generate_ips(){
    max=$1;
    prog='';
    case $2 in
        6)
            prog='cf_v6';
            ;;
        *)
            prog='cf_v4';
            ;;
    esac

    set --;
    num=0;
    while true; do
        ip=$($prog);
        unique=true;
        for index in $@; do
            if [ "$index" == "$ip" ]; then
                unique=false;
            fi;
        done;
        if [ $unique == 'true' ]; then
            set -- $@ $ip;
            num=$(($num + 1));
        fi;
        if [ $num -ge $max ]; then
            break;
        fi;
    done;
    echo $@;
};

speedtest(){
    exe_file='/var/tmp/warp';
    result_file='/var/tmp/result.csv'
    if [ ! -f "$exe_file" ]; then
        curl -Sfo "$exe_file" "https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/warp-yxip/warp-$1"
    fi;
    ulimit -n 102400;
    chmod +x "$exe_file" && "$exe_file" -file "$2" -output "$result_file" >/dev/null 2>&1;
    if [ -f "$result_file" ]; then
        ips=$(cat "$result_file" | awk -F, 'NR != 1 && NR <= '$(($3 + 1))'{print $1}');
        rm -f "$result_file";
        echo $ips;
    else
        if [ $DRY_RUN != 'true' ]; then
            rm -f $exe_file;
        fi;
        exit 1;
    fi;
};

get_ip_cadidates(){
    limit=100
    ip_file='/var/tmp/ip.txt'
    for index in $(generate_ips $limit $1); do
        echo "$index" >> "$ip_file";
    done;
    if [ $4 == 'true' ]; then
        ip_list=$(speedtest $(archAffix) "$ip_file" $3);
    else
        ip_list=$(head -$3 "$ip_file" | awk '{print $1":"'$2'}');
    fi;
    result=$?;
    rm -f "$ip_file";
    echo $ip_list;
    if [ $result -ne 0 ]; then
        exit 1;
    fi;
};

main(){
    num_cadidates=10;
    dl_retry_times=3;
    wait_in_between=5;
    retry=0;
    arch=$(archAffix);
    if [ $? -ne 0 ]; then
        retry=$dl_retry_times;
    fi
    echo "Running on $arch"
    loss=$(get_ping_loss $WATCH_ADD);
    while [ $loss -ge $LOSS_THR ]; do
        if [ $retry -lt $dl_retry_times ]; then
            echo "Try to run speed test"
            cadidates=$(get_ip_cadidates $FAMILY $DEFAULT_PORT $num_cadidates true);
        else
            echo "Use random ip on port $DEFAULT_PORT"
            cadidates=$(get_ip_cadidates $FAMILY $DEFAULT_PORT $num_cadidates false);
        fi;
        if [ $? -ne 0 ]; then
            retry=$(($retry + 1));
            continue;
        fi
        for cfip in $cadidates; do
            loss=$(get_ping_loss $WATCH_ADD);
            if [ $loss -lt $LOSS_THR ]; then
                break;
            fi;
            echo "changing $INTERFACE endpoint to $cfip";
            if [ $DRY_RUN == 'true' ]; then
                continue;
            fi;
            if [ ! $INTERFACE ]; then
                continue;
            fi;
            wg set $INTERFACE peer 'bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=' endpoint $cfip;
            sleep $wait_in_between;
        done
    done;
    if [ $DRY_RUN = 'true' ]; then
        exit 0;
    fi;
    if [ ! $INTERFACE ]; then
        exit 0;
    fi;
    if [ ! $CONFIG ]; then
        exit 0;
    fi;
    endpoint=$(wg show $INTERFACE endpoints | awk '{print $2}');
    if [ "$(uname -i)" == 'pfSense' ]; then
        if [ $(pfSsh.php playback chgwgpeer $CONFIG) != $endpoint ]; then
            pfSsh.php playback chgwgpeer $CONFIG $(echo $endpoint|awk -F: '{print $1}') $(echo $endpoint|awk -F: '{print $2}') || true;
        fi;
    else
        sed -i -r 's/Endpoint =.*/Endpoint = '$endpoint'/' $CONFIG
    fi;
};


pids=$(pgrep -afl $0);
if [ $(echo $pids|grep -o $0|wc -l) -gt 1 ]; then
    echo "An other process is already running."
    exit;
fi;


usage(){
    echo "Usage: $0 [-4] [-6] [-i <INTERFACE>] [-c <CONFIG>] [-a <ADDRESS>] [-l <LOSS>] [-p <PORT>] [-d]";
    echo "Options:"
    echo "    -4            IPv4"
    echo "    -6            IPv6"
    echo "    -i INTERFACE  Interface"
    echo "    -c CONFIG     Config"
    echo "    -a ADDRESS    Watch address"
    echo "    -l LOSS       Loss threshold"
    echo "    -p PORT       Default port"
    echo "    -d            Dry run"
}

FAMILY=4;
INTERFACE='';
CONFIG='';
WATCH_ADD='1.1.1.1';
LOSS_THR=40;
DEFAULT_PORT=4500;
DRY_RUN=false;
while getopts ":h46i:c:a:l:p:d" opt; do
    case $opt in
        h)
            usage;
            exit;;
        4)
            FAMILY=4;
            ;;
        6)
            FAMILY=6;
            ;;
        i)
            INTERFACE=$OPTARG;
            ;;
        c)
            CONFIG=$OPTARG;
            ;;
        a)
            WATCH_ADD=$OPTARG;
            ;;
        l)
            LOSS_THR=$OPTARG;
            ;;
        p)
            DEFAULT_PORT=$OPTARG;
            ;;
        d)
            DRY_RUN=true;
            ;;
        :)
            echo "Option -$OPTARG requires an argument.";
            exit 1;;
        ?)
            echo "Invalid Option: -$OPTARG";
            exit 1;;
    esac
done

main
