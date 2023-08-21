set -Eeuo pipefail

source ./vars.env

# Get options
while getopts "d:sh" flag; do
  case "${flag}" in
    d) DEBUG_LEVEL=${OPTARG};;
    s) SUBSCRIBE_ALL_SUBNETS="--subscribe-all-subnets";;
    h)
       echo "Start a PoN Builder Geth Node"
       echo
       echo "usage: $0 <Options> <DATADIR> <NETWORK-PORT> <HTTP-PORT>"
       echo
       echo "Options:"
       echo "   -h: this help"
       echo
       echo "Positional arguments:"
       echo "  DATADIR       Value for --datadir parameter"
       echo "  NETWORK-PORT  Value for --port"
       echo "  HTTP-PORT     Value for --http.port"
       echo "  AUTH-PORT     Value for --authrpc.port"
       echo "  BEACON-ENDPOINTS  Value for --builder.beacon_endpoints"
       echo "  GENESIS_FILE  Value for geth init"
       exit
       ;;
  esac
done

# Get positional arguments
data_dir=${@:$OPTIND+0:1}
network_port=${@:$OPTIND+1:1}
http_port=${@:$OPTIND+2:1}
auth_port=${@:$OPTIND+3:1}
beacon_endpoints=${@:$OPTIND+4:1}
builder_port=${@:$OPTIND+5:1}
bls_key=${@:$OPTIND+6:1}
wallet_private_key=${@:$OPTIND+7:1}
builder_accesspoint=${@:$OPTIND+8:1}
genesis_file=${@:$OPTIND+9:1}


# Init
$GETH_BINARY init \
    --datadir $data_dir \
    $genesis_file

echo "Completed init"

exec $GETH_BINARY \
    --datadir $data_dir \
    --ipcdisable \
    --http \
    --http.api="engine,eth,web3,net,debug,mev" \
    --networkid=$CHAIN_ID \
    --syncmode=full \
    --bootnodes $EL_BOOTNODE_ENODE \
    --port $network_port \
    --http.port $http_port \
    --authrpc.port $auth_port \
    --builder \
    --builder.beacon_endpoints $beacon_endpoints \
    --builder.relay_endpoint $RELAY_ENDPOINT \
    --builder.secret_key $bls_key \
    --builder.wallet_private_key $wallet_private_key \
    --builder.public_accesspoint $builder_accesspoint \
    --builder.listen_addr 127.0.0.1:$builder_port \
    --builder.rpbs http://localhost:3000 \
    --builder.metrics \
    --builder.metrics_reset \
    --builder.bundles \
    --builder.bundles_reset

echo "Completed PoN Builder start"
echo "PoN Builder is running on http://localhost:10000"
echo "PoN Builder public access point is $BUILDER_PUBLIC_ACCESS_POINT"
echo "PoN Builder is connected to beacon node at $beacon_endpoints"
echo "PoN Builder is connected to relay at $RELAY_ENDPOINT"