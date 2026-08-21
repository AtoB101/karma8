# karma-economy frontend

可嵌入的 React 页面组件（wagmi + viem）。

## 页面

| 组件 | 功能 | 盈利关闭时 |
|------|------|------------|
| `StakePage` | 质押 / 查看权重 / 领分红 | 分红按钮置灰 |
| `NodeRegisterPage` | 仲裁节点注册 | 注册可用 |
| `GovernancePage` | 提案 / 投票 / 执行 | 投票可用 |
| `ContributionNftPage` | 贡献 NFT 申领状态 | 权重分红锁定 |
| `MiniAppEconomyPage` | Telegram 经济面（状态/钱包/收益/贡献） | 分红锁定；验证不在本页 |

## MiniApp 嵌入

```text
/?view=miniapp
/?view=miniapp&tab=rewards
```

主仓负责 initData 验签与 Verification；本页只展示经济合约状态。  
说明：[`../integrations/telegram-miniapp/ECONOMY_SURFACE.md`](../integrations/telegram-miniapp/ECONOMY_SURFACE.md)

环境：

```bash
# 根目录 .env
KARMA8_ECONOMY_HOST=https://economy.example.com
MINIAPP_ORIGIN=https://miniapp.example.com,https://web.telegram.org

# 前端
cp .env.example .env.local   # or:
npm run sync-addresses -- sepolia
npm run dev
```

Vite 使用 `MINIAPP_ORIGIN` 配置 CORS + CSP `frame-ancestors`（见 `vite.config.ts`）。

## 使用

```tsx
import { MiniAppEconomyPage, type EconomyAddresses } from "@karma8/economy-frontend";

const addresses: EconomyAddresses = {
  treasury: "0x...",
  stake: "0x...",
  governor: "0x...",
  stakerPool: "0x...",
  developerPool: "0x...",
  contributionNft: "0x...",
  karmaToken: "0x...",
  feeBridge: "0x...",
  settlementMirror: "0x...",
  contributorRegistry: "0x...",
  contributionLedger: "0x...",
  cocreationScore: "0x...",
  usdc: "0x...",
  karmaBilateral: "0x...",
};

export default function App() {
  return <MiniAppEconomyPage addresses={addresses} />;
}
```

需由宿主应用提供 `wagmi` / `viem` / `React` 与钱包连接上下文。  
引入字体（可选）：Fraunces + DM Sans。

```bash
npm i
npm run sync-addresses -- local   # 从 deployments/local.json
npm run dev
```
