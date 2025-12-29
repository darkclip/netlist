/ip firewall address-list
remove [find list=List_Private]

add address=10.0.0.0/8 list=List_Private
add address=100.64.0.0/10 list=List_Private
add address=127.0.0.0/8 list=List_Private
add address=169.254.0.0/16 list=List_Private
add address=172.16.0.0/12 list=List_Private
add address=192.0.0.0/24 list=List_Private
add address=192.0.2.0/24 list=List_Private
add address=192.88.99.0/24 list=List_Private
add address=192.168.0.0/16 list=List_Private
add address=198.18.0.0/15 list=List_Private
add address=198.51.100.0/24 list=List_Private
add address=203.0.113.0/24 list=List_Private
add address=224.0.0.0/3 list=List_Private
