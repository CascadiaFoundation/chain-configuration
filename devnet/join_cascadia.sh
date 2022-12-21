#!/bin/bash -i

##### CONFIGURATION ###

export CASCADIA_BRANCH=v0.1.1
export GENESIS_ZIPPED_URL=https://github.com/CascadiaFoundation/chain-configuration/raw/master/devnet/genesis.json.gz
export NODE_HOME=$HOME/.cascadiad
export CHAIN_ID=cascadia_9000-1
export NODE_MONIKER=my-node # only really need to change this one
export BINARY=cascadiad
export SEEDS="42792ba4376fcc0b5b469b05668b1fad51589d25@18.211.35.61:26656,dbf158f0e1d94f5bee310ed298becc0c7097545c@44.211.12.215:26656"
export PERSISTENT_PEERS="42792ba4376fcc0b5b469b05668b1fad51589d25@18.211.35.61:26656,dbf158f0e1d94f5bee310ed298becc0c7097545c@44.211.12.215:26656"

##### OPTIONAL STATE SYNC CONFIGURATION ###

# export STATE_SYNC=true # if you set this to true, please have TRUST HEIGHT and TRUST HASH and RPC configured
# export TRUST_HEIGHT=9500000
# export TRUST_HASH="92ABB312DFFA04D3439C5A0F74A07F46843ADC4EB391A723EAE00855ADECF5A4"
# export SYNC_RPC="rpc.sentry-01.theta-testnet.polypore.xyz:26657,rpc.sentry-02.theta-testnet.polypore.xyz:26657"

############## 

# you shouldn't need to edit anything below this

echo ">>>>>>>>>>> Updating apt-get..."
sudo apt-get update

echo ">>>>>>>>>>> Getting essentials..."
sudo apt-get install git build-essential ntp

echo ">>>>>>>>>>> Installing go..."
wget -q -O - https://git.io/vQhTU | bash -s - --version 1.18

echo ">>>>>>>>>>> Sourcing bashrc to get go in our path..."
source $HOME/.bashrc

export GOROOT=$HOME/.go
export PATH=$GOROOT/bin:$PATH
export GOPATH=/root/go
export PATH=$GOPATH/bin:$PATH

echo ">>>>>>>>>>> getting chain binary file"
wget https://github.com/CascadiaFoundation/cascadia-chain/releases/download/v0.1.1/cascadiad-v0.1.1-linux-amd64
mv cascadiad-v0.1.1-linux-amd64 $HOME/go/bin/cascadiad
chmod u+x $HOME/go/bin/cascadiad

echo ">>>>>>>>>>> getting genesis file"
wget $GENESIS_ZIPPED_URL
gunzip genesis.json.gz 

echo ">>>>>>>>>>> configuring chain..."
rm $NODE_HOME/config/genesis.json
$BINARY config chain-id $CHAIN_ID --home $NODE_HOME
$BINARY config keyring-backend test --home $NODE_HOME
$BINARY config broadcast-mode block --home $NODE_HOME
$BINARY init $NODE_MONIKER --home $NODE_HOME --chain-id=$CHAIN_ID

# if $STATE_SYNC; then
#     echo "enabling state sync..."
#     sed -i -e '/enable =/ s/= .*/= true/' $NODE_HOME/config/config.toml
#     sed -i -e "/trust_height =/ s/= .*/= $TRUST_HEIGHT/" $NODE_HOME/config/config.toml
#     sed -i -e "/trust_hash =/ s/= .*/= \"$TRUST_HASH\"/" $NODE_HOME/config/config.toml
#     sed -i -e "/rpc_servers =/ s/= .*/= \"$SYNC_RPC\"/" $NODE_HOME/config/config.toml
# else
#     echo "disabling state sync..."
# fi

# Set minimum gas price & peers
echo ">>>>>>>>>>> Set minimum gas price & peers..."
cd $HOME/.cascadiad/config
sed -i 's/minimum-gas-prices = ""/minimum-gas-prices = "0.001uCC"/' app.toml

echo ">>>>>>>>>>> copying over genesis file..."
cp genesis.json $NODE_HOME/config/genesis.json

echo ">>>>>>>>>>> setup cosmovisor dirs..."
mkdir -p $NODE_HOME/cosmovisor/genesis/bin

echo ">>>>>>>>>>> copy binary over..."
cp $(which cascadiad) $NODE_HOME/cosmovisor/genesis/bin

echo ">>>>>>>>>>> re-export binary"
export BINARY=$NODE_HOME/cosmovisor/genesis/bin/cascadiad
chmod 777 $BINARY

echo ">>>>>>>>>>> install cosmovisor"
export GO111MODULE=on
go install github.com/cosmos/cosmos-sdk/cosmovisor/cmd/cosmovisor@v1.0.0

echo ">>>>>>>>>>> setup systemctl"
sudo touch /etc/systemd/system/$NODE_MONIKER.service

sudo echo "[Unit]"                               > /etc/systemd/system/$NODE_MONIKER.service
sudo echo "Description=cosmovisor-$NODE_MONIKER" >> /etc/systemd/system/$NODE_MONIKER.service
sudo echo "After=network-online.target"          >> /etc/systemd/system/$NODE_MONIKER.service
sudo echo ""                                     >> /etc/systemd/system/$NODE_MONIKER.service
sudo echo "[Service]"                            >> /etc/systemd/system/$NODE_MONIKER.service
sudo echo "User=root"                        >> /etc/systemd/system/$NODE_MONIKER.service
sudo echo "ExecStart=/root/go/bin/cosmovisor start --x-crisis-skip-assert-invariants --home \$DAEMON_HOME --p2p.seeds $SEEDS --p2p.persistent_peers $PERSISTENT_PEERS"  >> /etc/systemd/system/$NODE_MONIKER.service
sudo echo "Restart=always"                       >> /etc/systemd/system/$NODE_MONIKER.service
sudo echo "RestartSec=3"                         >> /etc/systemd/system/$NODE_MONIKER.service
sudo echo "LimitNOFILE=4096"                     >> /etc/systemd/system/$NODE_MONIKER.service
sudo echo "Environment='DAEMON_NAME=cascadiad'"      >> /etc/systemd/system/$NODE_MONIKER.service
sudo echo "Environment='DAEMON_HOME=$NODE_HOME'" >> /etc/systemd/system/$NODE_MONIKER.service
sudo echo "Environment='DAEMON_ALLOW_DOWNLOAD_BINARIES=true'" >> /etc/systemd/system/$NODE_MONIKER.service
sudo echo "Environment='DAEMON_RESTART_AFTER_UPGRADE=true'" >> /etc/systemd/system/$NODE_MONIKER.service
sudo echo "Environment='DAEMON_LOG_BUFFER_SIZE=512'" >> /etc/systemd/system/$NODE_MONIKER.service
sudo echo ""                                     >> /etc/systemd/system/$NODE_MONIKER.service
sudo echo "[Install]"                            >> /etc/systemd/system/$NODE_MONIKER.service
sudo echo "WantedBy=multi-user.target"           >> /etc/systemd/system/$NODE_MONIKER.service

echo ">>>>>>>>>>> reload systemd..."
sudo systemctl daemon-reload

echo ">>>>>>>>>>> starting the daemon..."
sudo systemctl start $NODE_MONIKER.service

echo "***********************"
echo "find logs like this:"
echo "sudo journalctl -fu $NODE_MONIKER.service"
echo "***********************"
