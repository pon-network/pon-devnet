#!/usr/bin/env bash

#
# Starts a validator client based upon a genesis state created by
# `./setup.sh`.
#
# Usage: ./validator_client.sh <DATADIR> <BEACON-NODE-HTTP> <OPTIONAL-DEBUG-LEVEL>

set -Eeuo pipefail

source ./vars.env

DEBUG_LEVEL=info

BUILDER_PROPOSALS=

# Get options
while getopts "pd:" flag; do
  case "${flag}" in
    p) BUILDER_PROPOSALS="--builder-proposals";;
    d) DEBUG_LEVEL=${OPTARG};;
  esac
done

echo "Starting validator client with debug level: $DEBUG_LEVEL and builder proposals: $BUILDER_PROPOSALS"
echo "Validator api will be available at: 0.0.0.0:${@:$OPTIND+1:1}"
echo "Validator client will connect to beacon node at: ${@:$OPTIND+2:1}"

exec lighthouse \
	--debug-level $DEBUG_LEVEL \
	vc \
	$BUILDER_PROPOSALS \
	--datadir ${@:$OPTIND:1} \
	--testnet-dir $TESTNET_DIR \
	--http \
	--http-port ${@:$OPTIND+1:1} \
	--http-address 0.0.0.0 \
	--unencrypted-http-transport \
	--init-slashing-protection \
	--beacon-nodes ${@:$OPTIND+2:1} \
	--suggested-fee-recipient 0x690B9A9E9aa1C9dB991C7721a92d351Db4FaC990 \
	$VC_ARGS
