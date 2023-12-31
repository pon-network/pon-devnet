#!/usr/bin/env bash

#
# Starts a beacon node based upon a genesis state created by `./setup.sh`.
#

set -Eeuo pipefail

source ./vars.env

SUBSCRIBE_ALL_SUBNETS=
DEBUG_LEVEL=${DEBUG_LEVEL:-debug}
BOOST_ENDPOINT=

# Get options
while getopts "b:d:sh" flag; do
  case "${flag}" in
    b) BOOST_ENDPOINT="--builder ${OPTARG}";; # e.g. --builder http://localhost:18550
    d) DEBUG_LEVEL=${OPTARG};;
    s) SUBSCRIBE_ALL_SUBNETS="--subscribe-all-subnets";;
    h)
       echo "Start a beacon node"
       echo
       echo "usage: $0 <Options> <DATADIR> <NETWORK-PORT> <HTTP-PORT>"
       echo
       echo "Options:"
       echo "   -s: pass --subscribe-all-subnets to 'lighthouse bn ...', default is not passed"
       echo "   -b: BOOST_ENDPOINT, default is not passed"
       echo "   -d: DEBUG_LEVEL, default info"
       echo "   -h: this help"
       echo
       echo "Positional arguments:"
       echo "  DATADIR       Value for --datadir parameter"
       echo "  NETWORK-PORT  Value for --enr-udp-port, --enr-tcp-port and --port"
       echo "  HTTP-PORT     Value for --http-port"
       echo "  EXECUTION-ENDPOINT     Value for --execution-endpoint"
       echo "  EXECUTION-JWT     Value for --execution-jwt"
       exit
       ;;
  esac
done

# Get positional arguments
data_dir=${@:$OPTIND+0:1}
network_port=${@:$OPTIND+1:1}
http_port=${@:$OPTIND+2:1}
execution_endpoint=${@:$OPTIND+3:1}
execution_jwt=${@:$OPTIND+4:1}

lighthouse_binary=lighthouse

echo "Starting beacon node with:"
echo "  data_dir: $data_dir"
echo "  network_port: $network_port"
echo "  http_port: $http_port"
echo "  execution_endpoint: $execution_endpoint"
echo "  execution_jwt: $execution_jwt"
echo "  SUBSCRIBE_ALL_SUBNETS: $SUBSCRIBE_ALL_SUBNETS"
echo "  DEBUG_LEVEL: $DEBUG_LEVEL"
echo "  BOOST_ENDPOINT: $BOOST_ENDPOINT"

exec $lighthouse_binary \
	--debug-level $DEBUG_LEVEL \
	bn \
	$SUBSCRIBE_ALL_SUBNETS \
  $BOOST_ENDPOINT \
	--datadir $data_dir \
	--testnet-dir $TESTNET_DIR \
	--enable-private-discovery \
  --disable-peer-scoring \
	--staking \
	--enr-address 127.0.0.1 \
	--enr-udp-port $network_port \
	--enr-tcp-port $network_port \
	--port $network_port \
	--http \
	--http-port $http_port \
	--http-address 0.0.0.0 \
	--disable-packet-filter \
	--target-peers $((BN_COUNT - 1)) \
  --execution-endpoint $execution_endpoint \
  --execution-jwt $execution_jwt \
  --always-prepare-payload \
  --prepare-payload-lookahead 12000
