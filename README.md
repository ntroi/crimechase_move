# CrimeChase NFT Project

A blockchain-based NFT project built on the Aptos blockchain.

## Overview

CrimeChase is an NFT project that provides a comprehensive system for managing digital assets, including tokens, inventories, and certifications. The project is built on the Aptos blockchain and implements various features for secure and efficient asset management.

## Module Structure

### 1. Token Module (`crimechanse_token.move`)
- NFT token creation and management
- Token metadata handling (name, description, URI)
- Token property system with custom attributes
- Token transfer controls and restrictions
- Token burning mechanism
- Token locking/unlocking system
- Batch token operations
- Token collection management
- Token rarity system
- Subcollection support

### 2. Inventory Module (`crimechanse_inventory.move`)
- Item storage and management system
- Item stacking and quantity tracking
- Item transfer between inventories
- Batch item operations
- Inventory capacity management
- Item ownership verification
- Inventory state persistence
- Item metadata management

### 3. Certification Center Module (`crimechanse_certification_center.move`)
- Certification issuance and management
- Certification verification system
- Certification count tracking
- Batch certification operations
- Certification ownership management
- Certification state persistence
- Certification transfer controls
- Certification metadata handling

## Features

- Token Management
  - Create and customize NFT tokens
  - Manage token properties and metadata
  - Control token transfers and access
  - Handle token collections and subcollections

- Inventory System
  - Store and organize digital assets
  - Track item quantities
  - Transfer items between accounts
  - Manage inventory capacity

- Certification System
  - Issue and verify certifications
  - Track certification counts
  - Manage certification ownership
  - Handle batch certification operations

## Technical Details

- Built on Aptos blockchain
- Move language implementation
- Object-centric data model
- Secure ownership verification
- Efficient batch operations
- State persistence mechanisms

## Getting Started

1. Clone the repository
2. Install dependencies
3. Configure your Aptos environment
4. Deploy the contracts
5. Start interacting with the system

## Development

```bash
# Compile the contracts
aptos move compile --named-addresses crimechase=<your_address>

# Run tests
aptos move test

# Deploy
aptos move publish --named-addresses crimechase=<your_address>
```

## Testing

Each module includes comprehensive test cases:
- Token creation and management tests
- Inventory operation tests
- Certification system tests
- Property management tests
- Batch operation tests

## License

This project is licensed under the MIT License.