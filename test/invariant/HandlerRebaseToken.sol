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
    }



    function mint(uint256 amount, uint256 actorIndex) public {
        address user = users[bound(actorIndex, 0, users.length - 1)];
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);
        vm.prank(user);
        token.mint(user, amount);
        totalMinted += amount;
    }



    
}