# BitcoinKit-iOS

Bitcoin, BitcoinCash(ABC) and Dash wallet toolkit for Swift. This is a full implementation of SPV node including wallet creation/restore, synchronization with network, send/receive transactions, and more. The repository includes the main `BitcoinCore.swift` and `BitcoinKit.swift`, `BitcoinCashKit.swift` and `DashKit.swift` separate pods.


## Features

- Full SPV implementation for fast mobile performance
- Send/Receive Legacy transactions (*P2PKH*, *P2PK*, *P2SH*)
- [BIP32](https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki) hierarchical deterministic wallets implementation.
- [BIP39](https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki) mnemonic code for generating deterministic keys.
- [BIP44](https://github.com/bitcoin/bips/blob/master/bip-0044.mediawiki) multi-account hierarchy for deterministic wallets.
- [BIP21](https://github.com/bitcoin/bips/blob/master/bip-0021.mediawiki) URI schemes, which include payment address, amount, label and other params

### BitcoinKit.swift
- Send/Receive Segwit transactions (*P2WPKH*)
- Send/Receive Segwit transactions compatible with legacy wallets (*P2WPKH-SH*)
- base58, bech32

### BitcoinCashKit.swift
- bech32 cashaddr addresses

### DashKit.swift
- Instant send
- LLMQ lock, Masternodes validation

## Usage

On this page, we'll use *Kits* to refer to one of `BitcoinKit.swift`, `BitcoinCashKit.swift` and `DashKit.swift` kits.

### Initialization

*Kits* requires you to provide mnemonic phrase when it is initialized:

```swift
let words = ["word1", ... , "word12"]
```

#### Bitcoin

```swift
let bitcoinKit = BitcoinKit(withWords: words, walletId: "bitcoin-wallet-id", syncMode: .api, networkType: .mainNet)
```

#### Bitcoin Cash

```swift
let bitcoinCashKit = BitcoinCashKit(withWords: words, walletId: "bitcoin-cash-wallet-id", syncMode: .api, networkType: .mainNet)
```

#### Dash

```swift
let dashKit = DashKit(withWords: words, walletId: "dash-wallet-id", syncMode: .api, networkType: .mainNet)
```

All 3 *Kits* can be configured to work in `.mainNet` or `.testNet`. 

##### `syncMode` parameter
*Kits* can restore existing wallet or create a new one. When restoring, it generates addresses for given wallet according to bip44 protocol, then it pulls all historical transactions for each of those addresses. This is done only once on initial sync. `syncMode` parameter defines where it pulls historical transactions from. When they are pulled, it continues to sync according to [SPV](https://en.bitcoinwiki.org/wiki/Simplified_Payment_Verification) protocol no matter which syncMode was used for initial sync. There are 3 modes available:

- `.full`: Fully synchronizes from peer-to-peer network starting from the block when bip44 was introduced. This mode is the most private (since it fully complies with [SPV](https://en.bitcoinwiki.org/wiki/Simplified_Payment_Verification) protocol), but it takes approximately 2 hours to sync upto now (June 10, 2019).
- `.api`: Transactions before checkpoint are pulled from API(currently [Insight API](https://github.com/bitpay/insight-api) or [BcoinAPI](http://bcoin.io/api-docs/)). Then the rest is synchronized from peer-to-peer network. This is the fastest one, but it's possible for an attacker to learn which addresses you own. Checkpoints are updated with each new release and hardcoded so the blocks validation is not broken.
- `.newWallet`: No need to pull transactions.

##### Additional parameters:
- `confirmationsThreshold`: Minimum number of confirmations required for an unspent output in incoming transaction to be spent (*default: 6*)
- `minLogLevel`: Can be configured for debug purposes if required.

### Starting and Stopping

*Kits* require to be started with `start` command. It will be in synced state as long as it is possible. You can call `stop` to stop it

```swift
bitcoinKit.start()
bitcoinKit.stop()
```

### Getting wallet data

*Kits* hold all kinds of data obtained from and needed for working with blockchain network

#### Current Balance

Balance is provided in `Satoshi`:

```swift
bitcoinKit.balance

// 2937096768
```

#### Last Block Info

Last block info contains `headerHash`, `height` and `timestamp` that can be used for displaying sync info to user:

```swift
bitcoinKit.lastBlockInfo 

// ▿ Optional<BlockInfo>
//  ▿ some : BlockInfo
//    - headerHash : //"00000000000041ae2164b486398415cca902a41214cad72291ee04b212bed4c4"
//    - height : 1446751
//    ▿ timestamp : Optional<Int>
//      - some : 1544097931
```

#### Receive Address

Get an address which you can receive coins to. Receive address is changed each time after you actually get a transaction in which you receive coins to that address

```swift
bitcoinKit.receiveAddress

// "mgv1KTzGZby57K5EngZVaPdPtphPmEWjiS"
```

#### Transactions

*Kits* have `transactions(fromHash: nil, limit: nil)` methods which return `Single<TransactionInfo>`(for BitcoinKit and BitcoinCashKit) and `Single<DashTransactionInfo>`(for DashKit) [RX Single Observers](https://github.com/ReactiveX/RxSwift/blob/master/Documentation/Traits.md#single).

`TransactionInfo`:
```swift
//   ▿ TransactionInfo
//     - transactionHash : "0f83c9b330f936dc4a2458b7d3bb06dce6647a521bf6d98f9c9d3cdd5f6d2a73"
//     - transactionIndex : 500000
//     ▿ from : 2 elements
//       ▿ 0 : TransactionAddressInfo
//         - address : "mft8jpnf3XwwqhaYSYMSXePFN85mGU4oBd"
//         - mine : true
//       ▿ 1 : TransactionAddressInfo
//         - address : "mnNS5LEQDnYC2xqT12MnQmcuSvhfpem8gt"
//         - mine : true
//     ▿ to : 2 elements
//       ▿ 0 : TransactionAddressInfo
//         - address : "n43efNftHQ1cXYMZK4Dc53wgR6XgzZHGjs"
//         - mine : false
//       ▿ 1 : TransactionAddressInfo
//         - address : "mrjQyzbX9SiJxRC2mQhT4LvxFEmt9KEeRY"
//         - mine : true
//     - amount : -800378
//     ▿ blockHeight : Optional<Int>
//       - some : 1446602
//    ▿ timestamp : Optional<Int>
//       - some : 1543995972
```

`DashTransactionInfo`:
```swift
//   ▿ DashTransactionInfo
//     - transactionHash : "0f83c9b330f936dc4a2458b7d3bb06dce6647a521bf6d98f9c9d3cdd5f6d2a73"
//     - transactionIndex : 500000
//     - instantTx : true
//     ▿ from : 2 elements
//       ▿ 0 : TransactionAddressInfo
//         - address : "mft8jpnf3XwwqhaYSYMSXePFN85mGU4oBd"
//         - mine : true
//       ▿ 1 : TransactionAddressInfo
//         - address : "mnNS5LEQDnYC2xqT12MnQmcuSvhfpem8gt"
//         - mine : true
//     ▿ to : 2 elements
//       ▿ 0 : TransactionAddressInfo
//         - address : "n43efNftHQ1cXYMZK4Dc53wgR6XgzZHGjs"
//         - mine : false
//       ▿ 1 : TransactionAddressInfo
//         - address : "mrjQyzbX9SiJxRC2mQhT4LvxFEmt9KEeRY"
//         - mine : true
//     - amount : -800378
//     ▿ blockHeight : Optional<Int>
//       - some : 1446602
//    ▿ timestamp : Optional<Int>
//       - some : 1543995972
```

### Creating new transaction

In order to create new transaction, call `send(to: String, value: Int, feeRate: Int)` method on *Kits*

```swift
try bitcoinKit.send(to: "mrjQyzbX9SiJxRC2mQhT4LvxFEmt9KEeRY", value: 1000000, feeRate: 10000)
```

This first validates a given address and amount, creates new transaction, then sends it over the peers network. If there's any error with given address/amount or network, it raises an exception.

#### Validating transaction before send

One can validate address and fee by using following methods:

```swift
try bitcoinKit.validate(address: "mrjQyzbX9SiJxRC2mQhT4LvxFEmt9KEeRY")
try bitcoinKit.fee(for: 1000000, toAddress: "mrjQyzbX9SiJxRC2mQhT4LvxFEmt9KEeRY", senderPay: true, feeRate: 10000)
```
`senderPay` parameter defines who pays the fee

### Parsing BIP21 URI

You can use `parse` method to parse a BIP21 URI:

```swift
bitcoinKit.parse(paymentAddress: "bitcoin:175tWpb8K1S7NmH4Zx6rewF9WQrcZv245W?amount=50&label=Luke-Jr&message=Donation%20for%20project%20xyz")

// ▿ BitcoinPaymentData
//   - address : "175tWpb8K1S7NmH4Zx6rewF9WQrcZv245W"
//   - version : nil
//   ▿ amount : Optional<Double>
//     - some : 50.0
//   ▿ label : Optional<String>
//     - some : "Luke-Jr"
//   ▿ message : Optional<String>
//     - some : "Donation for project xyz"
//   - parameters : nil

```

### Subscribing to BitcoinKit data

*Kits* provide with data like transactions, blocks, balance, kits state in real-time. `BitcoinCoreDelegate` protocol must be implemented and set to *Kits* instance to receive that data.

```swift
class Manager {

	init(words: [String]) {
		bitcoinKit = BitcoinKit(withWords: words, walletId: "bitcoin-wallet-id")
        bitcoinKit.delegate = self
    }

}

extension Manager: BitcoinCoreDelegate {

    func transactionsUpdated(inserted: [TransactionInfo], updated: [TransactionInfo]) {
    }

    func transactionsDeleted(hashes: [String]) {
    }

    func balanceUpdated(balance: Int) {
    }

    func lastBlockInfoUpdated(lastBlockInfo: BlockInfo) {
    }

    public func kitStateUpdated(state: BitcoinCore.KitState) {
		// BitcoinCore.KitState can be one of 3 following states:
		// .synced
		// .syncing(progress: Double)
		// .notSynced
		// 
		// These states can be used to implement progress bar, etc
    }
    
}
```
Listener events are run in a dedicated background thread. It can be switched to main thread by setting the  ```delegateQueue``` property to ```DispatchQueue.main```

```swift
bitcoinKit.delegateQueue = DispatchQueue.main
```

## Prerequisites

* Xcode 10.0+
* Swift 5+
* iOS 11+

## Installation

### CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects. You can install it with the following command:

```bash
$ gem install cocoapods
```

> CocoaPods 1.5.0+ is required to build BitcoinKit.

To integrate BitcoinKit into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '10.0'
use_frameworks!

target '<Your Target Name>' do
  pod 'BitcoinCore.swift'
  pod 'BitcoinKit.swift'
  pod 'BitcoinCashKit.swift'
  pod 'DashKit.swift'
end
```

Then, run the following command:
```bash
$ pod install
```


## Example Project

All features of the library are used in example project. It can be referred as a starting point for usage of the library.

* [Example Project](https://github.com/horizontalsystems/bitcoin-kit-ios/tree/master/Example)

## Dependencies

* [HSHDWalletKit](https://github.com/horizontalsystems/hd-wallet-kit-ios) - HD Wallet related features, mnemonic phrase generation.
* [OpenSslKit.swift](https://github.com/horizontalsystems/open-ssl-kit-ios) - Crypto functions required for working with blockchain.
* [Secp256k1Kit.swift](https://github.com/horizontalsystems/secp256k1-kit-ios) - Crypto functions required for working with blockchain.

### Dash dependencies

* [BlsKit.swift](https://github.com/horizontalsystems/bls-kit-ios)
* [X11Kit.swift](https://github.com/horizontalsystems/x11-kit-ios)

## License

The `BitcoinKit-iOS` toolkit is open source and available under the terms of the [MIT License](https://github.com/horizontalsystems/bitcoin-kit-ios/blob/master/LICENSE).

