module sharded_assets::sharded_player;

use sharded_assets::item::{Self, Item};
use sui::bag::{Self, Bag};
use sui::dynamic_field as df;
use sui::object::{Self, UID, ID};
use sui::table::{Self, Table};
use sui::transfer;
use sui::tx_context::{Self, TxContext};

const MAX_ITEMS_PER_SHARD: u64 = 200;
const NUM_SHARDS: u64 = 10;

const EInvalidShardIndex: u64 = 0;
const ENotOwner: u64 = 1;
const EShardFull: u64 = 2;
const EItemNotFound: u64 = 3;

public struct ItemShard has key, store {
    id: UID,
    items: Bag,
    item_count: u64,
    id_to_key: Table<ID, u64>,
}

public struct Player has key {
    id: UID,
    owner: address,
    total_items: u64,
}

fun init(_ctx: &mut TxContext) {}

public entry fun create_player(ctx: &mut TxContext) {
    let mut player = Player {
        id: object::new(ctx),
        owner: tx_context::sender(ctx),
        total_items: 0,
    };

    let mut i = 0;
    while (i < NUM_SHARDS) {
        let shard = ItemShard {
            id: object::new(ctx),
            items: bag::new(ctx),
            item_count: 0,
            id_to_key: table::new(ctx),
        };
        df::add(&mut player.id, i, shard);
        i = i + 1;
    };

    transfer::transfer(player, tx_context::sender(ctx));
}

fun get_shard_index(item_id: ID): u64 {
    let id_bytes = object::id_to_bytes(&item_id);
    let mut hash: u64 = 0;
    let mut i = 0;
    let len = std::vector::length(&id_bytes);

    while (i < 8 && i < len) {
        hash = hash * 256 + (*std::vector::borrow(&id_bytes, i) as u64);
        i = i + 1;
    };

    hash % NUM_SHARDS
}

public entry fun add_item(player: &mut Player, item: Item, ctx: &mut TxContext) {
    assert!(player.owner == tx_context::sender(ctx), ENotOwner);

    let item_id = object::id(&item);
    let shard_index = get_shard_index(item_id);
    let shard: &mut ItemShard = df::borrow_mut(&mut player.id, shard_index);

    assert!(shard.item_count < MAX_ITEMS_PER_SHARD, EShardFull);

    let item_key = shard.item_count;
    table::add(&mut shard.id_to_key, item_id, item_key);
    bag::add(&mut shard.items, item_key, item);

    shard.item_count = shard.item_count + 1;
    player.total_items = player.total_items + 1;
}

public entry fun add_item_to_shard(
    player: &mut Player,
    item: Item,
    shard_index: u64,
    ctx: &mut TxContext,
) {
    assert!(shard_index < NUM_SHARDS, EInvalidShardIndex);
    assert!(player.owner == tx_context::sender(ctx), ENotOwner);

    let shard: &mut ItemShard = df::borrow_mut(&mut player.id, shard_index);

    assert!(shard.item_count < MAX_ITEMS_PER_SHARD, EShardFull);

    let item_key = shard.item_count;
    bag::add(&mut shard.items, item_key, item);

    shard.item_count = shard.item_count + 1;
    player.total_items = player.total_items + 1;
}

public entry fun remove_item_from_shard(
    player: &mut Player,
    shard_index: u64,
    item_key: u64,
    ctx: &mut TxContext,
) {
    assert!(shard_index < NUM_SHARDS, EInvalidShardIndex);
    assert!(player.owner == tx_context::sender(ctx), ENotOwner);

    let shard: &mut ItemShard = df::borrow_mut(&mut player.id, shard_index);
    let item: Item = bag::remove(&mut shard.items, item_key);

    shard.item_count = shard.item_count - 1;
    player.total_items = player.total_items - 1;

    transfer::public_transfer(item, tx_context::sender(ctx));
}

// --- Public View Functions ---

public fun get_item_value_from_shard(player: &Player, shard_index: u64, item_key: u64): u64 {
    assert!(shard_index < NUM_SHARDS, EInvalidShardIndex);

    let shard: &ItemShard = df::borrow(&player.id, shard_index);
    let item: &Item = bag::borrow(&shard.items, item_key);

    item::get_value(item)
}

public fun find_item_by_id(player: &Player, item_id: ID): (u64, u64) {
    let shard_index = get_shard_index(item_id);
    let shard: &ItemShard = df::borrow(&player.id, shard_index);

    assert!(table::contains(&shard.id_to_key, item_id), EItemNotFound);

    let item_key = *table::borrow(&shard.id_to_key, item_id);
    (shard_index, item_key)
}

public fun get_owner(player: &Player): address {
    player.owner
}

public fun get_total_items(player: &Player): u64 {
    player.total_items
}

public fun get_num_shards(): u64 {
    NUM_SHARDS
}

public fun get_shard_item_count(player: &Player, shard_index: u64): u64 {
    assert!(shard_index < NUM_SHARDS, EInvalidShardIndex);
    let shard: &ItemShard = df::borrow(&player.id, shard_index);
    shard.item_count
}

public fun get_max_items_per_shard(): u64 {
    MAX_ITEMS_PER_SHARD
}
