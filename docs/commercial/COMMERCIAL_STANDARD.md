# KARMA 商业化标准（Commercial Standard）

定义「官网 → Telegram Bot → Karma 主仓 → karma8 经济」达到**可公开商业运营**的硬标准。  
本仓（karma8）交付经济侧与官网经济入口；主仓交付 Bot / 验证 / 结算编排。

---

## 商业化三阶段

| 阶段 | 名称 | 对外含义 | 收费 |
|------|------|----------|------|
| **P0** | 技术闭环 | 本地/测网可跑通 | OFF |
| **P1** | 公开冷启动**（商业试点）** | 官网+TG 可服务真实用户 | fee=0，记 GMV |
| **P2** | 正式收费运营 | 公开收费 | `enableRevenueMode=true` |

**「按商业化标准」= 至少达到 P1，并具备一键升到 P2 的门禁。**

---

## P1 准入门禁（必须全部满足）

### 产品闭环
- [ ] 官网可访问（HTTPS），品牌清晰，CTA 进 Telegram / 经济控制台
- [ ] Telegram Bot + MiniApp 可打开；initData **服务端验签**（主仓）
- [ ] SIWE / Identity / Session（主仓）
- [ ] Order → Evidence → **Verification PASS** → Bilateral settle（主仓）
- [ ] settle → FeeBridge `collectAndRecord`（fee==quote）；冷启动 fee=0
- [ ] 经济面 `/?view=miniapp` 可嵌；CSP `frame-ancestors` 正确
- [ ] self_deal 不计 developer GMV

### 工程与安全
- [ ] karma8 安全 Critical 修复已合入发布分支
- [ ] `make commercial-check` 通过
- [ ] `make verify-wiring` 对目标网络 OK
- [ ] 无无限 USDC approve；不信前端 tg id / 金额
- [ ] Bot Token / 私钥不进 git

### 运维
- [ ] 域名 + TLS；监控 / 告警（至少：站点 up、RPC 可达、FeeBridge.core 匹配）
- [ ] 事故手册可读（`OPS_RUNBOOK.md`）
- [ ] 支持渠道与状态页入口（官网页脚）

### 自动检查

```bash
make commercial-check
```

---

## P2 额外门禁（开收费）

- [ ] P1 稳定运行达到约定观察期（建议 ≥14 天或 ≥N 笔真实 settle）
- [ ] BUILDER 仅治理发放（链上已禁自领特权角色）
- [ ] 治理提案开启 `enableRevenueMode`（参与度法定人数）
- [ ] 回购策略评审（默认仍建议暂停直到明确运营）
- [ ] （强烈建议）第三方审计报告归档

```bash
# 开收费前再跑
ENABLE_REVENUE_CHECKS=1 make commercial-check
```

---

## 仓库职责

| 能力 | 主仓 Karma | karma8 |
|------|-----------|--------|
| 官网（品牌/获客） | 可自建；或链到本仓官网 | **本仓提供经济官网入口** |
| Telegram Bot / 验签 | **必须** | 否 |
| Verification | **必须** | 否 |
| Bilateral settle 编排 | **必须** | FeeBridge 接收 |
| 国库 / 质押 / 分红 / NFT | 否 | **必须** |
| MiniApp 经济面 | iframe | **必须** |

---

## 相关文件

- 你的操作：`integrations/telegram-miniapp/USER_OPS_CHECKLIST.md`
- 主仓要求：`integrations/telegram-miniapp/COMMERCIAL_MAIN_REQUIREMENTS.md`
- 运维手册：`docs/commercial/OPS_RUNBOOK.md`
- 门禁脚本：`scripts/commercial_gate.sh`
