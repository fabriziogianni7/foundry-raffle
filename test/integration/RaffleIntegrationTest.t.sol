// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {BuyTicket} from "../../script/Interactions.s.sol";

contract FundMeIntegrationTest is StdCheats, Test {
    // deploy contract (you can import a deploy script)
    // This contract is always the msg sender
    Raffle raffle;
    DeployRaffle deployer;
    address FABRIZIO = makeAddr("FABRIZIO");
    uint256 public constant TICKET_PRICE = 1e18;

    uint256 public constant STARTING_USER_BALANCE = 100 ether;

    function setUp() external {
        deployer = new DeployRaffle();
        raffle = deployer.run();
        vm.deal(FABRIZIO, 100 ether);
    } // always run first

    function testBuyTicketInteraction() public {
        BuyTicket buyTicket = new BuyTicket();

        buyTicket.buyTicket(address(raffle));
        uint256 nParticipants = raffle.getNumbersOfParticipants();
        assertEq(nParticipants, 1);
    }
}
