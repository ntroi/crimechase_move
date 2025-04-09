module crimechase::inventory{    
    use std::signer;
    use std::vector;    
    use std::bcs;
    use std::simple_map::{Self, SimpleMap};
    use std::string::{String};

    use aptos_std::aptos_hash;    
    use aptos_framework::object::{Self, Object, ExtendRef};
    use aptos_framework::event;

    use crimechase::crimechase_token;
    use crimechase::utilities;
    use crimechase::appsigner;
    
    const ENOT_OWNER: u64 = 1;
    const ENOT_EXIST_INVENTORY: u64 = 2;
    const ENOT_AUTHORIZED: u64 = 8;
    const ENOT_COUNT_INVALID: u64 = 9;
    const ECOUNT_EXCEEDED: u64 = 10;
    const EACCOUNT_EMPTY: u64 = 11;
    const EOWNER_ADDRESS_EMPTY: u64 = 12;
    const EVECTOR_LENGTH_NOT_MATCHED: u64 = 13;
    const EACCOUNT_LENGTH_EXCEEDED: u64 = 14;

    const CONST_ACCOUNT_LENGTH_MAX: u64 = 100;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Inventory has key {
        account_no: u64,
        extend_ref: ExtendRef,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct ItemTable has key {
        owner: address,
        items: SimpleMap<String, u64>,
    }

    #[event]
    struct TransferEvent has drop, store {
        token_id: address,
        to: address,
    }

    #[event]
    struct TransferWalletToInventoryEvent has drop, store {
        account_no: u64,
        wallet_address: address,
        token_id: address,
    }

    #[event]
    struct TransferInventoryToWalletEvent has drop, store {
        account_no: u64,
        wallet_address: address,
        token_id: address,
    }

    #[event]
    struct LockEvent has drop, store {
        account_no: u64,
        token_id: address,
        lock: bool,
    }

    #[event]
    struct BurnEvent has drop, store {
        account_no: u64,
        token_id: address,
    }

    #[event]
    struct InventoryCreateEvent has drop, store {
        account_no: u64,
        address: address,
    }

    #[event]
    struct ItemTableCreateEvent has drop, store {
        account_no: u64,
    }

    #[event]
    struct ItemIncreaseEvent has drop, store {
        account_no: u64,
        itemkey: String,
        before: u64,
        after: u64,
    }

    #[event]
    struct ItemDecreaseEvent has drop, store {
        account_no: u64,
        itemkey: String,
        before: u64,
        after: u64,
    }

    public entry fun create(creator: &signer, account_no: u64) {
        assert!(utilities::is_authorized(creator), ENOT_AUTHORIZED);

        let app_signer = appsigner::get_appsigner(creator);

        let inventory_name = create_inventory_seed(account_no);
        let constructor_ref = object::create_named_object(&app_signer, inventory_name);
        let inventory_signer = object::generate_signer(&constructor_ref);
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        
        move_to(&inventory_signer, Inventory{
            account_no,            
            extend_ref,
        });

        //Make inventory soul-bounded, it can't be transfered to other.  
        object::set_untransferable(&constructor_ref);   

        event::emit(InventoryCreateEvent{
            account_no,
            address: object::address_from_constructor_ref(&constructor_ref),
        });
    }

    public entry fun transfer_to_wallet<T: key>(caller: &signer, account_no: u64, token: Object<T>, to_wallet: address) {
        assert!(utilities::is_authorized(caller), ENOT_AUTHORIZED);

        let inventory_addr = address_of(account_no);

        assert!(object::is_owner(token, inventory_addr), ENOT_OWNER);

        crimechase_token::forcefull_transfer(caller, token, to_wallet);

        event::emit(TransferInventoryToWalletEvent{
            account_no,
            wallet_address: to_wallet,
            token_id: object::object_address(&token),
        });
    }

    entry fun lock<T : key>(caller: &signer, account_no: u64, token: Object<T>, lock: bool) {
        assert!(utilities::is_authorized(caller), ENOT_AUTHORIZED);

        let inventory_addr = address_of(account_no);         
        assert!(object::is_owner(token, inventory_addr), ENOT_OWNER);

        crimechase_token::lock(caller, token, lock);

        event::emit(LockEvent{
            account_no,
            token_id: object::object_address(&token),
            lock
        });
    }

    entry fun burn<T: key>(caller: &signer, account_no: u64, token:Object<T>) {
        assert!(utilities::is_authorized(caller), ENOT_AUTHORIZED);

        let inventory_addr = address_of(account_no);         
        assert!(object::is_owner(token, inventory_addr), ENOT_OWNER);

        crimechase_token::burn(caller, token);

        event::emit(BurnEvent{
            account_no,
            token_id: object::object_address(&token)            
        });
    }

    entry fun unlock_and_update<T: key>(
        caller: &signer, 
        account_no: u64, 
        token: Object<T>, 
        keys: vector<String>,
        types: vector<String>,
        values: vector<vector<u8>>,
    ) {        
        assert!(utilities::is_authorized(caller), ENOT_AUTHORIZED);

        let inventory_addr = address_of(account_no);         
        assert!(object::is_owner(token, inventory_addr), ENOT_OWNER);

        crimechase_token::lock(caller, token, false);
        crimechase_token::upsert_properties(caller, token, keys, types, values);        
    }

    entry fun unlock_and_update_v2<T: key>(
        caller: &signer, 
        account_no: u64, 
        token: Object<T>, 
        keys: vector<String>,
        types: vector<String>,
        values: vector<vector<u8>>,
        keys_reset: vector<String>,
        types_reset: vector<String>,
        values_reset: vector<vector<u8>>,
    ) {        
        // Verify caller is authorized
        assert!(utilities::is_authorized(caller), ENOT_AUTHORIZED);

        // Check token ownership
        let inventory_addr = address_of(account_no);         
        assert!(object::is_owner(token, inventory_addr), ENOT_OWNER);

        // Unlock the token
        crimechase_token::lock(caller, token, false);
        
        // Update properties with reset support
        crimechase_token::upsert_properties_v2(caller, token, keys, types, values, keys_reset, types_reset, values_reset);
    }

    public entry fun increase_itemcount_batch(caller: &signer, accounts: vector<u64>, owner_addresses: vector<address>, key: String, amount: u64) acquires Inventory, ItemTable {
        assert!(utilities::is_authorized(caller), ENOT_AUTHORIZED);
        assert!(amount> 0, ENOT_COUNT_INVALID);
        assert!(!vector::is_empty(&accounts), EACCOUNT_EMPTY);
        assert!(!vector::is_empty(&owner_addresses), EOWNER_ADDRESS_EMPTY);

        let account_length = vector::length(&accounts);
        let address_length = vector::length(&owner_addresses);
        
        assert!(account_length == address_length, EVECTOR_LENGTH_NOT_MATCHED);
        assert!(account_length > 0 && account_length <= CONST_ACCOUNT_LENGTH_MAX, EACCOUNT_LENGTH_EXCEEDED);

        while (!vector::is_empty(&accounts)) {
            let account_no = vector::pop_back(&mut accounts);
            let owner_address = vector::pop_back(&mut owner_addresses);

            increase_itemcount(caller, account_no, owner_address, key, amount);
        };
    }
    
    public entry fun increase_itemcount(caller: &signer, account_no: u64, owner_address: address, key: String, amount: u64) acquires Inventory, ItemTable {
        assert!(amount> 0, ENOT_COUNT_INVALID);
        assert!(utilities::is_authorized(caller), ENOT_AUTHORIZED);

        let inventory_address = address_of(account_no);
        if(!exists<Inventory>(inventory_address)){
            create(caller, account_no);
        };

        let inventory = borrow_global_mut<Inventory>(inventory_address);

        if(!exists<ItemTable>(inventory_address)) {
            let object_signer = object::generate_signer_for_extending(&inventory.extend_ref);
            move_to(&object_signer, ItemTable{
                owner: owner_address,
                items: simple_map::new<String, u64>(),
            });

            event::emit(ItemTableCreateEvent{
                account_no,                
            });
        };

        let item_table = borrow_global_mut<ItemTable>(inventory_address);

        let before_amount = 0;
        let after_amount = 0;

        if(simple_map::contains_key(&item_table.items, &key)) {
            let old_value = simple_map::borrow_mut(&mut item_table.items, &key);
            before_amount = *old_value;
            after_amount = before_amount + amount;

            *old_value = after_amount;
        } else {
            simple_map::add(&mut item_table.items, key, amount);
            after_amount = amount;
        };

        event::emit(ItemIncreaseEvent{
            account_no,
            itemkey: key,
            before: before_amount,
            after: after_amount,
        });
    }

    public entry fun decrease_itemcount(caller: &signer, account_no: u64, key: String, amount: u64) acquires ItemTable {
        assert!(amount > 0, ENOT_COUNT_INVALID);

        let inventory_address = address_of(account_no);
        
        assert!(exists<ItemTable>(inventory_address), ENOT_EXIST_INVENTORY);

        let item_table = borrow_global_mut<ItemTable>(inventory_address);

        assert!(signer::address_of(caller) == item_table.owner || utilities::is_authorized(caller), ENOT_AUTHORIZED);

        let before_amount = 0;
        let after_amount = 0;

        if(simple_map::contains_key(&item_table.items, &key)) {
            let old_value = simple_map::borrow_mut(&mut item_table.items, &key);
            before_amount = *old_value;            
            
            assert!(before_amount >= amount, ECOUNT_EXCEEDED);

            after_amount = before_amount - amount;
            *old_value = after_amount;
        } else {
            abort ECOUNT_EXCEEDED;
        };

        event::emit(ItemDecreaseEvent{
            account_no,
            itemkey: key,
            before: before_amount,
            after: after_amount,
        });
    }

    public fun create_inventory_seed(account_no: u64) : vector<u8> {
        let s = b"inventory";
        let hash_key = aptos_hash::sha3_512(bcs::to_bytes(&account_no));

        vector::append(&mut s, b"::");
        vector::append(&mut s, hash_key);
        s
    }

    public entry fun update_itemtable(caller: &signer, account_no: u64, owner: address) acquires Inventory, ItemTable {
        assert!(utilities::is_authorized(caller), ENOT_AUTHORIZED);

        let inventory_address = address_of(account_no);

        if(!exists<Inventory>(inventory_address)) {
            create(caller, account_no);
        };

        let inventory = borrow_global_mut<Inventory>(inventory_address);

        if(!exists<ItemTable>(inventory_address)) {
            let object_signer = object::generate_signer_for_extending(&inventory.extend_ref);
            move_to(&object_signer, ItemTable{
                owner: owner,
                items: simple_map::new<String, u64>(),
            });
        } else {
            let itemtable = borrow_global_mut<ItemTable>(inventory_address);
            itemtable.owner = owner;
        };             
    }
    

    #[view]
    public fun address_of(account_no: u64) : address {        
        object::create_object_address(&appsigner::get_appsigner_address(), create_inventory_seed(account_no))        
    }

    #[view]
    public fun get_itemcount(account_no: u64, key: String) : u64 acquires ItemTable {
        let inventory_address = address_of(account_no);
        assert!(exists<ItemTable>(inventory_address), ENOT_EXIST_INVENTORY);

        let item_table = borrow_global<ItemTable>(address_of(account_no));
        let count = if(simple_map::contains_key(&item_table.items, &key)) {
            *simple_map::borrow(&item_table.items, &key)
        } else {
            0
        };

        count
    }

    public fun is_exists(account_no: u64) : bool {         
        let inventory_address = address_of(account_no);
        exists<Inventory>(inventory_address)
    }

    public fun is_owner_of<T: key>(account_no: u64, object: Object<T>) : bool {
        let inventory_address = address_of(account_no);
        object::is_owner(object, inventory_address)
    }

    #[test(creator=@0x123)]
    fun inventory_create_test(creator: &signer){
        appsigner::setup_for_test();
        let accountno = 1234;
        create(creator, accountno);
        is_exists(accountno);
    }
}