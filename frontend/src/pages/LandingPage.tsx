import { useEffect, useState } from "react";
import "../styles/economy.css";
import "../styles/landing.css";

type Props = {
  onOpenConsole: () => void;
  onOpenMiniApp: () => void;
  telegramUrl?: string;
};

/**
 * Commercial official entry (官网经济入口).
 * Hero: brand-first, one headline, one line, one CTA group, full-bleed atmosphere.
 */
export function LandingPage({ onOpenConsole, onOpenMiniApp, telegramUrl }: Props) {
  const [ready, setReady] = useState(false);
  useEffect(() => {
    const t = requestAnimationFrame(() => setReady(true));
    return () => cancelAnimationFrame(t);
  }, []);

  const tg = telegramUrl || import.meta.env.VITE_TELEGRAM_BOT_URL || "";

  return (
    <div className={`karma-landing ${ready ? "is-ready" : ""}`}>
      <div className="karma-landing-atmosphere" aria-hidden />
      <header className="karma-landing-nav">
        <span className="karma-landing-nav-brand">KARMA</span>
        <nav className="karma-landing-nav-links">
          <button type="button" className="karma-landing-link" onClick={onOpenConsole}>
            Console
          </button>
          <a className="karma-landing-link" href="/health.json" target="_blank" rel="noreferrer">
            Status
          </a>
        </nav>
      </header>

      <main className="karma-landing-hero">
        <p className="karma-landing-brand">KARMA</p>
        <h1 className="karma-landing-title">结算与贡献经济，接到每一次成交</h1>
        <p className="karma-landing-lead">
          在 Telegram 完成验证与履约，手续费与贡献激励由链上经济仓自动记账——冷启动零扣费，正式运营一键开启。
        </p>
        <div className="karma-landing-cta">
          {tg ? (
            <a className="karma-btn karma-btn-primary karma-landing-cta-main" href={tg} target="_blank" rel="noreferrer">
              打开 Telegram
            </a>
          ) : (
            <button type="button" className="karma-btn karma-btn-primary karma-landing-cta-main" onClick={onOpenMiniApp}>
              打开经济 MiniApp
            </button>
          )}
          <button type="button" className="karma-btn karma-btn-ghost" onClick={onOpenMiniApp}>
            经济面预览
          </button>
          <button type="button" className="karma-btn karma-btn-ghost" onClick={onOpenConsole}>
            运营控制台
          </button>
        </div>
      </main>

      <section className="karma-landing-strip" aria-label="how it works">
        <h2>官网 → Bot → 验证 → 经济</h2>
        <p>
          主仓负责身份、订单与 Verification；karma8 在 settle 后写入国库与 GMV。商业试点默认冷启动，公开收费前须通过治理门禁。
        </p>
        <ol className="karma-landing-steps">
          <li>
            <strong>官网</strong>
            <span>了解产品并进入 Telegram</span>
          </li>
          <li>
            <strong>Bot / MiniApp</strong>
            <span>下单、举证、验证通过</span>
          </li>
          <li>
            <strong>经济仓</strong>
            <span>FeeBridge 记账 · 质押与贡献可见</span>
          </li>
        </ol>
      </section>

      <footer className="karma-landing-foot">
        <span>KARMA Economy</span>
        <span>冷启动 · fee=0 · GMV 仍记</span>
        <a href="/?view=miniapp">/?view=miniapp</a>
      </footer>
    </div>
  );
}
