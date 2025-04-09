module crimechase::mint_helper {
    
    use std::string::{String};

    use aptos_framework::object::{Object};

    use crimechase::badge_draw_ticket;
    use crimechase::crimechase_token;

    
    entry fun mint_with_ticket(
        caller: &signer,
        account_no: u64,
        collection: String,
        description: String,
        name: String,
        uri: String,
        category: String,
        type: String,
        rarity: String,
        property_keys: vector<String>,
        property_types: vector<String>,
        property_values: vector<vector<u8>>,
        to: address,
    ) 
    {
        badge_draw_ticket::decrease_count(caller, account_no, 1);
        crimechase_token::mint_to(caller, collection, description, name, uri, category, type, rarity, property_keys, property_types, property_values, to);
    }

    entry fun mint_with_burn_pair<T: key>(
        caller: &signer,
        token_1: Object<T>,
        token_2: Object<T>,
        collection: String,
        description: String,
        name: String,
        uri: String,
        category: String,
        type: String,
        rarity: String,
        property_keys: vector<String>,
        property_types: vector<String>,
        property_values: vector<vector<u8>>,
        to: address
        ) 
    { 
        crimechase_token::burn_pair_token(caller, token_1, token_2);
        crimechase_token::mint_to(caller, collection, description, name, uri, category, type, rarity, property_keys, property_types, property_values, to);
    }

}