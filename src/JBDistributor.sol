// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IJBDistributor, TokenState, CollectVestingRoundData } from "./interfaces/IJBDistributor.sol";

/**
 * @title   JBDistributor
 * @notice 
 * @dev 
 */
abstract contract JBDistributor is IJBDistributor {
    event claimed(uint256 indexed tokenId, IERC20 token, uint256 amount, uint256 vestingReleaseRound);
    
    error AlreadyVesting();
    error VestingCancelled();
    error NotVestedYet();
    error NoAccess();

    // The starting block of the distributor
    uint256 immutable public startingBlock;

    // The minimum delay between two snapshots in blocks
    uint256 immutable public roundDuration;

    // The number of rounds until tokens are vested
    uint256 immutable public vestingRounds;

    // The amount of a token that is currently vesting
    mapping(IERC20 => uint256) public tokenVestingAmount;

    // The snapshot data of the token information for each round
    // IERC20 -> cycle -> token information
    mapping(IERC20 => mapping(uint256 => TokenState)) public tokenAtRound;

    // Maps tokenId -> cycle -> IERC20 token -> release amount
    mapping(uint256 => mapping(uint256 => mapping(IERC20 => uint256))) public tokenVesting;

    /**
     * 
     * @param _roundDuration The duration of a period/cycle in blocks (IMPORTANT: make sure this is correct for each blockchain/rollup this gets deployed to)
     * @param _vestingRounds The number of cycles it takes for rewards to vest
     */
    constructor(uint256 _roundDuration, uint256 _vestingRounds) {
        startingBlock = block.number;
        roundDuration = _roundDuration;
        vestingRounds = _vestingRounds;
    }

    /**
     * @param _tokenIds the ids to claim rewards for
     * @param _tokens the tokens to claim
     */
    function beginVesting(uint256[] calldata _tokenIds, IERC20[] calldata _tokens) external {
        uint256 _currentRound = currentRound();
        uint256 _totalStakeAmount = _totalStake(roundStartBlock(_currentRound));

        // Calculate the round in which the current rewards will release
        uint256 _vestingReleaseRound= _currentRound + vestingRounds;

        for(uint256 _i; _i < _tokens.length;) {
            IERC20 _token = _tokens[_i];

            // Scoped to prevent stack too deep
            uint256 _distributable;
            {
                // Check if a snapshot has been done of the token balance yet
                // no: take snapshot
                TokenState memory _state = _snapshotToken(_token);
                _distributable = _state.balance - _state.vestingAmount;
            }
            
            uint256 _totalVestingAmount;
            for(uint256 _j; _j < _tokenIds.length;) {
                // TODO: Make sure sender owns the token
                // TODO: Do we even need to check for ownership? The owner can always choose to not collect
                // TODO: Cache '_tokenStake' call
                // Get the staked amount for the token
                uint256 _tokenAmount = _distributable * _tokenStake(_tokenIds[_j]) / _totalStakeAmount;

                // Check if this token was already claimed (check might not be needed)
                if(tokenVesting[_tokenIds[_j]][_vestingReleaseRound][_token] != 0)
                    revert AlreadyVesting();

                // Claim the share for this token
                tokenVesting[_tokenIds[_j]][_vestingReleaseRound][_token] = _tokenAmount;

                emit claimed(_tokenIds[_j], _token, _tokenAmount, _vestingReleaseRound);

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
    ) public {
        // Make sure the vesting is done
        if(_round > currentRound())
            revert NotVestedYet();

        for(uint256 _i; _i < _tokens.length;){
            uint256 _totalTokenAmount;

            for(uint256 _j; _j < _tokenIds.length;){
                // TODO: make sure the sender owns the tokenId, this also makes sure it is not burned
                if (_i == 0 && !_canClaim(_tokenIds[_j], msg.sender)) revert NoAccess();

                // Add to the total amount of this token
                unchecked {
                    _totalTokenAmount += tokenVesting[_tokenIds[_j]][_round][_tokens[_i]];

                    // Delete this claim from the vesting
                    delete tokenVesting[_tokenIds[_j]][_round][_tokens[_i]];
             
                    ++_j;
                }
            }

            // Peform the transfer
            if(_totalTokenAmount != 0){
                unchecked {
                    // Update the amount that is left vesting
                    tokenVestingAmount[_tokens[_i]] -= _totalTokenAmount;
                }
                // Send the tokens
                _tokens[_i].transfer(msg.sender, _totalTokenAmount);
            }

            unchecked {
                ++_i;
            }
        }
    }



    function collectVestedRewards(
        CollectVestingRoundData[] calldata _rounds
    ) external {
        // TODO: We can optimize this call by batching transfers
        for (uint _i = 0; _i < _rounds.length;) {
            collectVestedRewards(_rounds[_i].tokenIds, _rounds[_i].tokens, _rounds[_i].round);

            unchecked {
                ++_i;
            }
        }
    }


    function _snapshotToken(IERC20 _token) internal returns (TokenState memory){
        uint256 _currentRound = currentRound();
        TokenState memory _state = tokenAtRound[_token][_currentRound];

        // If a snapshot was already taken at this cycle we do not take a new one
        if(_state.balance != 0) return _state;

        _state = TokenState({
            balance: _token.balanceOf(address(this)),
            vestingAmount: tokenVestingAmount[_token]
        }); 

        tokenAtRound[_token][_currentRound] = _state;

        return _state;
    }

    /**
        @notice
        @param _tokenID the token id to check for
        @param _user the user to check if it may claim
        @return _userMayClaimToken
    */
    function _canClaim(uint256 _tokenID, address _user) internal view virtual returns (bool _userMayClaimToken);

    /**
        @notice
        @param _blockNumber The block number to get the total staked amount at
        @return _stakedAmount The total amount staked at a block number, used to calculate the share of tokens at a timestamp
       
    */
    function _totalStake(uint256 _blockNumber) internal view virtual returns (uint256 _stakedAmount);

    /**
        @notice 
        @param _tokenId the token to get the backing amount for
        @return _tokenStakeAmount The amount that is backing the `_tokenId` 
    */
    function _tokenStake(uint256 _tokenId) internal view virtual returns (uint256 _tokenStakeAmount);

    function currentRound() public view returns (uint256) {
        return (block.number - startingBlock) / roundDuration;
    }

    function roundStartBlock(uint256 _round) public view returns (uint256) {
        return startingBlock + roundDuration * _round;
    }
}
