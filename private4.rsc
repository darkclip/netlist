/ip firewall address-list
remove [find list=List_Private]

add address=10.0.0.0/8 list=List_Private
add address=172.16.0.0/12 list=List_Private
add address=192.168.0.0/16 list=List_Private
add address=198.18.0.0/15 list=List_Private
