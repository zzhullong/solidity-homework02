# 作业二：讨饭合约 BeggingContract — 设计文档

日期：2026-11-16
作业：MetaNodeAcademy LearningRoadmap `contract/homework02.md`
实现工具链：Foundry（经用户确认；作业原文用 Remix 编译，README 同时给出 Remix 与 forge 两种路径）

## 1. 背景与目标

实现一个接受 ETH 捐赠的合约：记录每个捐赠者的金额，所有者可提取全部资金。作业必做项之外，用户要求把三个可选挑战（Donation 事件、Top3 捐赠排行榜、捐赠时间限制）全部实现。

目标：
- `BeggingContract` 覆盖 donate / withdraw / getDonation 三大功能。
- 事件、Top3 排行榜、时间窗口全部实现并测试。
- 完整测试：正常路径、权限、边界、时间边界、fuzz 不变量。
- 提供 Sepolia 部署脚本与中文 README；实际部署与截图由用户手动完成。

非目标：
- 不由本机代持私钥或代替用户在测试网广播交易。
- 不做前端。
- 不引入 OpenZeppelin；onlyOwner 自行实现。

失败标准（anti-goals）：
- 非 owner 能提走资金。
- 捐赠金额记录与实际余额不一致。
- 时间窗口边界行为不明确（开始/结束时刻是否可捐）。
- Top3 在不足 3 人或平手时行为错误。
- 部署脚本无法编译或缺少必要说明。

## 2. 约束

- Solidity `^0.8.24`，Foundry 1.9.0，依赖仅 forge-std。
- 作业原文要求 `address.transfer`，withdraw 按其要求实现；README 注明 `call` 是现代推荐写法。
- 部署需要用户提供 `SEPOLIA_RPC_URL`、`PRIVATE_KEY`（仅通过环境变量，不落盘）、`ETHERSCAN_API_KEY`。
- 时间窗口按 `block.timestamp` 判断，两端闭区间：`startTime <= now <= endTime`。
- 时间边界、Top3 平手规则需在 README 写明。

## 3. 接口

```solidity
contract BeggingContract {
    address public immutable owner;
    uint256 public immutable startTime;
    uint256 public immutable endTime;

    event Donation(address indexed donor, uint256 amount);
    event Withdrawal(address indexed owner, uint256 amount);

    constructor(uint256 _startTime, uint256 _endTime); // require start < end

    function donate() external payable;                  // only during window, value > 0
    function withdraw() external;                        // onlyOwner, balance > 0
    function getDonation(address donor) external view returns (uint256);
    function getTopDonors()
        external view
        returns (address[] memory topAddresses, uint256[] memory topAmounts);
}
```

行为约定：
- `donate`：`msg.value == 0` revert；窗口外 revert；首次捐赠时把地址加入 `donors` 数组；累计金额；触发 `Donation`。
- `withdraw`：非 owner revert；余额为 0 revert；`payable(owner).transfer(address(this).balance)`；触发 `Withdrawal`。捐赠记录保留不清零。
- `getTopDonors`：按捐赠总额降序返回至多 3 个地址与金额；金额相同按首次捐赠时间先后；view 函数内部扫描 `donors`，无需额外存储。
- 构造函数：`startTime < endTime`，否则 revert。

## 4. 测试策略

单一 `test/BeggingContract.t.sol`，按功能分组：
- 记账：单次/多次/多地址累计，未捐赠地址返回 0。
- 支付约束：0 值 revert，窗口外 revert。
- 权限：非 owner withdraw revert，owner 提取全额且合约余额归零。
- 事件：`vm.expectEmit` 校验 Donation 与 Withdrawal 的参数。
- 时间窗口：warp 到 start-1、start、中间、end、end+1，验证闭区间。
- Top3：空、1 人、2 人、3 人、4 人乱序、平手。
- fuzz：随机金额序列捐赠后，合约余额恒等于捐赠总和，且每个地址记录正确。
- 构造函数非法窗口 revert。
