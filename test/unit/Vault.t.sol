// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {RebaseToken} from "../../src/RebaseToken.sol";
import {IRebaseToken} from "../../src/interfaces/IRebaseToken.sol";
import {Vault} from "../../src/Vault.sol";
import {Test} from "forge-std/Test.sol";

contract VaultTest is Test {
    RebaseToken token; 
    Vault vault;
    address user;

    function setUp() public {
        token = new RebaseToken();
        vault = new Vault(IRebaseToken(address(token)));
        token.grantMintAndBurnRole(address(vault));
        user = makeAddr("user");
        vm.deal(user, 100 ether);
    }



    function testDeposit() public {
        vm.prank(user);
        vault.deposit{value: 10 ether}();
        assertEq(token.balanceOf(user), 10 ether);
    }

    function testRedeem() public {
        vm.startPrank(user);
        vault.deposit{value: 10 ether}();
        vault.redeem(5 ether);
        assertEq(token.balanceOf(user), 5 ether);
    }

    function testRedeemFails() public {
        TransferFail transferFail = new TransferFail(payable(address(vault)));
        
    
        vm.deal(address(transferFail), 10 ether);
        vm.prank(address(transferFail));
        vault.deposit{value: 10 ether}();
        

        vm.expectRevert(Vault.Vault__RedeemFailed.selector);
        transferFail.tryRedeem(5 ether);
    }

    function testRedeemWithInterestAccrued() public {
        vm.startPrank(user);
        vault.deposit{value: 10 ether}();
        vm.stopPrank();

        vm.deal(address(vault), 100 ether); // pokrycie na odsetki

        vm.startPrank(user);
        vm.warp(block.timestamp + 365 days);

        uint256 balanceWithInterest = token.balanceOf(user);
        uint256 ethBefore = user.balance;

        vault.redeem(balanceWithInterest);

        assertEq(token.balanceOf(user), 0);
        assertGt(user.balance, ethBefore);
        vm.stopPrank();
    }

    function testRedeemMaxAmount() public {
        vm.startPrank(user);
        vault.deposit{value: 10 ether}();
        vm.stopPrank();

        vm.deal(address(vault), 100 ether); // pokrycie na odsetki

        vm.startPrank(user);
        vm.warp(block.timestamp + 365 days);

        vault.redeem(type(uint256).max);

        assertEq(token.balanceOf(user), 0);
        vm.stopPrank();
    }

    function testRedeemEmitsEvent() public {
        vm.startPrank(user);
        vault.deposit{value: 10 ether}();
        vm.expectEmit(true, false, false, true);
        emit Vault.Redeem(user, 5 ether);
        vault.redeem(5 ether);
    }

    function testVaultCanReceiveEth() public {
        (bool ok,) = payable(address(vault)).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(address(vault).balance, 1 ether);
    }

    function testGetRebaseToken() public {
        assertEq(vault.getRebaseTokenAddress(), address(token));
    }

}



contract TransferFail {
    Vault vault;

    constructor(address payable _vault) {
        vault = Vault(_vault);
    }

    function tryRedeem(uint256 amount) external {
        vault.redeem(amount);
    }

    receive() external payable {
        revert();
    }

    function test() public {}

}