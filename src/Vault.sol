// SPDX-License-Identifier: MIT


pragma solidity ^0.8.24;

contract Vault {
    address private immutable i_rebaseToken;

    event Deposited(address user, uint256 amount);


    constructor(address _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }


    function deposit() external payable {
        i_rebaseToken.mint(msg.sender, msg.value);
        emit Deposited(msg.sender, msg.value);

    }


    function getRebaseTokenAddress() public view returns (address) {
        return i_rebaseToken;
    }

    receive() external payable {}
}