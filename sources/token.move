module hashcase::loyalty_points {
    use sui::token::{Self, Token, ActionRequest};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::object::{Self, UID};
    use sui::coin::{Self, TreasuryCap};
    use std::option;

    /// Custom errors
    const EInvalidAmount: u64 = 0;
    const EUnauthorized: u64 = 1;
    const EInsufficientBalance: u64 = 2;

    /// The OTW for the Token
    public struct LOYALTY_POINTS has drop {}

    /// Rule requirement for token operations
    public struct TokenRule has drop {}

    /// Initialize the loyalty points system
    fun init(otw: LOYALTY_POINTS, ctx: &mut TxContext) {
        // Create the currency
        let (treasury_cap, metadata) = coin::create_currency(
            otw,
            0, // no decimals
            b"HLP",
            b"Hashcase Loyalty Points",
            b"Hashcase Loyalty Points",
            option::none(),
            ctx
        );

        transfer::public_freeze_object(metadata);
        transfer::public_share_object(treasury_cap);
    }


    // At Start
    public fun create_user_points(
        treasury_cap: &mut TreasuryCap<LOYALTY_POINTS>,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let token = token::mint(treasury_cap, amount, ctx);
        let req = token::transfer(token, recipient, ctx);
        token::confirm_with_treasury_cap(treasury_cap, req, ctx);
    }

    // Subsequent Addition 
    public fun add_points(
        treasury_cap: &mut TreasuryCap<LOYALTY_POINTS>,
        user_token: &mut Token<LOYALTY_POINTS>,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let new_points = token::mint(treasury_cap, amount, ctx);
        token::join(user_token, new_points);
    }

    public fun spend_points(
        treasury_cap: &mut TreasuryCap<LOYALTY_POINTS>,
        token: &mut Token<LOYALTY_POINTS>,
        amount: u64,
        ctx: &mut TxContext
    ) {
        // Check sufficient balance
        assert!(token::value(token) >= amount, EInsufficientBalance);
        
        // Split the amount to spend
        let points_to_burn = token::split(token, amount, ctx);
        
        // Burn the split points
        let mut req = token::spend(points_to_burn, ctx);
        token::confirm_with_treasury_cap(treasury_cap, req, ctx);
    }

    /// Get current balance
    public fun get_balance(token: &Token<LOYALTY_POINTS>): u64 {
        token::value(token)
    }
}