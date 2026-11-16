// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {BeggingContract} from "../src/BeggingContract.sol";

contract Deploy is Script {
    function run() external returns (BeggingContract begging) {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        uint256 start = block.timestamp;
        uint256 end = start + 30 days;

        vm.startBroadcast(pk);
        begging = new BeggingContract(start, end);
        vm.stopBroadcast();
    }
}
