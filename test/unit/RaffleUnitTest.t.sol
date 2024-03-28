// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Test, console, Vm} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {LinkTokenInterface} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import {VRFCoordinatorV2} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/VRFCoordinatorV2.sol";
import {VRFCoordinatorV2Mock} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {Strings} from "../../lib/openzeppelin-contracts/contracts/utils/Strings.sol";

// run forge coverage --report debug > coverage.txt to have a file containing every line we didn't test
contract RaffleUnitTest is Test {
    /////////////////////////////
    /////   VARIABLES ///////////
    /////////////////////////////
    Raffle public raffle;

    event TicketBought(address indexed user, uint256 indexed ticketn);
    event RandomNumberGenerated();
    event WinnerPicked(address payable indexed winner);

    uint256 public constant TICKET_PRICE = 1e18;
    uint256 public constant STARTING_LINK_AMOUNT = 5e18;
    uint256 public constant STARTING_USER_BALANCE = 100 ether;
    address FABRIZIO = makeAddr("FABRIZIO");

    /////////////////////////////
    /////     SETUP   ///////////
    /////////////////////////////
    function setUp() public {
        DeployRaffle deployRaffle = new DeployRaffle();
        raffle = deployRaffle.run();
        vm.deal(FABRIZIO, STARTING_USER_BALANCE);
    }

    /////////////////////////////
    ///// MODIFIERS & HELPERS ///
    /////////////////////////////
    modifier buyRaffle() {
        uint256 PLAYERS_N = 10;
        for (uint256 i; i < PLAYERS_N - 1; i++) {
            address addr = makeAddr(Strings.toString(i));
            vm.deal(addr, 100 ether);
            vm.prank(addr);
            raffle.buyTicket{value: TICKET_PRICE}();
        }
        // letting also Fabrizio play :)
        vm.prank(FABRIZIO);
        raffle.buyTicket{value: TICKET_PRICE}();

        uint256 contractBalance = address(raffle).balance;
        assertEq(contractBalance, TICKET_PRICE * PLAYERS_N);

        _;
    }
    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    /////////////////////////////
    ///// GENERAL TESTS  ////////
    /////////////////////////////
    function testRaffleStateIsOpen() public buyRaffle {
        uint256 state = uint256(raffle.getRaffleState());
        assertEq(state, 0);
    }

    function testSubscriptionCreation() public view {
        uint256 subId = raffle.getSubId();
        console.log("subId %s", subId);
        assertNotEq(subId, 0);
    }

    function testGetSubscription() public view {
        uint64 subId = raffle.getSubId();

        address coordinatorAddress = raffle.getCoordinator();
        VRFCoordinatorV2 vRFCoordinatorV2 = VRFCoordinatorV2(
            coordinatorAddress
        );
        (uint96 balance, , , ) = vRFCoordinatorV2.getSubscription(subId);
        assertEq(balance, STARTING_LINK_AMOUNT);
    }

    /////////////////////////////
    ///// BUY TICKETS TESTS /////
    /////////////////////////////
    function testUserCanBuyTicket() public buyRaffle {
        uint256 ticketId = raffle.getUserTicket(FABRIZIO);
        assertEq(ticketId, 9);
    }
    function testRevertIfUserSendNotEnoughETH() public buyRaffle {
        vm.prank(FABRIZIO);

        vm.expectRevert(Raffle.Raffle__InsufficentETHSent.selector);
        raffle.buyTicket();
    }
    function testEmitBuyEvent() public {
        vm.prank(FABRIZIO);
        vm.expectEmit(true, true, false, false, address(raffle));
        emit TicketBought(FABRIZIO, 0);
        raffle.buyTicket{value: TICKET_PRICE}();
    }
    function testCantBuyTicketIfStateIsClosed() public buyRaffle {
        //vm.roll set the block
        //vm.warp set the timestamp
        vm.warp(block.timestamp + 1000000);
        vm.roll(block.number + 1);
        raffle.performUpkeep(""); //this should change the state to calculating
        vm.prank(FABRIZIO); // try to buy another ticket
        vm.expectRevert(Raffle.Raffle_RaffleIsClosed.selector);
        raffle.buyTicket{value: TICKET_PRICE}();
    }

    /////////////////////////////
    /////  UPKEEP TESTS /////////
    /////////////////////////////
    function testPerformUpkeepShouldEmitRandomNumberGenerated()
        public
        buyRaffle
    {
        vm.warp(block.timestamp + 1000000);
        vm.roll(block.number + 1);
        // vm.expectEmit(true, false, false, false, address(raffle));
        // emit RandomNumberGenerated();
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        assertGt(uint256(requestId), 0);
    }
    function testPerformUpkeepRevertIfupKeepNeededIsFalse() public buyRaffle {
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle_UpkeepNotNeeded.selector,
                address(raffle).balance,
                0,
                raffle.getNumbersOfParticipants(),
                block.timestamp,
                raffle.getLastTimeStamp(),
                raffle.getInterval()
            )
        );
        raffle.performUpkeep("");
    }
    function testCoordinatorEmitEventWithReqId() public buyRaffle {
        vm.warp(block.timestamp + 1000000);
        vm.roll(block.number + 1);
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[0].topics[1];
        assert(uint256(requestId) > 0);
    }

    /////////////////////////////
    // fulfillRandomWords TESTS /
    /////////////////////////////
    function testFulfillRandomWords() public skipFork buyRaffle {
        vm.warp(block.timestamp + 1000000);
        vm.roll(block.number + 1);

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory performUpkeepEntries = vm.getRecordedLogs();
        bytes32 requestId = performUpkeepEntries[1].topics[1];

        address coordinatorAddress = raffle.getCoordinator();
        VRFCoordinatorV2Mock coordinatorMock = VRFCoordinatorV2Mock(
            coordinatorAddress
        );
        vm.prank(coordinatorAddress);
        coordinatorMock.fulfillRandomWords(uint256(requestId), address(raffle));

        address lastWinner = raffle.getLastWinner();
        assert(lastWinner != address(0));
    }

    function testFuzzFulfillRandomWordsFailsWithDifferentRequestIds(
        uint256 requestId
    ) public skipFork buyRaffle {
        vm.warp(block.timestamp + 1000000);
        vm.roll(block.number + 1);

        vm.recordLogs();

        address coordinatorAddress = raffle.getCoordinator();
        VRFCoordinatorV2Mock coordinatorMock = VRFCoordinatorV2Mock(
            coordinatorAddress
        );
        vm.prank(coordinatorAddress);
        vm.expectRevert("nonexistent request");
        coordinatorMock.fulfillRandomWords(requestId, address(raffle));
    }
}
