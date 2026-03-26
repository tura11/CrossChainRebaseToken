// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract RebaseToken is ERC20{

    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterest, uint256 newInterest);
    uint256 private s_interestRate = 5e10; // 500000000000
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimeStamp;
    uint256 private constant PRECISION_FACTOR = 1e18;

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
        _mintAccuredInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external {
        if(_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccuredInterest(_from);
        _burn(_from, _amount);
    }

    function balanceOf(address _user) public view override returns (uint256) {
        return super.balanceOf(_user) * calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR;
    }

    function transfer(address _recipient, uint256 _amount) external override returns (bool) {
        _mintAccuredInterest(msg.sender);
        _mintAccuredInterest(_recipient);
        if(_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if(balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    function calculateUserAccumulatedInterestSinceLastUpdate(address _user) internal view returns (uint256 linearInterest) {
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimeStamp[_user];
        linearInterest = PRECISION_FACTOR + (s_userInterestRate[_user] * timeElapsed);
    }


    function _mintAccuredInterest(address _user) internal {
        uint256 previousPrinicpleBalance = super.balanceOf(_user);
        uint256 currentBalanace = balanceOf(_user);
        uint256 balanceIncrease = currentBalanace - previousPrinicpleBalance;
        s_userLastUpdatedTimeStamp[_user] = block.timestamp;

        _mint(_user, balanceIncrease);
    }


    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }
}