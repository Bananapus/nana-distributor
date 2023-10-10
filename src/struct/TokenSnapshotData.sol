// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @custom:member The token balance at the time of the snapshot.
/// @custom:member The amount of tokens vesting at the time of the snapshot.
struct TokenSnapshotData {
    uint256 balance;
    uint256 vestingAmount;
}
