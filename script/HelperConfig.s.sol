// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {DeployConfig, VRF, NetworkConfig} from "./structs/ConfigStructs.s.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;

    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant STARTING_LINK_AMOUNT = 5e18;
    uint256 public constant TICKET_PRICE = 1e3;

    constructor() {
        if (block.chainid == SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = getSepoliaConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilETHConfig();
        }
    }

    function getSepoliaConfig()
        public
        pure
        returns (NetworkConfig memory networkConfig)
    {
        networkConfig = NetworkConfig({
            vrfConfig: VRF({
                vrfCooridnatorAddress: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
                linkTokenAddress: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                startingLinkAMount: STARTING_LINK_AMOUNT,
                keyHash: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subId: 0, // should be set when initialized
                requestConfirmations: 3,
                callbackGasLimit: 2500000,
                numWords: 2
            }),
            deployConfig: DeployConfig({
                inrterval: 10,
                ticketPrice: TICKET_PRICE,
                privateKeySelector: "SEPOLIA_PK"
            })
        });
    }

    function getOrCreateAnvilETHConfig()
        public
        returns (NetworkConfig memory networkConfig)
    {
        if (activeNetworkConfig.vrfConfig.vrfCooridnatorAddress != address(0)) {
            return activeNetworkConfig;
        }
        uint96 BASEFEE = 1e17;
        uint96 GASPRICELINK = 1e9;
        vm.startBroadcast();

        VRFCoordinatorV2Mock vRFCoordinatorV2Mock = new VRFCoordinatorV2Mock(
            BASEFEE,
            GASPRICELINK
        );

        vm.stopBroadcast();
        networkConfig = NetworkConfig({
            vrfConfig: VRF({
                vrfCooridnatorAddress: address(vRFCoordinatorV2Mock),
                linkTokenAddress: address(0),
                startingLinkAMount: STARTING_LINK_AMOUNT,
                keyHash: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subId: 0,
                requestConfirmations: 3,
                callbackGasLimit: 2500000,
                numWords: 2
            }),
            deployConfig: DeployConfig({
                inrterval: 30,
                ticketPrice: TICKET_PRICE,
                privateKeySelector: "ANVIL_PK"
            })
        });
    }
}
