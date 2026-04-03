// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Pool} from "@ccip/ccip/libraries/Pool.sol";
import {TokenPool} from "@ccip/ccip/pools/TokenPool.sol";
import {IERC20} from "@ccip/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {IRebaseToken} from "./interfaces/IRebaseToken.sol";


contract RebaseTokenPool is TokenPool {
    constructor(IERC20 _token, address[] memory _allowlist, address _rnmProxy, address _router) TokenPool(_token, _allowlist, _rnmProxy, _router){}


    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn) public returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut){
        _validateLockOrBurn(lockOrBurnIn);
        uint256 userInterestRate = IRebaseToken(address(i_token)).getUserInterestRate(lockOrBurnIn.originalSender);
        IRebaseToken(address(i_token)).burn(address(this), lockOrBurnIn.amount);
        lockOrBurnOut = Pool.LockOrBurnOutV1({
            destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
            destPoolData: abi.encode(userInterestRate)
        });

    }


    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn) public returns (Pool.ReleaseOrMintOutV1 memory){
        _validateReleaseOrMint(releaseOrMintIn);
        uint256 userInterestRate = abi.decode(releaseOrMintIn.sourcePoolData, (uint256));
        IRebaseToken(address(i_token)).mint(releaseOrMintIn.receiver, releaseOrMintIn.amount, userInterestRate);
        return Pool.ReleaseOrMintOutV1({
            destinationAmount: releaseOrMintIn.amount
        });
    }

}