## Raffle

Proveably random Lottery contract. Done following this amazing [course](https://updraft.cyfrin.io/courses/foundry/smart-contract-lottery/recap) from [Cyfrin](https://updraft.cyfrin.io/)!

## What does it do

This contract is a Raffle contract. people can buy tickets and participate to win the raffle.

## Tools

It uses Chainlink [VRF](https://docs.chain.link/vrf) and [Automation](https://automation.chain.link/).

## Patterns

I followed the following code layout:

```
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
```

Using [CEI pattern](https://fravoll.github.io/solidity-patterns/checks_effects_interactions.html) for writing functions!

Done some minimal Unit and integration tests.

## How To Run Locally

Install dependencies:

```
make install
```

Build project:

```
make build
```

Run test locally:

```
make run-test
```

Run test on Sepolia:

```
make test-sepolia
```

Deploy on Anvil:

```
# On another terminal run
anvil
# then run
make deploy-anvil
```

Deploy on Sepolia:

```
# then run
make deploy-sepolia
```

## Contract

Here is the deployed and verified contract:

[0xa612988B15f427b8FFAD62828C1A854Ad57a1d4b](https://sepolia.etherscan.io/address/0xa612988b15f427b8ffad62828c1a854ad57a1d4b)
