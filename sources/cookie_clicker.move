/// This module provides basic functions for interacting with the Cookie Clicker Game 
/// Including the Cookie Clicker NFT
///
/// author: brianspha
/// license: MIT
module cookie_clicker_address::cookie_clicker {

    // Imports
    use aptos_framework::coin::{Self, MintCapability, BurnCapability};
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::timestamp;
    use std::string;
    use std::vector;
    use std::error;
    use aptos_framework::event;
    #[test_only]
    use aptos_framework::account::create_account_for_test;
    use aptos_token::token;
    use std::signer;
    use std::string::String;
    use aptos_token::token::TokenDataId;
    use aptos_framework::account::SignerCapability;
    use aptos_framework::resource_account;
    use aptos_framework::account;

    // Friend Modules
    

    // Struct definition

    // This struct stores an NFT collection's relevant information
    struct ModuleData has key {
        // Storing the signer capability here, so the module can programmatically sign for transactions
        signer_cap: SignerCapability,
        token_data_id: TokenDataId,
        burn_cap: BurnCapability<CookieClickerPlayToken>,
        mint_cap: MintCapability<CookieClickerPlayToken>,
    }

    struct Cookie has key {
        cookies: u256,
        player: address,
        upgrade_multiplier: u256,
        upgrade_cost: u256,
        click_multiplier: u256,
        initial_threshold: u256,
        increment_multiplier: u256,
        cookie_update_event: event::EventHandle<CookiesUpdated>,
        cookie_upgrade_event: event::EventHandle<CookiesUpgraded>,
        cookie_nft_swap_event: event::EventHandle<CookieToNFT>,
    }
    struct CookieClickerPlayToken {
        aptos_coin: AptosCoin
    }

     struct TokensClaimed has key {
        player: address,
        claimed: bool,
        amount: u64,
        claim_tokens_event: event::EventHandle<ClaimedFreeTokens>,
    }

    // Events definitions
    struct ClaimedFreeTokens has drop, store {
        tokens_claimed: u64,
    }

    struct CookieToNFT has drop, store {
        cookie_threshold: u256,
        cookies_left: u256,
        player: address,
    }

    struct CookiesUpdated has drop, store {
        old_cookies: u256,
        new_cookies: u256,
        upgrade_multiplier: u256,
        upgrade_cost: u256,
        click_multiplier: u256,
        initial_threshold: u256,
        increment_multiplier: u256,
        player: address,
    }

    struct CookiesUpgraded has drop, store {
        old_cookies: u256,
        new_cookies: u256,
        upgrade_multiplier: u256,
        new_upgrade_cost: u256,
        old_upgrade_cost: u256,
        player: address,
    }

    // Error code definitions
    const ENO_COOKIE_FOUND: u64 = 0;
    const ENO_NOT_ENOUGH_COOKIES: u64 = 1;
    const ENO_COOKIES_NOT_UPGRADED: u64 = 2;
    const ENO_INVALID_CLICK_MULTIPLIER: u64 = 3;
    const ENOT_ENOUGH_COOKIES_FOR_SWAP: u64 = 4;
    const ECOOKIES_NOT_SWOPED: u64 = 5;
    const ENOT_ENOUGH_COINS_TO_PLAY: u64 = 6;
    const EALREADY_CLAIMED_TOKENS: u64 = 6;
    // Constants definitions
    // To play the game one needs 5000 Aptos coins 
    const PLAY_COST:u64 = 5000;
    const ASSET_SYMBOL: vector<u8> = b"CC";
    const CLAIMABLE_TOKENS :u64 = 50000;


