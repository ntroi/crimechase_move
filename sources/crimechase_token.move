module crimechase::crimechase_token {
    use std::error;
    use std::option::{Self, Option};
    use std::string::{Self, String};
    use std::signer;
    use std::vector;

    use aptos_framework::object::{Self, ConstructorRef, Object};
    use aptos_framework::aggregator_v2::{Self, Aggregator, AggregatorSnapshot};
    use aptos_framework::event;

    use aptos_token_objects::collection;
    use aptos_token_objects::property_map;
    use aptos_token_objects::royalty;
    use aptos_token_objects::token;

    use crimechase::utilities;
    use crimechase::appsigner;
    
    /// Error codes...
    /// The collection does not exist
    const ECOLLECTION_DOES_NOT_EXIST: u64 = 1;
    /// The token does not exist
    const ETOKEN_DOES_NOT_EXIST: u64 = 2;
    /// The provided signer is not the creator
    const ENOT_CREATOR: u64 = 3;
    /// The field being changed is not mutable
    const EFIELD_NOT_MUTABLE: u64 = 4;
    /// The token being burned is not burnable
    const ETOKEN_NOT_BURNABLE: u64 = 5;
    /// The property map being mutated is not mutable
    const EPROPERTIES_NOT_MUTABLE: u64 = 6;    
    const ENOT_AUTHORIZED: u64 = 7;
    const ETOKEN_NOT_TRANSFERBLE: u64 = 8;

    const ESUBCOLLECTION_DOSE_NOT_EXIST: u64 = 9;
    const EINDEX_DOES_NOT_EXIST: u64 = 10;
    const ECOLLECTION_SUPPLY_EXCEEDED: u64 = 11;
    const ETOKEN_LOCKED: u64 = 12;
    const ETOKEN_LIST_EMPTY: u64 = 13;
    const EPROPERTIES_INPUT_NOT_MATCHED: u64 = 14;
    const EPROPERTIES_INPUT_SIZE_EXCEEDED: u64 = 15;

    /// const values 
    const CONST_COLLECTION_LIMIT_DEDICATOR: u64 = 999999999;
    const CONST_PROPERTIES_INPUT_SIZE_MAX: u64 = 50;

    const CONST_APPSIGNER_SEED: vector<u8> = b"CRIMECHASETOKEN";
    
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct CrimeChaseCollection has key {
        /// Used to mutate collection fields
        mutator_ref: Option<collection::MutatorRef>,
        /// Used to mutate royalties
        royalty_mutator_ref: Option<royalty::MutatorRef>,
        /// Determines if the creator can mutate the collection's description
        mutable_description: bool,
        /// Determines if the creator can mutate the collection's uri
        mutable_uri: bool,
        /// Determines if the creator can mutate token descriptions
        mutable_token_description: bool,
        /// Determines if the creator can mutate token names
        mutable_token_name: bool,
        /// Determines if the creator can mutate token properties
        mutable_token_properties: bool,
        /// Determines if the creator can mutate token uris
        mutable_token_uri: bool,
        /// Determines if the creator can burn tokens
        tokens_burnable_by_creator: bool,
        /// Determines if the creator can freeze tokens
        tokens_freezable_by_creator: bool,
        /// Determines if the index of token is 
        tokens_indexed_by_subcollection: bool,
        /// Determines if the index of token is 
        tokens_indexed_automatically: bool,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct CrimeChaseSubCollection has key {
        parent: Object<CrimeChaseCollection>,
        sub_name: String,
        current_supply: Aggregator<u64>, 
        total_minted: Aggregator<u64>,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]    
    struct CrimeChaseToken has key {
        /// Used to burn.
        burn_ref: Option<token::BurnRef>,
        /// Used to control freeze.
        transfer_ref: Option<object::TransferRef>,
        /// Used to mutate fields
        mutator_ref: Option<token::MutatorRef>,
        /// Used to mutate properties
        property_mutator_ref: property_map::MutatorRef,
        /// 
        index: Option<AggregatorSnapshot<u64>>,
        ///
        is_lock: bool,        
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]    
    struct CrimeChaseTokenUniqueKey has key {
        unique_key : u64,
    }


    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]    
    struct CrimeChaseContentskey has key {
        key : String,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]    
    struct CrimeChaseResetProperty has key {
        keys : vector<String>,
    }

    //events
    #[event]
    struct BurnTokenEvent has drop, store {
        caller: address,
        token_id: address,
    }
    
    /// Create a new unlimited collection
    /// 
    public entry fun create_collection(
        creator: &signer,
        description: String,
        name: String,
        uri: String,
        mutable_description: bool,
        mutable_royalty: bool,
        mutable_uri: bool,
        mutable_token_description: bool,
        mutable_token_name: bool,
        mutable_token_properties: bool,
        mutable_token_uri: bool,
        tokens_burnable_by_creator: bool,
        tokens_freezable_by_creator: bool,
        tokens_indexed_by_subcollection: bool,
        tokens_indexed_automatically: bool,
        royalty_numerator: u64,
        royalty_denominator: u64,        
    ) {
        create_collection_object(
            creator,
            description,
            CONST_COLLECTION_LIMIT_DEDICATOR,
            name,
            uri,
            mutable_description,
            mutable_royalty,
            mutable_uri,
            mutable_token_description,
            mutable_token_name,
            mutable_token_properties,
            mutable_token_uri,
            tokens_burnable_by_creator,
            tokens_freezable_by_creator,
            tokens_indexed_by_subcollection,
            tokens_indexed_automatically,
            royalty_numerator,
            royalty_denominator
        );
    }

    fun create_collection_object(
        creator: &signer,
        description: String,
        _max_supply: u64,
        name: String,
        uri: String,
        mutable_description: bool,
        mutable_royalty: bool,
        mutable_uri: bool,
        mutable_token_description: bool,
        mutable_token_name: bool,
        mutable_token_properties: bool,
        mutable_token_uri: bool,
        tokens_burnable_by_creator: bool,
        tokens_freezable_by_creator: bool,
        tokens_indexed_by_subcollection: bool,
        tokens_indexed_automatically: bool,
        royalty_numerator: u64,
        royalty_denominator: u64,
    ): Object<CrimeChaseCollection> {
        assert!(utilities::is_authorized(creator), ENOT_AUTHORIZED);

        let appsigner = appsigner::get_appsigner(creator);

        let creator_addr = signer::address_of(creator);
        let royalty = royalty::create(royalty_numerator, royalty_denominator, creator_addr);
        let constructor_ref = collection::create_unlimited_collection(
                &appsigner,
                description,
                name,
                option::some(royalty),
                uri);        

        let object_signer = object::generate_signer(&constructor_ref);
        let mutator_ref = if (mutable_description || mutable_uri) {
            option::some(collection::generate_mutator_ref(&constructor_ref))
        } else {
            option::none()
        };

        let royalty_mutator_ref = if (mutable_royalty) {
            option::some(royalty::generate_mutator_ref(object::generate_extend_ref(&constructor_ref)))
        } else {
            option::none()
        };

        let aptos_collection = CrimeChaseCollection {
            mutator_ref,
            royalty_mutator_ref,
            mutable_description,
            mutable_uri,
            mutable_token_description,
            mutable_token_name,
            mutable_token_properties,
            mutable_token_uri,
            tokens_burnable_by_creator,
            tokens_freezable_by_creator,
            tokens_indexed_by_subcollection,
            tokens_indexed_automatically,
        };
        move_to(&object_signer, aptos_collection);        

        object::object_from_constructor_ref(&constructor_ref)
    }

    fun create_subcollection<T: key>(
        creator: &signer,
        collection: Object<T>,
        subcollection: &String,
    ) : Object<CrimeChaseSubCollection> {
        let collection_name = collection::name(collection);
        let subcollection_name = *string::bytes(&collection_name);
        vector::append(&mut subcollection_name, b"::");
        vector::append(&mut subcollection_name, *string::bytes(subcollection));

        let parent = object::convert<T, CrimeChaseCollection>(collection);

        let constructor_ref = object::create_named_object(creator, subcollection_name);
        let subcollection = CrimeChaseSubCollection {
            parent, 
            sub_name: string::utf8(subcollection_name),
            current_supply: aggregator_v2::create_unbounded_aggregator(),
            total_minted: aggregator_v2::create_unbounded_aggregator(),
        };

        let object_signer = object::generate_signer(&constructor_ref);
        move_to(&object_signer, subcollection);

        object::object_from_constructor_ref<CrimeChaseSubCollection>(&constructor_ref)
    }
    
    public entry fun mint_to(
        creator: &signer,
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
    ) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        // it is only permmited for package publisher
        assert!(utilities::is_authorized(creator), ENOT_AUTHORIZED);

        let appsigner = appsigner::get_appsigner(creator);

        let token = mint_token_object(&appsigner, collection, description, name, uri, category, type, rarity, property_keys, property_types, property_values);
        object::transfer(&appsigner, token, to);        
    }
    
    public entry fun mint(
        creator: &signer,
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
    ) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        // it is only permmited for package publisher
        assert!(utilities::is_authorized(creator), ENOT_AUTHORIZED);

        let appsigner = appsigner::get_appsigner(creator);

        mint_token_object(&appsigner, collection, description, name, uri, category, type, rarity, property_keys, property_types, property_values);
    }

    public entry fun mint_with_validator(
        creator: &signer,
        validator: &signer,
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
    ) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        assert!(utilities::is_authorized(validator), ENOT_AUTHORIZED);
        
        let appsigner = appsigner::get_appsigner(creator);

        mint_token_object(&appsigner, collection, description, name, uri, category, type, rarity, property_keys, property_types, property_values);
    }

    public entry fun mint_with_validator_to(
        creator: &signer,
        validator: &signer,
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
    ) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        assert!(utilities::is_authorized(validator), ENOT_AUTHORIZED);

        let appsigner = appsigner::get_appsigner(creator);

        let token = mint_token_object(&appsigner, collection, description, name, uri, category, type, rarity, property_keys, property_types, property_values);
        object::transfer(&appsigner, token, to);
    }

    entry fun mint_with_uniquekey(
        creator: &signer,
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
        unique_key: u64,        
        to: address,
    ) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        // it is only permmited for package publisher
        assert!(utilities::is_authorized(creator), ENOT_AUTHORIZED);

        let appsigner = appsigner::get_appsigner(creator);

        let token = mint_token_object_with_uniquekey(&appsigner, collection, description, name, uri, category, type, rarity, property_keys, property_types, property_values, unique_key);

        object::transfer(&appsigner, token, to);
    }   

     entry fun mint_and_lock(
        creator: &signer,
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
        unique_key: u64,        
        to: address,
        lock: bool,
    ) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        // it is only permmited for package publisher
        assert!(utilities::is_authorized(creator), ENOT_AUTHORIZED);

        let appsigner = appsigner::get_appsigner(creator);

        let token = mint_token_object_with_uniquekey(&appsigner, collection, description, name, uri, category, type, rarity, property_keys, property_types, property_values, unique_key);        

        object::transfer(&appsigner, token, to);
        lock(creator, token, lock);
    }      

    // Property is easily removable by accepting an additional reset property.
    entry fun mint_and_lock_v2(creator: &signer,
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
        property_keys_reset: vector<String>,
        property_types_reset: vector<String>,
        property_values_reset: vector<vector<u8>>,
        unique_key: u64,        
        to: address,
        lock: bool,
    ) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        // it is only permmited for package publisher
        assert!(utilities::is_authorized(creator), ENOT_AUTHORIZED);

        let appsigner = appsigner::get_appsigner(creator);

        // Create the token with reset properties
        let token = mint_token_object_with_uniquekey_and_reset(
            &appsigner, 
            collection, 
            description, 
            name, 
            uri, 
            category, 
            type, 
            rarity, 
            property_keys, 
            property_types, 
            property_values,
            property_keys_reset,
            property_types_reset,
            property_values_reset,
            unique_key
        );
        
        object::transfer(&appsigner, token, to);
        lock(creator, token, lock);
    }

    // Internal function that creates a token with reset properties
    fun mint_token_object_with_uniquekey_and_reset(
        creator: &signer,
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
        property_keys_reset: vector<String>,
        property_types_reset: vector<String>,
        property_values_reset: vector<vector<u8>>,
        unique_key: u64,
    ): Object<CrimeChaseToken> acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        // Combine regular properties and reset properties
        let combined_keys = vector::empty<String>();
        let combined_types = vector::empty<String>();
        let combined_values = vector::empty<vector<u8>>();
        
        // Add regular properties
        let i = 0;
        while (i < vector::length(&property_keys)) {
            vector::push_back(&mut combined_keys, *vector::borrow(&property_keys, i));
            vector::push_back(&mut combined_types, *vector::borrow(&property_types, i));
            vector::push_back(&mut combined_values, *vector::borrow(&property_values, i));
            i = i + 1;
        };
        
        // Add reset properties
        let i = 0;
        while (i < vector::length(&property_keys_reset)) {
            vector::push_back(&mut combined_keys, *vector::borrow(&property_keys_reset, i));
            vector::push_back(&mut combined_types, *vector::borrow(&property_types_reset, i));
            vector::push_back(&mut combined_values, *vector::borrow(&property_values_reset, i));
            i = i + 1;
        };
        
        // Create token with constructor_ref to get signer
        let constructor_ref = mint_internal_with_uniquekey(
            creator,
            collection,
            description,
            name,
            uri,
            category, 
            type,
            rarity,
            combined_keys,
            combined_types,
            combined_values,
            unique_key,
        );
        
        // Generate object signer from constructor_ref
        let object_signer = object::generate_signer(&constructor_ref);
        
        // Store reset keys in CrimeChaseResetProperty
        let reset_property = CrimeChaseResetProperty {
            keys: property_keys_reset,
        };
        move_to(&object_signer, reset_property);
        
        // Get collection and handle freezable tokens
        let collection = collection_object(creator, &collection);
        let freezable_by_creator = are_collection_tokens_freezable(collection);
        
        if (freezable_by_creator) {
            let crimechase_token_addr = object::address_from_constructor_ref(&constructor_ref);
            let crimechase_token = borrow_global_mut<CrimeChaseToken>(crimechase_token_addr);
            let transfer_ref = object::generate_transfer_ref(&constructor_ref);
            option::fill(&mut crimechase_token.transfer_ref, transfer_ref);
        };

        object::object_from_constructor_ref(&constructor_ref)
    }

    public entry fun upsert_properties_v2<T: key>(
        creator: &signer,
        token: Object<T>,
        keys: vector<String>,
        types: vector<String>,
        values: vector<vector<u8>>,
        keys_reset: vector<String>,
        types_reset: vector<String>,
        values_reset: vector<vector<u8>>,
    ) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseResetProperty {
        let crimechase_token = authorized_borrow(&token, creator);
        assert!(
            are_properties_mutable(token),
            error::permission_denied(EPROPERTIES_NOT_MUTABLE),
        );

        // Validate regular properties
        let key_length = vector::length(&keys);
        let type_length = vector::length(&types);
        let value_length = vector::length(&values);

        assert!(
            key_length == type_length && key_length == value_length,
            EPROPERTIES_INPUT_NOT_MATCHED,
        );

        assert!(
            key_length > 0 && key_length < CONST_PROPERTIES_INPUT_SIZE_MAX,
            EPROPERTIES_INPUT_SIZE_EXCEEDED,
        );
        
        // Validate reset properties
        let reset_key_length = vector::length(&keys_reset);
        let reset_type_length = vector::length(&types_reset);
        let reset_value_length = vector::length(&values_reset);
        
        assert!(
            reset_key_length == reset_type_length && reset_key_length == reset_value_length,
            EPROPERTIES_INPUT_NOT_MATCHED,
        );
        
        // Get CrimeChaseResetProperty from the token
        let token_address = object::object_address(&token);

        if(exists<CrimeChaseResetProperty>(token_address))
        {
            let old_reset_property = borrow_global_mut<CrimeChaseResetProperty>(token_address);        
        
            // Remove previously stored reset keys
            let old_reset_keys = &old_reset_property.keys;
            let i = 0;
            while (i < vector::length(old_reset_keys)) {
                let key = vector::borrow(old_reset_keys, i);
                if (property_map::contains_key(&token, key)) {
                    property_map::remove(&crimechase_token.property_mutator_ref, key);
                };
                i = i + 1;
            };
        
            // Update with new reset keys
            old_reset_property.keys = keys_reset;
        };        
        
        // Update all regular properties
        while (!vector::is_empty(&keys)) {
            let key = vector::pop_back(&mut keys);
            let type = vector::pop_back(&mut types);
            let value = vector::pop_back(&mut values);

            if(property_map::contains_key(&token, &key)) {
                property_map::update(&crimechase_token.property_mutator_ref, &key, type, value);
            } else {
                property_map::add(&crimechase_token.property_mutator_ref, key, type, value);
            };
        };
        
        // Add or update reset properties
        while (!vector::is_empty(&keys_reset)) {
            let key = vector::pop_back(&mut keys_reset);
            let type = vector::pop_back(&mut types_reset);
            let value = vector::pop_back(&mut values_reset);

            if(property_map::contains_key(&token, &key)) {
                property_map::update(&crimechase_token.property_mutator_ref, &key, type, value);
            } else {
                property_map::add(&crimechase_token.property_mutator_ref, key, type, value);
            };
        };
    }

    /// Mint a token into an existing collection, and retrieve the object / address of the token.
    fun mint_token_object(
        creator: &signer,
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
    ): Object<CrimeChaseToken> acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {       

        let constructor_ref = mint_internal(
            creator,
            collection,
            description,
            name,
            uri,
            category, 
            type,
            rarity,
            property_keys,
            property_types,
            property_values,
        );

        let collection = collection_object(creator, &collection);

        // If tokens are freezable, add a transfer ref to be able to freeze transfers
        let freezable_by_creator = are_collection_tokens_freezable(collection);
        if (freezable_by_creator) {
            let crimechase_token_addr = object::address_from_constructor_ref(&constructor_ref);
            let crimechase_token = borrow_global_mut<CrimeChaseToken>(crimechase_token_addr);
            let transfer_ref = object::generate_transfer_ref(&constructor_ref);
            option::fill(&mut crimechase_token.transfer_ref, transfer_ref);
        };

        object::object_from_constructor_ref(&constructor_ref)
    }    

       /// Mint a token into an existing collection, and retrieve the object / address of the token.
    fun mint_token_object_with_uniquekey(
        creator: &signer,
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
        unique_key: u64,
    ): Object<CrimeChaseToken> acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {       

        let constructor_ref = mint_internal_with_uniquekey(
            creator,
            collection,
            description,
            name,
            uri,
            category, 
            type,
            rarity,
            property_keys,
            property_types,
            property_values,
            unique_key,
        );

        let collection = collection_object(creator, &collection);

        // If tokens are freezable, add a transfer ref to be able to freeze transfers
        let freezable_by_creator = are_collection_tokens_freezable(collection);
        if (freezable_by_creator) {
            let crimechase_token_addr = object::address_from_constructor_ref(&constructor_ref);
            let crimechase_token = borrow_global_mut<CrimeChaseToken>(crimechase_token_addr);
            let transfer_ref = object::generate_transfer_ref(&constructor_ref);
            option::fill(&mut crimechase_token.transfer_ref, transfer_ref);
        };

        object::object_from_constructor_ref(&constructor_ref)
    }

    fun mint_internal(
        creator: &signer,
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
    ): ConstructorRef acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        
        let constructor_ref = token::create(creator, collection, description, name, option::none(), uri);
        let object_signer = object::generate_signer(&constructor_ref);

        let collection_obj = collection_object(creator, &collection);
        let collection = borrow_collection(&collection_obj);        
   
        let mutator_ref = if (
            collection.mutable_token_description
                || collection.mutable_token_name
                || collection.mutable_token_uri
        ) {
            option::some(token::generate_mutator_ref(&constructor_ref))
        } else {
            option::none()
        };

        let burn_ref = if (collection.tokens_burnable_by_creator) {
            option::some(token::generate_burn_ref(&constructor_ref))
        } else {
            option::none()
        };

        let index = if(collection.tokens_indexed_by_subcollection) {

            let subcollection_name_seed = *string::bytes(&category);
            vector::append(&mut subcollection_name_seed, b"_");
            vector::append(&mut subcollection_name_seed, *string::bytes(&type));
            vector::append(&mut subcollection_name_seed, b"_");
            vector::append(&mut subcollection_name_seed, *string::bytes(&rarity));

            let subcollection_name = string::utf8(subcollection_name_seed);
            if(!is_exist_subcollection(creator, collection_obj, &subcollection_name)) {
                create_subcollection(creator, collection_obj, &subcollection_name);
            };

            let subcollection = borrow_mut_subcollection(creator, collection_obj, &subcollection_name);
            option::some(increment_supply(subcollection))
        } else {
            option::none()
        };

        let property_mutator_ref = property_map::generate_mutator_ref(&constructor_ref); 
        let properties = property_map::prepare_input(property_keys, property_types, property_values);
        property_map::init(&constructor_ref, properties);
        property_map::add_typed(&property_mutator_ref, string::utf8(b"Category"), category);
        property_map::add_typed(&property_mutator_ref, string::utf8(b"Type"), type);
        property_map::add_typed(&property_mutator_ref, string::utf8(b"Rarity"), rarity);

        let crimechase_token = CrimeChaseToken {
            burn_ref,
            transfer_ref: option::none(),
            mutator_ref,
            property_mutator_ref,
            index,
            is_lock: false,
        }; 

        move_to(&object_signer, crimechase_token);        

        //let i = token::index(object::object_from_constructor_ref<CrimeChaseToken>(&constructor_ref));
        let i = instance(object::object_from_constructor_ref<CrimeChaseToken>(&constructor_ref));
        let new_name = name;
        string::append(&mut new_name, string::utf8(b" #"));            
        string::append(&mut new_name, aptos_std::string_utils::to_string(&i));

        token::set_name(&token::generate_mutator_ref(&constructor_ref), new_name);

        constructor_ref
    }

     fun mint_internal_with_uniquekey(
        creator: &signer,
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
        unique_key: u64,
    ): ConstructorRef acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        //this key in unique in category
        let constructor_ref = if(unique_key != 0) {
            let key_string = aptos_std::string_utils::to_string_with_integer_types(&unique_key);
            let seed_string = aptos_std::string_utils::format2(&b"{}_{}", category, key_string);
            token::create_named_token(creator, collection, description, seed_string, option::none(), uri)
        } else {
            token::create_named_token(creator, collection, description, name, option::none(), uri)
        };
        
        let object_signer = object::generate_signer(&constructor_ref);

        let collection_obj = collection_object(creator, &collection);
        let collection = borrow_collection(&collection_obj);        
   
        let mutator_ref = if (
            collection.mutable_token_description
                || collection.mutable_token_name
                || collection.mutable_token_uri
        ) {
            option::some(token::generate_mutator_ref(&constructor_ref))
        } else {
            option::none()
        };

        let burn_ref = if (collection.tokens_burnable_by_creator) {
            option::some(token::generate_burn_ref(&constructor_ref))
        } else {
            option::none()
        };

        let index = if(collection.tokens_indexed_by_subcollection) {

            let subcollection_name_seed = *string::bytes(&category);
            vector::append(&mut subcollection_name_seed, b"_");
            vector::append(&mut subcollection_name_seed, *string::bytes(&type));
            vector::append(&mut subcollection_name_seed, b"_");
            vector::append(&mut subcollection_name_seed, *string::bytes(&rarity));

            let subcollection_name = string::utf8(subcollection_name_seed);
            if(!is_exist_subcollection(creator, collection_obj, &subcollection_name)) {
                create_subcollection(creator, collection_obj, &subcollection_name);
            };

            let subcollection = borrow_mut_subcollection(creator, collection_obj, &subcollection_name);
            option::some(increment_supply(subcollection))
        } else {
            option::none()
        };

        let property_mutator_ref = property_map::generate_mutator_ref(&constructor_ref); 
        let properties = property_map::prepare_input(property_keys, property_types, property_values);
        property_map::init(&constructor_ref, properties);
        property_map::add_typed(&property_mutator_ref, string::utf8(b"Category"), category);
        property_map::add_typed(&property_mutator_ref, string::utf8(b"Type"), type);
        property_map::add_typed(&property_mutator_ref, string::utf8(b"Rarity"), rarity);
        property_map::add_typed(&property_mutator_ref, string::utf8(b"UniqueKey"), unique_key);

        let crimechase_token = CrimeChaseToken {
            burn_ref,
            transfer_ref: option::none(),
            mutator_ref,
            property_mutator_ref,
            index,
            is_lock: false,
        }; 

        move_to(&object_signer, crimechase_token);        

        //let i = token::index(object::object_from_constructor_ref<CrimeChaseToken>(&constructor_ref));
        let i = instance(object::object_from_constructor_ref<CrimeChaseToken>(&constructor_ref));
        let new_name = name;
        string::append(&mut new_name, string::utf8(b" #"));            
        string::append(&mut new_name, aptos_std::string_utils::to_string(&i));

        token::set_name(&token::generate_mutator_ref(&constructor_ref), new_name);

        constructor_ref
    }

    #[view]
    public fun instance_by_token_id(token_id: address) : u64 acquires CrimeChaseCollection, CrimeChaseToken {
        instance(object::address_to_object<CrimeChaseToken>(token_id))
    }
    
    public fun instance<T: key>(token: Object<T>) : u64 acquires CrimeChaseCollection, CrimeChaseToken {
        if(are_collection_tokens_indexed_by_subcollection(token::collection_object(token))) {
            let crime_token = borrow(&token);
            assert!(option::is_some(&crime_token.index), EINDEX_DOES_NOT_EXIST);
            aggregator_v2::read_snapshot(option::borrow(&crime_token.index))
        } else {
            token::index(token)
        }
    }

    #[view]
    public fun tokendata<T: key>(token: Object<T>) : (String, u64, u64) acquires CrimeChaseCollection, CrimeChaseToken {
        (token::name(token), instance(token), 0)
    }

     /// Called by token on mint to increment supply if there's an appropriate Supply struct.
    fun increment_supply(
        subcollection: &mut CrimeChaseSubCollection,
    ) : AggregatorSnapshot<u64> {
        assert!(
            aggregator_v2::try_add(&mut subcollection.current_supply, 1),
            error::out_of_range(ECOLLECTION_SUPPLY_EXCEEDED),
        );
        aggregator_v2::add(&mut subcollection.total_minted, 1);
        aggregator_v2::snapshot(&subcollection.total_minted)
    }

    /// Called by token on burn to decrement supply if there's an appropriate Supply struct.
    fun decrement_supply(
        subcollection: &mut CrimeChaseSubCollection,
    ) {
        aggregator_v2::sub(&mut subcollection.current_supply, 1);
    }

    // Token accessors
    inline fun borrow<T: key>(token: &Object<T>): &CrimeChaseToken {
        let token_address = object::object_address(token);
        assert!(
            exists<CrimeChaseToken>(token_address),
            error::not_found(ETOKEN_DOES_NOT_EXIST),
        );
        borrow_global<CrimeChaseToken>(token_address)
    }

    #[view]
    public fun are_properties_mutable<T: key>(token: Object<T>): bool acquires CrimeChaseCollection {
        let collection = token::collection_object(token);
        borrow_collection(&collection).mutable_token_properties
    }

    #[view]
    public fun is_burnable<T: key>(token: Object<T>): bool acquires CrimeChaseToken {
        option::is_some(&borrow(&token).burn_ref)
    }

    #[view]
    public fun is_freezable_by_creator<T: key>(token: Object<T>): bool acquires CrimeChaseCollection {
        are_collection_tokens_freezable(token::collection_object(token))
    }

    #[view]
    public fun is_mutable_description<T: key>(token: Object<T>): bool acquires CrimeChaseCollection {
        is_mutable_collection_token_description(token::collection_object(token))
    }

    #[view]
    public fun is_mutable_name<T: key>(token: Object<T>): bool acquires CrimeChaseCollection {
        is_mutable_collection_token_name(token::collection_object(token))
    }

    #[view]
    public fun is_mutable_uri<T: key>(token: Object<T>): bool acquires CrimeChaseCollection {
        is_mutable_collection_token_uri(token::collection_object(token))
    }

    // Token mutators

    inline fun authorized_borrow<T: key>(token: &Object<T>, creator: &signer): &CrimeChaseToken {
        assert!(utilities::is_authorized(creator), ENOT_AUTHORIZED);

        let token_address = object::object_address(token);
        assert!(
            exists<CrimeChaseToken>(token_address),
            error::not_found(ETOKEN_DOES_NOT_EXIST),
        );
        
        borrow_global<CrimeChaseToken>(token_address)
    }

    inline fun authorized_borrow_mut<T: key>(token: &Object<T>, creator: &signer): &mut CrimeChaseToken {
        assert!(utilities::is_authorized(creator), ENOT_AUTHORIZED);

        let token_address = object::object_address(token);
        assert!(
            exists<CrimeChaseToken>(token_address),
            error::not_found(ETOKEN_DOES_NOT_EXIST),
        );

        borrow_global_mut<CrimeChaseToken>(token_address)
    }

    public entry fun burn_pair_token<T: key>(caller: &signer, token_1: Object<T>, token_2: Object<T>) acquires CrimeChaseToken {
        burn(caller, token_1);
        burn(caller, token_2);
    }

    public entry fun burn<T: key>(creator: &signer, token: Object<T>) acquires CrimeChaseToken {
        let caller_address = signer::address_of(creator);
        assert!(utilities::is_authorized(creator) || object::is_owner(token, caller_address), ENOT_AUTHORIZED);

        let crimechase_token = borrow(&token);
        assert!(
            option::is_some(&crimechase_token.burn_ref),
            error::permission_denied(ETOKEN_NOT_BURNABLE),
        );

        let token_address = object::object_address(&token);

        move crimechase_token;
        let crimechase_token = move_from<CrimeChaseToken>(token_address);
        let CrimeChaseToken {
            burn_ref,
            transfer_ref: _,
            mutator_ref: _,
            property_mutator_ref,
            index: _,
            is_lock: _,
        } = crimechase_token;
        property_map::burn(property_mutator_ref);
        token::burn(option::extract(&mut burn_ref));

        event::emit(BurnTokenEvent{
            caller: caller_address,
            token_id: token_address,            
        });
    }

    public entry fun burn_two<T: key>(caller: &signer, token_1: Object<T>, token_2: Object<T>) acquires CrimeChaseToken {
        burn(caller, token_1);
        burn(caller, token_2);
    }

    public entry fun burn_batch<T: key>(caller: &signer, tokens: vector<Object<T>>) acquires CrimeChaseToken {
        assert!(utilities::is_authorized(caller), ENOT_AUTHORIZED);
        assert!(!vector::is_empty(&tokens), ETOKEN_LIST_EMPTY);

        let address_of_caller = signer::address_of(caller);

        while (!vector::is_empty(&tokens)) {
            let token = vector::pop_back(&mut tokens);

            assert!(object::is_owner(token, address_of_caller), ENOT_AUTHORIZED);
            
            burn(caller, token);
        };
    }    

    public entry fun freeze_transfer<T: key>(creator: &signer, token: Object<T>) acquires CrimeChaseCollection, CrimeChaseToken {
        let crimechase_token = authorized_borrow(&token, creator);
        assert!(
            are_collection_tokens_freezable(token::collection_object(token))
                && option::is_some(&crimechase_token.transfer_ref),
            error::permission_denied(EFIELD_NOT_MUTABLE),
        );
        object::disable_ungated_transfer(option::borrow(&crimechase_token.transfer_ref));
    }

    public entry fun unfreeze_transfer<T: key>(
        creator: &signer,
        token: Object<T>
    ) acquires CrimeChaseCollection, CrimeChaseToken {
        let crimechase_token = authorized_borrow(&token, creator);
        assert!(
            are_collection_tokens_freezable(token::collection_object(token))
                && option::is_some(&crimechase_token.transfer_ref),
            error::permission_denied(EFIELD_NOT_MUTABLE),
        );
        object::enable_ungated_transfer(option::borrow(&crimechase_token.transfer_ref));
    }

    public entry fun set_description<T: key>(
        creator: &signer,
        token: Object<T>,
        description: String,
    ) acquires CrimeChaseCollection, CrimeChaseToken {
        assert!(
            is_mutable_description(token),
            error::permission_denied(EFIELD_NOT_MUTABLE),
        );
        let crimechase_token = authorized_borrow(&token, creator);
        token::set_description(option::borrow(&crimechase_token.mutator_ref), description);
    }

    public entry fun set_name<T: key>(
        creator: &signer,
        token: Object<T>,
        name: String,
    ) acquires CrimeChaseCollection, CrimeChaseToken {
        assert!(
            is_mutable_name(token),
            error::permission_denied(EFIELD_NOT_MUTABLE),
        );
        let crimechase_token = authorized_borrow(&token, creator);
        token::set_name(option::borrow(&crimechase_token.mutator_ref), name);
    }

    public entry fun set_uri<T: key>(
        creator: &signer,
        token: Object<T>,
        uri: String,
    ) acquires CrimeChaseCollection, CrimeChaseToken {
        assert!(
            is_mutable_uri(token),
            error::permission_denied(EFIELD_NOT_MUTABLE),
        );
        let crimechase_token = authorized_borrow(&token, creator);
        token::set_uri(option::borrow(&crimechase_token.mutator_ref), uri);
    }

    public entry fun add_property<T: key>(
        creator: &signer,
        token: Object<T>,
        key: String,
        type: String,
        value: vector<u8>,
    ) acquires CrimeChaseCollection, CrimeChaseToken {
        let crimechase_token = authorized_borrow(&token, creator);
        assert!(
            are_properties_mutable(token),
            error::permission_denied(EPROPERTIES_NOT_MUTABLE),
        );

        property_map::add(&crimechase_token.property_mutator_ref, key, type, value);
    }

    public entry fun upsert_properties<T: key>(
        creator: &signer,
        token: Object<T>,
        keys: vector<String>,
        types: vector<String>,
        values: vector<vector<u8>>,
    ) acquires CrimeChaseCollection, CrimeChaseToken {
        let crimechase_token = authorized_borrow(&token, creator);
        assert!(
            are_properties_mutable(token),
            error::permission_denied(EPROPERTIES_NOT_MUTABLE),
        );

        let key_length = vector::length(&keys);
        let type_length = vector::length(&types);
        let value_length = vector::length(&values);

        assert!(
            key_length == type_length && key_length == value_length,
            EPROPERTIES_INPUT_NOT_MATCHED,
        );

        assert!(
            key_length > 0 && key_length < CONST_PROPERTIES_INPUT_SIZE_MAX,
            EPROPERTIES_INPUT_SIZE_EXCEEDED,
        );

        while (!vector::is_empty(&keys)) {
            let key = vector::pop_back(&mut keys);
            let type = vector::pop_back(&mut types);
            let value = vector::pop_back(&mut values);

            if(property_map::contains_key(&token, &key)) {
                property_map::update(&crimechase_token.property_mutator_ref, &key, type, value);
            } else {
                property_map::add(&crimechase_token.property_mutator_ref, key, type, value);
            };
        };
    }

    public entry fun add_typed_property<T: key, V: drop>(
        creator: &signer,
        token: Object<T>,
        key: String,
        value: V,
    ) acquires CrimeChaseCollection, CrimeChaseToken {
        let crimechase_token = authorized_borrow(&token, creator);
        assert!(
            are_properties_mutable(token),
            error::permission_denied(EPROPERTIES_NOT_MUTABLE),
        );

        property_map::add_typed(&crimechase_token.property_mutator_ref, key, value);
    }

    public entry fun remove_property<T: key>(
        creator: &signer,
        token: Object<T>,
        key: String,
    ) acquires CrimeChaseCollection, CrimeChaseToken {
        let crimechase_token = authorized_borrow(&token, creator);
        assert!(
            are_properties_mutable(token),
            error::permission_denied(EPROPERTIES_NOT_MUTABLE),
        );

        property_map::remove(&crimechase_token.property_mutator_ref, &key);
    }

    public entry fun update_property<T: key>(
        creator: &signer,
        token: Object<T>,
        key: String,
        type: String,
        value: vector<u8>,
    ) acquires CrimeChaseCollection, CrimeChaseToken {
        let crimechase_token = authorized_borrow(&token, creator);
        assert!(
            are_properties_mutable(token),
            error::permission_denied(EPROPERTIES_NOT_MUTABLE),
        );

        property_map::update(&crimechase_token.property_mutator_ref, &key, type, value);
    }

    public entry fun update_typed_property<T: key, V: drop>(
        creator: &signer,
        token: Object<T>,
        key: String,
        value: V,
    ) acquires CrimeChaseCollection, CrimeChaseToken {
        let crimechase_token = authorized_borrow(&token, creator);
        assert!(
            are_properties_mutable(token),
            error::permission_denied(EPROPERTIES_NOT_MUTABLE),
        );

        property_map::update_typed(&crimechase_token.property_mutator_ref, &key, value);
    }

    // Collection accessors

    inline fun collection_object(creator: &signer, name: &String): Object<CrimeChaseCollection> {
        let collection_addr = collection::create_collection_address(&signer::address_of(creator), name);
        
        object::address_to_object<CrimeChaseCollection>(collection_addr)
    }

    inline fun borrow_collection<T: key>(token: &Object<T>): &CrimeChaseCollection {
        let collection_address = object::object_address(token);
        assert!(
            exists<CrimeChaseCollection>(collection_address),
            error::not_found(ECOLLECTION_DOES_NOT_EXIST),
        );
        borrow_global<CrimeChaseCollection>(collection_address)
    }    

    inline fun borrow_mut_subcollection<T: key>(creator: &signer, collection: Object<T>, subcollection: &String): &mut CrimeChaseSubCollection {
        assert!(utilities::is_authorized(creator), ENOT_AUTHORIZED);

        let collection_name = collection::name(collection);
        let subcollection_name = *string::bytes(&collection_name);
        vector::append(&mut subcollection_name, b"::");
        vector::append(&mut subcollection_name, *string::bytes(subcollection)); 

        let subcollection_address = object::create_object_address(&signer::address_of(creator), subcollection_name);
        assert!(
            exists<CrimeChaseSubCollection>(subcollection_address),
            error::not_found(ESUBCOLLECTION_DOSE_NOT_EXIST),
        );
        borrow_global_mut<CrimeChaseSubCollection>(subcollection_address)
    }

    public fun is_exist_subcollection<T: key>(creator: &signer, collection: Object<T>, subcollection: &String): bool {
        let collection_name = collection::name(collection);
        let subcollection_name = *string::bytes(&collection_name);
        vector::append(&mut subcollection_name, b"::");
        vector::append(&mut subcollection_name, *string::bytes(subcollection)); 

        let subcollection_address = object::create_object_address(&signer::address_of(creator), subcollection_name);
        exists<CrimeChaseSubCollection>(subcollection_address)
    }

    public fun is_mutable_collection_description<T: key>(
        collection: Object<T>,
    ): bool acquires CrimeChaseCollection {
        borrow_collection(&collection).mutable_description
    }

    public fun is_mutable_collection_royalty<T: key>(
        collection: Object<T>,
    ): bool acquires CrimeChaseCollection {
        option::is_some(&borrow_collection(&collection).royalty_mutator_ref)
    }

    public fun is_mutable_collection_uri<T: key>(
        collection: Object<T>,
    ): bool acquires CrimeChaseCollection {
        borrow_collection(&collection).mutable_uri
    }

    public fun is_mutable_collection_token_description<T: key>(
        collection: Object<T>,
    ): bool acquires CrimeChaseCollection {
        borrow_collection(&collection).mutable_token_description
    }

    public fun is_mutable_collection_token_name<T: key>(
        collection: Object<T>,
    ): bool acquires CrimeChaseCollection {
        borrow_collection(&collection).mutable_token_name
    }

    public fun is_mutable_collection_token_uri<T: key>(
        collection: Object<T>,
    ): bool acquires CrimeChaseCollection {
        borrow_collection(&collection).mutable_token_uri
    }

    public fun is_mutable_collection_token_properties<T: key>(
        collection: Object<T>,
    ): bool acquires CrimeChaseCollection {
        borrow_collection(&collection).mutable_token_properties
    }

    public fun are_collection_tokens_burnable<T: key>(
        collection: Object<T>,
    ): bool acquires CrimeChaseCollection {
        borrow_collection(&collection).tokens_burnable_by_creator
    }

    public fun are_collection_tokens_freezable<T: key>(
        collection: Object<T>,
    ): bool acquires CrimeChaseCollection {
        borrow_collection(&collection).tokens_freezable_by_creator
    }

    public fun are_collection_tokens_indexed_by_subcollection<T: key>(
        collection: Object<T>,
    ) : bool acquires CrimeChaseCollection {
        borrow_collection(&collection).tokens_indexed_by_subcollection
    }

    // Collection mutators

    inline fun authorized_borrow_collection<T: key>(collection: &Object<T>, creator: &signer): &CrimeChaseCollection {
        assert!(utilities::is_authorized(creator), ENOT_AUTHORIZED);

        let collection_address = object::object_address(collection);
        assert!(
            exists<CrimeChaseCollection>(collection_address),
            error::not_found(ECOLLECTION_DOES_NOT_EXIST),
        );
        borrow_global<CrimeChaseCollection>(collection_address)
    }

    public entry fun set_collection_description<T: key>(
        creator: &signer,
        collection: Object<T>,
        description: String,
    ) acquires CrimeChaseCollection {
        let aptos_collection = authorized_borrow_collection(&collection, creator);
        assert!(
            aptos_collection.mutable_description,
            error::permission_denied(EFIELD_NOT_MUTABLE),
        );
        collection::set_description(option::borrow(&aptos_collection.mutator_ref), description);
    }

    public fun set_collection_royalties<T: key>(
        creator: &signer,
        collection: Object<T>,
        royalty: royalty::Royalty,
    ) acquires CrimeChaseCollection {
        let aptos_collection = authorized_borrow_collection(&collection, creator);
        assert!(
            option::is_some(&aptos_collection.royalty_mutator_ref),
            error::permission_denied(EFIELD_NOT_MUTABLE),
        );
        royalty::update(option::borrow(&aptos_collection.royalty_mutator_ref), royalty);
    }

    entry fun set_collection_royalties_call<T: key>(
        creator: &signer,
        collection: Object<T>,
        royalty_numerator: u64,
        royalty_denominator: u64,
        payee_address: address,
    ) acquires CrimeChaseCollection {
        let royalty = royalty::create(royalty_numerator, royalty_denominator, payee_address);
        set_collection_royalties(creator, collection, royalty);
    }

    public entry fun set_collection_uri<T: key>(
        creator: &signer,
        collection: Object<T>,
        uri: String,
    ) acquires CrimeChaseCollection {
        let aptos_collection = authorized_borrow_collection(&collection, creator);
        assert!(
            aptos_collection.mutable_uri,
            error::permission_denied(EFIELD_NOT_MUTABLE),
        );
        collection::set_uri(option::borrow(&aptos_collection.mutator_ref), uri);
    }
    
    public entry fun forcefull_transfer<T: key>(caller: &signer, token: Object<T>, to: address) acquires CrimeChaseToken, CrimeChaseCollection {        
        assert!(utilities::is_authorized(caller), ENOT_AUTHORIZED);
        assert!(is_locked(token) == false, ETOKEN_LOCKED);

        let crimechase_token = authorized_borrow(&token, caller);
        assert!(
            are_collection_tokens_freezable(token::collection_object(token))
                && option::is_some(&crimechase_token.transfer_ref),
            error::permission_denied(EFIELD_NOT_MUTABLE),
        );
        
        let transfer_ref = option::borrow(&crimechase_token.transfer_ref);
        let linear_ref = object::generate_linear_transfer_ref(transfer_ref);

        object::transfer_with_ref(linear_ref, to);
    }

    public entry fun lock<T: key>(caller: &signer, token: Object<T>, lock: bool) acquires CrimeChaseToken {
        assert!(utilities::is_authorized(caller), ENOT_AUTHORIZED);

        let crimechase_token = authorized_borrow_mut(&token, caller);
        crimechase_token.is_lock = lock;
    }

    #[view]
    public fun is_locked<T: key>(token: Object<T>) : bool acquires CrimeChaseToken {
        let crimechase_token = borrow(&token);
        crimechase_token.is_lock
    }

    #[view]
    public fun is_locked_batch<T: key>(addresses: vector<Object<T>>) : vector<bool> acquires CrimeChaseToken {
        assert!(!vector::is_empty(&addresses), ETOKEN_LIST_EMPTY);

        let results = vector::empty<bool>();       

        while (!vector::is_empty(&addresses)) {
            let addr = vector::pop_back(&mut addresses);
            vector::push_back(&mut results, is_locked(addr));
        };

        results
    }

    #[view]
    public fun is_locked_batch_call(addresses: vector<address>) : vector<bool> acquires CrimeChaseToken {
        assert!(!vector::is_empty(&addresses), ETOKEN_LIST_EMPTY);

        let results = vector::empty<bool>();       

        while (!vector::is_empty(&addresses)) {
            let addr = vector::pop_back(&mut addresses);
            vector::push_back(&mut results, is_locked<CrimeChaseToken>(object::address_to_object<CrimeChaseToken>(addr)));
        };

        results
    }
    
    // Tests
    
    #[test_only]
    use aptos_framework::account;

    #[test(creator = @crimechase)]
    fun test_create_and_transfer(creator: &signer) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, true);
        let token = mint_to_helper(creator, collection_name, token_name, @0x345);
    }    

       #[test(creator = @crimechase)]
    fun test_create_and_transfer_uniquekey(creator: &signer) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, true);
        let token = mint_to_helper(creator, collection_name, token_name, @0x345);
        
        assert!(object::is_owner(token, @0x345), 1);
    }    

    #[test(creator = @crimechase)]
    #[expected_failure]
    fun test_frozen_transfer(creator: &signer) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);
        freeze_transfer(creator, token);
        object::transfer(creator, token, @0x345);
    }

    #[test(creator = @crimechase)]
    fun test_unfrozen_transfer(creator: &signer) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);
        freeze_transfer(creator, token);
        unfreeze_transfer(creator, token);
        object::transfer(creator, token, @0x345);
    }

    #[test(creator = @crimechase)]
    fun test_transfer_with_ref(creator: &signer) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);

        forcefull_transfer(creator, token, @0x345);
    }

    #[test(creator = @crimechase, another = @0x456)]
    #[expected_failure]
    fun test_noncreator_freeze(creator: &signer, another: &signer) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);
        freeze_transfer(another, token);
    }

    #[test(creator = @crimechase, another = @0x456)]
    #[expected_failure]
    fun test_noncreator_unfreeze(creator: &signer, another: &signer) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);
        freeze_transfer(creator, token);
        unfreeze_transfer(another, token);
    }

    #[test(creator = @crimechase)]
    fun test_set_description(creator: &signer) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);

        let description = string::utf8(b"not");
        assert!(token::description(token) != description, 0);
        set_description(creator, token, description);
        assert!(token::description(token) == description, 1);
    }

    #[test(creator = @crimechase)]
    #[expected_failure]
    fun test_set_immutable_description(creator: &signer) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, false);
        let token = mint_helper(creator, collection_name, token_name);

        set_description(creator, token, string::utf8(b""));
    }

    #[test(creator = @crimechase, noncreator = @0x456)]
    #[expected_failure]
    fun test_set_description_non_creator(
        creator: &signer,
        noncreator: &signer,
    ) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);

        let description = string::utf8(b"not");
        set_description(noncreator, token, description);
    }

    #[test(creator = @crimechase)]
    fun test_set_name(creator: &signer) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);

        let name = string::utf8(b"not");
        assert!(token::name(token) != name, 0);
        set_name(creator, token, name);
        assert!(token::name(token) == name, 1);
    }

    #[test(creator = @crimechase)]
    #[expected_failure]
    fun test_set_immutable_name(creator: &signer) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, false);
        let token = mint_helper(creator, collection_name, token_name);

        set_name(creator, token, string::utf8(b""));
    }

    #[test(creator = @crimechase, noncreator = @0x456)]
    #[expected_failure]
    fun test_set_name_non_creator(
        creator: &signer,
        noncreator: &signer,
    ) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);

        let name = string::utf8(b"not");
        set_name(noncreator, token, name);
    }

    #[test(creator = @crimechase)]
    fun test_set_uri(creator: &signer) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);

        let uri = string::utf8(b"not");
        assert!(token::uri(token) != uri, 0);
        set_uri(creator, token, uri);
        assert!(token::uri(token) == uri, 1);
    }

    #[test(creator = @crimechase)]
    #[expected_failure]
    fun test_set_immutable_uri(creator: &signer) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, false);
        let token = mint_helper(creator, collection_name, token_name);

        set_uri(creator, token, string::utf8(b""));
    }

    #[test(creator = @crimechase, noncreator = @0x456)]
    #[expected_failure]
    fun test_set_uri_non_creator(
        creator: &signer,
        noncreator: &signer,
    ) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);

        let uri = string::utf8(b"not");
        set_uri(noncreator, token, uri);
    }

    #[test(creator = @crimechase)]
    fun test_burnable(creator: &signer) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);
        let token_addr = object::object_address(&token);

        assert!(exists<CrimeChaseToken>(token_addr), 0);
        burn(creator, token);
        assert!(!exists<CrimeChaseToken>(token_addr), 1);
    }

    #[test(creator = @crimechase)]
    #[expected_failure]
    fun test_not_burnable(creator: &signer) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, false);
        let token = mint_helper(creator, collection_name, token_name);

        burn(creator, token);
    }

    #[test(creator = @crimechase, noncreator = @0x456)]
    #[expected_failure]
    fun test_burn_non_creator(
        creator: &signer,
        noncreator: &signer,
    ) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);

        burn(noncreator, token);
    }

    #[test(creator = @crimechase)]
    fun test_set_collection_description(creator: &signer) acquires CrimeChaseCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let collection = create_collection_helper(creator, collection_name, true);
        let value = string::utf8(b"not");
        assert!(collection::description(collection) != value, 0);
        set_collection_description(creator, collection, value);
        assert!(collection::description(collection) == value, 1);
    }

    #[test(creator = @crimechase)]
    #[expected_failure]
    fun test_set_immutable_collection_description(creator: &signer) acquires CrimeChaseCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let collection = create_collection_helper(creator, collection_name, false);
        set_collection_description(creator, collection, string::utf8(b""));
    }

    #[test(creator = @crimechase, noncreator = @0x456)]
    #[expected_failure]
    fun test_set_collection_description_non_creator(
        creator: &signer,
        noncreator: &signer,
    ) acquires CrimeChaseCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let collection = create_collection_helper(creator, collection_name, true);
        set_collection_description(noncreator, collection, string::utf8(b""));
    }

    #[test(creator = @crimechase)]
    fun test_set_collection_uri(creator: &signer) acquires CrimeChaseCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let collection = create_collection_helper(creator, collection_name, true);
        let value = string::utf8(b"not");
        assert!(collection::uri(collection) != value, 0);
        set_collection_uri(creator, collection, value);
        assert!(collection::uri(collection) == value, 1);
    }

    #[test(creator = @crimechase)]
    #[expected_failure]
    fun test_set_immutable_collection_uri(creator: &signer) acquires CrimeChaseCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let collection = create_collection_helper(creator, collection_name, false);
        set_collection_uri(creator, collection, string::utf8(b""));
    }

    #[test(creator = @crimechase, noncreator = @0x456)]
    #[expected_failure]
    fun test_set_collection_uri_non_creator(
        creator: &signer,
        noncreator: &signer,
    ) acquires CrimeChaseCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let collection = create_collection_helper(creator, collection_name, true);
        set_collection_uri(noncreator, collection, string::utf8(b""));
    }

    #[test(creator = @crimechase)]
    fun test_property_add(creator: &signer) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");
        let property_name = string::utf8(b"u8");
        let property_type = string::utf8(b"u8");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);
        add_property(creator, token, property_name, property_type, vector [ 0x08 ]);

        assert!(property_map::read_u8(&token, &property_name) == 0x8, 0);
    }

    #[test(creator = @crimechase)]
    fun test_property_upsert(creator: &signer) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");
        let property_name = string::utf8(b"u8");
        let property_type = string::utf8(b"u8");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);
        add_property(creator, token, property_name, property_type, vector [ 0x08 ]);

        assert!(property_map::read_u8(&token, &property_name) == 0x8, 0);
        
        let keys = vector::empty<String>();
        let types = vector::empty<String>();
        let values = vector::empty<vector<u8>>();

        vector::push_back(&mut keys, string::utf8(b"u8"));
        vector::push_back(&mut keys, string::utf8(b"u16"));

        vector::push_back(&mut types, string::utf8(b"u8"));
        vector::push_back(&mut types, string::utf8(b"u8"));

        vector::push_back(&mut values, vector[0x08]);
        vector::push_back(&mut values, vector[0x08]);

        upsert_properties(creator, token, keys, types, values);

        assert!(property_map::contains_key(&token, &string::utf8(b"u8")), 1);
        assert!(property_map::contains_key(&token, &string::utf8(b"u16")), 2);
    }

    #[test(creator = @crimechase)]
    fun test_property_typed_add(creator: &signer) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");
        let property_name = string::utf8(b"u8");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);
        add_typed_property<CrimeChaseToken, u8>(creator, token, property_name, 0x8);

        assert!(property_map::read_u8(&token, &property_name) == 0x8, 0);
    }

    #[test(creator = @crimechase)]
    fun test_property_update(creator: &signer) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");
        let property_name = string::utf8(b"bool");
        let property_type = string::utf8(b"bool");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);
        
        update_property(creator, token, property_name, property_type, vector [ 0x00 ]);

        assert!(!property_map::read_bool(&token, &property_name), 0);
    }

    #[test(creator = @crimechase)]
    fun test_property_update_typed(creator: &signer) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");
        let property_name = string::utf8(b"bool");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);
        
        update_typed_property<CrimeChaseToken, bool>(creator, token, property_name, false);

        assert!(!property_map::read_bool(&token, &property_name), 0);
    }

    #[test(creator = @crimechase)]
    fun test_property_remove(creator: &signer) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");
        let property_name = string::utf8(b"bool");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);
        
        remove_property(creator, token, property_name);
    }

    #[test(creator = @crimechase)]
    fun test_royalties(creator: &signer) acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        appsigner::setup_for_test();

        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        let collection = create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);

        let royalty_before = option::extract(&mut token::royalty(token));
        set_collection_royalties_call(creator, collection, 2, 3, @0x444);
        let royalty_after = option::extract(&mut token::royalty(token));
        assert!(royalty_before != royalty_after, 0);
    }

    #[test_only]
    fun create_collection_helper(
        creator: &signer,
        collection_name: String,
        flag: bool,
    ): Object<CrimeChaseCollection> {
        create_collection_object(
            creator,
            string::utf8(b"collection description"),
            1,
            collection_name,
            string::utf8(b"collection uri"),
            flag,
            flag,
            flag,
            flag,
            flag,
            flag,
            flag,
            flag,
            flag,
            false,
            flag,
            1,
            100,
        )
    }

    #[test_only]
    use std::bcs;

    #[test_only]
    fun mint_helper(
        creator: &signer,
        collection_name: String,
        token_name: String,
    ): Object<CrimeChaseToken> acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        let creator_addr = signer::address_of(creator);
        account::create_account_for_test(creator_addr);

        let appsigner = appsigner::get_appsigner(creator);

        mint_token_object(
            &appsigner,
            collection_name,
            string::utf8(b"description"),
            token_name,
            string::utf8(b"uri"),
            string::utf8(b"category"),
            string::utf8(b"type"),
            string::utf8(b"rarity"),
            vector[string::utf8(b"bool")],
            vector[string::utf8(b"0x1::string::String")],
            vector[bcs::to_bytes(&string::utf8(b"test"))],
        )
    }

    #[test_only]
    fun mint_to_helper(
        creator: &signer,
        collection_name: String,
        token_name: String,
        to: address,
    ): Object<CrimeChaseToken> acquires CrimeChaseCollection, CrimeChaseToken, CrimeChaseSubCollection {
        let creator_addr = signer::address_of(creator);
        account::create_account_for_test(creator_addr);

        let appsigner = appsigner::get_appsigner(creator);

        let token = mint_token_object(
            &appsigner,
            collection_name,
            string::utf8(b"description"),
            token_name,
            string::utf8(b"uri"),
            string::utf8(b"category"),
            string::utf8(b"type"),
            string::utf8(b"rarity"),
            vector[string::utf8(b"bool")],
            vector[string::utf8(b"0x1::string::String")],
            vector[bcs::to_bytes(&string::utf8(b"test"))],
        );

        object::transfer(&appsigner, token, to);      
        token  
    }
}