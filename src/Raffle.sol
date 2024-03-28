// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {VRFConsumerBaseV2} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {VRFCoordinatorV2} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/VRFCoordinatorV2.sol";
import {LinkTokenInterface} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import {VRF} from "../script/structs/ConfigStructs.s.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title Raffle
 * @author Fabriziogianni7
 * @notice This is a sample of a raffle contract using vrf2
 * @dev Implement chainlink vrf2
 */
contract Raffle is VRFConsumerBaseV2, Ownable {
    // users need can buy a ticket
    // contract need to extract a random number every x blocks

    //// Errors ////
    error Raffle__InsufficentETHSent();
    error Raffle__PaymentError();
    error Raffle_RaffleIsClosed();
    error Raffle_UpkeepNotNeeded(
        uint256 balance,
        RaffleState s_raffleState,
        uint256 nParticipants,
        uint256 currentTimestamp,
        uint256 s_lastTimestamp,
        uint256 i_interval
    );
    error Raffle__WrongRequestId(uint256 requestId);
    error Raffle__OnlyCoordinatorCanCallFulfillRandomWords(address sender);

    enum RaffleState {
        OPEN, // 0
        CLOSED, // 1
        CALCULATING // 2
    }

    uint256 private immutable i_interval;
    uint256 private s_lastTimestamp;
    uint256 private s_ticketPrice;
    uint256 private s_requestId;
    uint256[] private s_randomWords;
    address payable[] private s_participants;
    address payable private s_lastWinner;
    VRF private vrf;
    RaffleState private s_raffleState;

    //// Events ////
    event TicketBought(address indexed user, uint256 indexed ticketn);
    event RandomNumberGenerated(uint256 indexed requestId);
    event WinnerPicked(address payable indexed winner);

    constructor(
        uint256 _ticketPrice,
        uint256 _interval,
        VRF memory _vrf
    ) VRFConsumerBaseV2(_vrf.vrfCooridnatorAddress) Ownable(msg.sender) {
        s_ticketPrice = _ticketPrice;
        i_interval = _interval;
        s_lastTimestamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
        VRF memory updatedVrf = _createNewSubscription(_vrf);
        vrf = updatedVrf;
    }

    ///////////////////////////////
    ///// EXTERNAL FUNCTIONS //////
    ///////////////////////////////

    // Assumes this contract owns link.
    // 1000_000_000_000_000_000 = 1 LINK
    function topUpSubscription(uint256 amount) external onlyOwner {
        _topUpSubscription(amount);
    }

    function performUpkeep(bytes calldata /* performData */) external {
        (bool upKeepNeeded, ) = checkUpkeep("");
        if (!upKeepNeeded) {
            revert Raffle_UpkeepNotNeeded(
                address(this).balance,
                s_raffleState,
                s_participants.length,
                block.timestamp,
                s_lastTimestamp,
                i_interval
            );
        }
        s_lastTimestamp = block.timestamp;
        _getRandomNumber();
    }

    ///////////////////////////////
    ///// PUBLIC FUNCTIONS ////////
    ///////////////////////////////
    /**
     * @dev this is for chainlink automation to know when pick winner need to be called
     * @dev this will be called by chainlink DON every block!
     * @dev conditions:
     *   1. the interval passed by
     *   2. Raffle is in open state
     *   3. contract has some ETH balance
     *   4. Subscription is funded with LINK (implicit?)
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timePassed = (block.timestamp - s_lastTimestamp) > i_interval;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_participants.length > 0;
        upkeepNeeded = (timePassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0");
    }

    // TODO: check user is not already in raffle
    function buyTicket() public payable {
        if (msg.value < s_ticketPrice) revert Raffle__InsufficentETHSent(); // using revert is more gas eficient
        if (s_raffleState != RaffleState.OPEN) revert Raffle_RaffleIsClosed(); // using revert is more gas eficient

        s_participants.push(payable(msg.sender));
        emit TicketBought(msg.sender, s_participants.length - 1);
    }

    ///////////////////////////////
    ///// INTERNAL FUNCTIONS //////
    ///////////////////////////////
    function _topUpSubscription(uint256 amount) internal onlyOwner {
        LinkTokenInterface linkToken = LinkTokenInterface(vrf.linkTokenAddress);

        linkToken.transferAndCall(
            address(vrf.vrfCooridnatorAddress),
            amount,
            abi.encode(vrf.subId)
        );
    }

    function _getRandomNumber() internal {
        s_raffleState = RaffleState.CALCULATING;
        VRFCoordinatorV2 coordinator = VRFCoordinatorV2(
            vrf.vrfCooridnatorAddress
        );
        s_requestId = coordinator.requestRandomWords(
            vrf.keyHash,
            vrf.subId,
            vrf.requestConfirmations,
            vrf.callbackGasLimit,
            vrf.numWords
        );

        emit RandomNumberGenerated(s_requestId);
    }

    // checkx effect interactions
    // can be called by Coordinator
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        if (requestId != s_requestId) revert Raffle__WrongRequestId(requestId);
        if (msg.sender != vrf.vrfCooridnatorAddress)
            revert Raffle__OnlyCoordinatorCanCallFulfillRandomWords(msg.sender);

        s_randomWords = randomWords;
        address payable[] memory participants = s_participants;
        uint256 indexOfWinner = randomWords[0] % participants.length;

        address payable winner = participants[indexOfWinner];
        s_raffleState = RaffleState.OPEN;
        s_participants = new address payable[](0);
        s_lastTimestamp = block.timestamp;
        s_lastWinner = winner;
        emit WinnerPicked(winner);

        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__PaymentError();
        }
    }

    ///////////////////////////////
    ///// PRIVATE FUNCTIONS //////
    ///////////////////////////////

    // Create a new subscription when the contract is initially deployed.
    function _createNewSubscription(
        VRF memory _vrf
    ) private returns (VRF memory) {
        VRFCoordinatorV2 vRFCoordinatorV2 = VRFCoordinatorV2(
            _vrf.vrfCooridnatorAddress
        );
        _vrf.subId = vRFCoordinatorV2.createSubscription();
        // Add this contract as a consumer of its own subscription.
        vRFCoordinatorV2.addConsumer(_vrf.subId, address(this));
        return _vrf;
    }

    ///////////////////////////////
    ///// VIEW FUNCTIONS //////////
    ///////////////////////////////
    function getTicketPrice() external view returns (uint256) {
        return s_ticketPrice;
    }

    function getUserTicket(address user) external view returns (uint256) {
        address payable[] memory participants = s_participants;
        uint256 ticketN;
        for (uint256 i; i < participants.length; i++) {
            if (user == participants[i]) {
                ticketN = i;
            }
        }
        return ticketN;
    }
    function getNumbersOfParticipants() external view returns (uint256) {
        return s_participants.length;
    }
    function getRequestId() external view returns (uint256) {
        return s_requestId;
    }
    function getSubId() external view returns (uint64) {
        return vrf.subId;
    }
    function getLinkTokenAddress() external view returns (address) {
        return vrf.linkTokenAddress;
    }
    function getCoordinator() external view returns (address) {
        return vrf.vrfCooridnatorAddress;
    }
    function getRandomWords() external view returns (uint256[] memory) {
        return s_randomWords;
    }
    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }
    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimestamp;
    }
    function getInterval() external view returns (uint256) {
        return i_interval;
    }
    function getLastWinner() external view returns (address payable) {
        return s_lastWinner;
    }
}
