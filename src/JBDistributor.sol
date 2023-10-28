// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IJBDistributor} from "./interfaces/IJBDistributor.sol";
import {TokenSnapshotData} from "./struct/TokenSnapshotData.sol";
import {CollectVestingRoundData} from "./struct/CollectVestingRoundData.sol";
import {mulDiv} from "@prb/math/Common.sol";

 /// @notice A contract managing distributions of tokens to be claimed and vested by stakers of any other token.
abstract contract JBDistributor is IJBDistributor {
    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    error AlreadyVesting();
    error VestingCancelled();
    error NotVestedYet();
    error NoAccess();

    //*********************************************************************//
    // ---------------- public immutable stored properties --------------- //
    //*********************************************************************//

    /// @notice The starting block of the distributor.
    uint256 public immutable startingBlock;

    /// @notice The minimum amount of time stakers have to claim rewards, specified in blocks.
    uint256 public immutable roundDuration;

    /// @notice The number of rounds until tokens are fully vested.
    uint256 public immutable vestingRounds;

    //*********************************************************************//
    // --------------------- public constant properties  ----------------- //
    //*********************************************************************//

    uint256 public constant MAX_SHARE = 100_000;
    
    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /// @notice The amount of a token that is currently vesting.
    /// @custom:param token The address of the token that is vesting.
    mapping(IERC20 token => uint256 amount) public totalVestingAmountOf;

    /// @custom:param tokenId The ID of the token to which the vesting amount belongs. 
    /// @custom:param round The round during which the vesting began. 
    /// @custom:param token The address of the token being vested. 
    mapping(uint256 tokenId=> mapping(uint256 round => mapping(IERC20 token => uint256 amount))) public vestingTokenAmountAtRoundOf;

    //*********************************************************************//
    // ------------------------ internal properties ---------------------- //
    //*********************************************************************//

    /// @notice The snapshot data of the token information for each round.
    /// @custom:param token The address of the token being claimed and vested.
    /// @custom:param round The round to which the data applies.
    mapping(IERC20 token => mapping(uint256 round => TokenSnapshotData snapshot)) internal _snapshotAtRoundOf;

    //*********************************************************************//
    // -------------------------- public views --------------------------- //
    //*********************************************************************//
      
    /// @notice The number of the current round.
    function currentRound() public view returns (uint256) {
        return (block.number - startingBlock) / roundDuration;
    }
    
    /// @notice The block at which a round started.
    /// @param _round The round to get the start block of.
    function roundStartBlock(uint256 _round) public view returns (uint256) {
        return startingBlock + roundDuration * _round;
    }

    /// @notice The snapshot data of the token information for each round.
    /// @custom:param token The address of the token being claimed and vested.
    /// @custom:param round The round to which the data applies.
    function snapshotAtRoundOf(IERC20 token, uint256 round) external view returns(TokenSnapshotData memory) {
        return _snapshotAtRoundOf[token][round];
    }

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param _roundDuration The minimum amount of time stakers have to claim rewards, specified in blocks. (IMPORTANT: make sure this is correct for each blockchain/rollup this gets deployed to)
    /// @param _vestingRounds The number of rounds until tokens are fully vested.
    constructor(uint256 _roundDuration, uint256 _vestingRounds) {
        startingBlock = block.number;
        roundDuration = _roundDuration;
        vestingRounds = _vestingRounds;
    }
   
    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************// 

    /// @notice Claims tokens and beings vesting.
    /// @param _tokenIds the ids to claim rewards for
    /// @param _tokens the tokens to claim
    function beginVesting(uint256[] calldata _tokenIds, IERC20[] calldata _tokens) external {

        // Keep a reference to the current round.
        uint256 _currentRound = currentRound();

        // Keep a reference to the total staked amount at the curren round.
        uint256 _totalStakeAmount = _totalStake(roundStartBlock(_currentRound));

        // Calculate the round at which the current rewards will be release.
        uint256 _vestingReleaseRound = _currentRound + vestingRounds;

        // Keep a reference to the number of tokens that vesting is starting for.
        uint256 _numberOfTokens = _tokens.length;

        // Keep a reference to the token being iterated on.
        IERC20 _token;

        // Loop through each token of which vested is begining.
        for (uint256 _i; _i < _numberOfTokens;) {
            // Set the token.
            _token = _tokens[_i];

            // Scoped to prevent stack too deep
            uint256 _distributable;
            {
                // Take a snapshot of the token balance if it hasn't been taken already.
                TokenSnapshotData memory _snapshot = _takeSnapshotOf(_token);
                _distributable = _snapshot.balance - _snapshot.vestingAmount;
            }

            // Keep a reference to the total amount vested.
            uint256 _totalVestingAmount;

            // Keep a reference to the number of token IDs.
            uint256 _numberOfTokenIds = _tokenIds.length;

            // Keep a reference to the ID of the token being iterated on.
            uint256 _tokenId;

            /// Loop through each token ID for which vesting is begining. 
            for (uint256 _j; _j < _numberOfTokenIds;) {
                // Set the token ID.
                _tokenId = _tokenIds[_j];

                // Make sure this token hasn't already been claimed.
                if (vestingTokenAmountAtRoundOf[_tokenId][_vestingReleaseRound][_token] != 0) revert AlreadyVesting();

                // Keep a reference to the amount of tokens being claimed.
                uint256 _tokenAmount = mulDiv(_distributable, _tokenStake(_tokenId), _totalStakeAmount);

                // Claim the share for this token
                vestingTokenAmountAtRoundOf[_tokenId][_vestingReleaseRound][_token] = _tokenAmount;

                emit Claimed(_tokenId, _token, _tokenAmount, _vestingReleaseRound);

                unchecked {
                    // Increment the amount of tokens that have been claimed and are now vesting.
                    _totalVestingAmount += _tokenAmount;

                    ++_j;
                }
            }

            unchecked {
                // Store the updated total claimed amount now vesting.
                totalVestingAmountOf[_token] += _totalVestingAmount;

                ++_i;
            }
        }
    }

    /// @notice Allows an address to collect vested tokens for various rounds.
    /// @param _rounds The rounds to collect for.
    function collectVestedRewards(CollectVestingRoundData[] calldata _rounds) external {
        // TODO: We can optimize this call by batching transfers
        // Collect for each specified round.
        for (uint256 _i = 0; _i < _rounds.length;) {
            collectVestedRewards(_rounds[_i].tokenIds, _rounds[_i].tokens, _rounds[_i].round, _rounds[_i].beneficiary);

            unchecked {
                ++_i;
            }
        }
    }

    /// @notice Release vested rewards in the case that a token was burned
    /// @param _tokenIds The IDs of the 721s to claim for.
    /// @param _tokens The address of the tokens being claimed.
    /// @param _round The round during which the tokens were done vesting.
    /// @param _beneficiary The recipient of the profit share
    function releaseForfeitedRewards(uint256[] calldata _tokenIds, IERC20[] calldata _tokens, uint256 _round, address _beneficiary) external {
        // Make sure that all tokens are burned
        for(uint256 _i; _i < _tokenIds.length;) {
            if(!_tokenBurned(_tokenIds[_i])) revert NoAccess();
            unchecked {
                ++_i;
            }
        }

        // Unlock the rewards and send them to the beneficiary
        _unlockRewards(
            _tokenIds,
            _tokens,
            _round,
            _beneficiary,
            false,
            500 // (0.5% share)
        );
    }
    
    //*********************************************************************//
    // ----------------------- public transactions ----------------------- //
    //*********************************************************************// 

    /// @notice Collect vested tokens.
    /// @param _tokenIds The IDs of the 721s to claim for.
    /// @param _tokens The address of the tokens being claimed.
    /// @param _round The round during which the tokens were done vesting.
    function collectVestedRewards(uint256[] calldata _tokenIds, IERC20[] calldata _tokens, uint256 _round, address _beneficiary) public {
        // Make sure that all tokens can be claimed by this sender
        for(uint256 _i; _i < _tokenIds.length;) {
            if(!_canClaim(_tokenIds[_i], msg.sender)) revert NoAccess();
            unchecked {
                ++_i;
            }
        }

        // Unlock the rewards and send them to the beneficiary
        _unlockRewards(
            _tokenIds,
            _tokens,
            _round,
            _beneficiary,
            true,
            MAX_SHARE
        );
    }

    //*********************************************************************//
    // ---------------------- internal transactions ---------------------- //
    //*********************************************************************// 

    function _unlockRewards(uint256[] calldata _tokenIds, IERC20[] calldata _tokens, uint256 _round, address _beneficiary, bool _ownerClaim, uint256 _share) internal {
        // Make sure the specified round has passed.
        if (_round > currentRound()) revert NotVestedYet();

        // Keep a reference to the number of tokens.
        uint256 _numberOfTokens = _tokens.length; 

        // Keep a reference to the token being iterated on.
        IERC20 _token;

        // Loop through each token of which vested rewards are being collected.
        for (uint256 _i; _i < _numberOfTokens;) {

            // Set the token.
            _token = _tokens[_i];

            // Keep a reference to the total amount of tokens there are.
            uint256 _totalTokenAmount;

            // Keep a reference to the number of token IDs.
            uint256 _numberOfTokenIds = _tokenIds.length; 

            // Keep a reference to the ID of the token being iterated on.
            uint256 _tokenId;

            /// Loop through each token ID for which vested rewards are being collected.
            for (uint256 _j; _j < _numberOfTokenIds;) {
                // Set the token ID.
                _tokenId = _tokenIds[_j];

                // Add to the total amount of this token being vested.
                unchecked {
                    uint256 _roundVestingAmount = vestingTokenAmountAtRoundOf[_tokenId][_round][_token];
                    _totalTokenAmount += _roundVestingAmount;

                    emit Collected(
                        _tokenId,
                        _token,
                        _roundVestingAmount,
                        _round
                    );

                    // Delete this vesting amount.
                    delete vestingTokenAmountAtRoundOf[_tokenId][_round][_token];

                    ++_j;
                }
            }

            // Perform the transfer.
            if (_totalTokenAmount != 0) {
                unchecked {
                    // Update the amount that is left vesting.
                    totalVestingAmountOf[_token] -= _totalTokenAmount;
                }

                // If this claim is from the owner (or on behave of the owner)
                if (_ownerClaim) {
                    // Send the tokens to the beneficiary.
                    _token.transfer(_beneficiary, _totalTokenAmount);

                } else if (_share != 0) {
                    // If this was an unlock for a burned token and a profit share is enabled
                    // Send part of the share to the sender 
                    _token.transfer(_beneficiary, _totalTokenAmount * _share / MAX_SHARE);
                }
                
            }

            unchecked {
                ++_i;
            }
        }
    }

    /// @notice The distribution state for the provided address.
    /// @param _token The token address to take a snapshot of.
    /// @return snapshot The snapshot data.
    function _takeSnapshotOf(IERC20 _token) internal returns (TokenSnapshotData memory snapshot) {
        // Keep a reference to the current round.
        uint256 _currentRound = currentRound();

        /// Keep a reference to the token's snapshot. 
        snapshot = _snapshotAtRoundOf[_token][_currentRound];

        // If a snapshot was already taken at this cycle, do not take a new one.
        if (snapshot.balance != 0) return snapshot;

        // Take a snapshot.
        snapshot = TokenSnapshotData({balance: _token.balanceOf(address(this)), vestingAmount: totalVestingAmountOf[_token]});

        // Store the snapshot.
        _snapshotAtRoundOf[_token][_currentRound] = snapshot;

        emit SnapshotCreated(
            _currentRound,
            _token,
            snapshot.balance,
            snapshot.vestingAmount
        );
    }

    //*********************************************************************//
    // ----------------------- virtual transactions ---------------------- //
    //*********************************************************************// 

    /// @notice A flag indicating if an account can currency claim their tokens.
    /// @param _tokenId The ID of the token to check.
    /// @param _account the account to check if it can claim.
    /// @return canClaim A flag indicating if claiming is allowed.
    function _canClaim(uint256 _tokenId, address _account) internal view virtual returns (bool canClaim);

    /// @notice The total amount staked at the given block.
    /// @param _blockNumber The block number to get the total staked amount at
    /// @return totalStakedAmount The total amount staked at a block number.
    function _totalStake(uint256 _blockNumber) internal view virtual returns (uint256 totalStakedAmount);

    /// @notice The amount of token's staked for the given 721 token ID.
    /// @param _tokenId The ID of the token to get the staked value of.
    /// @return tokenStakeAmount The amount of staked tokens that is being represented by the 721.
    function _tokenStake(uint256 _tokenId) internal view virtual returns (uint256 tokenStakeAmount);

    /// @notice Checks if the given token was burned or not
    /// @param _tokenId the tokenId to check
    /// @return tokenWasBurned true A boolean that is true if the token was burned
    function _tokenBurned(uint256 _tokenId) internal view virtual returns (bool tokenWasBurned);
}
