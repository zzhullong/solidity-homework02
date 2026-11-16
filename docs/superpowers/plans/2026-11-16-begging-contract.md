# 作业二：BeggingContract 讨饭合约 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** 用 Foundry 实现 BeggingContract（捐赠、提现、查询、事件、Top3 排行榜、捐赠时间窗口），配完整测试、Sepolia 部署脚本和中文 README，并推送为独立 GitHub 仓库。

**Architecture:** 单一合约 + 单一测试文件 + 单一部署脚本；时间窗口与 Top3 均为无额外存储的轻量实现。owner 权限自行实现，不引入 OpenZeppelin。

**Tech Stack:** Solidity 0.8.24、Foundry 1.9.0、forge-std。

**Spec:** `docs/superpowers/specs/2026-11-16-begging-contract-design.md`

## Global Constraints

- `pragma solidity ^0.8.24;`，依赖只有 forge-std。
- 时间窗口闭区间：`startTime <= block.timestamp <= endTime`。
- 作业要求 `address.transfer`：`withdraw` 用 `payable(owner).transfer(address(this).balance)`；README 注明 `call` 是现代推荐写法。
- 部署私钥只通过 `PRIVATE_KEY` 环境变量传入，`.env` 被 gitignore，仓库内只放 `.env.example`。
- 每任务结束 `forge test` 通过；提交信息 conventional commits，结尾附：
  `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`
- 仓库路径：`/Users/zulg/solidity-homework02`；远程 `git@github.com:zzhullong/solidity-homework02.git`。

## Review Focus

- 非 owner 提现：必须 revert，且不能通过合约 fallback 绕过。
- 零值捐赠：`msg.value == 0` 必须 revert，否则 donors 数组会被垃圾地址污染。
- 时间窗口边界：恰好等于 startTime / endTime 必须可捐，前后一秒必须 revert。
- 提现后状态：合约余额归零、owner 收到全额、捐赠记录保留。
- Top3 不足 3 人/平手：返回长度正确、顺序稳定（平手按首次捐赠先后），空仓库返回空数组。

---

### Task 1: 初始化 Foundry 仓库

**Files:**
- Create: `foundry.toml`, `remappings.txt`, `.gitignore`, `README.md`, `lib/forge-std`
- Create dirs: `src/`, `test/`, `script/`

**Interfaces:**
- Produces: 可运行 `forge build` 的空项目。

- [x] **Step 1: 建目录并初始化 git**

```bash
mkdir -p /Users/zulg/solidity-homework02/{src,test,script,lib}
cd /Users/zulg/solidity-homework02
git init -b main
```

- [x] **Step 2: 写配置文件**

`foundry.toml`：
```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc = "0.8.24"
optimizer = true
optimizer_runs = 200
```
`remappings.txt`：
```
forge-std/=lib/forge-std/src/
```

- [x] **Step 3: 安装 forge-std**

```bash
forge install foundry-rs/forge-std
```
HTTPS 失败时用 SSH 克隆并改写 `.gitmodules` 为 HTTPS（同作业一计划 Task 1 Step 3）。

- [x] **Step 4: 写 `.gitignore` 与 README 骨架**

`.gitignore`：
```
out/
cache/
broadcast/
.env
```
README 骨架：作业链接、功能列表、运行方式。

- [x] **Step 5: 验证并提交**

Run: `forge build`
Expected: 成功。
```bash
git add -A
git commit -m "chore: scaffold foundry project"
```

---

### Task 2: 核心合约（捐赠、查询、提现）

**Files:**
- Create: `src/BeggingContract.sol`
- Test: `test/BeggingContract.t.sol`

**Interfaces:**
- Produces:
  ```solidity
  contract BeggingContract {
      address public immutable owner;
      uint256 public immutable startTime;
      uint256 public immutable endTime;
      constructor(uint256 _startTime, uint256 _endTime);
      function donate() external payable;
      function withdraw() external;
      function getDonation(address donor) external view returns (uint256);
  }
  ```

- [x] **Step 1: 写失败测试**

测试合约 `setUp`：`vm.warp(1_000_000)`；`begging = new BeggingContract(block.timestamp, block.timestamp + 7 days)`；给 alice/bob `vm.deal(..., 10 ether)`。

