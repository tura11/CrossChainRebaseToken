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
    ///         TEST  INTEREST                   ///
    ///////////////////////////////////////////////


    function testGlobalInterestRateCanOnlyDecrease() public {
        vm.prank(owner);
        token.announceInterestRate(5e9); // default value was 5e10;
        vm.warp(block.timestamp + 48 hours);
        token.executeInterestRate();
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
        token.announceInterestRate(5e11); // default value was 5e10;
    }

    function testSetInterestEmitEvent() public {
        vm.warp(0);
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit RebaseToken.InterestRateAnnounced(5e9 , 48 hours);
        token.announceInterestRate(5e9);
    }

    function testAnnounceRevertsIfNotOwner() public {
    vm.prank(user);
    vm.expectRevert();
    token.announceInterestRate(5e9);
}

    function testAnnounceRevertsIfRateNotDecreasing() public {
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector,
                5e10, 5e11
            )
        );
        token.announceInterestRate(5e11);
    }

    function testAnnounceSetsPendingState() public {
        vm.warp(1000);
        vm.prank(owner);
        token.announceInterestRate(5e9);

        (uint256 rate, uint256 validAt) = token.getPendingInterestRate();
        assertEq(rate, 5e9);
        assertEq(validAt, 1000 + 48 hours);
    }

    function testAnnounceEmitsEvent() public {
        vm.warp(0);
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit RebaseToken.InterestRateAnnounced(5e9, 48 hours);
        token.announceInterestRate(5e9);
    }

    function testExecuteRevertsIfNotOwner() public {
        vm.prank(owner);
        token.announceInterestRate(5e9);
        vm.warp(block.timestamp + 48 hours);

        vm.prank(user);
        vm.expectRevert();
        token.executeInterestRate();
    }

    function testExecuteRevertsIfNoPending() public {
        vm.prank(owner);
        vm.expectRevert(RebaseToken.RebaseToken__NoAnnouncementPending.selector);
        token.executeInterestRate();
    }

    function testExecuteRevertsIfTooEarly() public {
        vm.prank(owner);
        token.announceInterestRate(5e9);

        uint256 validAt = block.timestamp + 48 hours;
        vm.warp(block.timestamp + 48 hours - 1);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                RebaseToken.RebaseToken__TimelockNotExpired.selector,
                validAt
            )
        );
        token.executeInterestRate();
    }

    function testExecuteSetsNewRate() public {
        vm.prank(owner);
        token.announceInterestRate(5e9);
        vm.warp(block.timestamp + 48 hours);
        vm.prank(owner);
        token.executeInterestRate();

        assertEq(token.getInterestRate(), 5e9);
    }

    function testExecuteClearsPending() public {
        vm.prank(owner);
        token.announceInterestRate(5e9);
        vm.warp(block.timestamp + 48 hours);
        vm.prank(owner);
        token.executeInterestRate();

        (uint256 rate, uint256 validAt) = token.getPendingInterestRate();
        assertEq(rate, 0);
        assertEq(validAt, 0);
    }

    function testExecuteEmitsEvent() public {
        vm.prank(owner);
        token.announceInterestRate(5e9);
        vm.warp(block.timestamp + 48 hours);

        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit RebaseToken.InterestRateSet(5e9);
        token.executeInterestRate();
    }

    function testCancelRevertsIfNotOwner() public {
        vm.prank(owner);
        token.announceInterestRate(5e9);

        vm.prank(user);
        vm.expectRevert();
        token.cancelInterestRateAnnouncement();
    }

    function testCancelClearsPending() public {
        vm.prank(owner);
        token.announceInterestRate(5e9);
        vm.prank(owner);
        token.cancelInterestRateAnnouncement();

        (uint256 rate, uint256 validAt) = token.getPendingInterestRate();
        assertEq(rate, 0);
        assertEq(validAt, 0);
    }

    function testCancelEmitsEvent() public {
        vm.prank(owner);
        token.announceInterestRate(5e9);

        vm.prank(owner);
        vm.expectEmit(false, false, false, false);
        emit RebaseToken.InterestRateAnnouncementCancelled();
        token.cancelInterestRateAnnouncement();
    }

    function testCancelPreventsExecute() public {
        vm.prank(owner);
        token.announceInterestRate(5e9);
        vm.prank(owner);
        token.cancelInterestRateAnnouncement();

        vm.warp(block.timestamp + 48 hours);
        vm.prank(owner);
        vm.expectRevert(RebaseToken.RebaseToken__NoAnnouncementPending.selector);
        token.executeInterestRate();
    }

    



    ////////////////////////////////////////////////
    ///         TEST MINT                        ///
    ///////////////////////////////////////////////


    function testFirstMint() public {
        vm.prank(owner);
        token.grantMintAndBurnRole(userPerm);
        vm.prank(userPerm);
        token.mint(userPerm, 1e18, 5e10);
        
        assertEq(token.balanceOf(userPerm), 1e18);
        assertEq(token.getInterestRate(), 5e10);
    }

    function testMultipleMint() public {
        vm.prank(owner);
        token.grantMintAndBurnRole(userPerm);
        vm.startPrank(userPerm);
        
        token.mint(userPerm, 1e18, token.getInterestRate());
        vm.warp(block.timestamp + 30 days);
        
        uint256 balanceAfter30Days = token.balanceOf(userPerm);
        token.mint(userPerm, 1e18, token.getInterestRate());
        
        uint256 expectedPrinciple = balanceAfter30Days + 1e18;
        assertEq(token.principleBalanceOf(userPerm), expectedPrinciple);
        assertEq(token.getInterestRate(), 5e10);

        vm.warp(block.timestamp + 30 days);

        assertEq(token.principleBalanceOf(userPerm), expectedPrinciple);
        
        assertGt(token.balanceOf(userPerm), token.principleBalanceOf(userPerm)); // greate than because balanceOf includes interest without write to storage
        assertEq(token.getInterestRate(), 5e10);
    }

    function testUserWithoutPermCannotMint() public {
        vm.prank(user);
        vm.expectRevert();
        token.mint(userPerm, 1e18, 5e10);
    }


    ////////////////////////////////////////////////
    ///         TEST BURN                        ///
    ///////////////////////////////////////////////



    function testBurn() public {
        vm.prank(owner);
        token.grantMintAndBurnRole(userPerm);
        vm.startPrank(userPerm);
        token.mint(userPerm, 1e18, token.getInterestRate());
        assertEq(token.balanceOf(userPerm), 1e18);
        token.burn(userPerm, 1e18);
        vm.stopPrank();
        assertEq(token.balanceOf(userPerm), 0);
    }


   function testBurnAfterInterestAccrued() public {
        vm.prank(owner);
        token.grantMintAndBurnRole(userPerm);
        vm.startPrank(userPerm);

        token.mint(userPerm, 1e18, token.getInterestRate());
        vm.warp(block.timestamp + 30 days);

        uint256 balanceWithInterest = token.balanceOf(userPerm);
        token.burn(userPerm, 1e18);

        assertEq(token.balanceOf(userPerm), balanceWithInterest - 1e18);
        vm.stopPrank();
    }

    function testTwoBurnsWithTimeBetween() public {
        vm.prank(owner);
        token.grantMintAndBurnRole(userPerm);
        vm.startPrank(userPerm);

        token.mint(userPerm, 10e18, token.getInterestRate());
        vm.warp(block.timestamp + 30 days);

        token.burn(userPerm, 1e18);
        vm.warp(block.timestamp + 30 days); 

        uint256 balanceAfterFirstBurn = token.balanceOf(userPerm);
        token.burn(userPerm, 1e18);

        assertEq(token.balanceOf(userPerm), balanceAfterFirstBurn - 1e18);
        vm.stopPrank();
    }

    function testBurnMaxAmount() public {
        vm.prank(owner);
        token.grantMintAndBurnRole(userPerm);
        vm.startPrank(userPerm);
        token.mint(userPerm, 1e18, token.getInterestRate());
        token.burn(userPerm, type(uint256).max);
        vm.stopPrank();
        assertEq(token.balanceOf(userPerm), 0);
    }

    /////////////////////////////////////////////////
    ///         TEST TRANSFER                     ///
    ///////////////////////////////////////////////


    function testTransferSuccesfuly() public {
        vm.prank(owner);
        token.grantMintAndBurnRole(userPerm);
        vm.startPrank(userPerm);
        token.mint(userPerm, 1e18, token.getInterestRate());
        token.transfer(user, 1e18);
        vm.stopPrank();
        assertEq(token.balanceOf(userPerm), 0);
        assertEq(token.balanceOf(user), 1e18);
        assertEq(token.getUserInterestRate(user), 5e10);
    }

    function testTrasnferWithMaxAmount() public {
        vm.prank(owner);
        token.grantMintAndBurnRole(userPerm);
        vm.startPrank(userPerm);
        token.mint(userPerm, 1e18, token.getInterestRate());
        token.transfer(user, type(uint256).max);
        vm.stopPrank();
        assertEq(token.balanceOf(userPerm), 0);
        assertEq(token.balanceOf(user), 1e18);
        assertEq(token.getUserInterestRate(user), 5e10);
    }

    function testTransferFromSuccesfuly() public {
        vm.prank(owner);
        token.grantMintAndBurnRole(userPerm);
        vm.startPrank(userPerm);
        token.approve(owner, 1e18);
        token.mint(userPerm, 1e18, token.getInterestRate());
        vm.stopPrank();
        vm.prank(owner);
        token.transferFrom(userPerm, user, 1e18);
        
        assertEq(token.balanceOf(userPerm), 0);
        assertEq(token.balanceOf(user), 1e18);
        assertEq(token.getUserInterestRate(user), 5e10);
    }
    function testTransferFromWithMaxAmount() public {
        vm.prank(owner);
        token.grantMintAndBurnRole(userPerm);
        vm.startPrank(userPerm);
        token.approve(owner, 1000e18);
        token.mint(userPerm, 1e18, token.getInterestRate());
        vm.stopPrank();
        vm.prank(owner);
        token.transferFrom(userPerm, user, type(uint256).max);
        
        assertEq(token.balanceOf(userPerm), 0);
        assertEq(token.balanceOf(user), 1e18);
        assertEq(token.getUserInterestRate(user), 5e10);
    }
 
}