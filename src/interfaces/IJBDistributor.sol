// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { JBSplitAllocationData } from "@juicebox/structs/JBSplitAllocationData.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title   JBDistributor
 * @notice 
 * @dev 
 */
interface IJBDistributor {

    function currentClaimable(uint256 _tokenId) external view returns(IERC20[] memory _tokens, uint256[] memory _claimableAmounts);
    
    function getBasket() external view returns (IERC20[] memory _token, uint256[] memory _distributableAmount);
    
    function claim(uint256 _tokenId) external;
    
    function claim(uint256[] calldata _tokenId) external;

    function addAssetToBasket(IERC20 _token) external;
}
