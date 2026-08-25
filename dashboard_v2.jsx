import { useState, useEffect, useRef } from "react";

const SCHEMES = [
  { name: "Tanky No. 2", sets: 4, entries: 12, amount: 892340, status: "active" },
  { name: "Tanky No. 1", sets: 3, entries: 9, amount: 641200, status: "active" },
  { name: "Mehboob Colony", sets: 2, entries: 6, amount: 429800, status: "active" },
  { name: "Hussain Colony", sets: 2, entries: 4, amount: 318500, status: "warning" },
  { name: "14G Water Works", sets: 1, entries: 3, amount: 198400, status: "active" },
  { name: "46F Water Works", sets: 2, entries: 5, amount: 284600, status: "active" },
];

const MONTHLY = [
  { m: "Aug", v: 1.89 }, { m: "Sep", v: 2.45 }, { m: "Oct", v: 1.98 },
  { m: "Nov", v: 3.12 }, { m: "Dec", v: 2.67 }, { m: "Jan", v: 2.84 },
];

const MACHINERY = [
  { name: "Motor", running: 17, total: 32, color: "#60A5FA", glow: "rgba(96,165,250,0.3)", variants: [{ l: "20HP", n: 1 }, { l: "25HP", n: 11 }, { l: "30HP", n: 3 }, { l: "40HP", n: 10 }, { l: "50HP", n: 7 }] },
  { name: "Pump", running: 12, total: 12, color: "#34D399", glow: "rgba(52,211,153,0.3)", variants: [{ l: "3×4", n: 3 }, { l: "4×5", n: 7 }, { l: "5×6", n: 2 }] },
  { name: "Transformer", running: 20, total: 24, color: "#FBBF24", glow: "rgba(251,191,36,0.3)", variants: [{ l: "25kV", n: 7 }, { l: "50kV", n: 14 }, { l: "100kV", n: 2 }, { l: "200kV", n: 1 }] },
  { name: "Turbine", running: 13, total: 20, color: "#A78BFA", glow: "rgba(167,139,250,0.3)", variants: [{ l: "Standard", n: 20 }] },
];

const ENTRIES = [
  { scheme: "Tanky No. 2", set: "Set 1", type: "Motor", voucher: 2303, amount: 86192, date: "20-11-2025", reg: "P-44" },
  { scheme: "Mehboob Colony", set: "Set 1", type: "Pump", voucher: 2321, amount: 89605, date: "12-02-2025", reg: "P-71" },
  { scheme: "Tanky No. 1", set: "Set 2", type: "Transformer", voucher: 1490, amount: 59818, date: "19-09-2024", reg: "P-38" },
  { scheme: "Hussain Colony", set: "Set 1", type: "Motor", voucher: 1861, amount: 111319, date: "04-12-2025", reg: "P-55" },
  { scheme: "14G Water Works", set: "Set 1", type: "Pump", voucher: 1111, amount: 65920, date: "05-03-2025", reg: "P-29" },
];

const TYPE_STYLE = {
  Motor:       { bg: "rgba(96,165,250,0.12)",  text: "#60A5FA",  dot: "#60A5FA"  },
  Pump:        { bg: "rgba(52,211,153,0.12)",  text: "#34D399",  dot: "#34D399"  },
  Transformer: { bg: "rgba(251,191,36,0.12)",  text: "#FBBF24",  dot: "#FBBF24"  },
  Turbine:     { bg: "rgba(167,139,250,0.12)", text: "#A78BFA",  dot: "#A78BFA"  },
};

function Rs(n) { return "Rs. " + Number(n).toLocaleString("en-PK"); }

function AnimatedNumber({ target, duration = 1200, prefix = "", suffix = "" }) {
  const [val, setVal] = useState(0);
  useEffect(() => {
    let start = null;
    const step = (ts) => {
      if (!start) start = ts;
      const prog = Math.min((ts - start) / duration, 1);
      const ease = 1 - Math.pow(1 - prog, 3);
      setVal(Math.floor(ease * target));
      if (prog < 1) requestAnimationFrame(step);
    };
    requestAnimationFrame(step);
  }, [target]);
  return <span>{prefix}{val.toLocaleString("en-PK")}{suffix}</span>;
}

