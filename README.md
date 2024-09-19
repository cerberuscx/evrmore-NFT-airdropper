# NFT Airdropper

## Overview
NFT Airdropper is a simple batch script designed to manage and airdrop NFTs using the Evrmore RPC.

## Features
- List existing assets
- Mint unique 1-of-1 NFTs
- Airdrop NFTs to single or multiple addresses
- Check EVR balance and asset balances

## Requirements
- Evrmore node with RPC access
- RPC credentials

## Installation
1. Clone the repository.
    ```bash
    git clone https://github.com/yourusername/nft-airdropper.git
    ```
2. Navigate to the directory:
    ```bash
    cd nft-airdropper
    ```

3. Copy `.env.example` to `.env` and configure it with your own RPC settings:
    ```bash
    cp .env.example .env
    ```

4. Edit `.env` and set your **RPC_URL**, **RPC_USER**, and **RPC_PASS**.

## Usage
Run the batch file:
```bash
NFT_Airdropper.bat
