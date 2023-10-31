// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @custom:member releaseRound The round at which the amount fully vests.
/// @custom:member amount The original amount of tokens that were claimed.
/// @custom:member shareClaimed The share of the amount that has already been claimed. (out of `MAX_SHARE`)
struct VestingData {
    uint256 vestRound;
    uint256 amount;
    uint256 shareClaimed;
}