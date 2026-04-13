// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RebaseToken} from "../../src/RebaseToken.sol";
import {Vault} from "../../src/Vault.sol";
import {IRebaseToken} from "../../src/interfaces/IRebaseToken.sol";

contract Handler is Test {
    RebaseToken token;
    Vault vault;
    uint256 public totalMinted;
    uint256 public totalBurned;
    address[] public actors = new address[](3);

    constructor(address _token, address _vault) {
        token = RebaseToken(_token);
        vault = Vault(payable(_vault));
        actors[0] = makeAddr("actor0");
        actors[1] = makeAddr("actor1");
        actors[2] = makeAddr("actor2");
    }

    function deposit(uint256 actorIndex, uint256 amount) public {
        address actor = actors[bound(actorIndex, 0, actors.length - 1)];
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(actor, amount);
        vm.prank(actor);
        vault.deposit{value: amount}();
        totalMinted += amount;
    }

    function redeem(uint256 actorIndex, uint256 amount) public {
        address actor = actors[bound(actorIndex, 0, actors.length - 1)];
        uint256 maxAmountToWithdraw = token.balanceOf(actor);
        if (maxAmountToWithdraw < 1e5) return;
        amount = bound(amount, 1e5, maxAmountToWithdraw);
        vm.prank(actor);
        vault.redeem(amount);
        totalBurned += amount;
    }

    function warp(uint256 time) public {
        time = bound(time, 0, 30 days);
        vm.warp(block.timestamp + time);
    }
}
