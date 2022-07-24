# Open Source Pizza
distribute open source sponsorship using smart contracts

## Set up
```
npm install

npm install -g truffle
```

### Install Geth on Mac
```
brew tap ethereum/ethereum
brew install ethereum
```

### Set up testnet accounts
1. export wallet account mnemonic and save to `.secret`
1. export wallet address 0 private key and save to <keyfile>

## Compile contracts
```
truffle compile
```

## Deploy contracts to Ropsten testnet
```
# start local ethereum ropsten node
geth account import <keyfile>
geth --ropsten --http --http.port 8545 --http.api eth,net,web3,personal

truffle migrate --network development
```


