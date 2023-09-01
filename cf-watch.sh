dev=$1;

pids=$(pgrep -afl $0);
if [ "$(echo $pids|awk '{print $1}')" != "$$" ]; then
    exit;
fi

get_rnd(){
    echo $(od -An -N2 -i /dev/random);
    return $?;
};

get_ping_loss(){
    loss_percent=$(ping -c 10 -qn $1 | awk '/packet loss/{for(i=6;i<=NF;i++)if($i ~ /packet/)print $((i-1))}');
    loss=${loss_percent%?};
    echo ${loss%.*};
    return $?;
};

cf_v4(){
    echo 188.114.$((($(get_rnd) % 4) + 96)).$((($(get_rnd) % 253) + 1));
    return $?;
};

cf_v6(){
    hex=$(head /dev/urandom | md5sum | head -c 16);
    hex1=$(echo $hex | awk '{print substr($0,1,4)}');
    hex2=$(echo $hex | awk '{print substr($0,5,4)}');
    hex3=$(echo $hex | awk '{print substr($0,9,4)}');
    hex4=$(echo $hex | awk '{print substr($0,13,4)}');
    echo 2606:4700:d$(($(get_rnd) % 2))::$hex1:$hex2:$hex3:$hex4;
    return $?;
};

watch="1.1.1.1";
loss=$(get_ping_loss $watch);
while [ $loss -gt 30 ]; do
    cfip=$(cf_v4);
    echo "changing $dev endpoint to $cfip";
    wg set $dev peer "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=" endpoint "$cfip:4500";
    pfSsh.php playback chgwgpeer 0 $cfip 4500 || true;
    sleep 5;
    loss=$(get_ping_loss $watch);
done;
