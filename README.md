# Simple Local Testnet

These scripts allow for running a small local testnet with multiple beacon nodes and validator clients and a geth execution client with PoN Builder enabled, and other geth clients without the builder enabled.
This additionally sets a specified number of validator nodes to run MEV Boost for block proposals through a relay or connected builder.

## Requirements

The scripts require `lcli`, `lighthouse` (at the time of writing we have been using the `unstable` branch for the local testnet), `geth` (PoN Builder version), `bootnode` to be installed on `PATH`.

Note: In order to get the testnet working and builders building blocks with withdrawals, we start all validators on the local testnet with the same ETH1 ECDSA withdrawal credentials. Otherwise, the builder and relayer will refuse to build and accept blocks respectively and in a real testnet / mainnet environment there is not a scenario where there would be zero withdrawals so we want to be as representative as possible. There will be a pull request open to Lighthouse with these changes.

Ensure your user or the scripts have permissions to create and delete files in the current directory, and execute binaries in the current directory.

MacOS users need to install GNU `sed` and GNU `grep`, and add them both to `PATH` as well.

From the
root of this repository, run:

```bash
make
make install-lcli
```

## Starting the testnet

Modify `vars.env` as desired.

The testnet starts with a post-merge genesis state. 
Start a consensus layer and execution layer boot node along with `BN_COUNT`
number of beacon nodes each connected to a geth execution client and `VC_COUNT` validator clients. Where `BOOST_VALIDATORS` number of validators from `VC_COUNT` that are set to run MEV Boost for block proposals through a relay or connected builder.

The `start_local_testnet.sh` script takes four options `-v VC_COUNT`, `-d DEBUG_LEVEL`, `-p` to enable builder proposals and `-h` for help. It also takes a mandatory `GENESIS_FILE` for initialising geth's state.
A sample `genesis.json` is provided in this directory.

The `ETH1_BLOCK_HASH` environment variable is set to the block_hash of the genesis execution layer block which depends on the contents of `genesis.json`. Users of these scripts need to ensure that the `ETH1_BLOCK_HASH` variable is updated if genesis file is modified.

To update this, run the netowrk, and query for the first block (block 0) using the geth client. The block hash can then be obtained from the output and set as the `ETH1_BLOCK_HASH` variable. Stop and restart the network for the change to take effect and for the chain to progress using this valid hash now.

The options may be in any order or absent in which case they take the default value specified.
- VC_COUNT: the number of validator clients to create, default: `BN_COUNT`
- DEBUG_LEVEL: one of { error, warn, info, debug, trace }, default: `info`



```bash
./start_local_testnet.sh genesis.json -p
```

The PoN Builder is by default enabled on the first geth execution client. Needed parameters are set in `vars.env` and `start_local_testnet.sh` script. The PoN Builder requires `RELAY_ENDPOINT`, `BUILDER_BLS_SECRET_KEY`, `BUILDER_WALLET_PRIVATE_KEY`, and `BUILDER_PUBLIC_ACCESS_POINT` to be set according to PoN Builder flag requirements.

## Stopping the testnet

This is not necessary before `start_local_testnet.sh` as it invokes `stop_local_testnet.sh` automatically.
```bash
./stop_local_testnet.sh
```

### Starting fresh

Delete the current testnet and all related files using. Generally not necessary as `start_local_test.sh` does this each time it starts.

```bash
./clean.sh
```

### Updating the genesis time of the beacon state

If it's been a while since you ran `./setup` then the genesis time of the
genesis state will be far in the future, causing lots of skip slots.

Update the genesis time to now using:

```bash
./reset_genesis_time.sh
```

> Note: you probably want to just rerun `./start_local_testnet.sh` to start over
> but this is another option.