    /// Initializes the Cookie Clicker NFT module.
    ///
    /// This function creates an NFT collection, specifies the token to be minted,
    /// and registers the resource account for the module.
    ///
    /// Parameters:
    /// - `resource_signer`: The signer representing the resource account.
    ///
    fun init_module(resource_signer: &signer) {
        let collection_name = string::utf8(b"Cookie Clicker Collection");
        let description = string::utf8(b"This is the cookie clicker NFT collection");
        let collection_uri = string::utf8(b"https://pngimg.com/d/cookie_PNG13669.png");
        let token_name = string::utf8(b"Cookie Clicker");
        let token_uri = string::utf8(b"https://pngimg.com/d/cookie_PNG13669.png");
        // This means that the supply of the token will not be tracked.
        let maximum_supply = 0;
        // This variable sets if we want to allow mutation for collection description, uri, and maximum.
        // Here, we are setting all of them to false, which means that we don't allow mutations to any CollectionData fields.
        let mutate_setting = vector<bool>[ false, false, false ];

        // Create the NFT collection.
        token::create_collection(resource_signer, collection_name, description, collection_uri, maximum_supply, mutate_setting);

        // Create a token data id to specify the token to be minted.
        let token_data_id = token::create_tokendata(
            resource_signer,
            collection_name,
            token_name,
            string::utf8(b""),
            0,
            token_uri,
            signer::address_of(resource_signer),
            1,
            0,
            // This variable sets if we want to allow mutation for token maximum, uri, royalty, description, and properties.
            // Here we enable mutation for properties by setting the last boolean in the vector to true.
            token::create_token_mutability_config(
                &vector<bool>[ false, false, false, false, true ]
            ),
            // We can use property maps to record attributes related to the token.
            // In this example, we are using it to record the receiver's address.
            // We will mutate this field to record the user's address
            // when a user successfully mints a token in the `mint_event_ticket()` function.
            vector<String>[string::utf8(b"given_to")],
            vector<vector<u8>>[b""],
            vector<String>[ string::utf8(b"address") ],
        );

        // Store the token data id within the module, so we can refer to it later
        // when we're minting the NFT
        let resource_signer_cap = resource_account::retrieve_resource_account_cap(resource_signer, @source_addr);
        // Fungible 
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<CookieClickerPlayToken>(
            resource_signer,
            string::utf8(b"Cookie Clicker Play Token"),
            string::utf8(b"CCPT"),
            18,
            false,
        );
        // Destroy freeze cap because we aren't using it
        coin::destroy_freeze_cap(freeze_cap);

        // Register the resource account so it has CoinStore for CookieClickerPlayToken
        coin::register<AptosCoin>(resource_signer);

        move_to(resource_signer, ModuleData {
            signer_cap: resource_signer_cap,
            token_data_id,
            burn_cap,
            mint_cap,
        });
    }

    /// Claims tokens for the player.
    ///
    /// This function allows the player to claim tokens, mints the specified number
    /// of tokens, and transfers them to the player's account.
    ///
    /// Parameters:
    /// - `player`: The signer representing the player's account.
    ///
    /// # Errors
    ///
    /// This function reverts with the following error codes:
    /// - `EALREADY_CLAIMED_TOKENS`: If the player has already claimed tokens.
    ///
    /// Returns: The `TokensClaimed` struct representing the player's claimed tokens data.
    ///
    public fun claim_tokens(player: signer) acquires TokensClaimed, ModuleData {
        let player_address: address = signer::address_of(&player);

        // Check if the player has already claimed tokens
        assert!(!exists<TokensClaimed>(player_address), error::not_found(EALREADY_CLAIMED_TOKENS));

        move_to(
        &player,
        TokensClaimed {
            player: player_address,
            claimed: true,
            amount: CLAIMABLE_TOKENS,
            claim_tokens_event: account::new_event_handle<ClaimedFreeTokens>(&player),
        },
        );

        let tokens_claimed = borrow_global_mut<TokensClaimed>(player_address);
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);

        // Register the player so they can have the store account for the token
        coin::register<AptosCoin>(&player);
        // Mint CLAIMABLE_TOKENS to the resource account
        coin::deposit<CookieClickerPlayToken>(player_address, coin::mint<CookieClickerPlayToken>(CLAIMABLE_TOKENS, &module_data.mint_cap));

