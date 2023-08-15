// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TokenState } from "../struct/TokenState.sol";
/**
 * @title   JBDistributor
 * @notice 
 * @dev 
 */
interface IJBDistributor {
    /**
     * @return _duration the duration of a round in blocks
     */
    function roundDuration() external view returns(uint256 _duration);

    /**
     * @return _rounds the number of rounds until rewards are vested
     */
    function vestingRounds() external view returns(uint256 _rounds);

    /**
     * @notice 
     * @param _token the token to check for
     * @return _amount the amount of the token balance that is currenly vesting
     */
    function tokenVestingAmount(IERC20 _token) external view returns(uint256 _amount);

    /***
     * 
     */
    function tokenAtRound(IERC20 _token, uint256 _round) external view returns (uint256 _balance, uint256 _vestingAmount);


    /**
     * 
     * @param _721TokenID the id of the 721 to check for
     * @param _round the vesting unlock round 
     * @param _token the ERC20 token that is vesting
     */
    function tokenVesting(uint256 _721TokenID, uint256 _round, IERC20 _token) external view returns (uint256 _tokenVestingAmount);


    /**
     * @param _tokenIds the ids to claim rewards for
     * @param _tokens the tokens to claim
     */
    function beginVesting(uint256[] calldata _tokenIds, IERC20[] calldata _tokens) external;


     /**
     * Collect vested tokens
     * @param _tokenIds the nft ids to claim for
     * @param _tokens the tokens to claim
     * @param _round the round in which the tokens were done vesting
     */
    function collectVestedRewards(
        uint256[] calldata _tokenIds,
        IERC20[] calldata _tokens,
        uint256 _round
    ) external;
}
