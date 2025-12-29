/ipv6 firewall address-list
remove [find list=List_Private]

add address=::1/128 list=List_Private
add address=fc00::/6 list=List_Private
