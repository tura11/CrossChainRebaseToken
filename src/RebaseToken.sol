// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract RebaseToken is ERC20{

    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterest, uint256 newInterest);
    uint256 private s_interestRate = 5e10;
    mapping(address => uint256) private userInterestRate;

    event InterestRateSet(uint256 newInterestRate);
    constructor() ERC20("RebaseToken", "RBT") {

    }


    function setInterestRate(uint256 _newInterestRate) external {
        if(_newInterestRate < s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }



    function mint(address _to, uint256 _amount) external {
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }


    function getUserInterestRate(address _user) external view returns (uint256) {
        return userInterestRate[_user];
    }
}