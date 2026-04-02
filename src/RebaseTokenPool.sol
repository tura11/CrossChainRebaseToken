// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Pool} from "@ccip/contracts/src/v0.8/ccip/libraries/Pool.sol";
import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract RebaseTokenPool is TokenPool {
    constructor(IERC20 _token, address[] memory _allowlist, address _rnmProxy, address _router) TokenPool(_token, _allowlist, _rnmProxy, _router){}


    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn) public returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut);


    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn) public returns (Pool.ReleaseOrMintOutV1 memory);

}