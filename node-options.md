# PulseChain Archive Node Customization Options

This document lists all the customization options available for your PulseChain Archive Node. As an archive node, certain parameters require specific settings to properly maintain full historical data.

## Execution Client (go-pulse) Options

### Basic Configuration
- `--datadir` - Data directory for the blockchain data (where all blockchain data will be stored)
- `--syncmode` - Blockchain sync mode (archive, full, light). **For archive nodes, this must be set to `archive`** to retain all historical state data
- `--network` - Network to connect to (pulsechain, pulsechain-testnet-v4)

### Network Options
- `--maxpeers` - Maximum number of network peers (default: 50). Higher values can improve sync speed but increase bandwidth usage
- `--maxpendpeers` - Maximum number of pending connection attempts (default: 100)
- `--port` - Network listening port (default: 30303). Ensure this port is accessible if behind a firewall

### Performance Options
- `--cache` - Memory allocated to internal caching in MB (default: 4096). Higher values improve performance on systems with more RAM
- `--cache.database` - Percentage of cache memory allocated to database (default: 50)
- `--cache.trie` - Percentage of cache memory allocated to trie caching (default: 25)
- `--cache.gc` - Percentage of cache memory allocated to garbage collection (default: 25)

### API & Interface
- `--http` - Enable the HTTP-RPC server. Required if you want to connect to the node with tools or applications
- `--http.addr` - HTTP-RPC server listening interface (default: "localhost"). Set to "0.0.0.0" to allow external connections
- `--http.port` - HTTP-RPC server listening port (default: 8545)
- `--http.api` - APIs offered over the HTTP-RPC interface (comma-separated list such as "eth,net,web3")
- `--http.corsdomain` - Comma-separated list of domains to accept cross-origin requests
- `--ws` - Enable the WS-RPC server. Required for applications that use WebSocket connections
- `--ws.addr` - WS-RPC server listening interface (default: "localhost")
- `--ws.port` - WS-RPC server listening port (default: 8546)

### Advanced Options
- `--state.gc-mode` - Garbage collection mode ("full", "archive") (default: "full"). **For archive nodes, this should be set to `archive`** to prevent pruning of historical states
- `--metrics` - Enable metrics collection and reporting. Useful for monitoring node performance
- `--metrics.addr` - Metrics reporting server interface (default: "127.0.0.1")
- `--metrics.port` - Metrics reporting server port (default: 6060)

## Consensus Client (lighthouse) Options

### Basic Configuration
- `--datadir` - Path to the directory where all beacon node data is stored
- `--network` - The chain network to use (pulsechain, pulsechain-testnet-v4)

### Network Options
- `--port` - The TCP/UDP port to listen on (default: 9000)
- `--target-peers` - The target number of peers (default: 50). Affects network bandwidth usage and sync performance
- `--boot-nodes` - ENR, multiaddr, or /dns4/... address of peer to connect to. Helps node discover the network

### API & Interface
- `--http` - Enable the HTTP API server. Required to interact with the beacon node
- `--http-address` - The address to listen on for HTTP API requests (default: 127.0.0.1)
- `--http-port` - The port to listen on for HTTP API requests (default: 5052)
- `--http-allow-origin` - A comma-separated list of HTTP origins to allow, or "*" to allow any origin

### Performance Options
- `--validator-monitor-auto` - Enable automatic detection of validators attached to this beacon node
- `--validator-monitor-pubkeys` - A comma-separated list of 0x-prefixed validator public keys to monitor

### Advanced Options
- `--checkpoint-sync-url` - The URL to download checkpoint sync data from (only for testnet v4)
- `--genesis-beacon-api-url` - URL to download genesis state for checkpoint sync
- `--execution-timeout` - Max time to wait for execution engine response (in seconds)

## Example Configuration

Below is an example of what your `/blockchain/node_config.env` might look like for an archive node:

```
# Execution client settings
DATADIR=/blockchain/data
SYNCMODE=archive
NETWORK=pulsechain
HTTP=true
HTTP_ADDR=0.0.0.0
HTTP_PORT=8545
HTTP_API=eth,net,web3,txpool,debug
CACHE=8192
STATE_GC_MODE=archive

# Consensus client settings
LIGHTHOUSE_DATADIR=/blockchain/consensus
LIGHTHOUSE_HTTP=true
LIGHTHOUSE_HTTP_ADDRESS=0.0.0.0
LIGHTHOUSE_HTTP_PORT=5052
```

## Modifying Parameters

You can modify these parameters in three ways:

1. **During Installation**: The installer will prompt for key parameters
2. **Editing Configuration**: Modify `/blockchain/node_config.env` directly
3. **Recreating Containers**: Stop containers with `./shutdown.sh`, edit parameters, then restart

## Important Notes

- **Archive Node Requirements**: Running a proper archive node requires setting both `--syncmode=archive` and `--state.gc-mode=archive`
- **Resource Usage**: Archive nodes require significant storage (often 1TB+ for PulseChain) and benefit from 16GB+ RAM
- **Parameter Changes**: Changing parameters like `--datadir`, `--network`, or `--syncmode` requires restarting the node
- **Default Values**: Default values are optimized for most users - modify with caution
- **Advanced Parameters**: Advanced parameters should only be changed if you understand their impact
- **Network Exposure**: Setting address parameters to "0.0.0.0" exposes services to the network - ensure proper firewall rules are in place 