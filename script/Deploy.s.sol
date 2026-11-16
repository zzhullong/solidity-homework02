// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {BeggingContract} from "../src/BeggingContract.sol";

/// @title Sepolia 部署脚本
/// @notice 部署 BeggingContract，捐赠窗口为部署时刻起 30 天。
contract Deploy is Script {
    /// @dev Sepolia 的 chain id；部署前校验，避免误连主网或其他网络
    uint256 internal constant SEPOLIA_CHAIN_ID = 11_155_111;

    /// @notice 执行部署
    /// @dev 发送者由 forge 命令行的 --account 或 --private-key 指定，脚本本身不读取私钥
    function run() external returns (BeggingContract begging) {
        require(block.chainid == SEPOLIA_CHAIN_ID, "not Sepolia");

        uint256 start = block.timestamp;
        uint256 end = start + 30 days;

        vm.startBroadcast();
        begging = new BeggingContract(start, end);
        vm.stopBroadcast();
    }
}
