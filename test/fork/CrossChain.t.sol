// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;


import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../../src/RebaseToken.sol";
import {RebaseTokenPool} from "../../src/RebaseTokenPool.sol";
import {Vault} from "../../src/Vault.sol";
import {IRebaseToken} from "../../src/interfaces/IRebaseToken.sol";
import {CCIPLocalSimulatorFork} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {Register} from "@chainlink/local/src/ccip/Register.sol";
import {IERC20} from "@ccip/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {RegistryModuleOwnerCustom} from "@ccip/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {TokenPool} from "@ccip/ccip/pools/TokenPool.sol";
import {RateLimiter} from "@ccip/ccip/libraries/RateLimiter.sol";
import {Client} from "@ccip/ccip/libraries/Client.sol";
import {IRouterClient} from "@ccip/ccip/interfaces/IRouterClient.sol";


contract CrossChainTest is Test {
    address owner = makeAddr("owner");
    address user  = makeAddr("user");
    uint256 sepoliaFork;
    uint256 arbSepoliaFork;

    CCIPLocalSimulatorFork ccipLocalSimulatorFork;

    RebaseToken sepoliaToken;
    RebaseToken arbSepoliaToken;
    Vault vault;

    RebaseTokenPool sepoliaPool;
    RebaseTokenPool arbSepoliaPool;

    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbSepoliaNetworkDetails;


    function setUp() public{
        sepoliaFork = vm.createSelectFork("eth-sepolia");
        arbSepoliaFork = vm.createFork("arb-sepolia");

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);

        vm.startPrank(owner);
        sepoliaToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(sepoliaToken)));
        sepoliaPool = new RebaseTokenPool(IERC20(address(sepoliaToken)), new address[](0), sepoliaNetworkDetails.rmnProxyAddress, sepoliaNetworkDetails.routerAddress);
        sepoliaToken.grantMintAndBurnRole(address(vault));
        sepoliaToken.grantMintAndBurnRole(address(sepoliaPool));
        RegistryModuleOwnerCustom(sepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(address(sepoliaToken));
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(sepoliaToken));
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(address(sepoliaToken), address(sepoliaPool));
        configureTokenPool(arbSepoliaFork, address(arbSepoliaPool), sepoliaNetworkDetails.chainSelector, address(sepoliaPool), address(sepoliaToken));
        vm.stopPrank();

        vm.selectFork(arbSepoliaFork);
        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        vm.startPrank(owner);
        arbSepoliaToken = new RebaseToken();
        arbSepoliaPool = new RebaseTokenPool(IERC20(address(arbSepoliaToken)), new address[](0), arbSepoliaNetworkDetails.rmnProxyAddress, arbSepoliaNetworkDetails.routerAddress);
        arbSepoliaToken.grantMintAndBurnRole(address(arbSepoliaPool));
        arbSepoliaToken.grantMintAndBurnRole(address(vault));
        RegistryModuleOwnerCustom(arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(address(arbSepoliaToken));
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(arbSepoliaToken));
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(address(arbSepoliaToken), address(arbSepoliaPool));
        configureTokenPool(sepoliaFork, address(sepoliaPool), arbSepoliaNetworkDetails.chainSelector, address(arbSepoliaPool), address(arbSepoliaToken));
        vm.stopPrank();
    }


    function configureTokenPool(uint256 fork, address localPool,uint64 remoteChainSelector, address remotePool, address remoteTokenAddress) public {
        vm.selectFork(fork);
        vm.prank(owner);
        bytes[] memory remotePoolAddresses = new bytes[](1);
        remotePoolAddresses[0] = abi.encode(remotePool);
        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            allowed: true,
            remotePoolAddress: abi.encode(remotePoolAddresses),
            remoteTokenAddress: abi.encode(remoteTokenAddress),
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false,
                capacity: 0,
                rate: 0
            }),
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false,
                capacity: 0,
                rate: 0
            })
        });
        TokenPool(localPool).applyChainUpdates(chainsToAdd);
    }


    function bridgeTokens(uint256 amountToBridge, uint256 localFork, uint256 remoteFork, Register.NetworkDetails memory localNetworkDetails, Register.NetworkDetails memory remoteNetworkDetails, RebaseToken localToken, RebaseToken remoteToken) public {
        vm.selectFork(localFork);
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(localToken),
            amount: amountToBridge
        });
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(user),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: localNetworkDetails.linkAddress,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 0}))
        });
        
        uint256 fee = IRouterClient(localNetworkDetails.routerAddress).getFee(remoteNetworkDetails.chainSelector, message);
        ccipLocalSimulatorFork.requestLinkFromFaucet(user, fee);
        vm.prank(user);
        IERC20(localNetworkDetails.linkAddress).approve(localNetworkDetails.routerAddress, fee);
        vm.prank(user);
        IERC20(address(localToken)).approve(localNetworkDetails.routerAddress, amountToBridge);
        uint256 localBalanceBefore = localToken.balanceOf(user);
        vm.prank(user);
        IRouterClient(localNetworkDetails.routerAddress).ccipSend(remoteNetworkDetails.chainSelector, message);
        uint256 localBalanceAfter = localToken.balanceOf(user);
        assertEq(localBalanceAfter, localBalanceBefore - amountToBridge);
        uint256 localUserInterestRate = localToken.getUserInterestRate(user);

        vm.selectFork(remoteFork);
        vm.warp(block.timestamp + 20 minutes);
        uint256 remoteBalanceBefore = remoteToken.balanceOf(user);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(remoteFork);
        uint256 remoteBalanceAfter = remoteToken.balanceOf(user);
        assertEq(remoteBalanceAfter, remoteBalanceBefore + amountToBridge);
        uint256 remoteUserInterestRate = remoteToken.getUserInterestRate(user);
        assertEq(localUserInterestRate, remoteUserInterestRate);
        


    }
}