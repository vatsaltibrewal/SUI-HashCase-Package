module hashcase::hashcase_module {
    // Sui Standard Imports
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::display;
    use sui::package;
    use sui::url::{Self, Url};
    use sui::event;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::table::{Self, Table};
    use sui::balance::{Self, Balance};
    use sui::hash::keccak256;
    
    // Standard Sui Libraries
    use std::string::{Self, String};
    use std::option::{Self, Option};
    use std::vector;
    use std::hash;

    // ======== Constant Errors ========
    const ENotAdmin: u64 = 0;
    const ENotOwner: u64 = 1;
    const ENotAuthorized: u64 = 2;
    const EInvalidAmount: u64 = 3;
    const EAlreadyClaimed: u64 = 4;
    const ECollectionNotDynamic: u64 = 5;
    const EInsufficientPayment: u64 = 6;
    const ENFTNotBurnable: u64 = 7;
    const ENFTAlreadyBurned: u64 = 8;
    const ECollectionFull: u64 = 9;
    const EInvalidMetadata: u64 = 10;
    const EInvalidMintType: u64 = 11;

    // Mint Type Enum
    const MINT_TYPE_FREE: u8 = 0;
    const MINT_TYPE_FIXED_PRICE: u8 = 1;
    const MINT_TYPE_DYNAMIC_PRICE: u8 = 2;

    // ======== Events ========
    public struct CollectionCreated has copy, drop {
        collection_id: ID,
        name: String,
        creator: address,
        mint_type: u8
    }

    public struct NFTMinted has copy, drop {
        nft_id: ID,
        collection_id: ID,
        creator: address,
        recipient: address,
        token_number: u64,
        mint_price: u64
    }

    public struct NFTClaimed has copy, drop {
        original_nft_id: ID,
        claimed_nft_id: ID,
        claimer: address
    }

    public struct NFTBurned has copy, drop {
        nft_id: ID,
        burner: address
    }

    public struct NFTMetadataUpdated has copy, drop {
        nft_id: ID,
        collection_id: ID,
        updater: address,
        new_metadata_version: u64
    }

    // ======== Capabilities ========
    public struct AdminCap has key, store { 
        id: UID 
    }

    public struct OwnerCap has key, store { 
        id: UID,
        creator: address 
    }

    // ======== Core Structs ========
    public struct Collection has key {
        id: UID,
        name: String,
        description: String,
        creator: address,
        owner: address,
        nfts: Table<ID, NFT>,
        mint_type: u8,
        base_mint_price: u64,
        collected_funds: Balance<SUI>,
        is_open_edition: bool,
        max_supply: Option<u64>,
        current_supply: u64,
        is_dynamic: bool,
        is_claimable: bool,
        base_image_url: Url,
        base_attributes: vector<String>,
        current_token_number: u64,
        nft_prices: Table<ID, u64>
    }

    public struct NFT has key, store {
        id: UID,
        name: String,
        description: String,
        image_url: Url,
        collection_id: ID,
        creator: address,
        attributes: vector<String>,
        token_number: u64,
        mint_price: u64,
        metadata_version: u64
    }

    public struct ClaimedNFT has key, store {
        id: UID,
        original_nft_id: ID,
        name: String,
        description: String,
        image_url: Url,
        collection_id: ID,
        claimer: address,
        claimed_date: u64,
        attributes: vector<String>
    }

    // ======== Initialization ========
    fun init(ctx: &mut TxContext) {
        // Create and transfer AdminCap to deployer
        let admin = AdminCap { 
            id: object::new(ctx) 
        };
        transfer::transfer(admin, tx_context::sender(ctx));
    }

    // ======== Admin Functions ========
    public entry fun create_owner_cap(
        _admin: &AdminCap,
        for_address: address,
        ctx: &mut TxContext
    ) {
        let owner_cap = OwnerCap { 
            id: object::new(ctx),
            creator: for_address
        };
        transfer::transfer(owner_cap, for_address);
    }

    public entry fun admin_mint_nft(
        _admin: &AdminCap,
        collection: &mut Collection,
        name: String,
        description: String,
        image_url_bytes: vector<u8>,
        attributes: vector<String>,
        recipient: address,
        ctx: &mut TxContext
    ) {
        // Admin can mint in any collection
        let nft = internal_mint_nft(
            collection, 
            name, 
            description, 
            image_url_bytes, 
            attributes, 
            0, // mint price for admin mint
            recipient, 
            ctx
        );
        
        // Transfer the NFT to recipient
        transfer::public_transfer(nft, recipient);
    }

    // ======== Admin Functions for Flexibility ========
    public entry fun admin_set_nft_price(
        _admin: &AdminCap,
        collection: &mut Collection,
        nft_id: ID,
        new_price: u64
    ) {
        // Only works for dynamic pricing collections
        assert!(
            collection.mint_type == MINT_TYPE_DYNAMIC_PRICE, 
            EInvalidMintType
        );

        // Update price in the table
        if (table::contains(&collection.nft_prices, nft_id)) {
            *table::borrow_mut(&mut collection.nft_prices, nft_id) = new_price;
        };
    }

    // ======== Owner Functions ========
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
    ) {
        // Verify owner
        assert!(
            owner_cap.creator == tx_context::sender(ctx), 
            ENotOwner
        );

        let sender = tx_context::sender(ctx);

        let collection = Collection {
            id: object::new(ctx),
            name,  // Removed .clone()
            description,
            creator: sender,
            owner: sender,
            nfts: table::new(ctx),
            mint_type,
            base_mint_price: if (mint_type == MINT_TYPE_FREE) { 0 } else { base_mint_price },
            collected_funds: balance::zero(),
            is_open_edition,
            max_supply: if (max_supply == 0) { option::none() } else { option::some(max_supply) },
            current_supply: 0,
            is_dynamic,
            is_claimable,
            base_image_url: url::new_unsafe_from_bytes(base_image_url_bytes),
            base_attributes,
            current_token_number: 0,
            nft_prices: table::new(ctx)
        };

        event::emit(CollectionCreated {
            collection_id: object::uid_to_inner(&collection.id),
            name,
            creator: sender,
            mint_type
        });

        transfer::share_object(collection);
    }

    // Function to update NFT metadata directly
    public entry fun update_nft_metadata(
        collection: &Collection,  // Only need immutable reference to verify collection
        nft: &mut NFT,
        name: String,
        description: String,
        image_url_bytes: vector<u8>,
        attributes: vector<String>,
        ctx: &mut TxContext
    ) {
        // Verify the NFT belongs to the collection
        assert!(nft.collection_id == object::uid_to_inner(&collection.id), ENotAuthorized);
        
        // Verify collection is dynamic
        assert!(collection.is_dynamic, ECollectionNotDynamic);

        // Update NFT metadata fields
        nft.name = name;
        nft.description = description;
        nft.image_url = url::new_unsafe_from_bytes(image_url_bytes);
        nft.attributes = attributes;
        
        // Increment metadata version
        nft.metadata_version = nft.metadata_version + 1;

        // Emit update event
        event::emit(NFTMetadataUpdated {
            nft_id: object::uid_to_inner(&nft.id),
            collection_id: object::uid_to_inner(&collection.id),
            updater: tx_context::sender(ctx),
            new_metadata_version: nft.metadata_version
        });
    }

    // ======== Internal Mint Function ========
    fun internal_mint_nft(
        collection: &mut Collection,
        name: String,
        description: String,
        image_url_bytes: vector<u8>,
        attributes: vector<String>,
        mint_price: u64,
        recipient: address,
        ctx: &mut TxContext
    ): NFT {
        // Verify collection supply
        if (!collection.is_open_edition) {
            assert!(
                option::is_none(&collection.max_supply) || 
                collection.current_supply < *option::borrow(&collection.max_supply),
                ECollectionFull
            );
        };

        // Generate unique token number
        collection.current_token_number = collection.current_token_number + 1;
        let token_number = collection.current_token_number;

        let nft_id = object::new(ctx);
        let nft_id_inner = object::uid_to_inner(&nft_id);

        // Create NFT - store in a local variable first
        let new_nft = NFT {
            id: nft_id,
            name,
            description,
            image_url: url::new_unsafe_from_bytes(image_url_bytes),
            collection_id: object::uid_to_inner(&collection.id),
            creator: tx_context::sender(ctx),
            attributes,
            token_number,
            mint_price,
            metadata_version: 1
        };

        // Update collection
        table::add(&mut collection.nfts, nft_id_inner, new_nft);
        
        // Add to price table if dynamic pricing
        if (collection.mint_type == MINT_TYPE_DYNAMIC_PRICE) {
            table::add(&mut collection.nft_prices, nft_id_inner, mint_price);
        };

        collection.current_supply = collection.current_supply + 1;

        event::emit(NFTMinted {
            nft_id: nft_id_inner,
            collection_id: object::uid_to_inner(&collection.id),
            creator: tx_context::sender(ctx),
            recipient,
            token_number,
            mint_price
        });

        // Create and return a new NFT instance
        NFT {
            id: object::new(ctx),
            name,
            description,
            image_url: url::new_unsafe_from_bytes(image_url_bytes),
            collection_id: object::uid_to_inner(&collection.id),
            creator: tx_context::sender(ctx),
            attributes,
            token_number,
            mint_price,
            metadata_version: 1
        }
    }

    // ======== Minting Functions ========
    // Free Mint
    public entry fun free_mint_nft(
        collection: &mut Collection,
        name: String,
        description: String,
        image_url_bytes: vector<u8>,
        attributes: vector<String>,
        ctx: &mut TxContext
    ) {
        // Verify free minting is allowed
        assert!(
            collection.mint_type == MINT_TYPE_FREE, 
            EInvalidMintType
        );

        let recipient = tx_context::sender(ctx);

        let nft = internal_mint_nft(
            collection, 
            name, 
            description, 
            image_url_bytes, 
            attributes,
            0,  // Free mint price
            recipient,
            ctx
        );

        transfer::public_transfer(nft, recipient);
    }

    // Fixed Price Mint
    public entry fun fixed_price_mint_nft(
        collection: &mut Collection,
        payment: &mut Coin<SUI>,
        name: String,
        description: String,
        image_url_bytes: vector<u8>,
        attributes: vector<String>,
        ctx: &mut TxContext
    ) {
        // Verify fixed price minting
        assert!(
            collection.mint_type == MINT_TYPE_FIXED_PRICE, 
            EInvalidMintType
        );

        // Store base_mint_price in local variable to avoid multiple borrows
        let price = collection.base_mint_price;
        
        // Verify payment
        assert!(
            coin::value(payment) >= price, 
            EInsufficientPayment
        );
        
        let payment_amount = coin::value(payment);

        // Transfer payment to collection balance
        let paid_coins = coin::split(payment, price, ctx);
        balance::join(
            &mut collection.collected_funds, 
            coin::into_balance(paid_coins)
        );
         // Refund remaining amount to the user
        let remaining_amount = payment_amount - price;
        if (remaining_amount > 0) {
            let remaining_coin = coin::split(payment, remaining_amount, ctx);
            transfer::public_transfer(remaining_coin, tx_context::sender(ctx));
        };

        // Mint NFT
        let nft = internal_mint_nft(
            collection, 
            name, 
            description, 
            image_url_bytes, 
            attributes, 
            price,
            tx_context::sender(ctx),
            ctx
        );

        transfer::public_transfer(nft, tx_context::sender(ctx));
    }

    // Dynamic Price Mint
    public entry fun dynamic_price_mint_nft(
        collection: &mut Collection,
        payment: &mut Coin<SUI>,
        name: String,
        description: String,
        image_url_bytes: vector<u8>,
        attributes: vector<String>,
        mint_price: u64,
        ctx: &mut TxContext
    ) {
        // Verify dynamic pricing
        assert!(
            collection.mint_type == MINT_TYPE_DYNAMIC_PRICE, 
            EInvalidMintType
        );

        // Verify payment
        assert!(
            coin::value(payment) >= mint_price, 
            EInsufficientPayment
        );
        
        // Transfer payment to collection balance
        let paid_coins = coin::split(payment, mint_price, ctx);
        balance::join(
            &mut collection.collected_funds, 
            coin::into_balance(paid_coins)
        );

        // Mint NFT
        let nft = internal_mint_nft(
            collection, 
            name, 
            description, 
            image_url_bytes, 
            attributes, 
            mint_price,
            tx_context::sender(ctx),
            ctx
        );

        transfer::public_transfer(nft, tx_context::sender(ctx));
    }

    
    public entry fun withdraw_collection_funds(
        _owner_cap: &OwnerCap,  // Added underscore to fix unused parameter warning
        collection: &mut Collection,
        ctx: &mut TxContext
    ) {
        assert!(
            collection.owner == tx_context::sender(ctx), 
            ENotOwner
        );

        let total_funds = balance::value(&collection.collected_funds);
        
        let funds_to_withdraw = coin::from_balance(
            balance::split(&mut collection.collected_funds, total_funds), 
            ctx
        );

        transfer::public_transfer(
            funds_to_withdraw, 
            tx_context::sender(ctx)
        );
    }


    // Claim NFT Function
    public entry fun claim_nft(
        collection: &mut Collection,
        nft: NFT,  // Take ownership of the NFT directly
        ctx: &mut TxContext
    ) {
        // Verify collection is claimable
        assert!(collection.is_claimable, ENotAuthorized);
        
        // No need to verify ownership - if the user can pass the NFT object, they own it
        // due to Sui Move's ownership model
        
        // Verify NFT belongs to the collection
        assert!(nft.collection_id == object::uid_to_inner(&collection.id), ENotAuthorized);

        // Create claimed NFT
        let claimed_nft = ClaimedNFT {
            id: object::new(ctx),
            original_nft_id: object::uid_to_inner(&nft.id),
            name: collection.name,
            description: collection.description,
            image_url: collection.base_image_url,
            collection_id: object::uid_to_inner(&collection.id),
            claimer: tx_context::sender(ctx),
            claimed_date: tx_context::epoch(ctx),
            attributes: collection.base_attributes
        };

        // Get NFT ID before destructuring
        let nft_id = object::uid_to_inner(&nft.id);
        
        // Remove from collection's table if it exists there
        if (table::contains(&collection.nfts, nft_id)) {
            let removed_nft = table::remove(&mut collection.nfts, nft_id);
            let NFT { 
                id, 
                name: _, 
                description: _, 
                image_url: _, 
                collection_id: _, 
                creator: _, 
                attributes: _, 
                token_number: _,
                mint_price: _,
                metadata_version: _
            } = removed_nft;
            object::delete(id);
        };

        // Destruct the original NFT
        let NFT { 
            id, 
            name: _, 
            description: _, 
            image_url: _, 
            collection_id: _, 
            creator: _, 
            attributes: _, 
            token_number: _,
            mint_price: _,
            metadata_version: _
        } = nft;
        object::delete(id);

        // Update collection supply
        //collection.current_supply = collection.current_supply - 1;

        // Emit claim event
        event::emit(NFTClaimed {
            original_nft_id: nft_id,
            claimed_nft_id: object::uid_to_inner(&claimed_nft.id),
            claimer: tx_context::sender(ctx)
        });

        // Transfer claimed NFT to caller
        transfer::public_transfer(claimed_nft, tx_context::sender(ctx));
    }

    // ======== Utility Functions ========
    public fun get_collection_nft_count(collection: &Collection): u64 {
        table::length(&collection.nfts)
    }

    public fun get_collection_total_funds(collection: &Collection): u64 {
        balance::value(&collection.collected_funds)
    }
}