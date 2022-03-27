#!/bin/bash

# Script to update dyndns at strato for any domain name given the
# IPv6 address and the password. Or the IPv6 address can be omitted,
# then it will be inferred from the system's NIC's, and will just use
# the first non-deprecated global unicast IPv6 address it finds.

#----------------------------------------------------------------------------------------------

get_ipv6_guc_address () {
    # this will outputs something like
    # <dev> UP <IPV6ADDR>/<PREFIXLEN>
    local current_primary_ipv6_guc_address="$(ip -6 -brief address show scope global -deprecated | head -n1)"
    local device="$(echo $current_primary_ipv6_guc_address | cut -d ' ' -f1)"
    local ipv6_address_full="$(echo $current_primary_ipv6_guc_address | cut -d ' ' -f3)"
    # trim away the prefix length part, probably something like "/64"
    local ipv6_address="${ipv6_address_full:0:-3}"
    echo $ipv6_address
}

do_ddns_update() {
    # arguments: 
    #   $1: name of the domain to update
    #   $2: DYNDNS password, set in strato admin setings
    #   $3: ipv6 address to set
    echo "Will try to publish the address $3 for hostname $1."
    echo "The answer of the DynDNS server will be printed below. You can"
    echo "assume that it has succeeded if it prints good or nochg."
    local answer=$(curl -s -u "$1:$2" "https://dyndns.strato.com/nic/update?hostname=$1&myip=$3")
    echo "$answer"
    local first_word="$(echo $answer | cut -d ' ' -f1)"
    if [[ $first_word == good ]]; then
        exit 0
    elif [[ $first_word == nochg ]]; then
        exit 0
    else
        exit 1
    fi
}

#----------------------------------------------------------------------------------------------
# MAIN SCRIPT: parse options

print_usage () {
    echo "Usage: $(basename $0) -n DOMAIN -p PASSWD [-a ADDRESS]" 2>&1
    echo 'Update the given DOMAIN, which is registered by STRATO and set to DYNDNS,'
    echo 'to the given IPv6 address, or infer the primary IPv6 global unicast of any'
    echo 'connected NIC and use that.'
    echo '  -h, --help             Print this usage information'
    echo '  -n, --name DOMAIN      The domain name to udpate the IPv6 address of'
    echo '  -p, --pass PASSWD      The STRATO DynDNS password to authenticate the update'
    echo '  -a, --address ADDRESS  The address to update the domain name with. If not given,'
    echo '                         use the first active global unicast address found for any NIC.'
    exit 1
}

# if no arguments were given, just print out usage info and exit
if [[ ${#} -eq 0 ]]; then
   print_usage
fi

# parse options

DOMAIN=""
PASSWD=""
ADDRESS="$(get_ipv6_guc_address)"

# now enjoy the options in order and nicely split until we see --
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -h|--help)      print_usage;;
        -n|--name)      DOMAIN="$2"; shift ;;
        -p|--pass)      PASSWD="$2"; shift ;;
        -a|--address)   ADDRESS="$2"; shift ;;
        *)  echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# run script
do_ddns_update "$DOMAIN" "$PASSWD" "$ADDRESS"
