#!/usr/bin/env bash
# Start all processes necessary to create a local testnet

set -Eeuo pipefail

source ./vars.env

# Set a higher ulimit in case we want to import 1000s of validators.
ulimit -n 65536

# VC_COUNT is defaulted in vars.env
DEBUG_LEVEL=${DEBUG_LEVEL:-debug}
BUILDER_PROPOSALS="-p"

# Get options
while getopts "v:d:ph" flag; do
  case "${flag}" in
    v) VC_COUNT=${OPTARG};;
    d) DEBUG_LEVEL=${OPTARG};;
    p) BUILDER_PROPOSALS="-p";;
    h)
        validators=$(( $VALIDATOR_COUNT / $BN_COUNT ))
        echo "Start local testnet, defaults: 1 eth1 node, $BN_COUNT beacon nodes,"
        echo "and $VC_COUNT validator clients with each vc having $validators validators."
        echo
        echo "usage: $0 <Options>"
        echo
        echo "Options:"
        echo "   -v: VC_COUNT    default: $VC_COUNT"
        echo "   -d: DEBUG_LEVEL default: info"
        echo "   -p:             enable builder proposals"
        echo "   -h:             this help"
        exit
        ;;
  esac
done

if (( $VC_COUNT > $BN_COUNT )); then
    echo "Error $VC_COUNT is too large, must be <= BN_COUNT=$BN_COUNT"
    exit
fi

if (( $BOOST_VALIDATORS > $BN_COUNT )); then
    echo "Error $BOOST_VALIDATORS is too large, must be <= BN_COUNT=$BN_COUNT"
    exit
fi

if (( $PON_BUILDER_COUNT > $BN_COUNT )); then
    echo "Error $PON_BUILDER_COUNT is too large, must be <= BN_COUNT=$BN_COUNT"
    exit
fi

if (( $PON_BUILDER_COUNT + $BOOST_VALIDATORS > $BN_COUNT )); then
    echo "Error $PON_BUILDER_COUNT  PoN Builder + $BOOST_VALIDATORS Boost Validators is too large, must be <= BN_COUNT=$BN_COUNT"
    exit
fi

echo "Starting local testnet with $VC_COUNT validator clients, $BN_COUNT beacon nodes, with $BOOST_VALIDATORS being mev boost validators/clients."
echo "Number of PoN Builders: $PON_BUILDER_COUNT"

genesis_file=${@:$OPTIND+0:1}

# Init some constants
PID_FILE=$TESTNET_DIR/PIDS.pid
LOG_DIR=$TESTNET_DIR

# Stop local testnet and remove $PID_FILE
./stop_local_testnet.sh

# Clean $DATADIR and create empty log files so the
# user can "tail -f" right after starting this script
# even before its done.
./clean.sh
mkdir -p $LOG_DIR
for (( bn=1; bn<=$BN_COUNT; bn++ )); do
    touch $LOG_DIR/beacon_node_$bn.log
done
for (( el=1; el<=$PON_BUILDER_COUNT; el++ )); do
    touch $LOG_DIR/ponGeth_$el.log
done
for (( el=$PON_BUILDER_COUNT+1; el<=$BN_COUNT; el++ )); do
    touch $LOG_DIR/geth_$el.log
done
for (( vc=1; vc<=$VC_COUNT; vc++ )); do
    touch $LOG_DIR/validator_node_$vc.log
done

# Sleep with a message
sleeping() {
   echo sleeping $1
   sleep $1
}

# Execute the command with logs saved to a file.
#
# First parameter is log file name
# Second parameter is executable name
# Remaining parameters are passed to executable
execute_command() {
    LOG_NAME=$1
    EX_NAME=$2
    shift
    shift
    CMD="$EX_NAME $@ >> $LOG_DIR/$LOG_NAME 2>&1"
    echo "executing: $CMD"
    echo "$CMD" > "$LOG_DIR/$LOG_NAME"
    eval "$CMD &"
}

# Execute the command with logs saved to a file
# and is PID is saved to $PID_FILE.
#
# First parameter is log file name
# Second parameter is executable name
# Remaining parameters are passed to executable
execute_command_add_PID() {
    execute_command $@
    echo "$!" >> $PID_FILE
}


# Setup data
echo "executing: ./setup.sh >> $LOG_DIR/setup.log"
./setup.sh >> $LOG_DIR/setup.log 2>&1