```solidity
function testDonateRecordsAmount() public {
    vm.prank(alice); begging.donate{value: 1 ether}();
    assertEq(begging.getDonation(alice), 1 ether);
}
function testDonateAccumulates() public {
    vm.startPrank(alice);
    begging.donate{value: 1 ether}();
    begging.donate{value: 2 ether}();
    vm.stopPrank();
    assertEq(begging.getDonation(alice), 3 ether);
}
function testDonateZeroReverts() public {
    vm.prank(alice); vm.expectRevert(); begging.donate{value: 0}();
}
function testGetDonationUnknownReturnsZero() public view {
    assertEq(begging.getDonation(address(0xCAFE)), 0);
}
function testWithdrawByOwnerTransfersAll() public {
    vm.prank(alice); begging.donate{value: 1 ether}();
    vm.prank(bob); begging.donate{value: 2 ether}();
    uint256 before = owner.balance;
    vm.prank(owner); begging.withdraw();
    assertEq(address(begging).balance, 0);
    assertEq(owner.balance, before + 3 ether);
}
function testWithdrawOnlyOwnerReverts() public {
    vm.prank(alice); begging.donate{value: 1 ether}();
    vm.prank(alice); vm.expectRevert(); begging.withdraw();
}
function testWithdrawEmptyBalanceReverts() public {
    vm.prank(owner); vm.expectRevert(); begging.withdraw();
}
function testFuzzBalanceMatchesDonations(uint96 a, uint96 b) public {
    a = uint96(bound(a, 1, 5 ether)); b = uint96(bound(b, 1, 5 ether));
    vm.prank(alice); begging.donate{value: a}();
    vm.prank(bob); begging.donate{value: b}();
    assertEq(address(begging).balance, uint256(a) + uint256(b));
    assertEq(begging.getDonation(alice), a);
    assertEq(begging.getDonation(bob), b);
}
```

- [x] **Step 2: 运行并确认失败**

Run: `forge test --match-contract BeggingContractTest`
Expected: 编译失败（BeggingContract 未定义）。

- [x] **Step 3: 实现**

要点：构造函数 `require(_startTime < _endTime, "invalid window")`；`owner = msg.sender`；`donate` 要求 `msg.value > 0`，首次捐赠（`donations[msg.sender] == 0`）时 push 到 `donors`，累计；`withdraw` 用 `onlyOwner` modifier，`require(address(this).balance > 0, "nothing to withdraw")`，`payable(owner).transfer(address(this).balance)`；`getDonation` 返回 mapping。时间窗口本任务暂不启用（Task 5 加）。

- [x] **Step 4: 运行测试通过**

Run: `forge test --match-contract BeggingContractTest -vvv`
Expected: 8 个测试 PASS。

- [x] **Step 5: 提交**

```bash
git add src/BeggingContract.sol test/BeggingContract.t.sol
git commit -m "feat: add begging contract core with tests"
```

---

### Task 3: Donation 与 Withdrawal 事件

**Files:**
- Modify: `src/BeggingContract.sol`
- Modify: `test/BeggingContract.t.sol`

**Interfaces:**
- Produces:
  ```solidity
  event Donation(address indexed donor, uint256 amount);
  event Withdrawal(address indexed owner, uint256 amount);
  ```

- [x] **Step 1: 写失败测试**

```solidity
function testDonationEvent() public {
    vm.expectEmit(true, false, false, true, address(begging));
    emit BeggingContract.Donation(alice, 1 ether);
    vm.prank(alice); begging.donate{value: 1 ether}();
}
function testWithdrawalEvent() public {
    vm.prank(alice); begging.donate{value: 1 ether}();
    vm.expectEmit(true, false, false, true, address(begging));
    emit BeggingContract.Withdrawal(owner, 1 ether);
    vm.prank(owner); begging.withdraw();
}
```

- [x] **Step 2: 运行并确认失败**

Run: `forge test --match-test "Event" -vvv`
Expected: FAIL（事件不存在，编译失败）。

- [x] **Step 3: 实现**

在 `donate` 记账后 `emit Donation(msg.sender, msg.value);`；`withdraw` 在 transfer 前记录 `uint256 amount = address(this).balance;`，转账后 `emit Withdrawal(owner, amount);`。

- [x] **Step 4: 运行测试通过**

Run: `forge test --match-test "Event" -vvv`
Expected: PASS。

- [x] **Step 5: 提交**

```bash
git add src/BeggingContract.sol test/BeggingContract.t.sol
git commit -m "feat: emit donation and withdrawal events"
```

---

### Task 4: Top3 捐赠排行榜

**Files:**
- Modify: `src/BeggingContract.sol`
- Modify: `test/BeggingContract.t.sol`

**Interfaces:**
- Produces:
  ```solidity
  function getTopDonors()
      external view
      returns (address[] memory topAddresses, uint256[] memory topAmounts);
  ```

- [x] **Step 1: 写失败测试**

```solidity
function testTopDonorsEmpty() public view {
    (address[] memory addrs, uint256[] memory amounts) = begging.getTopDonors();
    assertEq(addrs.length, 0);
    assertEq(amounts.length, 0);
}
function testTopDonorsFewerThanThree() public { /* 2 人，断言长度 2、降序 */ }
function testTopDonorsSortedDescending() public {
    // 4 人金额 1,5,3,4 => [5,4,3]
}
function testTopDonorsTieKeepsEarlierFirst() public {
    // alice 1, bob 1, carol 1 => [alice,bob,carol]
}
```

- [x] **Step 2: 运行并确认失败**

Run: `forge test --match-test "TopDonors" -vvv`
Expected: 编译失败。

- [x] **Step 3: 实现**

