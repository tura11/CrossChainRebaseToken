// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;


import {Test} from "forge-std/Test.sol";
import {RebaseToken} from "../../src/RebaseToken.sol";


contract HandlerRebaseToken is Test {
    RebaseToken token; 
    address user;
    address owner;
    uint256 public totalMinted;
    uint256 public totalBurned;

    constructor(address _token) {
        token = RebaseToken(_token);
        user = makeAddr("user");
        owner = makeAddr("owner");
    }



    
}