/ipv6 firewall address-list
remove [find list=List_Private]

add address=::1/128 list=List_Private
add address=fc00::/7 list=List_Private
add address=fe80::/10 list=List_Private
add address=ff00::/8 list=List_Private
