#!/bin/sh


archAffix(){
    os='';
    arch='';
    case $(uname) in
        Linux)
            os='linux';
            case $(uname -m) in
                i386 | i686) arch='386' ;;
                x86_64 | amd64) arch='amd64' ;;
                armv8 | arm64 | aarch64) arch='arm64' ;;
                *) echo 'unsupported CPU' && exit 1 ;;
            esac;
            ;;
        Darwin)
            os='darwin';
            case $(uname -m) in
                x86_64 | amd64) arch='amd64' ;;
                armv8 | arm64 | aarch64) arch='arm64' ;;
                *) echo 'unsupported CPU' && exit 1 ;;
            esac;
            ;;
        FreeBSD)
            os='freebsd';
            case $(uname -m) in
                i386 | i686) arch='386' ;;
                x86_64 | amd64) arch='amd64' ;;
                armv8 | arm64 | aarch64) arch='arm64' ;;
                *) echo 'unsupported CPU' && exit 1 ;;
            esac;
            ;;
        *)
            echo 'unsupported OS' && exit 1 ;;
    esac;
    echo $os-$arch;
};

get_rnd_dec(){
    echo $(od -An -N2 -i /dev/urandom);
};

get_rnd_hex(){
    echo $(od -An -N2 -x /dev/urandom);
};

get_ping_loss(){
    if [ $TEST_RUN -eq 1 ]; then
        echo 100;
        exit;
    fi;
    if [ $DRY_RUN -eq 1 ]; then
        echo 100;
        exit;
    fi;
    loss_percent=$(ping -c 12 -qni 0.25 $1 | awk '/packet loss/{for(i=6;i<=NF;i++)if($i ~ /packet/)print $((i-1))}');
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
    while [ $num -lt $max ]; do
        ip=$($prog);
        unique=1;
        for item in $@; do
            if [ $item = $ip ]; then
                unique=0;
                break;
            fi;
        done;
        if [ $unique -eq 0 ]; then
            continue;
        fi;
        set -- $@ $ip;
        num=$((num + 1));
    done;
    echo $@;
};

speedtest(){
    exe_file='/var/tmp/warp';
    result_file='/var/tmp/result.csv'
    if [ ! -x "$exe_file" ]; then
        curl -SfLo "$exe_file" "https://git.tink.ltd:8443/tink/netlist/raw/branch/better-warp-ip/warp-$1" 2>&1;
    fi;
    ulimit -n 102400;
    chmod +x "$exe_file" && "$exe_file" -file "$2" -output "$result_file" >/dev/null 2>&1;
    if [ -f "$result_file" ]; then
        ips=$(cat "$result_file" | awk -F, 'NR != 1 && NR <= '$(($3 + 1))'{print $1}');
        rm -f "$result_file";
        echo $ips;
    else
        if [ $DRY_RUN -eq 0 ]; then
            rm -f $exe_file;
        fi;
        exit 1;
    fi;
};

get_ip_cadidates(){
    limit=100;
    ip_file='/var/tmp/ip.txt'
    rm -f "$ip_file";
    for item in $(generate_ips $limit $1); do
        echo "$item" >> "$ip_file";
    done;
    if [ $4 -eq 1 ]; then
        result_list=$(speedtest $(archAffix) "$ip_file" $3);
    else
        result_list=$(head -$3 "$ip_file" | awk '{print $1":"'$2'}');
    fi;
    ret_code=$?;
    rm -f "$ip_file";
    echo $result_list;
    if [ $ret_code -ne 0 ]; then
        exit 1;
    fi;
};

resolve_ip_addresses(){
    addresses=$(cat "$1");
    port=$2;
    set --;
    for addr in $addresses; do
        ips=$(getent ahosts $addr | awk '{print $1}');
        for ip in $ips; do
            unique=1;
            for item in $@; do
                if [ $item = $ip:$port ]; then
                    unique=0;
                    break;
                fi;
            done;
            if [ $unique -eq 0 ]; then
                continue;
            fi;
            set -- $@ $ip:$port;
        done;
    done;
    echo $@;
};

get_json_value(){
    json=$1;
    key=$2;
    if [ -z "$3" ]; then
        num=1;
    else
        num=$3;
    fi;
    value=$(echo "$json" | awk -F"[,:}]" '{for(i=1;i<=NF;i++){if($i~/'$key'\042/){print $(i+1)}}}' | tr -d '"' | sed -n $num'p');
    echo $value;
};