view 函数遍历 `donors`：维护长度 ≤3 的降序数组；每个地址与当前末位比较，严格大于才插入，金额相等时保留先出现者；返回 `min(3, donors.length)` 长度的两个数组。

- [x] **Step 4: 运行测试通过**

Run: `forge test --match-test "TopDonors" -vvv`
Expected: PASS。

- [x] **Step 5: 提交**

```bash
git add src/BeggingContract.sol test/BeggingContract.t.sol
git commit -m "feat: add top three donors view"
```

---

### Task 5: 捐赠时间窗口

**Files:**
- Modify: `src/BeggingContract.sol`
- Modify: `test/BeggingContract.t.sol`

**Interfaces:**
- Produces: `donate` 受 `onlyDuringDonationWindow` 约束；`startTime`/`endTime` 已在 Task 2 定义为 immutable。

- [x] **Step 1: 写失败测试**

```solidity
function testDonateBeforeStartReverts() public {
    vm.warp(begging.startTime() - 1);
    vm.prank(alice); vm.expectRevert(); begging.donate{value: 1 ether}();
}
function testDonateAtStartSucceeds() public {
    vm.warp(begging.startTime());
    vm.prank(alice); begging.donate{value: 1 ether}();
    assertEq(begging.getDonation(alice), 1 ether);
}
function testDonateAtEndSucceeds() public {
    vm.warp(begging.endTime());
    vm.prank(alice); begging.donate{value: 1 ether}();
    assertEq(begging.getDonation(alice), 1 ether);
}
function testDonateAfterEndReverts() public {
    vm.warp(begging.endTime() + 1);
    vm.prank(alice); vm.expectRevert(); begging.donate{value: 1 ether}();
}
function testConstructorRejectsInvalidWindow() public {
    vm.expectRevert(); new BeggingContract(100, 100);
}
```

- [x] **Step 2: 运行并确认失败**

Run: `forge test --match-test "Donate.*(Start|End|Window)|Constructor" -vvv`
Expected: 窗口外捐赠的测试 FAIL。

- [x] **Step 3: 实现**

加 modifier：
```solidity
modifier onlyDuringDonationWindow() {
    require(block.timestamp >= startTime && block.timestamp <= endTime, "donation window closed");
    _;
}
```
挂到 `donate`。

- [x] **Step 4: 运行全部测试**

Run: `forge test -vvv`
Expected: 全部 PASS（含 Task 2–4 的测试，注意 Task 2 的 fuzz 测试在 setUp 的窗口内执行）。

- [x] **Step 5: 提交**

```bash
git add src/BeggingContract.sol test/BeggingContract.t.sol
git commit -m "feat: restrict donations to time window"
```

---

### Task 6: 部署脚本、README 与全量验证

**Files:**
- Create: `script/Deploy.s.sol`, `.env.example`
- Modify: `README.md`

**Interfaces:**
- Consumes: `BeggingContract(uint256,uint256)`。

- [x] **Step 1: 写部署脚本**

```solidity
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
```

`.env.example`：
```
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/<key>
PRIVATE_KEY=<your_test_wallet_private_key>
ETHERSCAN_API_KEY=<your_etherscan_key>
```

- [x] **Step 2: 编译并测试**

Run: `forge build && forge test -vvv`
Expected: 编译成功，全部测试 PASS。

- [x] **Step 3: 补全 README**

内容：
- 作业来源链接、功能清单（必做 + 三个可选挑战及实现方式）。
- 合约接口与行为说明（时间窗口闭区间、Top3 平手规则、transfer 与现代 call 的差异说明）。
- 本地测试：`forge test -vvv`。
- Sepolia 部署（forge 路径）：
  ```bash
  cp .env.example .env   # 填入真实值，.env 不入库
  source .env
  forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
  ```
- Remix 路径：把 `src/BeggingContract.sol` 粘贴进 Remix，构造参数填 `startTime`/`endTime`（Unix 时间戳），部署到 Sepolia。
- 合约地址占位：`<待部署后填写>`；测试截图占位：`<待补充>`。
- 安全说明：私钥只放在本地 `.env`，测试用临时钱包。

- [x] **Step 4: 格式检查并提交**

Run: `forge fmt --check`
Expected: 退出码 0；若有差异 `forge fmt` 后再跑 `forge test`。
```bash
git add script/Deploy.s.sol .env.example README.md
git commit -m "docs: add deployment script and usage documentation"
```

---

### Task 7: 创建并推送远程仓库

**前置条件：** 用户已在 GitHub 创建空仓库 `zzhullong/solidity-homework02`，或提供了可创建仓库的凭据。

- [x] **Step 1: 关联远程**

```bash
cd /Users/zulg/solidity-homework02
git remote add origin git@github.com:zzhullong/solidity-homework02.git
```

- [x] **Step 2: 推送并验证**

```bash
git push -u origin main
git ls-remote --heads origin
```
Expected: 输出包含 `refs/heads/main`，SHA 与本地 HEAD 一致。
