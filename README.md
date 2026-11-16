# BeggingContract 讨饭合约（作业二）

MetaNodeAcademy LearningRoadmap [`contract/homework02.md`](https://github.com/MetaNodeAcademy/LearningRoadmap/blob/main/contract/homework02.md) 的实现，使用 Foundry 开发与测试。

## 功能

| 功能 | 说明 |
|---|---|
| `donate()` | 向合约捐赠 ETH，按地址累计记录，首次捐赠时加入捐赠者列表 |
| `withdraw()` | 合约所有者提取合约全部余额 |
| `getDonation(address)` | 查询某个地址的累计捐赠金额 |
| `getTopDonors()` | 返回累计捐赠金额最多的前 3 个地址与金额 |
| `Donation` / `Withdrawal` 事件 | 每次捐赠、提现都会记录链上事件 |
| 捐赠时间窗口 | 仅在构造时设定的 `startTime`–`endTime`（含两端）内可捐赠 |

## 接口

```solidity
contract BeggingContract {
    address public immutable owner;
    uint256 public immutable startTime;
    uint256 public immutable endTime;

    event Donation(address indexed donor, uint256 amount);
    event Withdrawal(address indexed owner, uint256 amount);

    constructor(uint256 _startTime, uint256 _endTime);
    function donate() external payable;
    function withdraw() external;
    function getDonation(address donor) external view returns (uint256);
    function getTopDonors()
        external view
        returns (address[] memory topAddresses, uint256[] memory topAmounts);
}
```

## 行为约定

- **权限**：`withdraw` 只能由部署者（`owner`）调用；其他地址调用会 revert。
- **捐赠金额**：`msg.value` 必须大于 0；同一地址多次捐赠会累加。
- **时间窗口**：`startTime <= block.timestamp <= endTime` 时可捐赠。开始时刻与结束时刻都可捐，窗口外 revert；构造时要求 `startTime < endTime`。
- **提现**：要求合约余额大于 0；按作业要求使用 `payable(owner).transfer(...)`。现代 Solidity 更推荐 `call{value: ...}("")` 配合重入防护，本项目按作业要求保留 `transfer`。提现后链上捐赠记录保留，不做清零。
- **排行榜**：`getTopDonors` 是 view 函数，内部扫描捐赠者列表，返回至多 3 个地址及金额，按金额降序；金额相同时，先捐赠者排在前。不足 3 人时返回实际人数。
- **owner 地址**：实际部署时 owner 是部署交易的发送者（通常是 MetaMask 的 EOA）。由于使用 `transfer`，如果 owner 是合约账户，它必须能接收 ETH，否则提现会 revert。

## 运行测试

```bash
forge test -vvv
```

当前测试覆盖：捐赠记账与累加、零值捐赠、未知地址查询、owner/非 owner 提现、提现后余额与到账金额、事件参数、时间窗口前后与两端、Top3 排序/不足 3 人/平手、构造函数非法窗口，以及 fuzz 校验合约余额恒等于捐赠总和。

## 部署到 Sepolia

### 方式一：Foundry 脚本

```bash
cp .env.example .env
# 编辑 .env，填入 Sepolia RPC、测试钱包私钥、Etherscan API Key
source .env

forge script script/Deploy.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

脚本构造参数为：`startTime = 部署时刻`，`endTime = startTime + 30 天`。如需自定义时间窗口，修改 `script/Deploy.s.sol` 中的 `start`/`end`。

部署成功后会输出合约地址；可复制 `broadcast/Deploy.s.sol/<chainId>/run-latest.json` 中的地址到下方。

### 方式二：Remix

1. 打开 [Remix IDE](https://remix.ethereum.org)，新建 `BeggingContract.sol` 并粘贴 `src/BeggingContract.sol` 内容。
2. 编译器选择 0.8.24 及以上，Environment 选择 **Injected Provider - MetaMask**，网络切到 Sepolia。
3. Deploy 时填入构造参数：`_startTime`、`_endTime`（Unix 时间戳，单位秒，且 start 必须小于 end）。
4. 用 MetaMask 调用 `donate` 并附带 ETH；切换回 owner 账户调用 `withdraw`；调用 `getDonation` 验证记账。

## 部署信息

- 合约地址：`<待部署后填写>`
- 测试网：Sepolia
- Etherscan：`<部署后填写链接>`
- 测试截图：`<待补充>`

## 安全说明

- 私钥只通过本地环境变量传入，`.env` 已被 `.gitignore` 排除，仓库只保留 `.env.example`。
- 请使用专门的测试钱包，不要在测试网钱包中存放主网资产。
- 本项目为课程作业实现，未经过第三方审计。

## 项目结构

```
src/      BeggingContract.sol
test/     BeggingContract.t.sol（19 个测试）
script/   Deploy.s.sol
lib/      forge-std（git submodule）
```

克隆后如未拉取子模块：

```bash
git submodule update --init --recursive
```