main(){
    num_cadidates=10;
    dl_retry_times=3;
    wait_in_between=5;
    retry=0;
    arch=$(archAffix);
    if [ $? -ne 0 ]; then
        retry=$dl_retry_times;
    fi;
    echo "$arch";
    loss=$(get_ping_loss $WATCH_ADD);
    while [ $loss -ge $LOSS_THR ]; do
        if [ ! -r "$ENDPOINTS" ]; then
            if [ $retry -lt $dl_retry_times ]; then
                echo "test ip speed";
                cadidates=$(get_ip_cadidates $FAMILY $DEFAULT_PORT $num_cadidates 1);
            else
                echo "random ip on $DEFAULT_PORT";
                cadidates=$(get_ip_cadidates $FAMILY $DEFAULT_PORT $num_cadidates 0);
            fi;
            if [ $? -ne 0 ]; then
                retry=$(($retry + 1));
                continue;
            fi;
        else
            echo "file ip on $DEFAULT_PORT";
            cadidates=$(resolve_ip_addresses "$ENDPOINTS" $DEFAULT_PORT);
        fi;
        for ip_port in $cadidates; do
            loss=$(get_ping_loss $WATCH_ADD);
            if [ $loss -lt $LOSS_THR ]; then
                break;
            fi;
            echo "set $INTERFACE to $ip_port";
            if [ $TEST_RUN -eq 1 ]; then
                continue;
            fi;
            if [ $DRY_RUN -eq 1 ]; then
                continue;
            fi;
            if [ -z $INTERFACE ]; then
                continue;
            fi;
            wg set $INTERFACE peer $PUB_KEY endpoint $ip_port;
            sleep $wait_in_between;
        done
        if [ $TEST_RUN -eq 1 ]; then
            exit;
        fi;
    done;
    if [ $DRY_RUN -eq 1 ]; then
        exit;
    fi;
    if [ -z $INTERFACE ]; then
        exit;
    fi;
    endpoint=$(wg show $INTERFACE endpoints | awk '{print $2}');
    serveraddress=$(echo $endpoint|awk -F: '{print $1}');
    serverport=$(echo $endpoint|awk -F: '{print $2}');
    case $(uname -i) in
        pfSense)
            if [ $CONFIG ] && [ $(pfSsh.php playback wgpeer $CONFIG) != $endpoint ]; then
                echo "set pfSense";
                pfSsh.php playback wgpeer $CONFIG $serveraddress $serverport || true;
            fi;
            ;;
        *)
            if [ $CONFIG ] && [ $(grep -i "Endpoint" $CONFIG|awk '{print $3}') != $endpoint ]; then
                echo "set config";
                sed -i -r s/Endpoint.*/Endpoint = $endpoint/i $CONFIG;
            fi;
            if [ $HOST ]; then
                json=$(curl -ksSfL "https://$HOST/api/wireguard/client/getClient/$UUID" -H "Authorization: Basic $BASIC") 2>&1;
                s_add=$(get_json_value "$json" serveraddress);
                s_port=$(get_json_value "$json" serverport);
                if [ "$s_add:$s_port" != $endpoint ]; then
                    echo "set opnSense";
                    curl -ksSfLX POST "https://$HOST/api/wireguard/client/setClient/$UUID" \
                        -H "Content-Type: application/json" \
                        -H "Authorization: Basic $BASIC" \
                        -d '{"client":{"serveraddress":"'$serveraddress'","serverport":"'$serverport'","servers":"'$SERVER'"}}' 2>&1;
                fi;
            fi;
            ;;
    esac;
};


already_running(){
    self=$(echo $0 $@|awk '{OFS="_";$1="__"$1;print $0}')
    cmds=$(pgrep -afl $0|awk '{OFS="_";$1="";$2="";print $0}');
    set --;
    num_occur=0;
    num_unique=0;
    pos=0;
    for proc in $cmds; do
        unique=1;
        for item in $@; do
            if [ $item = $proc ]; then
                unique=0;
                break;
            fi;
        done;
        if [ $self = $proc ]; then
            num_occur=$((num_occur + 1));
        fi;
        if [ $unique -eq 0 ]; then
            continue;
        fi;
        set -- $@ $proc;
        num_unique=$((num_unique + 1));
        if [ $self = $proc ]; then
            pos=$num_unique;
        fi;
    done;
    if [ $num_unique -eq $pos ]; then
        if [ $num_occur -le 5 ]; then
            echo 0;
            exit;
        fi;
    fi;
    echo 1;
};

usage(){
    echo "Usage: $0 [OPTIONS]";
    echo "Options:";
    echo "    -4                    IPv4 (default)";
    echo "    -6                    IPv6";
    echo "    -i <INTERFACE>        Interface";
    echo "    -c <CONFIG>           Config file name or pfSense interface name";
    echo "    -n <HOST>             Hostname for opnSense";
    echo "    -u <UUID>             UUID for opnSense wg client";
    echo "    -b <BASIC>            Basic auth string for opnSense";
    echo "    -s <SERVER>           Server UUID for opnSense";
    echo "    -a <ADDRESS>          Watch address (default: $WATCH_ADD)";
    echo "    -l <LOSS>             Loss threshold percentage (default: $LOSS_THR)";
    echo "    -p <PORT>             endpoint's default port (default: $DEFAULT_PORT)";
    echo "    -e <ENDPOINTS_FILE>   File of endpoint's addresses";
    echo "    -k <PEER_PUBLIC_KEY>  Interface peer's public key (default: $PUB_KEY)";
    echo "    -t                    Speed test only";
    echo "    -d                    Dry run";
    echo "Note: If -e is not set, generate endpoints for warp, else resolve addresses and use default port.";
}

FAMILY=4;
INTERFACE='';
CONFIG='';
HOST='';
UUID='';
BASIC='';
SERVER='';
WATCH_ADD='1.1.1.1';
LOSS_THR=30;
DEFAULT_PORT=4500;
ENDPOINTS='';
PUB_KEY='bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=';
TEST_RUN=0;
DRY_RUN=0;
while getopts ":46i:c:n:u:b:s:a:l:p:e:k:td" OPT; do
    case $OPT in
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
        n)
            HOST=$OPTARG;
            ;;
        u)
            UUID=$OPTARG;
            ;;
        b)
            BASIC=$OPTARG;
            ;;
        s)
            SERVER=$OPTARG;
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
        e)
            ENDPOINTS=$OPTARG;
            ;;
        k)
            PUB_KEY=$OPTARG;
            ;;
        t)
            TEST_RUN=1;
            ;;
        d)
            DRY_RUN=1;
            ;;
        :)
            echo "Option -$OPTARG requires an argument.";
            exit 1;;
        ?)
            echo "Invalid Option: -$OPTARG";
            usage;
            exit 1;;
    esac;
done;


if [ $(uname -i) = 'pfSense' ] && [ $(already_running "$@") -eq 1 ]; then
    echo "Another process is already running.";
    exit;
fi;
main;

