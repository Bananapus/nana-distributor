// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@juicebox/structs/JBSplit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; 
import "forge-std/Test.sol";
import "../src/JBDistributorAlt.sol";

contract JBDistributorTest is Test {
    event Claimed(address indexed caller, address[] tokens, uint256[] amounts);
    event SnapshotTaken(uint256 timestamp);

    ForTest_JBDistributorAlt public distributor;

    TestToken tokenA;
    TestToken tokenB;

    function setUp() public {
        distributor = new ForTest_JBDistributorAlt();

        tokenA = new TestToken("TokenA", "A"); 
        tokenB = new TestToken("TokenB", "B"); 
    }

    function test_JbDistributor_canClaim() external {
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(tokenA);
        tokens[1] = IERC20(tokenB);

        // Send the tokens to the distributor
        tokenA.mint(address(distributor), 10 ether);
        tokenB.mint(address(distributor), 10 ether);

        // Set total staked to 1M
        distributor.setTotalStake(
            distributor.cycleStartTime(
                distributor.currentCycle()
            ),
            1_000_000
        );

        uint256[] memory nftIds = new uint256[](2);
        nftIds[0] = 1;
        nftIds[1] = 2;

        // Set each token to represent 100k
        distributor.setTokenStake(nftIds[0], 100_000);
        distributor.setTokenStake(nftIds[1], 100_000);

        // Do a claim with the 2 NFTs on the 2 tokens
        distributor.claim(nftIds, tokens);

        // Verify that each of the nfts received 10% of each of the tokens
        assertEq(distributor.tokenVesting(nftIds[0], 27, tokens[0]), 1 ether);
        assertEq(distributor.tokenVesting(nftIds[1], 27, tokens[0]), 1 ether);
        assertEq(distributor.tokenVesting(nftIds[0], 27, tokens[1]), 1 ether);
        assertEq(distributor.tokenVesting(nftIds[1], 27, tokens[1]), 1 ether);
    }

    function test_JbDistributor_canClaim_usesSnapshot() external {
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(tokenA);
        tokens[1] = IERC20(tokenB);

        // Send the tokens to the distributor
        tokenA.mint(address(distributor), 10 ether);
        tokenB.mint(address(distributor), 10 ether);

        // Set total staked to 1M
        distributor.setTotalStake(
            distributor.cycleStartTime(
                distributor.currentCycle()
            ),
            1_000_000
        );

        // Perform a claim
        {
            uint256[] memory _initialNftIds = new uint256[](2);
            _initialNftIds[0] = 1;
            _initialNftIds[1] = 2;

            // Set each token to represent 100k
            distributor.setTokenStake(_initialNftIds[0], 100_000);
            distributor.setTokenStake(_initialNftIds[1], 100_000);

            // Do a claim with the 2 NFTs on the 2 tokens
            distributor.claim(_initialNftIds, tokens);
        }

        // We now increase the balance of the distributor, the new claim should however not be impacted
        tokenA.mint(address(distributor), 10 ether);
        tokenB.mint(address(distributor), 10 ether);

        uint256[] memory nftIds = new uint256[](2);
        nftIds[0] = 3;
        nftIds[1] = 4;

        // Set each token to represent 100k
        distributor.setTokenStake(nftIds[0], 100_000);
        distributor.setTokenStake(nftIds[1], 100_000);

        // Do a claim with the 2 NFTs on the 2 tokens
        distributor.claim(nftIds, tokens);

        // Verify that each of the nfts still received 10% of each of the tokens
        assertEq(distributor.tokenVesting(nftIds[0], 27, tokens[0]), 1 ether);
        assertEq(distributor.tokenVesting(nftIds[1], 27, tokens[0]), 1 ether);
        assertEq(distributor.tokenVesting(nftIds[0], 27, tokens[1]), 1 ether);
        assertEq(distributor.tokenVesting(nftIds[1], 27, tokens[1]), 1 ether);
    }

}

contract ForTest_JBDistributorAlt is JBDistributor{

    mapping(uint256 => uint256) stakedAmount;
    mapping(uint256 => uint256) tokenStake;

    constructor() JBDistributor(2 weeks, 26) {

    }
    
    function _totalStake(uint256 _timestamp) internal view override virtual returns (uint256 _stakedAmount) {
        return stakedAmount[_timestamp];
    }

    function setTotalStake(uint256 _timestamp, uint256 _stakedAmount) external {
        stakedAmount[_timestamp] = _stakedAmount;
    }

    function _tokenStake(uint256 _tokenId) internal view override virtual returns (uint256 _tokenStakeAmount) {
        return tokenStake[_tokenId];
    }

    function setTokenStake(uint256 _tokenId, uint256 _tokenStakeAmount) external {
        tokenStake[_tokenId] = _tokenStakeAmount;
    }
}

contract TestToken is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {

    }

    function mint(address _recipient, uint256 _amount) external{
        _mint(_recipient, _amount);
    }
}