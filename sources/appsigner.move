module crimechase::appsigner {
    use std::signer;

    use aptos_framework::object::{Self, ExtendRef};

    use crimechase::utilities;

    friend crimechase::inventory;

    const ENOT_AUTHORIZED: u64 = 1;
    const CONST_APPSIGNER_SEED: vector<u8> = b"CrimeChase";

    struct AppSignerData has key {
        where: address,
    }

    struct AppSigner has key {
        extend_ref : ExtendRef,
    }

    fun init_module(creator: &signer) {
        let constructor_ref = object::create_named_object(creator, CONST_APPSIGNER_SEED);
        let app_signer = object::generate_signer(&constructor_ref);
        let extend_ref = object::generate_extend_ref(&constructor_ref);

        move_to(&app_signer, AppSigner{
            extend_ref,
        });

        move_to(creator, AppSignerData{
            where: signer::address_of(&app_signer),
        });     
    }

    public fun get_appsigner(caller: &signer) : signer acquires AppSigner {
        assert!(utilities::is_authorized(caller), ENOT_AUTHORIZED);

        let addr = @crimechase;        
        let appsigner = borrow_global<AppSigner>(object::create_object_address(&addr, CONST_APPSIGNER_SEED));
        object::generate_signer_for_extending(&appsigner.extend_ref)
    }

    public(friend) fun get_appsigner_without_permmit() : signer acquires AppSigner {
        let addr = @crimechase;        
        let appsigner = borrow_global<AppSigner>(object::create_object_address(&addr, CONST_APPSIGNER_SEED));
        object::generate_signer_for_extending(&appsigner.extend_ref)
    }

    #[view]
    public fun get_appsigner_address() : address {
        object::create_object_address(&@crimechase, CONST_APPSIGNER_SEED)
    }

    #[test_only]
    use aptos_framework::account::create_signer_for_test;

    #[test_only]
    use crimechase::certification_center_v2;

    #[test_only]
    public fun setup_for_test() {
        let creator = create_signer_for_test(@crimechase);
        let constructor_ref = object::create_named_object(&creator, CONST_APPSIGNER_SEED);
        let app_signer = object::generate_signer(&constructor_ref);
        let extend_ref = object::generate_extend_ref(&constructor_ref);

        move_to(&app_signer, AppSigner{
            extend_ref,
        });

        move_to(&creator, AppSignerData{
            where: signer::address_of(&app_signer),
        });     

        certification_center_v2::setup_for_test();
    }
}