// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DeployConfig, VRF, NetworkConfig} from "./structs/ConfigStructs.s.sol";
import {LinkTokenInterface} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import {VRFCoordinatorV2Mock} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract DeployRaffle is Script {
    // function setUp() public {}
    error DeployRaffle__DeplpyerDontHaveNecessaryLink();

    function run() public returns (Raffle) {
        HelperConfig helperConfig = new HelperConfig();
        (VRF memory vrfConfig, DeployConfig memory deployConfig) = helperConfig
            .activeNetworkConfig();

        uint256 deployerPrivateKey = vm.envUint(
            deployConfig.privateKeySelector
        );
        address deployerAccount = vm.envAddress("ACCOUNT");
        vm.startBroadcast(deployerPrivateKey);

        Raffle raffle = new Raffle(
            deployConfig.ticketPrice,
            deployConfig.inrterval,
            vrfConfig
        );

        // if we are in anvil
        if (block.chainid == 31337) {
            uint64 subId = raffle.getSubId();
            VRFCoordinatorV2Mock vRFCoordinatorV2Mock = VRFCoordinatorV2Mock(
                vrfConfig.vrfCooridnatorAddress
            );
            vRFCoordinatorV2Mock.fundSubscription(subId, 5e18);
        } else {
            LinkTokenInterface linkToken = LinkTokenInterface(
                vrfConfig.linkTokenAddress
            );

            bool deployerHasNecessaryAmount = linkToken.balanceOf(
                deployerAccount
            ) >= vrfConfig.startingLinkAMount;
            if (!deployerHasNecessaryAmount)
                revert DeployRaffle__DeplpyerDontHaveNecessaryLink();

            // send LINK to raffle!
            linkToken.transfer(address(raffle), vrfConfig.startingLinkAMount);

            // raffle send LINK to Coordinator
            raffle.topUpSubscription(vrfConfig.startingLinkAMount);
        }
        vm.stopBroadcast();
        return raffle;
    }
}
