// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IJBDistributor} from "./interfaces/IJBDistributor.sol";
import {TokenSnapshotData} from "./struct/TokenSnapshotData.sol";
import {CollectVestingRoundData} from "./struct/CollectVestingRoundData.sol";
import {VestingData} from "./struct/VestingData.sol";
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

    /// @notice The number of shares that represent 100%.
    uint256 public constant MAX_SHARE = 100_000;

    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /// @notice The amount of a token that is currently vesting.
    /// @custom:param _token The address of the token that is vesting.
    mapping(IERC20 _token => uint256 _amount) public totalVestingAmountOf;

    /// @notice All vesting data of a tokenId for any number of vesting tokens. 
    /// @custom:param _tokenId The ID of the token to which the vests belongs. 
    /// @custom:param _token The address of the token being vested. 
    mapping(uint256 _tokenId => mapping(IERC20 _token => VestingData[])) public vestingDataOf;

    /// @notice The index within vestingDataOf of the latest vest.
    /// @custom:param _tokenId The ID of the token to which the vests belongs. 
    /// @custom:param _token The address of the token being vested. 
    mapping(uint256 _tokenId => mapping(IERC20 _token => uint256)) public latestVestedIndexOf;

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
    function snapshotAtRoundOf(IERC20 token, uint256 round) external view returns (TokenSnapshotData memory) {
        return _snapshotAtRoundOf[token][round];
    }

    /// @notice Calculate how much of the token is claimed for the given tokenId, but not yet vested.
    /// @param _tokenId The ID of the token to calculate the token amount for.
    /// @param _token The address of the token being claimed.
    /// @return tokenAmount The amount of tokens that can be claimed once they have vested.
    function amountVestingFor(uint256 _tokenId, IERC20 _token) external view returns (uint256 tokenAmount) {
        // Keep a refrence to the latest vested index.
        uint256 _vestedIndex = latestVestedIndexOf[_tokenId][_token];                

        // Keep a reference to the number of vesting rounds for the tokenId and token.
        uint256 _numberOfVestingRounds = vestingDataOf[_tokenId][_token].length;

        while (_vestedIndex < _numberOfVestingRounds) {
            // Keep a reference to the vested data being iterated on.
            VestingData memory _vesting = vestingDataOf[_tokenId][_token][_vestedIndex];

            tokenAmount += mulDiv(
                _vesting.amount,
                MAX_SHARE - _vesting.shareClaimed,
                MAX_SHARE
            );

            unchecked {
                ++_vestedIndex;
            }
        }
    }

    /// @notice Calculate how much of the token is currently ready to be vested for the given tokenId.
    /// @param _tokenId The ID of the token to calculate the token amount for.
    /// @param _token The address of the token being claimed.
    /// @return tokenAmount The amount of tokens that can be claimed right now.
    function amountVestedFor(uint256 _tokenId, IERC20 _token) external view returns (uint256 tokenAmount) {
        // The round that we are in right now.
        uint256 _currentRound = currentRound();

        // Keep a refrence to the latest vested index.
        uint256 _vestedIndex = latestVestedIndexOf[_tokenId][_token];                

        // Keep a reference to the number of vesting rounds for the tokenId and token.
        uint256 _numberOfVestingRounds = vestingDataOf[_tokenId][_token].length;

        while (_vestedIndex < _numberOfVestingRounds) {
            uint256 _lockedShare;

            // Keep a reference to the vested data being iterated on.
            VestingData memory _vestingData = vestingDataOf[_tokenId][_token][_vestedIndex];

            // Calculate the share amount that is locked.
            if (_vestingData.vestRound > _currentRound)
                _lockedShare = (_vestingData.vestRound - _currentRound) * MAX_SHARE / vestingRounds;
            
            // Add the amount that has neither already been claimed, or is still locked.
            tokenAmount += mulDiv(
                _vestingData.amount,
                MAX_SHARE - _vestingData.shareClaimed - _lockedShare,
                MAX_SHARE
            );

            unchecked {
                ++_vestedIndex;
            }
        }
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
    function claimRewardsOf(uint256[] calldata _tokenIds, IERC20[] calldata _tokens) external {
        // Keep a reference to the current round.
        uint256 _currentRound = currentRound();

        // Keep a reference to the total staked amount at the curren round.
        uint256 _totalStakeAmount = _totalStake(roundStartBlock(_currentRound));

        // Calculate the round at which the current rewards will be release.
        uint256 _vestRound = _currentRound + vestingRounds;

        // Keep a reference to the number of tokens that vesting is starting for.
        uint256 _numberOfTokens = _tokens.length;

        // Keep a reference to the token being iterated on.
        IERC20 _token;

        // Loop through each token of which vested is begining.
        for (uint256 _i; _i < _numberOfTokens;) {
            // Set the token.
            _token = _tokens[_i];

            // Keep a reference to the total balance of this token in this contract that is not yet vesting.
            uint256 _distributable;

            // Scoped to prevent stack too deep
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

                // Keep a reference to the number of vests existing for the given tokenId and token.
                uint256 _numVesting = vestingDataOf[_tokenId][_token].length;

                // Make sure this token hasn't already been claimed by checking if the last item is the current round.
                if (_numVesting != 0 && vestingDataOf[_tokenId][_token][_numVesting - 1].vestRound == _vestRound) revert AlreadyVesting();

                // Keep a reference to the amount of tokens being claimed.
                uint256 _tokenAmount = mulDiv(_distributable, _tokenStake(_tokenId), _totalStakeAmount);

                // Add to the list of vesting data.
                vestingDataOf[_tokenId][_token].push(VestingData({
                    vestRound: _vestRound,
                    amount: _tokenAmount,
                    shareClaimed: 0
                }));

                emit Claimed(_tokenId, _token, _tokenAmount, _vestRound);

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

    /// @notice Release vested rewards in the case that a token was burned
    /// @param _tokenIds The IDs of the 721s to claim for.
    /// @param _tokens The address of the tokens being claimed.
    function releaseForfeitedRewards(
        uint256[] calldata _tokenIds,
        IERC20[] calldata _tokens
    ) external {
        // Make sure that all tokens are burned
        for (uint256 _i; _i < _tokenIds.length;) {
            if (!_tokenBurned(_tokenIds[_i])) revert NoAccess();
            unchecked {
                ++_i;
            }
        }

        // Unlock the rewards and send them to the beneficiary
        _unlockRewards(_tokenIds, _tokens, address(0));
    }

    //*********************************************************************//
    // ----------------------- public transactions ----------------------- //
    //*********************************************************************//

    /// @notice Collect vested tokens.
    /// @param _tokenIds The IDs of the 721s to claim for.
    /// @param _tokens The address of the tokens being claimed.
    function vestRewardsOf(
        uint256[] calldata _tokenIds,
        IERC20[] calldata _tokens,
        address _beneficiary
    ) public {
        // Make sure that all tokens can be claimed by this sender
        for (uint256 _i; _i < _tokenIds.length;) {
            if (!_canClaim(_tokenIds[_i], msg.sender)) revert NoAccess();
            unchecked {
                ++_i;
            }
        }

        // Unlock the rewards and send them to the beneficiary
        _unlockRewards(_tokenIds, _tokens, _beneficiary);
    }

    //*********************************************************************//
    // ---------------------- internal transactions ---------------------- //
    //*********************************************************************//
    
    function _unlockRewards(
        uint256[] calldata _tokenIds,
        IERC20[] calldata _tokens,
        address _beneficiary
    ) internal {
        // Keep a reference to the current round.
        uint256 _currentRound = currentRound();

        // Keep a reference to the token being iterated on.
        IERC20 _token;

        // Loop through each token of which vested rewards are being collected.
        for (uint256 _i; _i < _tokens.length;) {
            // Set the token.
            _token = _tokens[_i];

            // Keep a reference to the total amount of tokens being claimed.
            uint256 _totalTokenAmountBeingClaimed;

            // Keep a reference to the ID of the token being iterated on.
            uint256 _tokenId;

            /// Loop through each token ID for which vested rewards are being collected.
            for (uint256 _j; _j < _tokenIds.length;) {
                // Set the token ID.
                _tokenId = _tokenIds[_j];

                 // Keep a refrence to the latest vested index.
                uint256 _vestedIndex = latestVestedIndexOf[_tokenId][_token];                

                // Keep a reference to the number of vesting rounds for the tokenId and token.
                uint256 _numberOfVestingRounds = vestingDataOf[_tokenId][_token].length;

                // Keep a reference to a vested index that will be incremented.
                uint256 _newLatestVestedIndex = _vestedIndex;

                while (_vestedIndex < _numberOfVestingRounds) {
                    // Keep a reference to the amount that'll remain locked.
                    uint256 _lockedShare;

                    // Keep a reference to the vested data being iterated on.
                    VestingData memory _vesting = vestingDataOf[_tokenId][_token][_newLatestVestedIndex];

                    // Calculate the share amount that will remain locked.
                    // If there's no beneficiary, treat the full amount as unlocked.
                    if (_beneficiary != address(0) && _vesting.vestRound > _currentRound)
                        _lockedShare = (_vesting.vestRound - _currentRound) * MAX_SHARE / vestingRounds;

                    // Calculate the amount being claimed.
                    uint256 _claimAmount = mulDiv(
                        _vesting.amount,
                        MAX_SHARE - _vesting.shareClaimed - _lockedShare,
                        MAX_SHARE
                    );

                    if (_claimAmount != 0) {
                        // Increment the total amount being claimed.
                        _totalTokenAmountBeingClaimed += _claimAmount;

                        emit Collected(_tokenId, _token, _claimAmount, _vesting.vestRound);
                    }

                    unchecked {
                        ++_vestedIndex;
                        
                        // If there's no longer a vesting amount for this entry, increment.
                        if (_lockedShare == 0) ++_newLatestVestedIndex;
                        // Update to reflect the share claimed if the full amount hasn't been vested.
                        else vestingDataOf[_tokenId][_token][_newLatestVestedIndex].shareClaimed = MAX_SHARE - _lockedShare;
                    }
                }

                // Set the new latest vested index.
                if (_newLatestVestedIndex != _vestedIndex) latestVestedIndexOf[_tokenId][_token] = _newLatestVestedIndex;

                unchecked {
                    ++_j;
                }
            }

            // Perform the transfer.
            if (_totalTokenAmountBeingClaimed != 0) {
                unchecked {
                    // Update the amount that is left vesting.
                    totalVestingAmountOf[_token] -= _totalTokenAmountBeingClaimed;
                }

                // If this claim is from the owner (or on behave of the owner)
                if (_beneficiary != address(0)) {
                    // Send the tokens to the beneficiary.
                    _token.transfer(_beneficiary, _totalTokenAmountBeingClaimed);
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

        emit SnapshotCreated(_currentRound, _token, snapshot.balance, snapshot.vestingAmount);
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
