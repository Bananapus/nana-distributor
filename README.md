# Bananapus Distributor

## Summary

`JBDistributor.sol` is a token distribution system that manages the claiming and vesting of tokens for stakers of any other token.

- The contract is initialized with a starting block, a round duration, and a number of vesting rounds.
  - The starting block is the block at which the contract begins operation.
  - The round duration is the minimum amount of time (in blocks) stakers have to claim rewards.
  - The vesting rounds is the number of rounds until tokens are fully vested.
- The contract allows users to begin vesting tokens. This is done through the `beginVesting` function, which takes an array of token IDs and an array of ERC-20 tokens the user wants to claim. The function calculates the amount of tokens to be vested based on the total stake amount and the stake of the token ID. It then adds this vesting data to the `vestingDataOf` mapping and emits a `Claimed` event.
- The contract allows users to claim vested rewards through the `collectVestedRewards` function. This function calculates the amount of tokens that can be claimed based on the vesting data and the current round. It then transfers the claimed tokens to the beneficiary and updates the total vesting amount.

_If you're having trouble understanding this contract, take a look at the [core protocol contracts](https://github.com/Bananapus/nana-core) and the [documentation](https://docs.juicebox.money/) first. If you have questions, reach out on [Discord](https://discord.com/invite/ErQYmth4dS)._

## Install

For `npm` projects (recommended):

```bash
npm install @bananapus/distributor
```

For `forge` projects (not recommended):

```bash
forge install Bananapus/nana-distributor
```

Add `@bananapus/distributor/=lib/nana-distributor/` to `remappings.txt`. You'll also need to install `nana-distributor`'s dependencies and add similar remappings for them.

## Develop

`nana-distributor` uses [npm](https://www.npmjs.com/) for package management and the [Foundry](https://github.com/foundry-rs/foundry) development toolchain for builds, tests, and deployments. To get set up, [install Node.js](https://nodejs.org/en/download) and install [Foundry](https://github.com/foundry-rs/foundry):

```bash
curl -L https://foundry.paradigm.xyz | sh
```

You can download and install dependencies with:

```bash
npm install && forge install
```

If you run into trouble with `forge install`, try using `git submodule update --init --recursive` to ensure that nested submodules have been properly initialized.

Some useful commands:

| Command               | Description                                         |
| --------------------- | --------------------------------------------------- |
| `forge build`         | Compile the contracts and write artifacts to `out`. |
| `forge fmt`           | Lint.                                               |
| `forge test`          | Run the tests.                                      |
| `forge build --sizes` | Get contract sizes.                                 |
| `forge coverage`      | Generate a test coverage report.                    |
| `foundryup`           | Update foundry. Run this periodically.              |
| `forge clean`         | Remove the build artifacts and cache directories.   |

To learn more, visit the [Foundry Book](https://book.getfoundry.sh/) docs.

## Scripts

For convenience, several utility commands are available in `package.json`.

| Command                           | Description                            |
| --------------------------------- | -------------------------------------- |
| `npm test`                        | Run local tests.                       |
| `npm run coverage`                | Generate an LCOV test coverage report. |
| `npm run deploy:ethereum-mainnet` | Deploy to Ethereum mainnet             |
| `npm run deploy:ethereum-sepolia` | Deploy to Ethereum Sepolia testnet     |
| `npm run deploy:optimism-mainnet` | Deploy to Optimism mainnet             |
| `npm run deploy:optimism-testnet` | Deploy to Optimism testnet             |
