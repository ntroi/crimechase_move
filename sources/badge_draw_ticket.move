module crimechase::badge_draw_ticket {
    use std::string;    
    use std::vector;    
    use std::bcs;

    use aptos_std::aptos_hash;
    use aptos_framework::object;
    
    use crimechase::utilities;
    use crimechase::inventory;

    const ETICKET_COUNT_INVALID: u64 = 1;    
    const ETICKET_NOT_EXISTS: u64 = 2;
    const ENOT_AUTHORIZED: u64 = 3;

    const CONST_BADGE_DRAW_TICKET_NAME: vector<u8> = b"BadgeDrawTicket";

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct BadgeDrawTicket has key {
        owner: address,
        count: u64,
    }
    
    //decreasing ticket count is available by admin or owner.
    public entry fun decrease_count(caller: &signer, account_no: u64, count: u64) {
        inventory::decrease_itemcount(caller, account_no, string::utf8(CONST_BADGE_DRAW_TICKET_NAME), count);
    }

    
    entry fun increase_count_batch(caller: &signer, accounts: vector<u64>, owner_addresses: vector<address>, count: u64) {
        inventory::increase_itemcount_batch(caller, accounts, owner_addresses, string::utf8(CONST_BADGE_DRAW_TICKET_NAME), count);
    }

    //increasing ticket count is only available by admin.    
    public entry fun increase_count(caller: &signer, account_no: u64, owner_address: address, count: u64) {
        inventory::increase_itemcount(caller, account_no, owner_address, string::utf8(CONST_BADGE_DRAW_TICKET_NAME), count);
    }

    public entry fun create(creator: &signer, account_no: u64, owner: address, count: u64) {
        assert!(utilities::is_authorized(creator), ENOT_AUTHORIZED);
        assert!(count >= 0, ETICKET_COUNT_INVALID);

        let name = create_seed(account_no);
        let constructor_ref = object::create_named_object(creator, name);
        let object_signer = object::generate_signer(&constructor_ref);

        move_to(&object_signer, BadgeDrawTicket{
            owner,
            count,
        });

        //Make inventory soul-bounded, that means, it can't be transfered to other.  
        object::set_untransferable(&constructor_ref);        
    }

    public fun create_seed(account_no: u64) : vector<u8> {
        let s = b"badgedrawticket";
        let hash_key = aptos_hash::sha3_512(bcs::to_bytes(&account_no));

        vector::append(&mut s, b"::");
        vector::append(&mut s, hash_key);
        s
    }

    #[view]
    public fun ticket_count(account_no: u64): u64 {
        inventory::get_itemcount(account_no, string::utf8(CONST_BADGE_DRAW_TICKET_NAME))
    }
    
    #[view]
    public fun address_of(account_no: u64) : address {
        let seed = create_seed(account_no);
        object::create_object_address(&@crimechase, seed)        
    }    

    public fun is_exists(account_no: u64) : bool { 
        let seed = create_seed(account_no);    
        let address = object::create_object_address(&@crimechase, seed);
        exists<BadgeDrawTicket>(address)
    }

    inline fun borrow(account_no: u64): &BadgeDrawTicket {
        let ticket_address = address_of(account_no);
        assert!(exists<BadgeDrawTicket>(ticket_address), ETICKET_NOT_EXISTS);

        borrow_global_mut<BadgeDrawTicket>(ticket_address)        
    }

    inline fun borrow_mut(account_no: u64) 
        : &mut BadgeDrawTicket acquires BadgeDrawTicket {
        let ticket_address = address_of(account_no);
        assert!(exists<BadgeDrawTicket>(ticket_address), ETICKET_NOT_EXISTS);

        borrow_global_mut<BadgeDrawTicket>(ticket_address)        
    }

    #[test_only]
    use crimechase::appsigner;

    #[test(caller = @crimechase)]
    fun test_increase(caller: &signer) {
        appsigner::setup_for_test();

        let account_no = 1;
        let owner_addr = @0x456;
        let count = 1;

        crimechase::inventory::create(caller, account_no);
        increase_count(caller, account_no, owner_addr, count);
    }

    #[test(caller = @0x456)]
    #[expected_failure]
    fun test_increase_fail(caller: &signer) {
        appsigner::setup_for_test();

        let account_no = 1;
        let owner_addr = @0x456;
        let count = 1;

        crimechase::inventory::create(caller, account_no);
        increase_count(caller, account_no, owner_addr, count);        
    }

    #[test(creator= @crimechase, caller = @crimechase)]
    fun test_decrease(creator: &signer, caller: &signer) {
        appsigner::setup_for_test();
        
        let account_no = 1;
        let owner_addr = @0x456;
        let count = 1;

        crimechase::inventory::create(creator, account_no);
        increase_count(caller, account_no, owner_addr, 10);        
        decrease_count(caller, account_no, 1);
    }
}