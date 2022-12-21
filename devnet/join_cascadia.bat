
rem evmos compile on windows
rem install golang , gcc, sed for windows
rem 1. install msys2 : https://www.msys2.org/
rem 2. pacman -S mingw-w64-x86_64-toolchain
rem    pacman -S sed
rem    pacman -S mingw-w64-x86_64-jq
rem 3. add path C:\msys64\mingw64\bin  
rem             C:\msys64\usr\bin

set KEY="mykey"
set CHAINID="cascadia_9000-1"
set MONIKER="localtestnet"
set KEYRING="test"
set KEYALGO="eth_secp256k1"
set LOGLEVEL="info"
set GENESIS_ZIPPED_URL=https://github.com/CascadiaFoundation/chain-configuration/raw/master/devnet/genesis.json.gz
set SEEDS="42792ba4376fcc0b5b469b05668b1fad51589d25@18.211.35.61:26656,dbf158f0e1d94f5bee310ed298becc0c7097545c@44.211.12.215:26656"
set PERSISTENT_PEERS="42792ba4376fcc0b5b469b05668b1fad51589d25@18.211.35.61:26656,dbf158f0e1d94f5bee310ed298becc0c7097545c@44.211.12.215:26656"

# to trace evm
#TRACE="--trace"
set TRACE=""
set HOME=%USERPROFILE%\.cascadiad
echo %HOME%
set ETHCONFIG=%HOME%\config\config.toml
set GENESIS=%HOME%\config\genesis.json
set TMPGENESIS=%HOME%\config\tmp_genesis.json

@echo getting chain binary file
wget https://github.com/CascadiaFoundation/cascadia-chain/releases/download/v0.1.1/cascadiad-v0.1.1-windows-amd64.exe
mv cascadiad-v0.1.1-windows-amd64.exe %HOME%\cascadiad


@echo clear home folder
del /s /q %HOME%

cascadiad config keyring-backend %KEYRING%
cascadiad config chain-id %CHAINID%

cascadiad keys add %KEY% --keyring-backend %KEYRING% --algo %KEYALGO%

rem Set moniker and chain-id for Evmos (Moniker can be anything, chain-id must be an integer)
cascadiad init %MONIKER% --chain-id %CHAINID% 

@REM rem Change parameter token denominations to uCC
@REM cat %GENESIS% | jq ".app_state[\"staking\"][\"params\"][\"bond_denom\"]=\"uCC\""   >   %TMPGENESIS% && move %TMPGENESIS% %GENESIS%
@REM cat %GENESIS% | jq ".app_state[\"crisis\"][\"constant_fee\"][\"denom\"]=\"uCC\"" > %TMPGENESIS% && move %TMPGENESIS% %GENESIS%
@REM cat %GENESIS% | jq ".app_state[\"gov\"][\"deposit_params\"][\"min_deposit\"][0][\"denom\"]=\"uCC\"" > %TMPGENESIS% && move %TMPGENESIS% %GENESIS%
@REM cat %GENESIS% | jq ".app_state[\"mint\"][\"params\"][\"mint_denom\"]=\"uCC\"" > %TMPGENESIS% && move %TMPGENESIS% %GENESIS%

@REM rem increase block time (?)
@REM cat %GENESIS% | jq ".consensus_params[\"block\"][\"time_iota_ms\"]=\"30000\"" > %TMPGENESIS% && move %TMPGENESIS% %GENESIS%

@REM rem gas limit in genesis
@REM cat %GENESIS% | jq ".consensus_params[\"block\"][\"max_gas\"]=\"10000000\"" > %TMPGENESIS% && move %TMPGENESIS% %GENESIS%

@REM rem setup
@REM sed -i "s/create_empty_blocks = true/create_empty_blocks = false/g" %ETHCONFIG%

@REM rem Allocate genesis accounts (cosmos formatted addresses)
@REM cascadiad add-genesis-account %KEY% 100000000000000000000000000uCC --keyring-backend %KEYRING%

@REM rem Sign genesis transaction
@REM cascadiad gentx %KEY% 1000000000000000000000uCC --keyring-backend %KEYRING% --chain-id %CHAINID%

@REM rem Collect genesis tx
@REM cascadiad collect-gentxs

@REM rem Run this to ensure everything worked and that the genesis file is setup correctly
@REM cascadiad validate-genesis



@REM rem Start the node (remove the --pruning=nothing flag if historical queries are not needed)
@REM cascadiad start --pruning=nothing %TRACE% --log_level %LOGLEVEL% --minimum-gas-prices=0.0001uCC
