// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

struct CollectVestingRoundData {
    uint256[] tokenIds;
    IERC20[] tokens;
    uint256 round;
}
