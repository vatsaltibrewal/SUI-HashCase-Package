module hashcase::loyalty {
    use sui::coin::{Self, TreasuryCap};
    use sui::token::{Self, Token, ActionRequest, TokenPolicy, TokenPolicyCap};
    use sui::tx_context::{TxContext, sender};
    use sui::transfer;
    use std::option::{Self, Option};

    /// Token amount mismatch error.
    const E_INCORRECT_AMOUNT: u64 = 0;

    /// One-time witness for the LOYALTY type.
    public struct LOYALTY has drop {}

    /// Marker type representing the Store for spending policies.
    public struct Store has drop {}

    /// Initialization: creates the LOYALTY token and policy, and gives
    /// the deploying admin the TreasuryCap and TokenPolicyCap.
    fun init(otw: LOYALTY, ctx: &mut TxContext) {
        // Create the token with symbol "LOY", name, and no decimals.
        let (treasury_cap, coin_metadata) =
            coin::create_currency(
                otw,
                0,                     // decimals
                b"HLP",                // symbol
                b"Hashcase Loyalty Points",      // name
                b"Hashcase Loyalty Points", // description
                option::none(),        // url
                ctx,
            );

        // Create a policy and get its cap.
        let (mut policy, policy_cap) = token::new_policy(&treasury_cap, ctx);

        token::allow(&mut policy, &policy_cap, token::spend_action(), ctx);

        // Allow transfers to be confirmed by treasury cap (for admin rewards)
        token::allow(&mut policy, &policy_cap, token::transfer_action(), ctx);

        // Share token policy and freeze metadata for public viewing.
        token::share_policy(policy);
        transfer::public_freeze_object(coin_metadata);

        // Give both caps to the deployer/admin.
        transfer::public_transfer(policy_cap, sender(ctx));
        transfer::public_transfer(treasury_cap, sender(ctx));
    }

    /// Admin-only minting: reward a user with amount points.
    public fun reward_user(
        cap: &mut TreasuryCap<LOYALTY>,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        let token = token::mint(cap, amount, ctx);
        let req = token::transfer(token, recipient, ctx);
        // Confirm transfer with the treasury cap.
        token::confirm_with_treasury_cap(cap, req, ctx);
    }

    public fun spend_points(
        policy: &mut TokenPolicy<LOYALTY>,
        token: Token<LOYALTY>,
        ctx: &mut TxContext,
    ) {
        let req = token::spend(token, ctx);
        token::confirm_request_mut(policy, req, ctx);
    }

}