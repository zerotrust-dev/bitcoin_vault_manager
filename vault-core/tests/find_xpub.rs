use bitcoin::bip32::ExtendedPubKey;

#[test]
fn test_known_xpubs() {
    // BIP32 test vector 1: Master xpub
    let xpub_str = "xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8";
    let result = xpub_str.parse::<ExtendedPubKey>();
    println!("xpub1: {:?}", result.is_ok());
    if let Ok(xpub) = &result {
        println!("  fingerprint: {}", hex::encode(xpub.fingerprint().as_bytes()));
    } else {
        println!("  err: {:?}", result.err());
    }
    
    // BIP32 test vector 2: child xpub  
    let xpub2 = "xpub6D4BDPcP2GT577Vvch3R8wDkScZWzQzMMUm3PWbmWvVJrZwQY4VUNgqFJPMM3No2dFDFGTsxxpG5uJh7n7epu4trkrX7x7DogT5Uv6fcLW5";
    let result2 = xpub2.parse::<ExtendedPubKey>();
    println!("xpub2: {:?}", result2.is_ok());
    if let Err(e) = &result2 {
        println!("  err: {:?}", e);
    }
}
