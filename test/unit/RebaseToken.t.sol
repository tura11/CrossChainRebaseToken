// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;


import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../../src/RebaseToken.sol";


contract RebaseTokenTest is Test {
    RebaseToken public token;
    address owner;
    address userPerm;
    address user;

    function setUp() public {
        token = new RebaseToken();
        owner = address(this);
        userPerm = makeAddr("userPerm");
        user = makeAddr("user");
    }

    ////////////////////////////////////////////////
    ///         TEST SET INTEREST                ///
    ///////////////////////////////////////////////


    function testGlobalInterestRateCanOnlyDecrease() public {
        vm.prank(owner);
        token.setInterestRate(5e9); // default value was 5e10;
    }

    function testSetInterestFunctionRevertIfRateIncreased() public {
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector,
                5e10,  
                5e11   
                )
            );
        token.setInterestRate(5e11); // default value was 5e10;
    }

    function testSetInterestEmitEvent() public {
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit RebaseToken.InterestRateSet(5e9);
        token.setInterestRate(5e9);
    }



    ////////////////////////////////////////////////
    ///         TEST MINT                        ///
    ///////////////////////////////////////////////


    function testFirstMint() public {
        vm.prank(owner);
        token.grantMintAndBurnRole(userPerm);
        vm.prank(userPerm);
        token.mint(userPerm, 1e18);
        
        assertEq(token.balanceOf(userPerm), 1e18);
        assertEq(token.getInterestRate(), 5e10);
    }

    function testMultipleMint() public {
        vm.prank(owner);
        token.grantMintAndBurnRole(userPerm);
        vm.startPrank(userPerm);
        
        token.mint(userPerm, 1e18);
        vm.warp(block.timestamp + 30 days);
        
        uint256 balanceAfter30Days = token.balanceOf(userPerm);
        token.mint(userPerm, 1e18);
        
        uint256 expectedPrinciple = balanceAfter30Days + 1e18;
        assertEq(token.principleBalanceOf(userPerm), expectedPrinciple);
        assertEq(token.getInterestRate(), 5e10);

        vm.warp(block.timestamp + 30 days);

        assertEq(token.principleBalanceOf(userPerm), expectedPrinciple);
        
        assertGt(token.balanceOf(userPerm), token.principleBalanceOf(userPerm));
        assertEq(token.getInterestRate(), 5e10);
    }

    function testUserWithoutPermCannotMint() public {
        vm.prank(user);
        vm.expectRevert();
        token.mint(user, 1e18);
    }


    ////////////////////////////////////////////////
    ///         TEST BURN                        ///
    ///////////////////////////////////////////////



    function testBurn() public {
        vm.prank(owner);
        token.grantMintAndBurnRole(userPerm);
        vm.startPrank(userPerm);
        token.mint(userPerm, 1e18);
        assertEq(token.balanceOf(userPerm), 1e18);
        token.burn(userPerm, 1e18);
        vm.stopPrank();
        assertEq(token.balanceOf(userPerm), 0);
    }
 
}