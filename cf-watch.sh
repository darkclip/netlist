#!/bin/sh


family=$1;
interface=$2;
config=$3;

debug=false;

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
                s390x) arch='s390x' ;;
                *) echo 'Unsupported CPU!' && exit 1 ;;
            esac;
            ;;
        Darwin)
            os='darwin';
            case $(uname -m) in
                x86_64 | amd64) arch='amd64' ;;
                armv8 | arm64 | aarch64) arch='arm64' ;;
                *) echo 'Unsupported CPU!' && exit 1 ;;
            esac;
            ;;
        *)
            echo 'Unsupported OS!' && exit 1;
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
    if [ $debug == 'true' ]; then
        echo 100;
        exit 0;
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
    index=$((0 - ($(get_rnd_dec) % 8)));
    echo $(eval "echo \$$(($#$index))")$((($(get_rnd_dec) % 253) + 1));
};

cf_v6(){
    echo [2606:4700:d$(($(get_rnd_dec) % 2))::$(get_rnd_hex):$(get_rnd_hex):$(get_rnd_hex):$(get_rnd_hex)];
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
        unique='true';
        for index in $@; do
            if [ "$index" == "$ip" ]; then
                unique='false';
            fi;
        done;
        if [ "$unique" == 'true' ]; then
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
    exe_file='warp';
    if [ ! -f $exe_file ]; then
        curl -Sfo $exe_file "https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/warp-yxip/warp-$1"
    fi;
    ulimit -n 102400;
    chmod +x $exe_file && ./$exe_file >/dev/null 2>&1;
    result_file='result.csv'
    if [ -f $result_file ]; then
        ips=$(cat $result_file | awk -F, 'NR != 1 && NR <= '$(($2 + 1))'{print $1}');
        rm -f $result_file;
        echo $ips;
    else
        if [ $debug != 'true' ]; then
            rm -f $exe_file;
        fi;
        exit 1;
    fi;
};

get_ip_cadidates(){
    limit=100
    ip_file='ip.txt'
    for index in $(generate_ips $limit $family); do
        echo "$index" >> $ip_file;
    done;
    if [ $3 == 'true' ]; then
        ip_list=$(speedtest $(archAffix) $1);
    else
        ip_list=$(head -$1 $ip_file | awk '{print $1":"'$2'}');
    fi;
    result=$?;
    if [ $result -ne 0 ]; then
        ip_list=$(head -$1 $ip_file | awk '{print $1":"'$2'}');
    fi;
    rm -f $ip_file;
    echo $ip_list;
    if [ $result -ne 0 ]; then
        exit 1;
    fi;
};

main(){
    num_cadidates=10
    default_port=4500
    dl_retry_times=3
    watch='1.1.1.1';
    threshold=40
    wait_in_between=5
    loss=$(get_ping_loss $watch);
    retry=0;
    while [ $loss -ge $threshold ]; do
        if [ $retry -lt $dl_retry_times ]; then
            cadidates=$(get_ip_cadidates $num_cadidates $default_port true);
        else
            cadidates=$(get_ip_cadidates $num_cadidates $default_port false);
        fi;
        if [ $? -eq 1 ]; then
            retry=$(($retry + 1));
        fi
        for cfip in $cadidates; do
            loss=$(get_ping_loss $watch);
            if [ $loss -lt $threshold ]; then
                break;
            fi;
            echo "changing $interface endpoint to $cfip";
            if [ $debug == 'true' ]; then
                continue;
            fi;
            if [ ! $interface ]; then
                continue;
            fi;
            wg set $interface peer 'bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=' endpoint $cfip;
            sleep $wait_in_between;
        done
    done;
    if [ $debug = 'true' ]; then
        exit 0;
    fi;
    if [ ! $interface ]; then
        exit 0;
    fi;
    if [ ! $config ]; then
        exit 0;
    fi;
    endpoint=$(wg show $interface endpoints | awk '{print $2}');
    if [ $(uname -i) == 'pfSense' ]; then
        if [ $(pfSsh.php playback chgwgpeer $config) != $endpoint ]; then
            pfSsh.php playback chgwgpeer $config $(echo $endpoint|awk -F: '{print $1}') $(echo $endpoint|awk -F: '{print $2}') || true;
        fi;
    fi;
};


pids=$(pgrep -afl $0);
if [ $(echo $pids|grep -o $0|wc -l) -gt 1 ]; then
    exit;
fi;

main
