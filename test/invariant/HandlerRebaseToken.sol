// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;


import {Test} from "forge-std/Test.sol";
import {RebaseToken} from "../../src/RebaseToken.sol";


contract HandlerRebaseToken is Test {
    RebaseToken token; 
    address[] users = new address[](3);
    address owner;
    uint256 public totalMinted;
    uint256 public totalBurned;

    constructor(address _token) {
        token = RebaseToken(_token);
        users[0] = makeAddr("user1");
        users[1] = makeAddr("user2");
        users[2] = makeAddr("user3");
        owner = makeAddr("owner");
        vm.prank(owner);
        token.grantMintAndBurnRole(address(this));
    }



    function mint(uint256 amount, uint256 actorIndex) public {
        address user = users[bound(actorIndex, 0, users.length - 1)];
        uint256 interestRate = token.getInterestRate();
        amount = bound(amount, 1e5, type(uint96).max);
        token.mint(user, amount, interestRate);
        totalMinted += amount;
    }


    function  burn(uint256 amount, uint256 actorIndex) public {
        address user = users[bound(actorIndex, 0, users.length - 1)];
        uint256 maxAmount = token.balanceOf(user);
        if(amount < 1e5) return;
        amount = bound(amount, 1e5, maxAmount);
        token.burn(user, amount);
        totalBurned += amount;
    }


    function warp(uint256 time) public {
        time = bound(time,0, 365days);
        vm.warp(block.timestamp + time);
    }

    function getUsers() public view returns (address[] memory) {
        return users;
    }



    
}