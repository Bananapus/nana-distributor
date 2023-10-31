// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CollectVestingRoundData} from "../struct/CollectVestingRoundData.sol";
import {TokenSnapshotData} from "../struct/TokenSnapshotData.sol";
import {VestingData} from "../struct/VestingData.sol";

interface IJBDistributor {
    event Claimed(uint256 indexed tokenId, IERC20 token, uint256 amount, uint256 vestingReleaseRound);
    event Collected(uint256 indexed tokenId, IERC20 token, uint256 amount, uint256 vestingReleaseRound);
    event SnapshotCreated(uint256 indexed round, IERC20 indexed token, uint256 balance, uint256 vestingAmount);

    function roundDuration() external view returns (uint256 duration);

    function vestingRounds() external view returns(uint256 _vestingRounds);

    function claimedFor(uint256 tokenId, IERC20 token) external view returns (uint256 _tokenAmount);

    function collectibleFor(uint256 tokenId, IERC20 token) external view returns (uint256 _tokenAmount);

    function totalVestingAmountOf(IERC20 token) external view returns (uint256 amount);

    function snapshotAtRoundOf(IERC20 token, uint256 round) external view returns (TokenSnapshotData memory snapshot);

    function beginVesting(uint256[] calldata tokenIds, IERC20[] calldata tokens) external;

    function collectVestedRewards(
        uint256[] calldata tokenIds,
        IERC20[] calldata tokens,
        address beneficiary
    ) external;
}
