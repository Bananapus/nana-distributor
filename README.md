# Bananapus Distributor

## Summary

`JBDistributor.sol` is a token distribution system that manages the claiming and vesting of tokens for stakers of any other token.

- The contract is initialized with a starting block, a round duration, and a number of vesting rounds.
  - The starting block is the block at which the contract begins operation.
  - The round duration is the minimum amount of time (in blocks) stakers have to claim rewards.
  - The vesting rounds is the number of rounds until tokens are fully vested.
- The contract allows users to begin vesting tokens. This is done through the `beginVesting` function, which takes an array of token IDs and an array of ERC-20 tokens the user wants to claim. The function calculates the amount of tokens to be vested based on the total stake amount and the stake of the token ID. It then adds this vesting data to the `vestingDataOf` mapping and emits a `Claimed` event.
- The contract allows users to claim vested rewards through the `collectVestedRewards` function. This function calculates the amount of tokens that can be claimed based on the vesting data and the current round. It then transfers the claimed tokens to the beneficiary and updates the total vesting amount.

<!-- ## Use-case
## Risks & trade-off
## Design
### Flow
### Contracts/interface -->

## Usage

You must have [Foundry](https://book.getfoundry.sh/) and [NodeJS](https://nodejs.dev/en/learn/how-to-install-nodejs/) to use this repo.

Install with `forge install && npm install`

If you run into trouble with nested dependencies, try running `git submodule update --init --force --recursive`.

```shell
$ forge build # Build
$ forge test # Run tests
$ forge fmt # Format
$ forge snapshot # Gas Snapshots
$ forge script Deploy # Deploy. Provide chain and key in arguments.
```

For help, see https://book.getfoundry.sh/ or run:

```shell
$ forge --help
$ anvil --help
$ cast --help
```