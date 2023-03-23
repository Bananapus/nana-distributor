// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IJBSplitAllocator, IERC165 } from "@juicebox/interfaces/IJBSplitAllocator.sol";
import { JBTokens } from "@juicebox/libraries/JBTokens.sol";
import { JBSplitAllocationData } from "@juicebox/structs/JBSplitAllocationData.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { JBGovernanceNFT } from 'lib/juice-governance-nft/src/JBGovernanceNFT.sol';
import "./interfaces/IJBDistributor.sol";

/**
 * @title   JBDistributor
 * @notice 
 * @dev 
 */
contract JBDistributor is IJBSplitAllocator, IJBDistributor {
    event Claimed(address indexed caller, address[] tokens, uint256[] amounts);
    event SnapshotTaken(uint256 timestamp);

    error JBDistributor_emptyClaim();
    error JBDistributor_snapshotTooEarly();
    error JBDistributor_canNotDistributeStakedToken();
    error JBDistributor_unsupportedToken();

    // The minimum delay between two snapshots
    uint256 immutable public periodicity;

    // The staked token
    IERC20 immutable public stakedToken;

    // The project id of the staked token, controlling this contract
    uint256 immutable public projectId;

    // The governance NFT
    JBGovernanceNFT immutable public governanceNFT;

    // The timestamp of the last snapshot
    uint256 public lastSnapshotAt;

    // staked token per address
    mapping(address => uint256) public stakedBalanceOf;

    // claimed status per epoch _staker => lastSnapshotAt => claimed
    mapping(address => mapping(uint256 => bool)) public claimed;

    // Project token received
    IERC20[] public projectTokens;

    // last snapshot amounts
    mapping(IERC20=>uint256) public currentAmountClaimable;
    
    // -- view --

    // return what _staker can claim now
    function currentClaimable(uint256 _tokenId) external override view returns (IERC20[] memory token, uint256[] memory claimableAmount) {
        address _staker = governanceNFT.ownerOf(_tokenId);
        // Already claimed? Return 0
        if(claimed[_staker][lastSnapshotAt]) return (new IERC20[](0), new uint256[](0));

        uint256 _totalStaked = stakedToken.balanceOf(address(this));
        
        uint256 _numberOfTokens = projectTokens.length;

        // prevent multiple SLOADS in the loop
        token = projectTokens;

        for(uint256 i; i < _numberOfTokens;) {
            claimableAmount[i] = currentAmountClaimable[token[i]] * stakedBalanceOf[_staker] / _totalStaked;
            unchecked {
                ++ i;
            }
        }
    }

    // return the current claimable basket (ie total amounts of each token)
    function getBasket() external override view returns (IERC20[] memory token, uint256[] memory claimableAmount) {
        uint256 _numberOfTokens = projectTokens.length;

        // prevent multiple SLOADS in the loop
        token = projectTokens;

        for(uint256 i; i < _numberOfTokens;) {
            claimableAmount[i] = currentAmountClaimable[token[i]];
            unchecked {
                ++ i;
            }
        }
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IJBSplitAllocator).interfaceId
            || interfaceId == type(IERC165).interfaceId;
    }

    // -- external --

    constructor(IERC20 _stakedToken, uint256 _projectId, uint256 _periodicity) {
        stakedToken = _stakedToken;
        periodicity = _periodicity;
        projectId = _projectId;

        governanceNFT = new JBGovernanceNFT(_stakedToken);
    }

    // deposit _depositAmount of stakedToken
    // function stake(uint256 _amount) external {
    //     // If delay has passed, take a new snapshot
    //     if(lastSnapshotAt + periodicity < block.timestamp) {
    //         takeSnapshot();
    //     }
    //     stakedToken.transferFrom(msg.sender, address(this), _amount);
        
    //     governanceNFT.mint(_amount, msg.sender);
    // }

    // function unstake(uint256 _amount) external {
    //     // If delay has passed, take a new snapshot
    //     if(lastSnapshotAt + periodicity < block.timestamp) {
    //         takeSnapshot();
    //     }
    // }

    function claim(uint256 _tokenId) external override {
        // protection for fee on transfer token (everything in try-catch and skip them?)
        // if none -> griefing vector
        // + same for token which revert or consume gas
        // + reentrancy vector

        // Only claim once per epoch
        claimed[msg.sender][lastSnapshotAt] = true;

        // todo
        // If delay has passed, take a new snapshot
        if(lastSnapshotAt + periodicity < block.timestamp) {
            takeSnapshot();
        }
    }

    function claim(uint256[] calldata _tokenId) external override {}

    // For now, only ERC20 -> to support project token without erc20, claim() should have a way to know if claimed/unclaimed
    // (additional mapping? Additional call to tokenStore.balanceOf? -> need gas check
    function allocate(JBSplitAllocationData calldata _data) external payable override {
        // Make sure the token is not the staking token, otherwise that suddenly becomes distributable
        if (IERC20(_data.token) == stakedToken) revert JBDistributor_canNotDistributeStakedToken();

        // Check if the token is supported
        if(!_isIn(IERC20(_data.token), projectTokens)) revert JBDistributor_unsupportedToken();//projectTokens.push(IERC20(_data.token));
        
        if(_data.token != JBTokens.ETH) IERC20(_data.token).transferFrom(msg.sender, address(this), _data.amount);

        // If delay has passed, take a new snapshot
        if(lastSnapshotAt + periodicity < block.timestamp) {
            takeSnapshot();
        }
    }

    function addAssetToBasket(IERC20 _token) external override {}


    // -- internal --

    // take a snapshot of the claimable basket total amounts
    // we reset the basket by relying on balance(this) only, as reserved allocation mint in beneficiary address
    function takeSnapshot() internal {
        uint256 _numberOfTokens = projectTokens.length;
        uint256 _newNumberOfTokens = _numberOfTokens;

        // prevent multiple SLOADS in the loop
        IERC20[] memory _token = projectTokens;

        for(uint256 i; i < _newNumberOfTokens;) {
            IERC20 _currentToken = _token[i];
            uint256 _currentTokenBalance = _currentToken.balanceOf(address(this));

            // remove the token with an empty balance
            if(_currentTokenBalance == 0) {
                projectTokens[i] = projectTokens[_newNumberOfTokens - 1];
                delete currentAmountClaimable[_currentToken];
                _newNumberOfTokens--;

                continue;
            }

            // Non-empty balance -> this is the new amount
            currentAmountClaimable[projectTokens[i]] = _currentTokenBalance;

            unchecked {
                ++ i;
            }
        }
        
        // Resize the array if needed
        if(_newNumberOfTokens != _numberOfTokens)
            assembly ("memory-safe") {
                sstore(sload(projectTokens.slot), _newNumberOfTokens)
            }

        lastSnapshotAt = block.timestamp;
        emit SnapshotTaken(lastSnapshotAt);
    }

    // returns true if a token is in a token array
    function _isIn(IERC20 _token, IERC20[] storage _tokens) internal view returns (bool) {
        uint256 _numberOfTokens = _tokens.length;

        for(uint256 i; i < _numberOfTokens;) {
            if(_tokens[i] == _token) return true;
            unchecked {
                ++ i;
            }
        }
        return false;
    }


}