# Update future hardforks time in the EL genesis file based on the CL genesis time
GENESIS_TIME=$(lcli pretty-ssz state_merge $TESTNET_DIR/genesis.ssz  | jq | grep -Po 'genesis_time": "\K.*\d')
echo $GENESIS_TIME
CAPELLA_TIME=$((GENESIS_TIME + (CAPELLA_FORK_EPOCH * 32 * SECONDS_PER_SLOT)))
echo $CAPELLA_TIME
sed -i 's/"shanghaiTime".*$/"shanghaiTime": '"$CAPELLA_TIME"',/g' $genesis_file
# cat $genesis_file

# Delay to let boot_enr.yaml to be created
execute_command_add_PID bootnode.log ./bootnode.sh
sleeping 1

execute_command_add_PID el_bootnode.log ./el_bootnode.sh
sleeping 1

# Start beacon nodes
BN_udp_tcp_base=9000
BN_http_port_base=3000

EL_base_network=7000
EL_base_http=4000
EL_base_auth_http=5000

VC_port_base=6000

PON_BUILDER_http=10000

BOOST_http_port_base=18551

(( $VC_COUNT < $BN_COUNT )) && SAS=-s || SAS=

# start pon builder geth nodes
for (( el=1; el<=$PON_BUILDER_COUNT; el++ )); do
    BUILDER_BLS_SECRET_KEY=$(eval echo \$BUILDER_BLS_SECRET_KEY_$el)
    BUILDER_WALLET_PRIVATE_KEY=$(eval echo \$BUILDER_WALLET_PRIVATE_KEY_$el)
    BUILDER_PUBLIC_ACCESS_POINT=$(eval echo \$BUILDER_PUBLIC_ACCESS_POINT_$el)

    execute_command_add_PID ponGeth_$el.log ./ponGeth.sh $DATADIR/geth_datadir$el $((EL_base_network + $el)) $((EL_base_http + $el)) $((EL_base_auth_http + $el)) http://localhost:$((BN_http_port_base + $el)) $((PON_BUILDER_http + $el)) $BUILDER_BLS_SECRET_KEY $BUILDER_WALLET_PRIVATE_KEY $BUILDER_PUBLIC_ACCESS_POINT $genesis_file
done


# Start geth nodes normally, not as a PoN builder
for (( el=$PON_BUILDER_COUNT+1; el<=$BN_COUNT; el++ )); do
    execute_command_add_PID geth_$el.log ./geth.sh $DATADIR/geth_datadir$el $((EL_base_network + $el)) $((EL_base_http + $el)) $((EL_base_auth_http + $el)) $genesis_file
done

sleeping 20

# Reset the `genesis.json` config file fork times.
sed -i 's/"shanghaiTime".*$/"shanghaiTime": 0,/g' $genesis_file

# Start non-MEV beacon nodes
for (( bn=1; bn<=$BN_COUNT-$BOOST_VALIDATORS; bn++ )); do
    secret=$DATADIR/geth_datadir$bn/geth/jwtsecret
    echo $secret
    execute_command_add_PID beacon_node_$bn.log ./beacon_node.sh $SAS -d $DEBUG_LEVEL $DATADIR/node_$bn $((BN_udp_tcp_base + $bn)) $((BN_http_port_base + $bn)) http://localhost:$((EL_base_auth_http + $bn)) $secret
done

# Start MEV beacon nodes
for (( bn=$BN_COUNT-$BOOST_VALIDATORS+1; bn<=$BN_COUNT; bn++ )); do
    secret=$DATADIR/geth_datadir$bn/geth/jwtsecret
    echo $secret
    echo "Starting MEV Boost node $bn on port $((BN_http_port_base + $bn)) with boost port $((BOOST_http_port_base))"
    execute_command_add_PID beacon_node_$bn.log ./beacon_node.sh $SAS -b http://localhost:$((BOOST_http_port_base)) -d $DEBUG_LEVEL $DATADIR/node_$bn $((BN_udp_tcp_base + $bn)) $((BN_http_port_base + $bn)) http://localhost:$((EL_base_auth_http + $bn)) $secret
done

# Start validator clients that are not running MEV Boost
for (( vc=1; vc<=$VC_COUNT-$BOOST_VALIDATORS; vc++ )); do
    execute_command_add_PID validator_node_$vc.log ./validator_client.sh -d $DEBUG_LEVEL $DATADIR/node_$vc $((VC_port_base + $vc)) http://localhost:$((BN_http_port_base + $vc))
done

# Start validator clients that are running MEV Boost
for (( vc=$VC_COUNT-$BOOST_VALIDATORS+1; vc<=$VC_COUNT; vc++ )); do
    execute_command_add_PID validator_node_$vc.log ./validator_client.sh $BUILDER_PROPOSALS -d $DEBUG_LEVEL $DATADIR/node_$vc $((VC_port_base + $vc)) http://localhost:$((BN_http_port_base + $vc))
done

echo "Started!"
