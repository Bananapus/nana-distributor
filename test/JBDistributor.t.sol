// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// import "@juicebox/structs/JBSplit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "forge-std/Test.sol";
import "../src/JBDistributor.sol";

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
        distributor.setTotalStake(distributor.roundStartBlock(distributor.currentRound()), 1_000_000);

        uint256[] memory nftIds = new uint256[](2);
        nftIds[0] = 1;
        nftIds[1] = 2;

        // Set each token to represent 100k
        distributor.setTokenStake(nftIds[0], 100_000);
        distributor.setTokenStake(nftIds[1], 100_000);

        // Do a claim with the 2 NFTs on the 2 tokens
        distributor.beginVesting(nftIds, tokens);

        // Verify that each of the nfts received 10% of each of the tokens
        assertEq(distributor.tokenVesting(nftIds[0], 26, tokens[0]), 1 ether);
        assertEq(distributor.tokenVesting(nftIds[1], 26, tokens[0]), 1 ether);
        assertEq(distributor.tokenVesting(nftIds[0], 26, tokens[1]), 1 ether);
        assertEq(distributor.tokenVesting(nftIds[1], 26, tokens[1]), 1 ether);
    }

    function test_JbDistributor_canClaim_usesSnapshot() external {
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(tokenA);
        tokens[1] = IERC20(tokenB);

        // Send the tokens to the distributor
        tokenA.mint(address(distributor), 10 ether);
        tokenB.mint(address(distributor), 10 ether);

        // Set total staked to 1M
        distributor.setTotalStake(distributor.roundStartBlock(distributor.currentRound()), 1_000_000);

        // Perform a claim
        {
            uint256[] memory _initialNftIds = new uint256[](2);
            _initialNftIds[0] = 1;
            _initialNftIds[1] = 2;

            // Set each token to represent 100k
            distributor.setTokenStake(_initialNftIds[0], 100_000);
            distributor.setTokenStake(_initialNftIds[1], 100_000);

            // Do a claim with the 2 NFTs on the 2 tokens
            distributor.beginVesting(_initialNftIds, tokens);
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
        distributor.beginVesting(nftIds, tokens);

        // Verify that each of the nfts still received 10% of each of the tokens
        assertEq(distributor.tokenVesting(nftIds[0], 26, tokens[0]), 1 ether);
        assertEq(distributor.tokenVesting(nftIds[1], 26, tokens[0]), 1 ether);
        assertEq(distributor.tokenVesting(nftIds[0], 26, tokens[1]), 1 ether);
        assertEq(distributor.tokenVesting(nftIds[1], 26, tokens[1]), 1 ether);
    }

    function test_JbDistributor_canCollect() external {
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(tokenA);
        tokens[1] = IERC20(tokenB);

        // Send the tokens to the distributor
        tokenA.mint(address(distributor), 10 ether);
        tokenB.mint(address(distributor), 10 ether);

        // Set total staked to 1M
        distributor.setTotalStake(distributor.roundStartBlock(distributor.currentRound()), 1_000_000);

        uint256[] memory nftIds = new uint256[](2);
        nftIds[0] = 1;
        nftIds[1] = 2;

        // Set each token to represent 100k
        distributor.setTokenStake(nftIds[0], 100_000);
        distributor.setTokenStake(nftIds[1], 100_000);

        // Do a claim with the 2 NFTs on the 2 tokens
        distributor.beginVesting(nftIds, tokens);

        // Forward to the start of cycle 26
        // In this test this is a year from the start
        vm.roll(distributor.roundStartBlock(26));

        distributor.collectVestedRewards(nftIds, tokens, 26);

        // Verify that we received the expected amount of tokens
        assertEq(tokenA.balanceOf(address(this)), 2 ether);
        assertEq(tokenB.balanceOf(address(this)), 2 ether);

        distributor.collectVestedRewards(nftIds, tokens, 26);
    }

    function test_JbDistributor_canClaimManyTokens() external {
        uint256 _nftCount = 3;
        uint256 _tokenCount = 6;

        IERC20[] memory tokens = new IERC20[](_tokenCount);
        for (uint256 i = 0; i < _tokenCount; i++) {
            // Create a new token to be distributed
            tokens[i] = new TestToken("TokenA", "A");
            // Send the tokens to the distributor
            TestToken(address(tokens[i])).mint(address(distributor), 10 ether);
        }

        // Set total staked to 1M
        distributor.setTotalStake(distributor.roundStartBlock(distributor.currentRound()), 1_000_000);

        uint256[] memory nftIds = new uint256[](_nftCount);
        for (uint256 i = 0; i < _nftCount; i++) {
            nftIds[i] = i + 1;
            // Share 50% of the staked tokens among all our tokens
            distributor.setTokenStake(nftIds[i], 500_000 / _nftCount);
        }

        // Do a claim with the 2 NFTs on the 2 tokens
        distributor.beginVesting(nftIds, tokens);

        // Make sure that we collected 50% of all the rewards of the cycle
        for (uint256 i = 0; i < _tokenCount; i++) {
            for (uint256 j = 0; j < _nftCount; j++) {
                assertApproxEqRel(distributor.tokenVesting(nftIds[j], 26, tokens[i]), 5 ether / _nftCount, 1e14);
            }
        }

        // Forward to the start of cycle 26
        // In this test this is a year from the start
        vm.roll(distributor.roundStartBlock(26));

        distributor.collectVestedRewards(nftIds, tokens, 26);

        // Make sure that we collected 50% of all the rewards of the cycle
        for (uint256 i = 0; i < _tokenCount; i++) {
            // Create a new token to be distributed
            assertApproxEqRel(tokens[i].balanceOf(address(this)), 5 ether, 1e14);
        }
    }
}

contract ForTest_JBDistributorAlt is JBDistributor {
    mapping(uint256 => uint256) stakedAmount;
    mapping(uint256 => uint256) tokenStake;

    // Time is in blocks, we want a cycle to be 2 weeks so we divide by the BLOCK_TIME (12 seconds)
    uint256 constant CYCLE_DURATION = 2 weeks / 12 seconds;

    constructor() JBDistributor(CYCLE_DURATION, 26) {}

    function _canClaim(uint256, address) internal view virtual override returns (bool _userMayClaimToken) {
        // TODO: add test cases that are not allowed
        return true;
    }

    function _totalStake(uint256 _timestamp) internal view virtual override returns (uint256 _stakedAmount) {
        return stakedAmount[_timestamp];
    }

    function setTotalStake(uint256 _timestamp, uint256 _stakedAmount) external {
        stakedAmount[_timestamp] = _stakedAmount;
    }

    function _tokenStake(uint256 _tokenId) internal view virtual override returns (uint256 _tokenStakeAmount) {
        return tokenStake[_tokenId];
    }

    function setTokenStake(uint256 _tokenId, uint256 _tokenStakeAmount) external {
        tokenStake[_tokenId] = _tokenStakeAmount;
    }
}

contract TestToken is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address _recipient, uint256 _amount) external {
        _mint(_recipient, _amount);
    }
}
