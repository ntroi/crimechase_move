module crimechase::utilities {
    const ENOT_ADMIN: u64 = 1;

    //use crimechase::certification_center_v1;
    use crimechase::certification_center_v2;

    public fun is_authorized(caller: &signer) : bool {        
        certification_center_v2::is_authorized(caller)
    }
    
    entry fun issue_certificate(issuer: &signer, recipient: address, expiration_time_microsec: u64) {
        certification_center_v2::issue(issuer, recipient, expiration_time_microsec);
    }
}