# Hashcase - Advanced NFT & Loyalty Platform on Sui

Hashcase is a comprehensive NFT platform built on the Sui blockchain, offering advanced NFT minting capabilities, gasless transactions, and an integrated loyalty points system.

## 🌟 Features

### NFT Functionality
- **Multiple Minting Options**
  - Free Minting
  - Fixed Price Minting
  - Dynamic Price Minting
  - Open Edition Collections
  - Gasless Minting with Enoki Sponsored Transactions

- **Advanced NFT Operations**
  - Claim & Burn System
  - Claim & Ship with Variant Selection
  - Dynamic NFT Metadata Updates
  - Randomized Token ID Generation
  - On-chain Loyalty Points Integration

### Role-Based Access Control
- **Admin Role**
  - Complete system control
  - Access to all collections
  - Administrative minting privileges
  
- **Owner Role**
  - Collection creation and management
  - NFT minting within owned collections
  - Collection funds withdrawal
  
- **User Role**
  - NFT minting capabilities
  - Collection interaction
  - Loyalty points earning and spending

### Loyalty Points System
- Closed-loop token system
- Points earning through platform interaction
- Redeemable rewards
- Balance tracking and management
- Secure point transfer system

## 📋 Smart Contracts

### Main NFT Contract
The primary contract handling NFT operations includes:
- Collection management
- Minting logic
- NFT claiming system
- Metadata management
- Fund management

```move
// Example Collection Creation
public entry fun create_collection(
    owner_cap: &OwnerCap,
    name: String,
    description: String,
    mint_type: u8,
    base_mint_price: u64,
    is_open_edition: bool,
    max_supply: u64,
    is_dynamic: bool,
    is_claimable: bool,
    base_image_url_bytes: vector<u8>,
    base_attributes: vector<String>,
    ctx: &mut TxContext
)
```

### Loyalty Points Contract
Manages the platform's loyalty system:
- Point distribution
- Balance management
- Reward redemption
- Point burning mechanism

```move
// Example Points Creation
public fun create_user_points(
    treasury_cap: &mut TreasuryCap<LOYALTY_POINTS>,
    amount: u64,
    recipient: address,
    ctx: &mut TxContext
)
```

## 🚀 Prerequisites
- Sui CLI installed
- Node.js environment
- Basic knowledge of Move programming

## 🔐 Security

- Role-based access control
- Secure fund management
- Protected administrative functions
- Validated transaction operations


## 🤝 Contributing

We welcome contributions! Please feel free to submit a Pull Request.


Built with ❤️ by Vatsal
