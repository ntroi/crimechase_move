# CrimeChase NFT Project

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**CrimeChase** is a multi-functional NFT project built on the Aptos blockchain. It provides a comprehensive smart contract system for the creation, management, and tracking of digital assets (NFTs, items, certificates), supporting a secure and efficient on-chain experience.

## Overview

Beyond simple NFT issuance, CrimeChase aims to provide an integrated environment where users can effectively own and interact with their digital assets. Utilizing Aptos's Object Model, each asset (token, inventory item, certificate) is managed as an independent object, enhancing flexibility and scalability.

## Architecture

The CrimeChase smart contract is designed with the following modular structure. Each module handles specific functions and interacts with others.

```mermaid
graph LR
    A[User Account] -- Sends Transaction --> B{CrimeChase Contract (Aptos)}
    B --> C[Token Module]
    B --> D[Inventory Module]
    B --> E[Certification Center Module]

    C -- Manages NFTs --> F[(NFT Object)]
    D -- Manages Items --> G[(Item Object)]
    E -- Manages Certs --> H[(Certification Object)]

    A -- Owns/Interacts --> F
    A -- Owns/Interacts --> G
    A -- Owns/Interacts --> H

    style B fill:#f9f,stroke:#333,stroke-width:2px
    style C fill:#ccf,stroke:#333,stroke-width:1px
    style D fill:#cfc,stroke:#333,stroke-width:1px
    style E fill:#ffc,stroke:#333,stroke-width:1px
```

User Account: Interacts with the CrimeChase contract via an Aptos wallet.
CrimeChase Contract: The main contract containing sub-modules, deployed on the blockchain.
Modules: Handle logic related to tokens, inventory, and certifications.
Objects: Each NFT, item, and certificate exists as an independent Object on Aptos, directly owned by the user.
Key Features
Integrated Asset Management: Manage various digital assets like NFTs, game items, and on-chain certificates within a single project.
Modular Design: Easy maintenance and scalability due to functional module separation.
Leverages Aptos Object Model: Clear ownership and management by representing each asset as an object.
Flexible Metadata and Properties: Assign diverse metadata and custom properties to tokens, items, and certificates.
Efficient Batch Operations: Supports processing multiple assets in a single transaction.
Enhanced Access Control: Strengthens asset security through features like token transfer restrictions and locking mechanisms.
Module Details
1. Token Module (crimechanse_token.move - Estimated)
Core Function: Manages the entire lifecycle of NFTs, including creation, transfer, and burning.
Characteristics:
Supports rich metadata (name, description, URI) and custom properties.
Systematic NFT classification through collection and subcollection structures.
Potential for implementing a rarity system.
Provides various control functions like transfer restrictions, burning, and locking/unlocking.
2. Inventory Module (crimechanse_inventory.move - Estimated)
Core Function: Stores and manages various digital items beyond NFTs (potentially trackable by quantity).
Characteristics:
Item stacking and quantity-based management.
Secure item transfers between user accounts.
Configurable inventory capacity limits.
Clear ownership verification through independent item objects.
3. Certification Center Module (crimechanse_certification_center.move - Estimated)
Core Function: Issues, verifies, and manages on-chain certificates or credentials.
Characteristics:
Certificate issuance and management by trusted authorities.
Easy on-chain verification of certificate validity.
Tracking of certificate ownership and transfer control.
Management of related metadata and status.
Getting Started
Clone the Repository:
Bash

git clone <your-repository-url>
cd crimechase_move
Set Up Development Environment: (Use sh-scripts/dev_setup.sh script if needed)
Install Aptos CLI and set up a profile (aptos init).
Deploy the Contract:
Modify the addresses in the move/Move.toml file to your account address.
Run the sh-scripts/move_publish.sh script or use the command below (Requires PROFILE environment variable).
Bash

# PROFILE=your_profile_name (e.g., default, devnet_admin)
# Addr=<your_account_address>
aptos move publish --named-addresses crimechase=$Addr --profile $PROFILE --assume-yes
Interact with the System: Use Aptos CLI or SDKs to call functions on the deployed contract.
Development
Compile:
Bash

# Addr=<your_account_address>
aptos move compile --named-addresses crimechase=$Addr
Run Tests: (Can use sh-scripts/move_tests.sh script)
Bash

aptos move test
Testing
Each module includes test cases covering key functionalities such as:

Token management tests (creation, transfer, property changes, etc.)
Inventory operation tests (adding items, transfers, quantity changes, etc.)
Certification system tests (issuance, verification, ownership transfer, etc.)
Batch operation functionality tests.

License
This project is distributed under the MIT License.