# WalletKit-iOS
Bitcoin and Bitcoin Cash protocols SPV wallet toolkit for Swift

## Usage

##### Example project:  
All features of the library are used in example project. It can be referred as a starting point for usage of the library.
- [Example Project](https://github.com/horizontalsystems/wallet-kit-ios/tree/dev/Example)

### HD Wallet

#### Generate new mnemonic words

```swift
let words = try? Mnemonic.generate(strength: .default, language: .english)
```

#### Validate words from user input

```swift
do {
    try Mnemonic.validate(words: words)
} catch Mnemonic.ValidationError {
}
```

### WalletKit

In order to work with a certain blockchain a `WalletKit` instance should be created and retained:

```swift
let bitcoinWalletKit = WalletKit(withWords: words, networkType: .bitcoinMainNet)
let bitcoinCashWalletKit = WalletKit(withWords: words, networkType: .bitcoinCashMainNet)
```

#### Getting data from WalletKit

`WalletKit` can return any required synced data for its blockchain:

```swift
let walletKit = WalletKit(withWords: words, networkType: .bitcoinMainNet)

let balance = walletKit.balance                   // balance in Sartoshis, e.g. 12500000 (0.125 BTC)
let progress = walletKit.progress                 // current sync progress, e.g. 0.25 (25%)
let lastBlockHeight = walletKit.lastBlockHeight   // height of the last synced block, e.g. 523002
let receiveAddress = walletKit.receiveAddress     // current receive address for wallet, e.g. mpiBoYpuaXwwUKxDnx6dg8LQNxSh39US9s
```

#### Transactions

`WalletKit` provides info about wallet related transactions in simple `TransactionInfo` structure:

```swift
let walletKit = WalletKit(withWords: words, networkType: .bitcoinMainNet)

let transaction = walletKit.transactions.first

let hash = transaction.hash                 // hash of a tx in reversed hex form
let amount = transaction.amount             // amount of coins transferred in tx (in Satoshis)
let blockHeight = transaction.blockHeight   // height of the block that includes tx
let timestamp = transaction.timestamp       // timestamp of the block (when the block was closed)
let fromAddresses = transaction.from        // array of `TransactionAddress` structures
let toAddresses = transaction.to

let addressInfo = fromAddress.first

let address = addressInfo.address
let mine = addressInfo.mine                 // informs that address belong to wallet or not
```

#### Observing changes in blockchain

In order to be able to observe changes from `WalletKit` the delegate can be set:

```swift
let walletKit = WalletKit(withWords: words, networkType: .bitcoinMainNet)
walletKit.delegate = delegate
```
The `delegate` should implement `BitcoinKitDelegate` protocol:

```swift
class Delegate: BitcoinKitDelegate {
    public func transactionsUpdated(walletKit: WalletKit, inserted: [TransactionInfo], updated: [TransactionInfo], deleted: [Int]) {
        // notifies that transactions set was changed and provides changed data
    }

    public func balanceUpdated(walletKit: WalletKit, balance: Int) {
        // notifies that balance of the wallet was updated
    }

    public func lastBlockHeightUpdated(walletKit: WalletKit, lastBlockHeight: Int) {
        // notifies that last block height was changed
    }

    public func progressUpdated(walletKit: WalletKit, progress: Double) {
        // notifies sync progress update
    }

}
```
