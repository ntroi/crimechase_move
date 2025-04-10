module crimechase::certification_center_v1{

    use std::signer;
    use std::timestamp;

    const ENOT_ADMIN: u64 = 1;
    const ENOT_AUTHORIZED: u64 = 2;
    const ENOT_EXIST_CERTIFICATE: u64 = 3;
    const EALREADY_EXIST_CERTIFICATE: u64 = 4;
    const EEXPIRED_CERTIFICATE: u64 = 5;

    //type #1    
    struct Certificate has key {
        issuer: address,
        expiration_date: u64,
    } 

    public entry fun issue(issuer: &signer, recipient: &signer, expiration_time_microsec: u64) {
        assert!(is_admin(issuer), ENOT_ADMIN);

        let addr = signer::address_of(recipient);

        assert!(!exists<Certificate>(addr), EALREADY_EXIST_CERTIFICATE);

        let expiration_date = if(expiration_time_microsec > 0) {
            timestamp::now_microseconds() + expiration_time_microsec
        } else {
            0
        };

        move_to(recipient, Certificate{
            issuer: signer::address_of(issuer),
            expiration_date,            
        });
    }

    public entry fun renew(issuer: &signer, recipient: &signer, expiration_time_microsec: u64) acquires Certificate {
        assert!(is_admin(issuer), ENOT_ADMIN);

        let addr = signer::address_of(recipient);
        assert!(exists<Certificate>(addr), ENOT_EXIST_CERTIFICATE);

        let certificate = borrow_global_mut<Certificate>(addr);

        let expiration_date = if(expiration_time_microsec > 0) {
            timestamp::now_microseconds() + expiration_time_microsec
        } else {
            0
        };

        certificate.expiration_date = expiration_date;
    }

    public fun is_authorized(caller: &signer) : bool acquires Certificate {
        if(is_admin(caller))
            return true;

        let addr = signer::address_of(caller);
        assert!(exists<Certificate>(addr), ENOT_EXIST_CERTIFICATE);

        let certificate = borrow_global<Certificate>(addr);
        if(certificate.expiration_date == 0)
            return true;

        let is_auth = certificate.expiration_date > timestamp::now_microseconds();
        assert!(is_auth, EEXPIRED_CERTIFICATE);
        is_auth
    }

    //simply 
    inline fun is_admin(caller: &signer) : bool {
        signer::address_of(caller) == @crimechase
    }

    // Unit test for issue function
    #[test]
    public fun test_issue_certificate() {
        let admin = create_signer(@crimechase);
        let recipient = create_account();
        let recipient_signer = create_signer(recipient);

        // Issue certificate with 1-hour expiration time
        issue(&admin, &recipient_signer, 3_600_000_000);
        let cert = borrow_global<Certificate>(recipient);
        assert!(cert.issuer == signer::address_of(&admin), 100);
        assert!(cert.expiration_date > timestamp::now_microseconds(), 101);
    }

    // Unit test for renewing a certificate
    #[test]
    public fun test_renew_certificate() {
        let admin = create_signer(@crimechase);
        let recipient = create_account();
        let recipient_signer = create_signer(recipient);

        // Issue a certificate first
        issue(&admin, &recipient_signer, 3_600_000_000);

        // Renew certificate with a 2-hour expiration time
        renew(&admin, &recipient_signer, 7_200_000_000);
        let cert = borrow_global<Certificate>(recipient);
        assert!(cert.expiration_date > timestamp::now_microseconds() + 3_600_000_000, 102);
    }

    // Unit test for checking authorization
    #[test]
    public fun test_is_authorized() {
        let admin = create_signer(@crimechase);
        let recipient = create_account();
        let recipient_signer = create_signer(recipient);

        // Admin should always be authorized
        assert!(is_authorized(&admin), 103);

        // Issue a certificate for the recipient
        issue(&admin, &recipient_signer, 3_600_000_000);

        // Recipient should be authorized now
        assert!(is_authorized(&recipient_signer), 104);

        // Expire the certificate and test authorization
        renew(&admin, &recipient_signer, 0); // Set to no expiration
        assert!(is_authorized(&recipient_signer), 105);
    }

    // Test case for expired certificate
    #[test]
    public fun test_expired_certificate() {
        let admin = create_signer(@crimechase);
        let recipient = create_account();
        let recipient_signer = create_signer(recipient);

        // Issue a certificate with a short expiration time (1 second)
        issue(&admin, &recipient_signer, 1_000_000);

        // Wait until expiration
        timestamp::advance_by(2_000_000);

        // Check that recipient is no longer authorized
        let success = is_authorized(&recipient_signer);
        assert!(!success, 106);
    }
}