function SparkBar({ data }) {
  const max = Math.max(...data.map(d => d.v));
  return (
    <div style={{ display: "flex", alignItems: "flex-end", gap: 5, height: 64 }}>
      {data.map((d, i) => {
        const isLast = i === data.length - 1;
        const h = Math.max((d.v / max) * 64, 6);
        return (
          <div key={i} style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 3 }}>
            <div style={{
              width: "100%", height: h, borderRadius: "4px 4px 0 0",
              background: isLast
                ? "linear-gradient(180deg, #60A5FA, #3B82F6)"
                : "rgba(255,255,255,0.06)",
              border: isLast ? "none" : "1px solid rgba(255,255,255,0.08)",
              boxShadow: isLast ? "0 0 12px rgba(96,165,250,0.4)" : "none",
              transition: "height 0.6s cubic-bezier(0.34,1.56,0.64,1)",
              position: "relative",
            }}>
              {isLast && <div style={{ position: "absolute", top: -1, left: 0, right: 0, height: 1, background: "#93C5FD", borderRadius: 1 }} />}
            </div>
            <span style={{ fontSize: 9, color: isLast ? "#60A5FA" : "rgba(255,255,255,0.25)", fontWeight: isLast ? 700 : 400, letterSpacing: "0.3px" }}>{d.m}</span>
          </div>
        );
      })}
    </div>
  );
}

function RingMeter({ running, total, color, glow, size = 52 }) {
  const r = (size - 10) / 2;
  const circ = 2 * Math.PI * r;
  const pct = running / total;
  return (
    <svg width={size} height={size} style={{ transform: "rotate(-90deg)", flexShrink: 0 }}>
      <circle cx={size/2} cy={size/2} r={r} fill="none" stroke="rgba(255,255,255,0.06)" strokeWidth={5} />
      <circle cx={size/2} cy={size/2} r={r} fill="none" stroke={color} strokeWidth={5}
        strokeDasharray={`${circ * pct} ${circ * (1 - pct)}`}
        strokeLinecap="round"
        style={{ filter: `drop-shadow(0 0 4px ${glow})` }} />
    </svg>
  );
}

