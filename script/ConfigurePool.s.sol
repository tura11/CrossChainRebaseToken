// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {TokenPool} from "@ccip/ccip/pools/TokenPool.sol";
import {RateLimiter} from "@ccip/ccip/libraries/RateLimiter.sol";

contract ConfigurePool is Script {
    function run(address localPool, uint64 remoteChainSelector, address remotePool, address remoteToken, bool outBoundRateLimiterIsEnabled, uint128 outBoundRateLimiterCapacity, uint128 outBoundRateLimiterRate, bool inBoundRateLimiterIsEnabled, uint128 inBoundRateLimiterCapacity, uint128 inBoundRateLimiterRate) public {
        vm.startBroadcast();
        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            allowed: true,
            remotePoolAddress: abi.encode(remotePool),
            remoteTokenAddress: abi.encode(remoteToken),
            outboundRateLimiterConfig: RateLimiter.Config({isEnabled: outBoundRateLimiterIsEnabled, capacity: outBoundRateLimiterCapacity, rate: outBoundRateLimiterRate}),
            inboundRateLimiterConfig: RateLimiter.Config({isEnabled: inBoundRateLimiterIsEnabled, capacity: inBoundRateLimiterCapacity, rate: inBoundRateLimiterRate})
        });
        TokenPool(localPool).applyChainUpdates(chainsToAdd);
        vm.stopBroadcast();
    }

    function test()public{}
}