// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CollectVestingRoundData} from "../struct/CollectVestingRoundData.sol";
import {TokenSnapshotData} from "../struct/TokenSnapshotData.sol";

interface IJBDistributor {
    event Claimed(uint256 indexed tokenId, IERC20 token, uint256 amount, uint256 vestingReleaseRound);

    function roundDuration() external view returns (uint256 duration);

    function vestingAmountOf(IERC20 token) external view returns (uint256 rounds);

    function snapshotAtRoundOf(IERC20 token, uint256 round) external view returns (uint256 amount);

    function vestingTokenAmountAtRoundOf(uint256 tokenId, uint256 round, IERC20 token)
        external
        view
        returns (uint256 vestingTokenAmount);

    function beginVesting(uint256[] calldata tokenIds, IERC20[] calldata tokens) external;

    function collectVestedRewards(uint256[] calldata tokenIds, IERC20[] calldata tokens, uint256 round, address beneficiary) external;

    function collectVestedRewards(CollectVestingRoundData[] calldata rounds) external;
}
