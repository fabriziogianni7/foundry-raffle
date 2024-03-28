// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

// call buyTicket
// testing this in integrations

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";

// fund the most recently deployed contract
contract BuyTicket is Script {
    uint256 public constant TICKET_PRICE = 1e3;
    function run() external {
        address mostRecentAddress = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        buyTicket(mostRecentAddress);
    }

    function buyTicket(address mostRecentAddress) public {
        vm.startBroadcast();
        Raffle(mostRecentAddress).buyTicket{value: TICKET_PRICE}();
        vm.stopBroadcast();
        console.log("ticket:");
    }
}
