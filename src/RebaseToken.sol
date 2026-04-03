// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";


contract RebaseToken is ERC20, Ownable, AccessControl {

    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterest, uint256 newInterest);

    uint256 private s_interestRate = 5e10; // 500000000000
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimeStamp;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    uint256 private constant PRECISION_FACTOR = 1e18;

    event InterestRateSet(uint256 newInterestRate);


    constructor() ERC20("RebaseToken", "RBT") Ownable(msg.sender) {}

    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }


    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        if(_newInterestRate >= s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }



    function mint(address _to, uint256 _amount, uint256 _userIntertestRate) external onlyRole(MINT_AND_BURN_ROLE){
        _mintAccuredInterest(_to);
        s_userInterestRate[_to] = _userIntertestRate;
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        if(_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccuredInterest(_from);
        _burn(_from, _amount);
    }

    function balanceOf(address _user) public view override returns (uint256) {
        return super.balanceOf(_user) * calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR;
    }

    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
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


    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccuredInterest(_sender);
        _mintAccuredInterest(_recipient);
        if(_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        if(balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[_sender]; // known issue with inheritence interest
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }

    function principleBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
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

    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }
}