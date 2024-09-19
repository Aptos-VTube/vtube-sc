module vtube::subscription {
    use std::signer;
    use std::vector;

    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;

    use aptos_std::table::{Self, Table};

    use vtube::protocol_coin::{BiUwU};

    /// @notice Error code for unauthorized caller
    const ERR_UNAUTHORIZED_CALLER: u64 = 1;

    /// @notice Error code for division by zero
    const ERR_DIVIDE_BY_ZERO: u64 = 2000;

    struct SubscriptionManagement<phantom CoinType> has key {
        prices: vector<u64>,
        period: u64,
        balances: Table<address, u64>,
        tiers: Table<address, u64>,
        start_times: Table<address, u64>
    }

    public entry fun create_subscription_plan<CoinType>(
        caller: &signer, prices: vector<u64>, period: u64
    ) {
        check_admin(caller);

        let balances = table::new<address, u64>();
        let tiers = table::new<address, u64>();
        let start_times = table::new<address, u64>();
        let subscription_management = SubscriptionManagement<CoinType> {
            prices,
            period,
            balances,
            tiers,
            start_times
        };
        move_to(caller, subscription_management);
    }

    public fun deposit<CoinType>(
        dst_addr: address, biuwu_coin: Coin<BiUwU>
    ) acquires SubscriptionManagement {
        let subscription_management =
            borrow_global_mut<SubscriptionManagement<CoinType>>(@vtube);
        let balance =
            table::borrow_mut_with_default(
                &mut subscription_management.balances, dst_addr, 0
            );
        *balance = *balance + coin::value(&biuwu_coin);
        coin::deposit(@vtube, biuwu_coin);
    }

    public fun update_tier<CoinType>(
        dst_addr: address, new_tier: u64
    ) acquires SubscriptionManagement {
        let subscription_management =
            borrow_global_mut<SubscriptionManagement<CoinType>>(@vtube);
        let balance =
            table::borrow_mut_with_default(
                &mut subscription_management.balances, dst_addr, 0
            );
        let tier =
            table::borrow_mut_with_default(
                &mut subscription_management.tiers, dst_addr, 0
            );
        let start_time =
            table::borrow_mut_with_default(
                &mut subscription_management.start_times,
                dst_addr,
                timestamp::now_microseconds()
            );
        if (new_tier > *tier) {
            let used_amount =
                ceil_mul_div(
                    timestamp::now_microseconds() - *start_time,
                    *vector::borrow(&subscription_management.prices, *tier),
                    subscription_management.period
                );
            *balance = *balance - used_amount;
        };
        *tier = new_tier;
        *start_time = timestamp::now_microseconds();
    }

    #[view]
    public fun is_active<CoinType>(dst_addr: address): bool acquires SubscriptionManagement {
        let subscription_management =
            borrow_global<SubscriptionManagement<CoinType>>(@vtube);
        let balance =
            table::borrow_with_default(&subscription_management.balances, dst_addr, &0);
        let tier = table::borrow_with_default(
            &subscription_management.tiers, dst_addr, &0
        );
        let start_time =
            table::borrow_with_default(
                &subscription_management.start_times,
                dst_addr,
                &timestamp::now_microseconds()
            );
        let num_periods =
            ceil_div_u64(
                timestamp::now_microseconds() - *start_time,
                subscription_management.period
            );
        num_periods * *vector::borrow(&subscription_management.prices, *tier)
            <= *balance
    }

    fun check_admin(caller: &signer) {
        assert!(signer::address_of(caller) == @vtube, ERR_UNAUTHORIZED_CALLER);
    }

    fun ceil_div_u64(x: u64, y: u64): u64 {
        (x + y - 1) / y
    }

    fun ceil_div_u128(x: u128, y: u128): u128 {
        (x + y - 1) / y
    }

    fun mul_div(x: u64, y: u64, z: u64): u64 {
        assert!(z != 0, ERR_DIVIDE_BY_ZERO);
        let r = (x as u128) * (y as u128) / (z as u128);
        (r as u64)
    }

    fun ceil_mul_div(x: u64, y: u64, z: u64): u64 {
        assert!(z != 0, ERR_DIVIDE_BY_ZERO);
        let r = ceil_div_u128((x as u128) * (y as u128), (z as u128));
        (r as u64)
    }
}
