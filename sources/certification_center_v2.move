module crimechase::certification_center_v2{

    use std::signer;
    use std::timestamp;
    
    use aptos_framework::event;
    use aptos_framework::simple_map::{Self, SimpleMap};

    const ENOT_ADMIN: u64 = 1;
    const ENOT_AUTHORIZED: u64 = 2;
    const ENOT_EXIST_CERTIFICATE: u64 = 3;
    const EALREADY_EXIST_CERTIFICATE: u64 = 4;
    const EEXPIRED_CERTIFICATE: u64 = 5;
    const EINVALID_EXPIRATION_TIME: u64 = 6;
    

    struct CertificationCenter has key {
        authorized_list : SimpleMap<address, u64>,        
    }

    #[event]
    struct CertificateIssueEvent has drop, store {
        issuer: address,
        recipient: address,
        expiration_time: u64,
        expiration_date: u64,
    }

    #[event]
    struct CertificateRenewEvent has drop, store {
        issuer: address,
        recipient: address,
        expiration_time: u64,
        expiration_date: u64,
    }

    fun init_module(creator: &signer) {

        move_to(creator, CertificationCenter{
            authorized_list: simple_map::new<address, u64>(),
        });
    }
   
    public entry fun issue(issuer: &signer, recipient: address, expiration_time_microsec: u64) acquires CertificationCenter {
        assert!(is_admin(issuer), ENOT_ADMIN);
        assert!(expiration_time_microsec >= 0, EINVALID_EXPIRATION_TIME);
        assert!(!contains_key(&recipient), EALREADY_EXIST_CERTIFICATE);

        let issuer_address = signer::address_of(issuer);
        let center = borrow_global_mut<CertificationCenter>(issuer_address);

        let expiration_date = if(expiration_time_microsec == 0) {
            0
        } else {
            timestamp::now_microseconds() + expiration_time_microsec
        };

        simple_map::add(&mut center.authorized_list, recipient, expiration_date);

        event::emit(CertificateIssueEvent{
            issuer: issuer_address,
            recipient,
            expiration_time: expiration_time_microsec,
            expiration_date,
        });
    }

    public entry fun renew(issuer: &signer, recipient: address, expiration_time_microsec: u64) acquires CertificationCenter {
        assert!(is_admin(issuer), ENOT_ADMIN);
        assert!(expiration_time_microsec >= 0, EINVALID_EXPIRATION_TIME);
        assert!(contains_key(&recipient), ENOT_EXIST_CERTIFICATE);

        let expiration_date = if(expiration_time_microsec == 0) {
            0
        } else {
            timestamp::now_microseconds() + expiration_time_microsec
        };

        *borrow_mut(&recipient) = expiration_date;

        event::emit(CertificateIssueEvent{
            issuer: signer::address_of(issuer),
            recipient,
            expiration_time: expiration_time_microsec,
            expiration_date,
        });
    }       

    inline fun contains_key(recipient: &address) : bool {
        let center = borrow_global<CertificationCenter>(@crimechase);
        simple_map::contains_key(&center.authorized_list, recipient)
    }

    inline fun borrow(recipient: &address): &u64 acquires CertificationCenter{
        let center = borrow_global<CertificationCenter>(@crimechase);

        simple_map::borrow(&center.authorized_list, recipient)
    }

    inline fun borrow_mut(recipient: &address): &mut u64 acquires CertificationCenter {
        let center = borrow_global_mut<CertificationCenter>(@crimechase);

        simple_map::borrow_mut(&mut center.authorized_list, recipient)
    }

    public fun is_authorized(caller: &signer) : bool acquires CertificationCenter{
        if(is_admin(caller))
            return true;

        let addr = signer::address_of(caller);
        if(!contains_key(&addr))
            return false;

        let expiration_date = *borrow(&addr);
        if(expiration_date == 0)
            return true;

        let is_auth = expiration_date > timestamp::now_microseconds();
        is_auth
    }

    //simply 
    inline fun is_admin(caller: &signer) : bool {
        signer::address_of(caller) == @crimechase
    }

    #[test_only]
    use aptos_framework::account;

    #[test_only]
    use crimechase::certification_center_v2;
    
    #[test]
    public fun test_issue_certificate() acquires CertificationCenter {

        let aptos = account::create_signer_for_test(@aptos_framework);        
        timestamp::set_time_has_started_for_testing(&aptos);

        let creator = account::create_signer_for_test(@crimechase);
        certification_center_v2::setup_for_test();

        let recipient = @0x1;
        let expiration_time = 10_000_000; // 10 seconds in microseconds

        certification_center_v2::issue(&creator, recipient, expiration_time);

        // Validate that the certificate was issued
        let expiration_date = *certification_center_v2::borrow(&recipient);
        let current_time = timestamp::now_microseconds();
        assert!(expiration_date > current_time, 102); // 102: Expiration time should be in the future
        assert!(expiration_date <= current_time + expiration_time, 103); // 103: Correct expiration
    }

    #[test]
    public fun test_renew_certificate() acquires CertificationCenter {
        let creator = account::create_signer_for_test(@crimechase);
        let aptos = account::create_signer_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos);

        certification_center_v2::setup_for_test();

        let recipient = @0x2;
        let initial_expiration = 10_000_000;
        certification_center_v2::issue(&creator, recipient, initial_expiration);

        let renewal_time = 20_000_000;
        certification_center_v2::renew(&creator, recipient, renewal_time);

        // Validate the certificate was renewed
        let updated_expiration_date = *certification_center_v2::borrow(&recipient);
        let current_time = timestamp::now_microseconds();
        assert!(updated_expiration_date > current_time, 104); // 104: Renewed expiration time should be in the future
        assert!(updated_expiration_date <= current_time + renewal_time, 105); // 105: Correct renewed expiration
    }

    #[test]
    public fun test_is_authorized() acquires CertificationCenter {
        let creator = account::create_signer_for_test(@crimechase);
        let aptos = account::create_signer_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos);

        certification_center_v2::setup_for_test();

        let recipient = @0x3;
        let expiration_time = 10_000_000;
        certification_center_v2::issue(&creator, recipient, expiration_time);

        let authorized_signer = account::create_signer_for_test(recipient);
        let is_auth = certification_center_v2::is_authorized(&authorized_signer);
        assert!(is_auth, 106); // 106: Recipient should be authorized

        // Simulate expiration
        let expiration_date = timestamp::now_microseconds() + 5_000_000;
        let remaining_time = expiration_time - 5_000_000;
        timestamp::fast_forward_seconds(expiration_date + remaining_time);
        let is_expired = certification_center_v2::is_authorized(&authorized_signer);
        assert!(!is_expired, 107); // 107: Recipient should not be authorized after expiration
    }

    #[test_only]
    use aptos_framework::account::create_signer_for_test;

    #[test_only]
    public fun setup_for_test() {
        let creator = create_signer_for_test(@crimechase);

        move_to(&creator, CertificationCenter{
            authorized_list: simple_map::new<address, u64>(),
        });
    }
}