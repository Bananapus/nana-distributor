// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IJBSplitAllocator, IERC165 } from "@juicebox/interfaces/IJBSplitAllocator.sol";
import { JBTokens } from "@juicebox/libraries/JBTokens.sol";
import { JBSplitAllocationData } from "@juicebox/structs/JBSplitAllocationData.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { JBGovernanceNFT } from 'lib/juice-governance-nft/src/JBGovernanceNFT.sol';
import "./interfaces/IJBDistributor.sol";

struct TokenState {
    uint256 balance;
    uint256 vestingAmount;
}

/**
 * @title   JBDistributor
 * @notice 
 * @dev 
 */
abstract contract JBDistributor {
    event claimed(uint256 indexed tokenId, IERC20 token, uint256 amount, uint256 vestingReleaseTimestamp);
    error AlreadyClaimed();

    // The starting time of the distributor
    uint256 immutable public startingTime;

    // The minimum delay between two snapshots
    uint256 immutable public periodicity;

    // The minimum delay between two snapshots
    uint256 immutable public vestingCycles;

    // The amount of a token that is currently vesting
    mapping(IERC20 => uint256) tokenVestingAmount;

    // The snapshot data of the token information for each cycle
    // IERC20 -> cycle -> token information
    mapping(IERC20 => mapping(uint256 => TokenState)) tokenAtCycle;

    // Maps tokenId -> cycle -> IERC20 token -> release amount
    mapping(uint256 => mapping(uint256 => mapping(IERC20 => uint256))) tokenVesting;

    /**
     * 
     * @param _periodicity The duration of a period/cycle
     * @param _vestingCycles The number of cycles it takes for rewards to vest
     */
    constructor(uint256 _periodicity, uint256 _vestingCycles) {
        startingTime = block.timestamp;
        periodicity = _periodicity;
        vestingCycles = _vestingCycles;
    }

    /**
     * @param _tokenIds the ids to claim rewards for
     * @param _tokens the tokens to claim
     */
    function claim(uint256[] calldata _tokenIds, IERC20[] calldata _tokens) external {
        uint256 _currentCycle = currentCycle();
        uint256 _totalStakeAmount = _totalStake(cycleStartTime(_currentCycle));

        // Calculate the cycle in which the current rewards will release
        uint256 _vestingReleaseCycle = _currentCycle + vestingCycles;

        for(uint256 _i; _i < _tokens.length;) {
            IERC20 _token = _tokens[_i];

            // Check if a snapshot has been done of the token balance yet
            // no: take snapshot
            TokenState memory _state = _snapshotToken(_token);
            uint256 _distributable = _state.balance - _state.vestingAmount;

            uint256 _totalVestingAmount;
            for(uint256 _j; _j < _tokenIds.length;) {
                // TODO: Make sure sender owns the token
                // TODO: Cache '_tokenStake' call
                // Get the staked amount for the token
                uint256 _tokenStakeAmount = _tokenStake(_tokenIds[_j]);
                uint256 _tokenAmount = _distributable * _tokenStakeAmount / _totalStakeAmount;

                // Check if this token was already claimed (check might not be needed)
                if(tokenVesting[_tokenIds[_j]][_vestingReleaseCycle][_token] != 0)
                    revert AlreadyClaimed();

                // Claim the share for this token
                tokenVesting[_tokenIds[_j]][_vestingReleaseCycle][_token] = _tokenAmount;

                emit claimed(_tokenIds[_j], _token, _tokenAmount, _vestingReleaseCycle);

                unchecked{
                    // Increment the amount of tokens that have been claimed
                    _totalVestingAmount += _tokenAmount;

                    ++_j;
                }
            }

            unchecked {
                // Update the global claimable amount to reflect this claim
                tokenVestingAmount[_token] += _totalVestingAmount;

                ++_i;
            }
        }
    }

    function _snapshotToken(IERC20 _token) internal returns (TokenState memory){
        uint256 _currentCycle = currentCycle();
        TokenState memory _state = tokenAtCycle[_token][_currentCycle];

        // If a snapshot was already taken at this cycle we do not take a new one
        if(_state.balance != 0) return _state;

        _state = TokenState({
            balance: _token.balanceOf(address(this)),
            vestingAmount: tokenVestingAmount[_token]
        }); 

        tokenAtCycle[_token][_currentCycle] = _state;

        return _state;
    }

    function _totalStake(uint256 _timestamp) internal view virtual returns (uint256 _stakedAmount);

    function _tokenStake(uint256 _tokenId) internal view virtual returns (uint256 _tokenStakeAmount);

    function currentCycle() public view returns (uint256) {
        return block.timestamp - startingTime / periodicity;
    }

    function cycleStartTime(uint256 _cycle) public view returns (uint256) {
        return startingTime + periodicity * _cycle;
    }
}