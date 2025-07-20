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
    const EInvalidTicket: u64 = 12;
    const ETicketUsed: u64 = 13;
    const ETicketMismatch: u64 = 14;

    // Mint Type Enum
    const MINT_TYPE_FREE: u8 = 0;
    const MINT_TYPE_FIXED_PRICE: u8 = 1;
    const MINT_TYPE_DYNAMIC_PRICE: u8 = 2;

    // ======== One-Time-Witness ========
    public struct HASHCASE_MODULE has drop {}

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

    public struct UpdateTicketCreated has copy, drop {
        ticket_id: ID,
        nft_id: ID,
        recipient: address,
        admin: address
    }

    public struct UpdateTicketUsed has copy, drop {
        ticket_id: ID,
        nft_id: ID,
        user: address
    }

    // ======== Capabilities ========
    public struct AdminCap has key, store { 
        id: UID 
    }

    public struct OwnerCap has key, store { 
        id: UID,
        creator: address 
    }

    // ======== Update Ticket System ========
    public struct UpdateTicket has key, store {
        id: UID,
        nft_id: ID,
        collection_id: ID,
        recipient: address,
        new_name: String,
        new_description: String,
        new_image_url: vector<u8>,
        new_attributes: vector<String>,
        created_by: address,
        created_at: u64,
        is_used: bool
    }

    // ======== Core Structs ========
    public struct Collection has key {
        id: UID,
        name: String,
        description: String,
        creator: address,
        owner: address,
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
    fun init(otw: HASHCASE_MODULE, ctx: &mut TxContext) {
        // Create and transfer AdminCap to deployer
        let admin = AdminCap { 
            id: object::new(ctx) 
        };
        transfer::transfer(admin, tx_context::sender(ctx));

        // Claim the Publisher for the package
        let publisher = package::claim(otw, ctx);

        // Set up Display for NFT
        let nft_keys = vector[
            b"name".to_string(),
            b"description".to_string(), 
            b"image_url".to_string(),
            b"creator".to_string(),
            b"collection_id".to_string(),
            b"token_number".to_string(),
            b"attributes".to_string(),
            b"mint_price".to_string(),
            b"metadata_version".to_string()
        ];

        let nft_values = vector[
            b"{name}".to_string(),
            b"{description}".to_string(),
            b"{image_url}".to_string(), 
            b"{creator}".to_string(),
            b"{collection_id}".to_string(),
            b"#{token_number}".to_string(),
            b"{attributes}".to_string(),
            b"{mint_price} SUI".to_string(),
            b"v{metadata_version}".to_string()
        ];

        let mut nft_display = display::new_with_fields<NFT>(
            &publisher, nft_keys, nft_values, ctx
        );
        nft_display.update_version();

        // Set up Display for ClaimedNFT
        let claimed_nft_keys = vector[
            b"name".to_string(),
            b"description".to_string(),
            b"image_url".to_string(), 
            b"claimer".to_string(),
            b"collection_id".to_string(),
            b"original_nft_id".to_string(),
            b"claimed_date".to_string(),
            b"attributes".to_string()
        ];

        let claimed_nft_values = vector[
            b"{name} (Claimed)".to_string(),
            b"{description}".to_string(),
            b"{image_url}".to_string(),
            b"{claimer}".to_string(), 
            b"{collection_id}".to_string(),
            b"{original_nft_id}".to_string(),
            b"Claimed at epoch {claimed_date}".to_string(),
            b"{attributes}".to_string()
        ];

        let mut claimed_nft_display = display::new_with_fields<ClaimedNFT>(
            &publisher, claimed_nft_keys, claimed_nft_values, ctx
        );
        claimed_nft_display.update_version();

        // Transfer publisher and displays to deployer
        transfer::public_transfer(publisher, tx_context::sender(ctx));
        transfer::public_transfer(nft_display, tx_context::sender(ctx));
        transfer::public_transfer(claimed_nft_display, tx_context::sender(ctx));
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

    // Admin-only Collection Creation
    public entry fun create_collection(
        _admin: &AdminCap,
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
        let sender = tx_context::sender(ctx);

        let collection = Collection {
            id: object::new(ctx),
            name,
            description,
            creator: sender,
            owner: sender,
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

    // ======== Update Ticket System Functions ========
    
    // Single Update Ticket Creation - Optimized for PTB usage
    public entry fun create_update_ticket(
        _admin: &AdminCap,
        nft_id: ID,
        collection_id: ID,
        recipient: address,
        new_name: String,
        new_description: String,
        new_image_url_bytes: vector<u8>,
        new_attributes: vector<String>,
        ctx: &mut TxContext
    ) {
        let admin_address = tx_context::sender(ctx);
        
        let ticket = UpdateTicket {
            id: object::new(ctx),
            nft_id,
            collection_id,
            recipient,
            new_name,
            new_description,
            new_image_url: new_image_url_bytes,
            new_attributes,
            created_by: admin_address,
            created_at: tx_context::epoch(ctx),
            is_used: false
        };

        event::emit(UpdateTicketCreated {
            ticket_id: object::uid_to_inner(&ticket.id),
            nft_id,
            recipient,
            admin: admin_address
        });

        transfer::public_transfer(ticket, recipient);
    }

    // Permission-based NFT Metadata Update using Ticket
    public entry fun update_nft_metadata_with_ticket(
        collection: &Collection,
        nft: &mut NFT,
        ticket: UpdateTicket,
        ctx: &mut TxContext
    ) {
        // Verify the NFT belongs to the collection
        assert!(nft.collection_id == object::uid_to_inner(&collection.id), ENotAuthorized);
        
        // Verify collection is dynamic
        assert!(collection.is_dynamic, ECollectionNotDynamic);

        // Verify ticket is for this specific NFT
        assert!(ticket.nft_id == object::uid_to_inner(&nft.id), ETicketMismatch);
        
        // Verify ticket collection matches
        assert!(ticket.collection_id == object::uid_to_inner(&collection.id), ETicketMismatch);
        
        // Verify ticket recipient matches sender
        assert!(ticket.recipient == tx_context::sender(ctx), ENotAuthorized);
        
        // Verify ticket hasn't been used
        assert!(!ticket.is_used, ETicketUsed);

        // Update NFT metadata with ticket data
        nft.name = ticket.new_name;
        nft.description = ticket.new_description;
        nft.image_url = url::new_unsafe_from_bytes(ticket.new_image_url);
        nft.attributes = ticket.new_attributes;
        
        // Increment metadata version
        nft.metadata_version = nft.metadata_version + 1;

        // Emit update event
        event::emit(NFTMetadataUpdated {
            nft_id: object::uid_to_inner(&nft.id),
            collection_id: object::uid_to_inner(&collection.id),
            updater: tx_context::sender(ctx),
            new_metadata_version: nft.metadata_version
        });

        // Emit ticket used event
        event::emit(UpdateTicketUsed {
            ticket_id: object::uid_to_inner(&ticket.id),
            nft_id: object::uid_to_inner(&nft.id),
            user: tx_context::sender(ctx)
        });

        // Consume the ticket (delete it)
        let UpdateTicket {
            id,
            nft_id: _,
            collection_id: _,
            recipient: _,
            new_name: _,
            new_description: _,
            new_image_url: _,
            new_attributes: _,
            created_by: _,
            created_at: _,
            is_used: _
        } = ticket;
        
        object::delete(id);
    }

    // Admin-only Free Mint
    public entry fun admin_free_mint_nft(
        _admin: &AdminCap,
        collection: &mut Collection,
        name: String,
        description: String,
        image_url_bytes: vector<u8>,
        attributes: vector<String>,
        recipient: address,
        ctx: &mut TxContext
    ) {
        // Verify free minting is allowed
        assert!(
            collection.mint_type == MINT_TYPE_FREE, 
            EInvalidMintType
        );

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

    // Admin-only Fixed Price Mint
    public entry fun admin_fixed_price_mint_nft(
        _admin: &AdminCap,
        collection: &mut Collection,
        payment: &mut Coin<SUI>,
        name: String,
        description: String,
        image_url_bytes: vector<u8>,
        attributes: vector<String>,
        recipient: address,
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
            coin::value(payment) == price, 
            EInsufficientPayment
        );

        // Transfer payment to collection balance
        let paid_coins = coin::split(payment, price, ctx);
        coin::put(&mut collection.collected_funds, paid_coins);

        // Mint NFT
        let nft = internal_mint_nft(
            collection, 
            name, 
            description, 
            image_url_bytes, 
            attributes, 
            price,
            recipient,
            ctx
        );

        transfer::public_transfer(nft, recipient);
    }

    // Admin-only Dynamic Price Mint
    public entry fun admin_dynamic_price_mint_nft(
        _admin: &AdminCap,
        collection: &mut Collection,
        payment: &mut Coin<SUI>,
        name: String,
        description: String,
        image_url_bytes: vector<u8>,
        attributes: vector<String>,
        mint_price: u64,
        recipient: address,
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
        coin::put(&mut collection.collected_funds, paid_coins);

        // Mint NFT
        let nft = internal_mint_nft(
            collection, 
            name, 
            description, 
            image_url_bytes, 
            attributes, 
            mint_price,
            recipient,
            ctx
        );

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

        // Create NFT instance to return
        let nft = NFT {
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

        // Return the NFT without storing it in collection table
        nft
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
        nft: NFT,
        ctx: &mut TxContext
    ) {
        // Verify collection is claimable
        assert!(collection.is_claimable, ENotAuthorized);
        
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
        collection.current_supply
    }

    public fun get_collection_total_funds(collection: &Collection): u64 {
        balance::value(&collection.collected_funds)
    }

    // ======== Ticket Utility Functions ========
    public fun is_ticket_valid(ticket: &UpdateTicket): bool {
        !ticket.is_used
    }

    public fun get_ticket_nft_id(ticket: &UpdateTicket): ID {
        ticket.nft_id
    }

    public fun get_ticket_recipient(ticket: &UpdateTicket): address {
        ticket.recipient
    }
}