// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;


import {Test, console} from "forge-std/Test.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";

contract TargetContract {
    
    function execute(uint256 amount, DamnValuableToken token, address player)
        external
        returns (bool)
    {
        // diagnostic
        console.log("TargetContract.execute called");
        console.log(" msg.sender:", msg.sender);
        console.log(" amount:", amount);
        console.log(" token:", address(token));
        console.log(" recovery:", player);
        console.log(" token.balanceOf(target):", token.balanceOf(address(this)));
        console.log(" token.allowance(target -> player):", token.allowance(address(this),player));

         token.transfer(msg.sender, amount);
         token.approve(player, amount); 
        // post-approve diagnostics
         console.log(" after transfer token.balanceOf(target):", token.balanceOf(address(this)));
        console.log(" after approve token.allowance(target -> player):", token.allowance(address(this),player));


        return true;
    }

}
