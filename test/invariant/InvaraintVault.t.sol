// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Handler} from "./Handler.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test} from "forge-std/Test.sol";
import {RebaseToken} from "../../src/RebaseToken.sol";
import {Vault} from "../../src/Vault.sol";
import {IRebaseToken} from "../../src/interfaces/IRebaseToken.sol";


contract RebaseTokenInvariant is StdInvariant, Test {
    RebaseToken token;
    Vault vault;
    Handler handler;
    address owner = makeAddr("owner");

    function setUp() public {
        vm.startPrank(owner);
        token = new RebaseToken();
        vault = new Vault(IRebaseToken(address(token)));
        token.grantMintAndBurnRole(address(vault));
        vm.stopPrank();

        handler = new Handler(address(token), address(vault));

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = Handler.deposit.selector;
        selectors[1] = Handler.redeem.selector;
        selectors[2] = Handler.warp.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function invariant_totalSupplyGteTotalMintedSubBurned() public view {
        uint256 totalMinted = handler.totalMinted();
        uint256 totalBurned = handler.totalBurned();
        assertGe(token.totalSupply(), totalMinted - totalBurned);
    }

    function invariant_BalanceOfGtePripicpleBalance() public view {
        address actor1 = handler.actors(0);
        address actor2 = handler.actors(1);
        assertGe(token.balanceOf(actor1), token.principleBalanceOf(actor1));
        assertGe(token.balanceOf(actor2), token.principleBalanceOf(actor2));
    }
}