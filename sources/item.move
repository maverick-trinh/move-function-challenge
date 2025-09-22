module sharded_assets::item;

use std::string::String;
use sui::object::{Self, UID, ID};
use sui::transfer;
use sui::tx_context::{Self, TxContext};

public struct Item has key, store {
    id: UID,
    name: String,
    value: u64,
}

public entry fun create(name: String, value: u64, ctx: &mut TxContext) {
    let item = Item {
        id: object::new(ctx),
        name,
        value,
    };

    transfer::public_transfer(item, tx_context::sender(ctx));
}

public fun get_value(self: &Item): u64 {
    self.value
}

public fun get_id(self: &Item): ID {
    object::id(self)
}

public fun get_name(self: &Item): String {
    self.name
}
