// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title BeggingContract 讨饭合约
/// @notice 接受 ETH 捐赠，按地址累计金额；所有者可提取全部资金，并提供 Top3 捐赠排行榜与捐赠时间窗口。
contract BeggingContract {
    /// @notice 合约部署者，唯一有权提取资金的地址
    address public immutable owner;

    /// @notice 允许捐赠的起始时间（Unix 时间戳，含）
    uint256 public immutable startTime;

    /// @notice 允许捐赠的结束时间（Unix 时间戳，含）
    uint256 public immutable endTime;

    /// @dev 捐赠者地址 => 累计捐赠金额
    mapping(address => uint256) private donations;

    /// @dev 所有捐赠过的地址（每个地址只出现一次），用于计算排行榜
    address[] private donors;

    /// @notice 每次捐赠触发
    event Donation(address indexed donor, uint256 amount);

    /// @notice 每次提现触发
    event Withdrawal(address indexed owner, uint256 amount);

    /// @param _startTime 捐赠窗口开始时间
    /// @param _endTime 捐赠窗口结束时间，必须晚于当前时间，否则窗口永远无法开启
    constructor(uint256 _startTime, uint256 _endTime) {
        require(_startTime < _endTime, "invalid window");
        require(_endTime > block.timestamp, "window already ended");
        owner = msg.sender;
        startTime = _startTime;
        endTime = _endTime;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    /// @dev 时间窗口为闭区间：[startTime, endTime] 内均可捐赠
    modifier onlyDuringDonationWindow() {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "donation window closed");
        _;
    }

    /// @notice 向合约捐赠 ETH，金额累加到调用者名下
    /// @dev 只接受大于 0 的金额；首次捐赠时把地址登记到 donors 列表
    function donate() external payable onlyDuringDonationWindow {
        require(msg.value > 0, "zero donation");
        // 首次捐赠（累计金额仍为 0）才登记地址，保证 donors 中每个地址唯一
        if (donations[msg.sender] == 0) {
            donors.push(msg.sender);
        }
        donations[msg.sender] += msg.value;
        emit Donation(msg.sender, msg.value);
    }

    /// @notice 提取合约全部余额给 owner（仅 owner）
    /// @dev 作业要求使用 address.transfer；现代 Solidity 更推荐 call{value: ...}("") 配合重入防护。
    /// 事件在转账前发出：若 transfer 失败会整体 revert，事件也会回滚。
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "nothing to withdraw");
        (bool ok, ) = payable(owner).call{value: balance}("");
        require(ok, "withdraw failed");
        emit Withdrawal(owner, balance);
        
       
    }

    /// @notice 查询某个地址的累计捐赠金额；未捐赠过返回 0
    /// @param donor 捐赠者地址
    function getDonation(address donor) external view returns (uint256) {
        return donations[donor];
    }

    /// @notice 返回累计捐赠金额最多的前 3 个地址与金额（不足 3 人时返回实际人数）
    /// @return topAddresses 按金额降序排列的地址
    /// @return topAmounts 与地址对应的金额
    /// @dev 扫描 donors 列表并在内存中维护一个长度不超过 3 的降序榜单；金额相同时先捐赠者排前。
    /// 复杂度 O(n)，作为 view 调用不消耗链上 gas，但捐赠者极多时可能触及 eth_call 的 gas 上限。
    function getTopDonors() external view returns (address[] memory topAddresses, uint256[] memory topAmounts) {
        uint256 count = donors.length < 3 ? donors.length : 3;
        topAddresses = new address[](count);
        topAmounts = new uint256[](count);

        uint256 filled = 0;
        for (uint256 i; i < donors.length; ++i) {
            address donor = donors[i];
            uint256 amount = donations[donor];

            // 找到插入位置：跳过所有金额大于等于当前金额的条目。
            // 用 >= 而不是 >，使金额相同的后来者排在已有捐赠者之后。
            uint256 pos = 0;
            while (pos < filled && topAmounts[pos] >= amount) {
                ++pos;
            }
            // 只有进入前 3 才插入；pos == 3 表示当前捐赠者排在榜外
            if (pos < 3) {
                uint256 limit = filled < 3 ? filled : 2;
                // 榜单已满 3 人时丢弃末位，并整体后移腾出位置
                for (uint256 j = limit; j > pos; --j) {
                    topAddresses[j] = topAddresses[j - 1];
                    topAmounts[j] = topAmounts[j - 1];
                }
                topAddresses[pos] = donor;
                topAmounts[pos] = amount;
                if (filled < 3) {
                    ++filled;
                }
            }
        }
    }
}
