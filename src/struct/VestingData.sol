// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @custom:member The original amount of tokens that were claimed.
/// @custom:member The share of the amount that has already been claimed. (out of `MAX_SHARE`)
struct VestingData {
    uint256 amount;
    uint256 shareClaimed;
}