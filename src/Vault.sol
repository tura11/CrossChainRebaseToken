// SPDX-License-Identifier: MIT


pragma solidity ^0.8.24;

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {
    error Vault__TransferFailed();

    IRebaseToken private immutable i_rebaseToken;

    event Deposited(address indexed user, uint256 amount);
    event Reedemed(address indexed user, uint256 amount);


    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }


    function deposit() external payable {
        uint256 interestRate = i_rebaseToken.getInterestRate();
        i_rebaseToken.mint(msg.sender, msg.value, interestRate);
        emit Deposited(msg.sender, msg.value);

    }


    function redeem(uint256 _amount) external {
        i_rebaseToken.burn(msg.sender, _amount);
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        if(!success) {
            revert Vault__TransferFailed();
        }
        emit Reedemed(msg.sender, _amount);
    }


    function getRebaseTokenAddress() public view returns (address) {
        return address(i_rebaseToken);
    }

    receive() external payable {}
}