        event::emit_event(
        &mut tokens_claimed.claim_tokens_event,
        ClaimedFreeTokens {
            tokens_claimed: CLAIMABLE_TOKENS,
        },
        );

    }

    /// Function that allows a player to create a new cookie or continue an existing game.
    ///
    /// Parameters:
    /// - `player`: The signer representing the player's account.
    /// - `cookies`: The number of initial cookies for the player.
    /// - `new_game`: A boolean flag indicating if it's a new game (true) or a continuation
    ///   of an existing game (false).
    ///
    /// Returns: The `Cookie` struct representing the player's cookie data.
    public entry fun create_cookie(player: signer, cookies: u256, new_game: bool) acquires Cookie,ModuleData {
        let player_address: address = signer::address_of(&player);
        assert!(coin::balance<ModuleData>(player_address)== PLAY_COST,error::not_found(ENOT_ENOUGH_COINS_TO_PLAY));

        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        let resource_signer = account::create_signer_with_capability(&module_data.signer_cap);
        let resource_signer_address: address = signer::address_of(&resource_signer);
        coin::transfer<ModuleData>(&player,resource_signer_address,PLAY_COST);

        if (!exists<Cookie>(player_address)) {
            move_to(
                &player,
                Cookie {
                    cookies: cookies,
                    player: player_address,
                    upgrade_multiplier: 2,
                    upgrade_cost: 10,
                    click_multiplier: 1,
                    initial_threshold: 5000,
                    increment_multiplier: 40,
                    cookie_update_event: account::new_event_handle<CookiesUpdated>(&player),
                    cookie_upgrade_event: account::new_event_handle<CookiesUpgraded>(&player),
                    cookie_nft_swap_event: account::new_event_handle<CookieToNFT>(&player),
                },
            );
            let old_cookies = borrow_global_mut<Cookie>(player_address);
            event::emit_event(
                    &mut old_cookies.cookie_update_event,
                    CookiesUpdated {
                        old_cookies: old_cookies.cookies,
                        new_cookies: old_cookies.cookies + cookies,
                        upgrade_multiplier: old_cookies.upgrade_multiplier,
                        upgrade_cost: old_cookies.upgrade_cost,
                        click_multiplier: old_cookies.click_multiplier,
                        player: player_address,
                        initial_threshold: old_cookies.initial_threshold,
                        increment_multiplier: old_cookies.increment_multiplier,
                    },
                );
        } else {
            let old_cookies = borrow_global_mut<Cookie>(player_address);

            if (new_game) {
                old_cookies.cookies = cookies;
                old_cookies.upgrade_multiplier = 2;
                old_cookies.upgrade_cost = 10;
                old_cookies.click_multiplier = 1;
                old_cookies.initial_threshold = 5000;
                old_cookies.increment_multiplier = 40;
                event::emit_event(
                    &mut old_cookies.cookie_update_event,
                    CookiesUpdated {
                        old_cookies: old_cookies.cookies,
                        new_cookies: old_cookies.cookies + cookies,
                        upgrade_multiplier: old_cookies.upgrade_multiplier,
                        upgrade_cost: old_cookies.upgrade_cost,
                        click_multiplier: old_cookies.click_multiplier,
                        player: player_address,
                        initial_threshold: 5000,
                        increment_multiplier: 40,
                    },
                );
            } else {
                old_cookies.cookies = old_cookies.cookies + cookies;
                event::emit_event(
                    &mut old_cookies.cookie_update_event,
                    CookiesUpdated {
                        old_cookies: old_cookies.cookies,
                        new_cookies: old_cookies.cookies + cookies,
                        upgrade_multiplier: old_cookies.upgrade_multiplier,
                        upgrade_cost: old_cookies.upgrade_cost,
                        click_multiplier: old_cookies.click_multiplier,
                        player: player_address,
                        initial_threshold: old_cookies.initial_threshold,
                        increment_multiplier: old_cookies.increment_multiplier,
                    },
                );
            }
        }
    }

    /// Function that upgrades the player's cookie.
    ///
    /// Parameters:
    /// - `player`: The signer representing the player's account.
    ///
    ///
    /// # Errors
    ///
    /// This function reverts with the following error codes
    /// - `ENO_COOKIE_FOUND`: If the player does not have an existing game.
    /// - `ENO_NOT_ENOUGH_COOKIES`: If the player does not have enough cookies to perform the upgrade.
    ///
    /// Returns: The updated `Cookie` struct representing the player's cookie data.
    public fun upgrade_cookie(player: signer) acquires Cookie {
        let player_address: address = signer::address_of(&player);
        assert!(exists<Cookie>(player_address), error::not_found(ENO_COOKIE_FOUND));
        let old_cookies = borrow_global_mut<Cookie>(player_address);
        assert!(old_cookies.cookies >= old_cookies.upgrade_cost, error::not_found(ENO_NOT_ENOUGH_COOKIES));
        let new_cookies = old_cookies.cookies - old_cookies.upgrade_cost;
        let new_click_multiplier = old_cookies.click_multiplier * old_cookies.upgrade_multiplier;
        let upgrade_cost = old_cookies.click_multiplier * old_cookies.upgrade_multiplier;

        event::emit_event(
            &mut old_cookies.cookie_upgrade_event,
            CookiesUpgraded {
                old_cookies: old_cookies.cookies,
                new_cookies: new_cookies,
                upgrade_multiplier: old_cookies.upgrade_multiplier,
                new_upgrade_cost: upgrade_cost,
                old_upgrade_cost: old_cookies.upgrade_cost,
                player: player_address,
            },
        );

        old_cookies.cookies = new_cookies;
        old_cookies.click_multiplier = new_click_multiplier;
        old_cookies.upgrade_cost = upgrade_cost;
    }

        
    /// Mints a Cookie NFT and transfers it to the specified receiver.
    ///
    /// This function mints a Cookie NFT using the token data ID stored in the module,
    /// and transfers the minted token to the specified receiver's account.
    ///
    /// Parameters:
    /// - `receiver`: The signer representing the receiver's account.
    ///
    /// # Errors
    ///
    /// This function does not have any specific error codes.
    ///
    /// Returns: None
    ///
    fun mint_cookie_nft(receiver: &signer) acquires ModuleData {
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);

        // Create a signer of the resource account from the signer capability stored in this module.
        // Using a resource account and storing its signer capability within the module allows the module to programmatically
        // sign transactions on behalf of the module.
        let resource_signer = account::create_signer_with_capability(&module_data.signer_cap);
        let token_id = token::mint_token(&resource_signer, module_data.token_data_id, 1);
        token::direct_transfer(&resource_signer, receiver, token_id, 1);

        // Mutate the token properties to update the property version of this token.
        // Note that here we are re-using the same token data id and only updating the property version.
        // This is because we are simply printing edition of the same token, instead of creating unique
        // tokens. The tokens created this way will have the same token data id, but different property versions.
        let (creator_address, collection, name) = token::get_token_data_id_fields(&module_data.token_data_id);
        token::mutate_token_properties(
            &resource_signer,
            signer::address_of(receiver),
            creator_address,
            collection,
            name,
            0,
            1,
            vector::empty<String>(),
            vector::empty<vector<u8>>(),
            vector::empty<String>(),
        );
    }


    /// Function that swaps cookies for an NFT.
    ///
    /// Parameters:
    /// - `player`: The signer representing the player's account.
    ///
    /// # Errors
    ///
    /// This function reverts with the following error codes
    /// - `ENO_COOKIE_FOUND`: If the player does not have an existing game.
    /// - `ENOT_ENOUGH_COOKIES_FOR_SWAP`: If the player does not have enough cookies to perform the swap.
    ///
    /// Emits a `CookieToNFT` event with information about the swap.
    public fun swop_cookie_for_nft(player: signer) acquires Cookie, ModuleData {
        let player_address: address = signer::address_of(&player);
        assert!(exists<Cookie>(player_address), error::not_found(ENO_COOKIE_FOUND));
        let old_cookies = borrow_global_mut<Cookie>(player_address);
        let current_threshold: u256 = ((old_cookies.initial_threshold * old_cookies.increment_multiplier) / 100) + old_cookies.initial_threshold;
        assert!(old_cookies.cookies >= current_threshold, error::not_found(ENOT_ENOUGH_COOKIES_FOR_SWAP));
        old_cookies.cookies = old_cookies.cookies - current_threshold;
        old_cookies.initial_threshold = current_threshold;
        mint_cookie_nft(&player);
        let cookies_left: u256 = old_cookies.cookies - current_threshold;
        event::emit_event(
            &mut old_cookies.cookie_nft_swap_event,
            CookieToNFT {
                cookie_threshold: current_threshold,
                cookies_left: cookies_left,
                player: player_address,
            },
        );
    }

    /// Function that retrieves the number of cookies for a given player.
    ///
    /// Parameters:
    /// - `player`: The address of the player's account.
    ///
    /// This example retrieves the number of cookies for the given player.
    ///
    /// # Errors
    ///
    /// This function can return the following errors:
    /// - `ENO_COOKIE_FOUND`: If the player does not have an existing game.
    ///
    /// Returns: The number of cookies for the player.
    public fun get_cookie(player: address): u256 acquires Cookie {
        assert!(exists<Cookie>(player), error::not_found(ENO_COOKIE_FOUND));
        borrow_global<Cookie>(player).cookies
    }

    /// Function that retrieves the click multiplier for a given player.
    ///
    /// Parameters:
    /// - `player`: The address of the player's account.
    ///
    /// This example retrieves the click multiplier for the given player.
    ///
    /// # Errors
    ///
    /// This function can return the following errors:
    /// - `ENO_COOKIE_FOUND`: If the player does not have an existing game.
    ///
    /// Returns: The click multiplier for the player.
    public fun get_player_click_multiplier(player: address): u256 acquires Cookie {
        assert!(exists<Cookie>(player), error::not_found(ENO_COOKIE_FOUND));
        borrow_global<Cookie>(player).click_multiplier
    }

    // Unit tests
    #[test_only]
      const EBALANCE_NOT_DEDUCTED: u64 = 6;
    #[test_only]
    fun setup(aptos_framework: &signer, sponsor: &signer): BurnCapability<AptosCoin> {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<AptosCoin>(
            aptos_framework,
            string::utf8(b"CC"),
            string::utf8(b"CC"),
            8,
            false,
        );
        coin::register<AptosCoin>(sponsor);
        let coins = coin::mint<AptosCoin>(100000, &mint_cap);
        coin::deposit(signer::address_of(sponsor), coins);
        coin::destroy_mint_cap(mint_cap);
        coin::destroy_freeze_cap(freeze_cap);

        burn_cap
    }



    #[test(player = @0xcafe,player_again= @0xcafe,resource_account = @0xc3bb8488ab1a5815a9d543d7e41b0e0df46a7396f89b22821f07a4362f75ddc5,aptos_framework = @aptos_framework)]
    public entry fun player_create_cookie(player: signer,player_again: signer,aptos_framework:signer,resource_account:signer) acquires Cookie,TokensClaimed,ModuleData  {
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        timestamp::update_global_time_for_test_secs(10);
        create_account_for_test(signer::address_of(&player));
        resource_account::create_resource_account(&player, vector::empty<u8>(), vector::empty<u8>());
        let player_address = signer::address_of(&player);
        init_module(&resource_account);
        claim_tokens(player);
        create_cookie(player_again, 0, false);

        assert!(get_cookie(player_address) == 0, ENO_COOKIE_FOUND);
        assert!(coin::balance<AptosCoin>(player_address) == 100000-PLAY_COST, EBALANCE_NOT_DEDUCTED);
 
    }

     #[test(player = @0x1, player_again = @0x1,resource_account = @0xc3bb8488ab1a5815a9d543d7e41b0e0df46a7396f89b22821f07a4362f75ddc5,aptos_framework = @aptos_framework)]
    public entry fun player_create_cookie_and_update(player: signer, player_again: signer,aptos_framework:signer,resource_account:signer) acquires Cookie,TokensClaimed,ModuleData {
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        timestamp::update_global_time_for_test_secs(10);
        create_account_for_test(signer::address_of(&player));
        resource_account::create_resource_account(&player, vector::empty<u8>(), vector::empty<u8>());
        let player_address = signer::address_of(&player);
        init_module(&resource_account);
        claim_tokens(player);
        create_cookie(player, 0, false);
        assert!(get_cookie(player_address) == 0, ENO_COOKIE_FOUND);
        create_cookie(player_again, 2000, false);
        assert!(get_cookie(player_address) == 2000, ENO_COOKIE_FOUND);
    }

    #[test(player = @0x1, player_again = @0x1, player_again1 = @0x1,resource_account = @0xc3bb8488ab1a5815a9d543d7e41b0e0df46a7396f89b22821f07a4362f75ddc5,aptos_framework = @aptos_framework)]
    public entry fun player_create_cookie_and_upgrade(player: signer, player_again: signer, player_again1: signer,aptos_framework:signer,resource_account:signer) acquires Cookie,TokensClaimed,ModuleData {
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        timestamp::update_global_time_for_test_secs(10);
        create_account_for_test(signer::address_of(&player));
        resource_account::create_resource_account(&player, vector::empty<u8>(), vector::empty<u8>());
        let player_address = signer::address_of(&player);
        init_module(&resource_account);
        claim_tokens(player);
        create_cookie(player, 0, false);
        assert!(get_cookie(player_address) == 0, ENO_COOKIE_FOUND);
        upgrade_cookie(player_again);
        assert!(get_cookie(player_address) == 990, ENO_COOKIES_NOT_UPGRADED);
        assert!(get_player_click_multiplier(player_address) == 2, ENO_INVALID_CLICK_MULTIPLIER);

        upgrade_cookie(player_again1);
        assert!(get_player_click_multiplier(player_address) == 4, ENO_INVALID_CLICK_MULTIPLIER);
    }

    #[test(player = @0x1, player_again = @0x1, player_again1 = @0x1,resource_account = @0xc3bb8488ab1a5815a9d543d7e41b0e0df46a7396f89b22821f07a4362f75ddc5,aptos_framework = @aptos_framework)]
    public entry fun player_create_cookie_new_game(player: signer, player_again: signer, player_again1: signer,aptos_framework:signer,resource_account:signer) acquires Cookie,TokensClaimed,ModuleData {
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        timestamp::update_global_time_for_test_secs(10);
        create_account_for_test(signer::address_of(&player));
        resource_account::create_resource_account(&player, vector::empty<u8>(), vector::empty<u8>());
        let player_address = signer::address_of(&player);
        init_module(&resource_account);
        claim_tokens(player);
        create_cookie(player, 0, false);
        assert!(get_cookie(player_address) == 0, ENO_COOKIE_FOUND);

        create_cookie(player_again, 2000, true);
        assert!(get_cookie(player_address) == 2000, ENO_COOKIE_FOUND);
    }

    #[test(player = @0xcafe, player_again = @0xcafe,player_again_1 = @0xcafe,resource_account = @0xc3bb8488ab1a5815a9d543d7e41b0e0df46a7396f89b22821f07a4362f75ddc5,aptos_framework = @aptos_framework)]
    public entry fun player_create_cookie_new_game_and_swop_cookie_for_nft(player: signer, player_again: signer,player_again_1: signer,resource_account:signer,aptos_framework:signer) acquires Cookie,TokensClaimed,ModuleData {
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        timestamp::update_global_time_for_test_secs(10);
        create_account_for_test(signer::address_of(&player));
        resource_account::create_resource_account(&player, vector::empty<u8>(), vector::empty<u8>());
        let player_address = signer::address_of(&player);
        init_module(&resource_account);
        claim_tokens(player);
        create_cookie(player, 0, false);
        assert!(get_cookie(player_address) == 0, ENO_COOKIE_FOUND);

        create_cookie(player_again, 20000, true);
        assert!(get_cookie(player_address) == 20000, ENO_COOKIE_FOUND);
        swop_cookie_for_nft(player_again_1);
        assert!(get_cookie(player_address) == 13000, ECOOKIES_NOT_SWOPED);
    }
 
    // Negative tests
    #[test(player = @0x1)]
    #[expected_failure(abort_code = 393216, location = Self)]
    public entry fun player_get_cookie_fail(player: signer) acquires Cookie {
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        timestamp::update_global_time_for_test_secs(10);
        create_account_for_test(signer::address_of(&player));
        resource_account::create_resource_account(&player, vector::empty<u8>(), vector::empty<u8>());
        let player_address = signer::address_of(&player);
        init_module(&resource_account);

        assert!(get_cookie(player_address) == 0, ENO_COOKIE_FOUND);
    }


    #[test(player = @0x1)]
    #[expected_failure(abort_code = 393216, location = Self)]
    public entry fun player_create_cookie_new_game_fail(player: signer) acquires Cookie {
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        timestamp::update_global_time_for_test_secs(10);
        create_account_for_test(signer::address_of(&player));
        resource_account::create_resource_account(&player, vector::empty<u8>(), vector::empty<u8>());
        let player_address = signer::address_of(&player);
        init_module(&resource_account);
        assert!(get_player_click_multiplier(player_address) == 4, ENO_INVALID_CLICK_MULTIPLIER);
    }

   
}
