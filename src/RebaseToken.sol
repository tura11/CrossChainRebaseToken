// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract RebaseToken is ERC20, Ownable, AccessControl {
    // ── Errors ────────────────────────────────────────────────────────────────
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterest, uint256 newInterest);
    error RebaseToken__NoAnnouncementPending();
    error RebaseToken__TimelockNotExpired(uint256 availableAt);
    error RebaseToken__AnnouncedRateMismatch(uint256 announced, uint256 attempted);

    // ── Constants ─────────────────────────────────────────────────────────────
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    uint256 private constant PRECISION_FACTOR = 1e18;
    uint256 private constant TIMELOCK_DURATION = 48 hours;

    // ── State ─────────────────────────────────────────────────────────────────
    uint256 private s_interestRate = 5e10;
    uint256 private s_pendingInterestRate; // rate zapowiedziany
    uint256 private s_pendingInterestRateValidAt; // kiedy można wykonać

    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimeStamp;

    // ── Events ────────────────────────────────────────────────────────────────
    event InterestRateAnnounced(uint256 pendingRate, uint256 validAt);
    event InterestRateSet(uint256 newInterestRate);
    event InterestRateAnnouncementCancelled();

    constructor() ERC20("RebaseToken", "RBT") Ownable(msg.sender) {}

    function announceInterestRate(uint256 _newInterestRate) external onlyOwner {
        if (_newInterestRate >= s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }

        uint256 validAt = block.timestamp + TIMELOCK_DURATION;
        s_pendingInterestRate = _newInterestRate;
        s_pendingInterestRateValidAt = validAt;

        emit InterestRateAnnounced(_newInterestRate, validAt);
    }

    function executeInterestRate() external onlyOwner {
        if (s_pendingInterestRateValidAt == 0) {
            revert RebaseToken__NoAnnouncementPending();
        }

        if (block.timestamp < s_pendingInterestRateValidAt) {
            revert RebaseToken__TimelockNotExpired(s_pendingInterestRateValidAt);
        }

        uint256 newRate = s_pendingInterestRate;

        s_pendingInterestRate = 0;
        s_pendingInterestRateValidAt = 0;

        s_interestRate = newRate;
        emit InterestRateSet(newRate);
    }

    function cancelInterestRateAnnouncement() external onlyOwner {
        s_pendingInterestRate = 0;
        s_pendingInterestRateValidAt = 0;
        emit InterestRateAnnouncementCancelled();
    }

    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    function mint(address _to, uint256 _amount, uint256 _userInterestRate) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = _userInterestRate;
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }

    // ── View ──────────────────────────────────────────────────────────────────
    function balanceOf(address _user) public view override returns (uint256) {
        uint256 principal = super.balanceOf(_user);
        if (principal == 0) return 0;
        return (principal * _calculateAccumulatedInterest(_user)) / PRECISION_FACTOR;
    }

    function principleBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    function getPendingInterestRate() external view returns (uint256 rate, uint256 validAt) {
        return (s_pendingInterestRate, s_pendingInterestRateValidAt);
    }

    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }

    // ── Internal ──────────────────────────────────────────────────────────────
    function _calculateAccumulatedInterest(address _user) internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimeStamp[_user];
        return PRECISION_FACTOR + (s_userInterestRate[_user] * timeElapsed);
    }

    function _mintAccruedInterest(address _user) internal {
        uint256 previousPrincipal = super.balanceOf(_user);
        uint256 currentBalance = balanceOf(_user);
        uint256 balanceIncrease = currentBalance - previousPrincipal;
        s_userLastUpdatedTimeStamp[_user] = block.timestamp;
        _mint(_user, balanceIncrease);
    }
}
