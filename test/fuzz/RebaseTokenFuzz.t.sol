// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../../src/RebaseToken.sol";
import {Vault} from "../../src/Vault.sol";
import {IRebaseToken} from "../../src/interfaces/IRebaseToken.sol";

contract RebaseTokenFuzz is Test {
    RebaseToken token;
    Vault vault;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        vm.startPrank(owner);
        token = new RebaseToken();
        vault = new Vault(IRebaseToken(address(token)));
        token.grantMintAndBurnRole(address(vault));
        (bool success,) = payable(address(vault)).call{value: 1e18}("");
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 rewardAmount) public {
        (bool success,) = payable(address(vault)).call{value: rewardAmount}("");
    }

    function testFuzzDepositLinear(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        uint256 startBalance = token.balanceOf(user);
        assertEq(startBalance, amount);

        vm.warp(block.timestamp + 1 hours);

        uint256 middleBalance = token.balanceOf(user);
        assertGt(middleBalance, startBalance);

        vm.warp(block.timestamp + 1 hours);

        uint256 endBalance = token.balanceOf(user);
        assertGt(endBalance, middleBalance);

        vm.stopPrank();
    }

    function testRedeemAfterTimePassed(uint256 amount, uint256 time) public {
        amount = bound(amount, 1e5, type(uint96).max);
        time = bound(time, 1000, type(uint96).max);

        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        vm.stopPrank();

        vm.warp(block.timestamp + time);

        uint256 balanceAfterTime = token.balanceOf(user);

        vm.deal(owner, balanceAfterTime - amount);
        vm.prank(owner);
        addRewardsToVault(balanceAfterTime - amount);
        vm.prank(user);
        vault.redeem(balanceAfterTime);
        vm.stopPrank();
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);

        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        address user2 = makeAddr("user2");
        assertEq(token.balanceOf(user), amount);
        assertEq(token.balanceOf(user2), 0);

        vm.prank(owner);
        token.announceInterestRate(4e10);
        vm.warp(block.timestamp + 48 hours);
        vm.prank(owner);
        token.executeInterestRate();

        uint256 userBalanceBeforeTransfer = token.balanceOf(user);

        vm.prank(user);
        token.transfer(user2, amountToSend);

        assertEq(token.balanceOf(user), userBalanceBeforeTransfer - amountToSend);
        assertEq(token.balanceOf(user2), amountToSend);

        assertEq(token.getUserInterestRate(user), 5e10);
        assertEq(token.getUserInterestRate(user2), 5e10);
    }
}
