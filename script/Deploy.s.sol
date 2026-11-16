// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {BeggingContract} from "../src/BeggingContract.sol";

contract Deploy is Script {
    uint256 internal constant SEPOLIA_CHAIN_ID = 11_155_111;

    function run() external returns (BeggingContract begging) {
        require(block.chainid == SEPOLIA_CHAIN_ID, "not Sepolia");

        uint256 start = block.timestamp;
        uint256 end = start + 30 days;

        vm.startBroadcast();
        begging = new BeggingContract(start, end);
        vm.stopBroadcast();
    }
}
