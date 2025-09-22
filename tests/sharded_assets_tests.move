#[test_only]
module sharded_assets::sharded_assets_tests;

use sharded_assets::item::{Self, Item};
use sharded_assets::sharded_player::{Self, Player};
use std::string;
use sui::test_scenario;

const ADMIN: address = @0xAD1;
const USER: address = @0xB0B;

#[test]
fun test_create_player() {
    let mut scenario = test_scenario::begin(ADMIN);

    // Create a player
    sharded_player::create_player(scenario.ctx());
    scenario.next_tx(ADMIN);

    // Check that player was created and transferred
    let player = scenario.take_from_sender<Player>();

    // Verify player properties
    assert!(sharded_player::get_owner(&player) == ADMIN, 0);
    assert!(sharded_player::get_total_items(&player) == 0, 1);
    assert!(sharded_player::get_num_shards() == 10, 2);

    // Check each shard is initialized
    let mut i = 0;
    while (i < sharded_player::get_num_shards()) {
        assert!(sharded_player::get_shard_item_count(&player, i) == 0, 3);
        i = i + 1;
    };

    test_scenario::return_to_sender(&scenario, player);
    scenario.end();
}

#[test]
fun test_add_items_to_shards() {
    let mut scenario = test_scenario::begin(ADMIN);

    // Create a player
    sharded_player::create_player(scenario.ctx());
    scenario.next_tx(ADMIN);

    let mut player = scenario.take_from_sender<Player>();

    // Create and add items one by one to avoid ordering issues
    item::create(string::utf8(b"Sword"), 100, scenario.ctx());
    scenario.next_tx(ADMIN);

    let item1 = scenario.take_from_sender<Item>();
    // Verify the item value before adding
    assert!(item::get_value(&item1) == 100, 10);
    sharded_player::add_item_to_shard(&mut player, item1, 0, scenario.ctx());

    item::create(string::utf8(b"Shield"), 50, scenario.ctx());
    scenario.next_tx(ADMIN);

    let item2 = scenario.take_from_sender<Item>();
    assert!(item::get_value(&item2) == 50, 11);
    sharded_player::add_item_to_shard(&mut player, item2, 1, scenario.ctx());

    item::create(string::utf8(b"Potion"), 25, scenario.ctx());
    scenario.next_tx(ADMIN);

    let item3 = scenario.take_from_sender<Item>();
    assert!(item::get_value(&item3) == 25, 12);
    sharded_player::add_item_to_shard(&mut player, item3, 2, scenario.ctx());

    // Verify items were added
    assert!(sharded_player::get_total_items(&player) == 3, 0);
    assert!(sharded_player::get_shard_item_count(&player, 0) == 1, 1);
    assert!(sharded_player::get_shard_item_count(&player, 1) == 1, 2);
    assert!(sharded_player::get_shard_item_count(&player, 2) == 1, 3);

    // Verify we can read item values
    let value0 = sharded_player::get_item_value_from_shard(&player, 0, 0);
    let value1 = sharded_player::get_item_value_from_shard(&player, 1, 0);
    let value2 = sharded_player::get_item_value_from_shard(&player, 2, 0);

    assert!(value0 == 100, 4);
    assert!(value1 == 50, 5);
    assert!(value2 == 25, 6);

    test_scenario::return_to_sender(&scenario, player);
    scenario.end();
}

#[test]
fun test_add_and_remove_items() {
    let mut scenario = test_scenario::begin(ADMIN);

    // Create a player
    sharded_player::create_player(scenario.ctx());
    scenario.next_tx(ADMIN);

    let mut player = scenario.take_from_sender<Player>();

    // Create an item
    item::create(string::utf8(b"Magic Wand"), 200, scenario.ctx());
    scenario.next_tx(ADMIN);

    let item = scenario.take_from_sender<Item>();

    // Add item to shard 0
    sharded_player::add_item_to_shard(&mut player, item, 0, scenario.ctx());
    assert!(sharded_player::get_total_items(&player) == 1, 0);
    assert!(sharded_player::get_shard_item_count(&player, 0) == 1, 1);

    // Remove the item
    sharded_player::remove_item_from_shard(&mut player, 0, 0, scenario.ctx());
    assert!(sharded_player::get_total_items(&player) == 0, 2);
    assert!(sharded_player::get_shard_item_count(&player, 0) == 0, 3);

    scenario.next_tx(ADMIN);

    // Verify the item was transferred back to owner
    let returned_item = scenario.take_from_sender<Item>();
    assert!(item::get_value(&returned_item) == 200, 4);
    assert!(item::get_name(&returned_item) == string::utf8(b"Magic Wand"), 5);

    test_scenario::return_to_sender(&scenario, returned_item);
    test_scenario::return_to_sender(&scenario, player);
    scenario.end();
}

#[test]
fun test_auto_sharding() {
    let mut scenario = test_scenario::begin(ADMIN);

    // Create a player
    sharded_player::create_player(scenario.ctx());
    scenario.next_tx(ADMIN);

    let mut player = scenario.take_from_sender<Player>();

    // Create multiple items and let the system auto-shard them
    let mut i = 0;
    while (i < 15) {
        item::create(string::utf8(b"Item"), i * 10, scenario.ctx());
        i = i + 1;
    };

    scenario.next_tx(ADMIN);

    // Add items using auto-sharding
    let mut added = 0;
    while (added < 15) {
        let item = scenario.take_from_sender<Item>();
        sharded_player::add_item(&mut player, item, scenario.ctx());
        added = added + 1;
    };

    // Verify all items were added
    assert!(sharded_player::get_total_items(&player) == 15, 0);

    // Verify items are distributed across different shards
    let mut total_in_shards = 0;
    let mut i = 0;
    while (i < sharded_player::get_num_shards()) {
        total_in_shards = total_in_shards + sharded_player::get_shard_item_count(&player, i);
        i = i + 1;
    };
    assert!(total_in_shards == 15, 1);

    test_scenario::return_to_sender(&scenario, player);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = sharded_player::ENotOwner)]
fun test_unauthorized_access() {
    let mut scenario = test_scenario::begin(ADMIN);

    // Create a player as ADMIN
    sharded_player::create_player(scenario.ctx());
    scenario.next_tx(ADMIN);

    let mut player = scenario.take_from_sender<Player>();

    // Try to add item as different user (should fail)
    scenario.next_tx(USER);

    item::create(string::utf8(b"Stolen Item"), 999, scenario.ctx());
    scenario.next_tx(USER);

    let item = scenario.take_from_sender<Item>();

    // This should fail with ENotOwner
    sharded_player::add_item_to_shard(&mut player, item, 0, scenario.ctx());

    test_scenario::return_to_sender(&scenario, player);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = sharded_player::EInvalidShardIndex)]
fun test_invalid_shard_index() {
    let mut scenario = test_scenario::begin(ADMIN);

    // Create a player
    sharded_player::create_player(scenario.ctx());
    scenario.next_tx(ADMIN);

    let mut player = scenario.take_from_sender<Player>();

    // Create an item
    item::create(string::utf8(b"Item"), 100, scenario.ctx());
    scenario.next_tx(ADMIN);

    let item = scenario.take_from_sender<Item>();

    // Try to add to invalid shard index (should fail)
    sharded_player::add_item_to_shard(&mut player, item, 99, scenario.ctx());

    test_scenario::return_to_sender(&scenario, player);
    scenario.end();
}
