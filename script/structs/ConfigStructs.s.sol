// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

struct DeployConfig {
    uint256 inrterval;
    uint256 ticketPrice;
    string privateKeySelector;
}
struct VRF {
    address vrfCooridnatorAddress;
    address linkTokenAddress;
    uint256 startingLinkAMount;
    bytes32 keyHash;
    uint64 subId;
    uint16 requestConfirmations;
    uint32 callbackGasLimit;
    uint32 numWords;
}
struct NetworkConfig {
    VRF vrfConfig;
    DeployConfig deployConfig;
}
