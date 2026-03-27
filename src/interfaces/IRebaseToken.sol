// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;


interface IRebaseToken {
    function mint(address account, uint256 amount) external;
    function burn(address account, uint256 amount) external;
    
}