const NAV = [
  { id: "dashboard", label: "Dashboard", icon: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/></svg> },
  { id: "schemes",   label: "Schemes",   icon: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/></svg> },
  { id: "import",    label: "Import",    icon: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg> },
  { id: "export",    label: "Export",    icon: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg> },
  { id: "backup",    label: "Backup",    icon: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg> },
  { id: "settings",  label: "Settings",  icon: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 00.33 1.82l.06.06a2 2 0 010 2.83 2 2 0 01-2.83 0l-.06-.06a1.65 1.65 0 00-1.82-.33 1.65 1.65 0 00-1 1.51V21a2 2 0 01-4 0v-.09A1.65 1.65 0 009 19.4a1.65 1.65 0 00-1.82.33l-.06.06a2 2 0 01-2.83-2.83l.06-.06A1.65 1.65 0 004.68 15a1.65 1.65 0 00-1.51-1H3a2 2 0 010-4h.09A1.65 1.65 0 004.6 9a1.65 1.65 0 00-.33-1.82l-.06-.06a2 2 0 012.83-2.83l.06.06A1.65 1.65 0 009 4.68a1.65 1.65 0 001-1.51V3a2 2 0 014 0v.09a1.65 1.65 0 001 1.51 1.65 1.65 0 001.82-.33l.06-.06a2 2 0 012.83 2.83l-.06.06A1.65 1.65 0 0019.4 9a1.65 1.65 0 001.51 1H21a2 2 0 010 4h-.09a1.65 1.65 0 00-1.51 1z"/></svg> },
];

export default function App() {
  const [active, setActive] = useState("dashboard");
  const [search, setSearch] = useState("");
  const totalRunning = MACHINERY.reduce((s, m) => s + m.running, 0);
  const totalUnits   = MACHINERY.reduce((s, m) => s + m.total, 0);
  const opRate = Math.round((totalRunning / totalUnits) * 100);

  const css = `
    @import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@300;400;500;600;700&family=DM+Mono:wght@400;500&display=swap');
    * { box-sizing: border-box; margin: 0; padding: 0; }
    ::-webkit-scrollbar { width: 4px; height: 4px; }
    ::-webkit-scrollbar-track { background: transparent; }
    ::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.1); border-radius: 4px; }
    @keyframes fadeUp { from { opacity:0; transform:translateY(14px); } to { opacity:1; transform:translateY(0); } }
    @keyframes pulse-ring { 0%,100% { opacity:0.6; } 50% { opacity:1; } }
    .card { animation: fadeUp 0.5s ease both; }
    .card:nth-child(1) { animation-delay: 0.05s; }
    .card:nth-child(2) { animation-delay: 0.10s; }
    .card:nth-child(3) { animation-delay: 0.15s; }
    .card:nth-child(4) { animation-delay: 0.20s; }
    .nav-item:hover .nav-label { color: #F1F5F9 !important; }
    .action-btn:hover { transform: translateY(-1px); filter: brightness(1.1); }
    .action-btn { transition: transform 0.15s, filter 0.15s; }
    .entry-row:hover { background: rgba(255,255,255,0.04) !important; }
    .scheme-row:hover { background: rgba(255,255,255,0.04) !important; }
    input:focus { outline: none; border-color: rgba(96,165,250,0.5) !important; }
  `;

  return (
    <div style={{ fontFamily: "'DM Sans', sans-serif", background: "#0A0F1E", minHeight: "100vh", display: "flex", color: "#E2E8F0" }}>
      <style>{css}</style>

      {/* ══════ SIDEBAR ══════ */}
      <aside style={{
        width: 230, minWidth: 230, background: "rgba(255,255,255,0.03)",
        borderRight: "1px solid rgba(255,255,255,0.06)",
        display: "flex", flexDirection: "column", height: "100vh",
        position: "sticky", top: 0,
      }}>
        {/* Logo */}
        <div style={{ padding: "22px 20px 18px", borderBottom: "1px solid rgba(255,255,255,0.05)" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <div style={{
              width: 38, height: 38, borderRadius: 12,
              background: "linear-gradient(135deg, #3B82F6 0%, #1D4ED8 100%)",
              display: "flex", alignItems: "center", justifyContent: "center",
              fontSize: 18, boxShadow: "0 0 20px rgba(59,130,246,0.35), inset 0 1px 0 rgba(255,255,255,0.2)",
            }}>💧</div>
            <div>
              <div style={{ fontSize: 14, fontWeight: 700, color: "#F1F5F9", letterSpacing: "-0.3px" }}>City Water</div>
              <div style={{ fontSize: 9, color: "rgba(255,255,255,0.3)", letterSpacing: "1.5px", textTransform: "uppercase", fontWeight: 500 }}>Works Admin</div>
            </div>
          </div>
        </div>

        {/* Nav links */}
        <nav style={{ flex: 1, padding: "14px 10px", display: "flex", flexDirection: "column", gap: 2 }}>
          <div style={{ fontSize: 9, color: "rgba(255,255,255,0.2)", letterSpacing: "1.4px", textTransform: "uppercase", fontWeight: 600, padding: "0 10px 8px" }}>Navigation</div>
          {NAV.map(item => {
            const isActive = active === item.id;
            return (
              <div key={item.id} className="nav-item" onClick={() => setActive(item.id)}
                style={{
                  display: "flex", alignItems: "center", gap: 10, padding: "9px 12px",
                  borderRadius: 10, cursor: "pointer", position: "relative", overflow: "hidden",
                  background: isActive ? "rgba(59,130,246,0.12)" : "transparent",
                  border: isActive ? "1px solid rgba(59,130,246,0.2)" : "1px solid transparent",
                  transition: "all 0.15s ease",
                }}>
                {isActive && <div style={{ position: "absolute", left: 0, top: 8, bottom: 8, width: 3, background: "#3B82F6", borderRadius: "0 3px 3px 0", boxShadow: "0 0 8px #3B82F6" }} />}
                <span style={{ color: isActive ? "#60A5FA" : "rgba(255,255,255,0.3)", display: "flex", transition: "color 0.15s" }}>{item.icon}</span>
                <span className="nav-label" style={{ fontSize: 13, fontWeight: isActive ? 600 : 400, color: isActive ? "#93C5FD" : "rgba(255,255,255,0.4)", transition: "color 0.15s", letterSpacing: "-0.2px" }}>{item.label}</span>
              </div>
            );
          })}
        </nav>

        {/* System health pill */}
        <div style={{ margin: "0 12px 20px", padding: "14px", borderRadius: 12, background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.06)" }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 8 }}>
            <span style={{ fontSize: 10, color: "rgba(255,255,255,0.35)", fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.8px" }}>Operational</span>
            <span style={{ fontSize: 11, fontWeight: 700, color: opRate >= 80 ? "#34D399" : "#FBBF24" }}>{opRate}%</span>
          </div>
          <div style={{ height: 4, borderRadius: 4, background: "rgba(255,255,255,0.06)", overflow: "hidden" }}>
            <div style={{
              height: "100%", borderRadius: 4,
              width: `${opRate}%`,
              background: opRate >= 80 ? "linear-gradient(90deg,#10B981,#34D399)" : "linear-gradient(90deg,#F59E0B,#FBBF24)",
              boxShadow: opRate >= 80 ? "0 0 8px rgba(52,211,153,0.5)" : "0 0 8px rgba(251,191,36,0.5)",
              transition: "width 1s ease",
            }} />
          </div>
          <div style={{ marginTop: 8, display: "flex", justifyContent: "space-between" }}>
            <span style={{ fontSize: 10, color: "rgba(255,255,255,0.25)" }}>{totalRunning} running</span>
            <span style={{ fontSize: 10, color: "rgba(255,255,255,0.25)" }}>{totalUnits - totalRunning} idle</span>
          </div>
        </div>
      </aside>

      {/* ══════ MAIN ══════ */}
      <div style={{ flex: 1, display: "flex", flexDirection: "column", overflow: "hidden", minHeight: "100vh" }}>

        {/* Topbar */}
        <header style={{
          height: 62, display: "flex", alignItems: "center", gap: 14,
          padding: "0 24px",
          background: "rgba(255,255,255,0.02)",
          borderBottom: "1px solid rgba(255,255,255,0.05)",
          backdropFilter: "blur(12px)",
          position: "sticky", top: 0, zIndex: 10,
        }}>
          <div style={{ position: "relative", flex: 1, maxWidth: 380 }}>
            <svg style={{ position: "absolute", left: 12, top: "50%", transform: "translateY(-50%)", color: "rgba(255,255,255,0.2)" }} width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="11" cy="11" r="8"/><path d="M21 21l-4.35-4.35"/></svg>
            <input
              value={search} onChange={e => setSearch(e.target.value)}
              placeholder="Search schemes, vouchers, amounts..."
              style={{
                width: "100%", padding: "8px 12px 8px 36px",
                background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)",
                borderRadius: 10, color: "#E2E8F0", fontSize: 12,
                fontFamily: "'DM Sans', sans-serif",
                transition: "border-color 0.2s",
              }} />
          </div>

          <div style={{ display: "flex", gap: 8, marginLeft: "auto" }}>
            {[
              { label: "+ Add Scheme",    style: { background: "linear-gradient(135deg,#3B82F6,#1D4ED8)", color: "#fff", boxShadow: "0 2px 12px rgba(59,130,246,0.35)" } },
              { label: "⬆ Import",        style: { background: "rgba(255,255,255,0.06)", color: "rgba(255,255,255,0.6)", border: "1px solid rgba(255,255,255,0.08)" } },
              { label: "⬇ Export",        style: { background: "rgba(255,255,255,0.06)", color: "rgba(255,255,255,0.6)", border: "1px solid rgba(255,255,255,0.08)" } },
            ].map(b => (
              <button key={b.label} className="action-btn" style={{ ...b.style, padding: "7px 14px", borderRadius: 8, fontSize: 12, fontWeight: 600, cursor: "pointer", fontFamily: "'DM Sans', sans-serif", border: b.style.border || "none" }}>{b.label}</button>
            ))}
            <div style={{ width: 34, height: 34, borderRadius: "50%", background: "linear-gradient(135deg,#3B82F6,#8B5CF6)", display: "flex", alignItems: "center", justifyContent: "center", color: "#fff", fontSize: 12, fontWeight: 700, cursor: "pointer", boxShadow: "0 0 12px rgba(139,92,246,0.3)" }}>A</div>
          </div>
        </header>

        {/* Content */}
        <main style={{ flex: 1, overflowY: "auto", padding: "22px 24px", display: "flex", flexDirection: "column", gap: 18 }}>

          {/* Page header */}
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-end" }}>
            <div>
              <div style={{ fontSize: 9, letterSpacing: "2px", textTransform: "uppercase", color: "rgba(255,255,255,0.25)", fontWeight: 600, marginBottom: 4 }}>Overview</div>
              <h1 style={{ fontSize: 26, fontWeight: 700, color: "#F1F5F9", letterSpacing: "-0.8px", lineHeight: 1 }}>Dashboard</h1>
              <p style={{ marginTop: 4, fontSize: 12, color: "rgba(255,255,255,0.3)" }}>Monday, 02 March 2026 · Fiscal Year 2025–26</p>
            </div>
            <div style={{ display: "flex", alignItems: "center", gap: 6, padding: "6px 12px", borderRadius: 20, background: "rgba(52,211,153,0.08)", border: "1px solid rgba(52,211,153,0.2)" }}>
              <div style={{ width: 6, height: 6, borderRadius: "50%", background: "#34D399", boxShadow: "0 0 8px #34D399", animation: "pulse-ring 2s infinite" }} />
              <span style={{ fontSize: 11, fontWeight: 600, color: "#34D399" }}>All Systems Active</span>
            </div>
          </div>

          {/* ── KPI CARDS ── */}
          <div style={{ display: "grid", gridTemplateColumns: "repeat(4,1fr)", gap: 12 }}>
            {[
              { label: "Total Schemes", value: 12, prefix: "", suffix: "", sub: "Water works locations", trend: "+2 this year", trendUp: true, accent: "#3B82F6", icon: "💧" },
              { label: "Total Sets",    value: 20, prefix: "", suffix: "", sub: "Machinery groups",     trend: "Across all schemes", trendUp: true, accent: "#A78BFA", icon: "⚙️" },
              { label: "Entries / Month", value: 47, prefix: "", suffix: "", sub: "Billing records",   trend: "+12% vs prior", trendUp: true, accent: "#34D399", icon: "📋" },
              { label: "Amount / Month", value: 284500, prefix: "Rs. ", suffix: "", sub: "Total expenditure", trend: "+8.4% vs prior", trendUp: true, accent: "#FBBF24", icon: "₨", large: true },
            ].map((c, i) => (
              <div key={i} className="card" style={{
                background: "rgba(255,255,255,0.03)",
                border: "1px solid rgba(255,255,255,0.06)",
                borderRadius: 14, padding: "18px 18px 16px",
                position: "relative", overflow: "hidden",
              }}>
                {/* Ambient glow */}
                <div style={{ position: "absolute", top: -30, right: -30, width: 80, height: 80, borderRadius: "50%", background: c.accent, opacity: 0.07, filter: "blur(20px)", pointerEvents: "none" }} />
                {/* Top accent line */}
                <div style={{ position: "absolute", top: 0, left: 16, right: 16, height: 1, background: `linear-gradient(90deg, transparent, ${c.accent}50, transparent)` }} />

                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 14 }}>
                  <span style={{ fontSize: 11, color: "rgba(255,255,255,0.4)", fontWeight: 500, letterSpacing: "0.2px" }}>{c.label}</span>
                  <div style={{ fontSize: 18, opacity: 0.7 }}>{c.icon}</div>
                </div>
                <div style={{ fontSize: c.large ? 17 : 30, fontWeight: 700, color: c.accent, letterSpacing: c.large ? "-0.3px" : "-1px", lineHeight: 1, fontFamily: c.large ? "'DM Mono', monospace" : "'DM Sans', sans-serif" }}>
                  <AnimatedNumber target={c.value} prefix={c.prefix} suffix={c.suffix} />
                </div>
                <div style={{ marginTop: 10, display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                  <span style={{ fontSize: 10, color: "rgba(255,255,255,0.25)" }}>{c.sub}</span>
                  <span style={{ fontSize: 9, fontWeight: 700, color: "#34D399", background: "rgba(52,211,153,0.1)", padding: "2px 7px", borderRadius: 20, letterSpacing: "0.3px" }}>↑ {c.trend}</span>
                </div>
              </div>
            ))}
          </div>

          {/* ── ROW 2: TREND CHART + MACHINERY STATUS ── */}
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1.2fr", gap: 12 }}>

            {/* Monthly Trend */}
            <div style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.06)", borderRadius: 14, padding: "18px 20px" }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 18 }}>
                <div>
                  <div style={{ fontSize: 13, fontWeight: 700, color: "#F1F5F9" }}>Monthly Expenditure</div>
                  <div style={{ fontSize: 11, color: "rgba(255,255,255,0.3)", marginTop: 2 }}>Aug 2025 – Jan 2026</div>
                </div>
                <div style={{ textAlign: "right" }}>
                  <div style={{ fontSize: 15, fontWeight: 700, color: "#60A5FA", fontFamily: "'DM Mono', monospace" }}>Rs. 2.84M</div>
                  <div style={{ fontSize: 10, color: "#34D399", marginTop: 1 }}>↑ 8.4% this month</div>
                </div>
              </div>
              <SparkBar data={MONTHLY} />
              <div style={{ display: "flex", justifyContent: "space-between", marginTop: 6 }}>
                {MONTHLY.map((d, i) => (
                  <div key={i} style={{ flex: 1, textAlign: "center" }}>
                    <span style={{ fontSize: 9, color: i === MONTHLY.length - 1 ? "#60A5FA" : "rgba(255,255,255,0.2)", fontFamily: "'DM Mono', monospace", fontWeight: i === MONTHLY.length - 1 ? 600 : 400 }}>
                      {d.v}M
                    </span>
                  </div>
                ))}
              </div>
            </div>

            {/* Machinery Overview */}
            <div style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.06)", borderRadius: 14, padding: "18px 20px" }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 14 }}>
                <div>
                  <div style={{ fontSize: 13, fontWeight: 700, color: "#F1F5F9" }}>Machinery Status</div>
                  <div style={{ fontSize: 11, color: "rgba(255,255,255,0.3)", marginTop: 2 }}>{totalRunning}/{totalUnits} operational · {opRate}% uptime</div>
                </div>
                <button className="action-btn" style={{ padding: "5px 12px", borderRadius: 8, background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.5)", fontSize: 11, fontWeight: 600, cursor: "pointer", fontFamily: "'DM Sans', sans-serif" }}>PDF Report</button>
              </div>

              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8 }}>
                {MACHINERY.map(m => {
                  const pct = Math.round((m.running / m.total) * 100);
                  return (
                    <div key={m.name} style={{
                      padding: "12px 12px", borderRadius: 10,
                      background: "rgba(255,255,255,0.02)",
                      border: `1px solid ${m.color}20`,
                      display: "flex", alignItems: "center", gap: 10,
                    }}>
                      <RingMeter running={m.running} total={m.total} color={m.color} glow={m.glow} size={44} />
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                          <span style={{ fontSize: 12, fontWeight: 600, color: "#E2E8F0" }}>{m.name}</span>
                          <span style={{ fontSize: 11, fontWeight: 700, color: m.color, fontFamily: "'DM Mono', monospace" }}>{m.running}/{m.total}</span>
                        </div>
                        <div style={{ marginTop: 6, height: 3, borderRadius: 3, background: "rgba(255,255,255,0.06)", overflow: "hidden" }}>
                          <div style={{ height: "100%", width: `${pct}%`, background: m.color, borderRadius: 3, boxShadow: `0 0 6px ${m.glow}` }} />
                        </div>
                        <div style={{ marginTop: 5, display: "flex", flexWrap: "wrap", gap: 3 }}>
                          {m.variants.slice(0, 3).map(v => (
                            <span key={v.l} style={{ fontSize: 9, color: m.color, background: `${m.color}15`, border: `1px solid ${m.color}25`, borderRadius: 4, padding: "1px 5px", fontFamily: "'DM Mono', monospace" }}>{v.l}×{v.n}</span>
                          ))}
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          </div>

          {/* ── ROW 3: RECENT ENTRIES + SCHEMES ── */}
          <div style={{ display: "grid", gridTemplateColumns: "1.4fr 1fr", gap: 12 }}>

            {/* Recent Entries */}
            <div style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.06)", borderRadius: 14, padding: "18px 20px" }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 16 }}>
                <div>
                  <div style={{ fontSize: 13, fontWeight: 700, color: "#F1F5F9" }}>Recent Billing Entries</div>
                  <div style={{ fontSize: 11, color: "rgba(255,255,255,0.3)", marginTop: 2 }}>Latest 5 records across all schemes</div>
                </div>
                <button className="action-btn" style={{ padding: "6px 14px", borderRadius: 8, background: "linear-gradient(135deg,#3B82F6,#1D4ED8)", color: "#fff", fontSize: 11, fontWeight: 700, cursor: "pointer", fontFamily: "'DM Sans', sans-serif", border: "none", boxShadow: "0 2px 8px rgba(59,130,246,0.3)" }}>+ Add Entry</button>
              </div>

              {/* Table header */}
              <div style={{ display: "grid", gridTemplateColumns: "1.6fr 80px 80px 90px 60px", gap: 8, padding: "6px 10px", borderRadius: 6, marginBottom: 4 }}>
                {["Scheme", "Type", "Voucher", "Amount", "Reg."].map(h => (
                  <span key={h} style={{ fontSize: 9, fontWeight: 700, color: "rgba(255,255,255,0.2)", textTransform: "uppercase", letterSpacing: "1px" }}>{h}</span>
                ))}
              </div>

              <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>
                {ENTRIES.map((e, i) => {
                  const ts = TYPE_STYLE[e.type] || {};
                  return (
                    <div key={i} className="entry-row" style={{
                      display: "grid", gridTemplateColumns: "1.6fr 80px 80px 90px 60px",
                      gap: 8, padding: "9px 10px", borderRadius: 8,
                      background: "rgba(255,255,255,0.01)", border: "1px solid rgba(255,255,255,0.04)",
                      alignItems: "center", cursor: "pointer", transition: "background 0.15s",
                    }}>
                      <div>
                        <div style={{ fontSize: 12, fontWeight: 600, color: "#E2E8F0", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{e.scheme}</div>
                        <div style={{ fontSize: 10, color: "rgba(255,255,255,0.25)", marginTop: 1 }}>{e.set} · {e.date}</div>
                      </div>
                      <div style={{ display: "inline-flex", alignItems: "center", gap: 4, background: ts.bg, borderRadius: 5, padding: "3px 8px" }}>
                        <div style={{ width: 4, height: 4, borderRadius: "50%", background: ts.dot, flexShrink: 0 }} />
                        <span style={{ fontSize: 10, fontWeight: 600, color: ts.text }}>{e.type}</span>
                      </div>
                      <span style={{ fontSize: 11, color: "rgba(255,255,255,0.4)", fontFamily: "'DM Mono', monospace" }}>#{e.voucher}</span>
                      <span style={{ fontSize: 11, fontWeight: 600, color: "#F1F5F9", fontFamily: "'DM Mono', monospace" }}>{Rs(e.amount)}</span>
                      <span style={{ fontSize: 10, color: "rgba(255,255,255,0.3)", fontFamily: "'DM Mono', monospace", background: "rgba(255,255,255,0.04)", padding: "2px 6px", borderRadius: 4, textAlign: "center" }}>{e.reg}</span>
                    </div>
                  );
                })}
              </div>

              <div style={{ marginTop: 10, display: "flex", gap: 8 }}>
                <button className="action-btn" style={{ flex: 1, padding: "8px", borderRadius: 8, border: "1px dashed rgba(255,255,255,0.1)", background: "transparent", color: "rgba(255,255,255,0.3)", fontSize: 11, fontWeight: 600, cursor: "pointer", fontFamily: "'DM Sans', sans-serif" }}>View all entries →</button>
                <button className="action-btn" style={{ padding: "8px 14px", borderRadius: 8, border: "1px solid rgba(251,191,36,0.2)", background: "rgba(251,191,36,0.06)", color: "#FBBF24", fontSize: 11, fontWeight: 600, cursor: "pointer", fontFamily: "'DM Sans', sans-serif" }}>📄 PDF</button>
                <button className="action-btn" style={{ padding: "8px 14px", borderRadius: 8, border: "1px solid rgba(52,211,153,0.2)", background: "rgba(52,211,153,0.06)", color: "#34D399", fontSize: 11, fontWeight: 600, cursor: "pointer", fontFamily: "'DM Sans', sans-serif" }}>💬 Share</button>
              </div>
            </div>

            {/* Schemes List */}
            <div style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.06)", borderRadius: 14, padding: "18px 20px" }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 16 }}>
                <div>
                  <div style={{ fontSize: 13, fontWeight: 700, color: "#F1F5F9" }}>Schemes</div>
                  <div style={{ fontSize: 11, color: "rgba(255,255,255,0.3)", marginTop: 2 }}>All water works locations</div>
                </div>
                <span style={{ fontSize: 11, color: "rgba(255,255,255,0.2)", background: "rgba(255,255,255,0.05)", padding: "3px 10px", borderRadius: 20, fontWeight: 600 }}>12 total</span>
              </div>

              <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
                {SCHEMES.map((s, i) => {
                  const barW = Math.round((s.amount / 892340) * 100);
                  return (
                    <div key={i} className="scheme-row" style={{
                      padding: "10px 12px", borderRadius: 8,
                      background: "rgba(255,255,255,0.02)", border: "1px solid rgba(255,255,255,0.04)",
                      cursor: "pointer", transition: "background 0.15s",
                    }}>
                      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 6 }}>
                        <div style={{ display: "flex", alignItems: "center", gap: 7 }}>
                          <div style={{ width: 6, height: 6, borderRadius: "50%", background: s.status === "active" ? "#34D399" : "#FBBF24", boxShadow: `0 0 6px ${s.status === "active" ? "#34D399" : "#FBBF24"}` }} />
                          <span style={{ fontSize: 12, fontWeight: 600, color: "#E2E8F0" }}>{s.name}</span>
                        </div>
                        <span style={{ fontSize: 11, fontWeight: 700, color: "#F1F5F9", fontFamily: "'DM Mono', monospace" }}>
                          {(s.amount / 1000).toFixed(0)}K
                        </span>
                      </div>
                      <div style={{ height: 3, borderRadius: 3, background: "rgba(255,255,255,0.05)", overflow: "hidden", marginBottom: 6 }}>
                        <div style={{ height: "100%", width: `${barW}%`, background: "linear-gradient(90deg,#3B82F6,#60A5FA)", borderRadius: 3 }} />
                      </div>
                      <div style={{ display: "flex", gap: 12 }}>
                        <span style={{ fontSize: 10, color: "rgba(255,255,255,0.25)" }}>{s.sets} sets</span>
                        <span style={{ fontSize: 10, color: "rgba(255,255,255,0.25)" }}>{s.entries} entries</span>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          </div>

          {/* ── QUICK ACTIONS ROW ── */}
          <div style={{ display: "grid", gridTemplateColumns: "repeat(6,1fr)", gap: 10 }}>
            {[
              { icon: "📁", label: "Import Excel", sub: ".xlsx / .csv", color: "#A78BFA", bg: "rgba(167,139,250,0.08)", border: "rgba(167,139,250,0.2)" },
              { icon: "📄", label: "Export PDF", sub: "Full report", color: "#FBBF24", bg: "rgba(251,191,36,0.08)", border: "rgba(251,191,36,0.2)" },
              { icon: "📊", label: "Export Excel", sub: ".xlsx format", color: "#34D399", bg: "rgba(52,211,153,0.08)", border: "rgba(52,211,153,0.2)" },
              { icon: "💬", label: "WhatsApp Share", sub: "Send PDF", color: "#25D366", bg: "rgba(37,211,102,0.08)", border: "rgba(37,211,102,0.2)" },
              { icon: "🛡", label: "Backup Data", sub: ".cww archive", color: "#60A5FA", bg: "rgba(96,165,250,0.08)", border: "rgba(96,165,250,0.2)" },
              { icon: "⚙️", label: "Settings", sub: "App config", color: "rgba(255,255,255,0.4)", bg: "rgba(255,255,255,0.03)", border: "rgba(255,255,255,0.08)" },
            ].map((a, i) => (
              <button key={i} className="action-btn" style={{
                padding: "14px 12px", borderRadius: 12,
                background: a.bg, border: `1px solid ${a.border}`,
                cursor: "pointer", textAlign: "left", fontFamily: "'DM Sans', sans-serif",
                display: "flex", flexDirection: "column", gap: 6,
              }}>
                <span style={{ fontSize: 20 }}>{a.icon}</span>
                <div>
                  <div style={{ fontSize: 11, fontWeight: 700, color: a.color, letterSpacing: "-0.2px" }}>{a.label}</div>
                  <div style={{ fontSize: 10, color: "rgba(255,255,255,0.2)", marginTop: 1 }}>{a.sub}</div>
                </div>
              </button>
            ))}
          </div>

        </main>
      </div>
    </div>
  );
}
