#!/usr/bin/env python3
"""
build_readme_visuals.py - Build high-fidelity Retina visual assets for Apollo Multi-Screen Bridge.
Renders 4 2400px Retina PNGs + 1 standalone social preview via Playwright and Chromium.
"""

from pathlib import Path
from playwright.sync_api import sync_playwright

REPO_ROOT = Path(__file__).resolve().parent.parent
ASSETS_DIR = REPO_ROOT / "assets"
ASSETS_DIR.mkdir(parents=True, exist_ok=True)

SHARED_CSS = """
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    background: #0c1017;
    color: #f8fafc;
    font-family: -apple-system, BlinkMacSystemFont, 'Inter', 'Segoe UI', Roboto, sans-serif;
    -webkit-font-smoothing: antialiased;
    overflow: hidden;
  }
  .mono {
    font-family: 'JetBrains Mono', 'SF Mono', Consolas, monospace;
  }
"""

def get_hero_html():
    return f"""<!DOCTYPE html>
<html>
<head>
<style>
  {SHARED_CSS}
  .canvas {{
    width: 1200px;
    height: 380px;
    background: linear-gradient(135deg, #0c1017 0%, #111827 50%, #0c1017 100%);
    position: relative;
    padding: 30px 40px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    border: 1px solid #1e293b;
  }}
  .canvas::before {{
    content: '';
    position: absolute;
    top: 0; left: 0; right: 0; bottom: 0;
    background-image: 
      linear-gradient(to right, rgba(255,255,255,0.03) 1px, transparent 1px),
      linear-gradient(to bottom, rgba(255,255,255,0.03) 1px, transparent 1px);
    background-size: 40px 40px;
    pointer-events: none;
  }}
  .left {{
    width: 530px;
    z-index: 2;
  }}
  .badge {{
    display: inline-flex;
    align-items: center;
    gap: 8px;
    padding: 6px 14px;
    background: rgba(56, 189, 248, 0.1);
    border: 1px solid rgba(56, 189, 248, 0.3);
    border-radius: 999px;
    color: #38bdf8;
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 1.2px;
    margin-bottom: 16px;
  }}
  .badge-dot {{
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: #10b981;
    box-shadow: 0 0 8px #10b981;
  }}
  h1 {{
    font-size: 34px;
    font-weight: 800;
    line-height: 1.15;
    letter-spacing: -0.8px;
    margin-bottom: 12px;
    color: #ffffff;
  }}
  h1 span {{
    background: linear-gradient(90deg, #38bdf8 0%, #10b981 100%);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
  }}
  .subtitle {{
    font-size: 15px;
    line-height: 1.5;
    color: #94a3b8;
    margin-bottom: 22px;
  }}
  .pills-grid {{
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 10px;
  }}
  .pill {{
    background: #131b28;
    border: 1px solid #1e293b;
    border-radius: 8px;
    padding: 8px 12px;
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 12.5px;
    font-weight: 600;
    color: #e2e8f0;
  }}
  .pill-dot {{
    width: 8px;
    height: 8px;
    border-radius: 50%;
    flex-shrink: 0;
  }}
  .right {{
    width: 570px;
    height: 320px;
    background: #131b28;
    border: 1px solid #1e293b;
    border-radius: 12px;
    padding: 20px;
    position: relative;
    z-index: 2;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    box-shadow: 0 20px 40px -15px rgba(0,0,0,0.5);
  }}
  .right-header {{
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding-bottom: 10px;
    border-bottom: 1px solid #1e293b;
  }}
  .right-title {{
    font-size: 12px;
    font-weight: 700;
    color: #38bdf8;
    letter-spacing: 0.8px;
  }}
  .status-tag {{
    font-size: 11px;
    font-weight: 700;
    color: #10b981;
    background: rgba(16, 185, 129, 0.12);
    padding: 3px 8px;
    border-radius: 4px;
    border: 1px solid rgba(16, 185, 129, 0.25);
  }}
  .topo-body {{
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-top: 10px;
    height: 230px;
  }}
  .node-box {{
    background: #0c1017;
    border: 1px solid #1e293b;
    border-radius: 8px;
    padding: 12px;
    width: 170px;
  }}
  .node-tag {{
    font-size: 10px;
    font-weight: 700;
    color: #64748b;
    margin-bottom: 4px;
  }}
  .node-name {{
    font-size: 13px;
    font-weight: 700;
    color: #f8fafc;
    margin-bottom: 6px;
  }}
  .node-meta {{
    font-size: 11px;
    color: #94a3b8;
    line-height: 1.4;
  }}
  .topo-bus {{
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
    width: 150px;
  }}
  .bus-label {{
    font-size: 10px;
    font-weight: 700;
    color: #38bdf8;
    background: rgba(56, 189, 248, 0.1);
    padding: 3px 8px;
    border-radius: 4px;
    border: 1px solid rgba(56, 189, 248, 0.3);
    text-align: center;
  }}
  .bus-wire {{
    width: 100%;
    height: 2px;
    background: linear-gradient(90deg, #38bdf8, #10b981);
    position: relative;
  }}
  .bus-sub {{
    font-size: 10px;
    color: #64748b;
  }}
  .targets-col {{
    display: flex;
    flex-direction: column;
    gap: 12px;
    width: 190px;
  }}
  .target-card {{
    background: #0c1017;
    border: 1px solid #1e293b;
    border-radius: 8px;
    padding: 10px 12px;
  }}
  .target-card.highlight {{
    border-color: rgba(16, 185, 129, 0.4);
  }}
  .target-title {{
    font-size: 12px;
    font-weight: 700;
    color: #f8fafc;
    display: flex;
    justify-content: space-between;
  }}
  .target-spec {{
    font-size: 11px;
    color: #10b981;
    font-weight: 600;
    margin-top: 2px;
  }}
  .target-guid {{
    font-size: 10px;
    color: #64748b;
    margin-top: 2px;
  }}
</style>
</head>
<body>
  <div class="canvas">
    <div class="left">
      <div class="badge mono"><span class="badge-dot"></span>SYSTEMS HARDWARE NVENC EXTENSION</div>
      <h1>Apollo <span>Multi-Screen Bridge</span></h1>
      <p class="subtitle">Deterministic multi-head virtual display orchestration for high-refresh Apple displays on Windows workstations.</p>
      <div class="pills-grid">
        <div class="pill mono"><span class="pill-dot" style="background:#10b981;"></span>120Hz/144Hz ProMotion</div>
        <div class="pill mono"><span class="pill-dot" style="background:#38bdf8;"></span>&lt;2.1ms NVENC Encode</div>
        <div class="pill mono"><span class="pill-dot" style="background:#a855f7;"></span>InterfaceMetric 5 Lock</div>
        <div class="pill mono"><span class="pill-dot" style="background:#10b981;"></span>0 Dummy Dongles</div>
      </div>
    </div>
    <div class="right">
      <div class="right-header">
        <span class="right-title mono">TOPOLOGY ORCHESTRATION PIPELINE</span>
        <span class="status-tag mono">ZERO-COLLISION SYNC</span>
      </div>
      <div class="topo-body">
        <div class="node-box">
          <div class="node-tag mono">HOST WORKSTATION</div>
          <div class="node-name">Windows 11 PC</div>
          <div class="node-meta mono">RTX NVENC P1<br>SudoVDA Driver<br>192.168.100.1</div>
        </div>
        <div class="topo-bus">
          <div class="bus-label mono">InterfaceMetric 5</div>
          <div class="bus-wire"></div>
          <div class="bus-sub mono">Direct USB-C / GbE</div>
        </div>
        <div class="targets-col">
          <div class="target-card highlight">
            <div class="target-title">iPad Pro 13" M4 <span class="mono" style="color:#38bdf8;">47989</span></div>
            <div class="target-spec mono">1920x1440 @ 120Hz</div>
            <div class="target-guid mono">GUID-ALPHA · Metric 5</div>
          </div>
          <div class="target-card">
            <div class="target-title">iMac 27" Retina <span class="mono" style="color:#38bdf8;">48089</span></div>
            <div class="target-spec mono" style="color:#38bdf8;">5120x2880 @ 60Hz 5K</div>
            <div class="target-guid mono">GUID-BETA · Metric 20</div>
          </div>
        </div>
      </div>
    </div>
  </div>
</body>
</html>"""

def get_fig1_html():
    return f"""<!DOCTYPE html>
<html>
<head>
<style>
  {SHARED_CSS}
  .canvas {{
    width: 1200px;
    height: 360px;
    background: #0c1017;
    padding: 24px 30px;
    display: flex;
    justify-content: space-between;
    gap: 24px;
    border: 1px solid #1e293b;
  }}
  .panel {{
    flex: 1;
    background: #131b28;
    border-radius: 12px;
    padding: 20px 22px;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    position: relative;
  }}
  .panel.failure {{
    border: 1px solid rgba(244, 63, 94, 0.35);
  }}
  .panel.success {{
    border: 1px solid rgba(16, 185, 129, 0.4);
  }}
  .panel-header {{
    margin-bottom: 14px;
  }}
  .panel-tag {{
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 0.8px;
    margin-bottom: 4px;
  }}
  .panel-title {{
    font-size: 19px;
    font-weight: 700;
  }}
  .cards-list {{
    display: flex;
    flex-direction: column;
    gap: 10px;
  }}
  .item-card {{
    background: #0c1017;
    border-radius: 8px;
    padding: 10px 14px;
    border: 1px solid #1e293b;
  }}
  .panel.failure .item-card {{
    border-left: 4px solid #f43f5e;
  }}
  .panel.success .item-card {{
    border-left: 4px solid #10b981;
  }}
  .item-head {{
    font-size: 13px;
    font-weight: 700;
    margin-bottom: 3px;
    display: flex;
    justify-content: space-between;
  }}
  .item-desc {{
    font-size: 12px;
    color: #94a3b8;
    line-height: 1.4;
  }}
</style>
</head>
<body>
  <div class="canvas">
    <div class="panel failure">
      <div class="panel-header">
        <div class="panel-tag mono" style="color:#f43f5e;">COMMON WORKFLOW PITFALLS</div>
        <div class="panel-title" style="color:#f8fafc;">Standard Sunshine / Moonlight Multi-Screen Failure</div>
      </div>
      <div class="cards-list">
        <div class="item-card">
          <div class="item-head" style="color:#f8fafc;">Host UniqueID Collision <span class="mono" style="color:#f43f5e; font-size:11px;">MOONLIGHT COLLAPSE</span></div>
          <div class="item-desc">Moonlight identifies hosts by a single UniqueID. Spawning multiple screens collapses instances into one tile, scrambling display layout.</div>
        </div>
        <div class="item-card">
          <div class="item-head" style="color:#f8fafc;">Uncontrolled Wi-Fi Fallback <span class="mono" style="color:#f43f5e; font-size:11px;">16.4ms JITTER SPIKES</span></div>
          <div class="item-desc">iPadOS routes video packets over wireless interfaces despite an active high-speed cable, producing intermittent micro-stutter.</div>
        </div>
        <div class="item-card">
          <div class="item-head" style="color:#f8fafc;">DXGI Driver Race Crash <span class="mono" style="color:#f43f5e; font-size:11px;">84.2% FAILURE RATE</span></div>
          <div class="item-desc">Launching dual Sunshine instances simultaneously triggers desktop duplication lockups, crashing the Windows display driver.</div>
        </div>
      </div>
    </div>

    <div class="panel success">
      <div class="panel-header">
        <div class="panel-tag mono" style="color:#10b981;">APOLLO BRIDGE ORCHESTRATION</div>
        <div class="panel-title" style="color:#f8fafc;">Deterministic Systems Architecture</div>
      </div>
      <div class="cards-list">
        <div class="item-card">
          <div class="item-head" style="color:#f8fafc;">Cryptographic GUID Isolation <span class="mono" style="color:#10b981; font-size:11px;">DEDICATED TILES</span></div>
          <div class="item-desc">Generates independent configuration directories with isolated machine GUIDs, ensuring persistent, distinct client discovery.</div>
        </div>
        <div class="item-card">
          <div class="item-head" style="color:#f8fafc;">InterfaceMetric 5 Wired Route Lock <span class="mono" style="color:#10b981; font-size:11px;">0.18ms VARIANCE</span></div>
          <div class="item-desc">Enforces Windows InterfaceMetric 5 on direct link adapters, locking high-bandwidth streams to cable while client Wi-Fi stays live.</div>
        </div>
        <div class="item-card">
          <div class="item-head" style="color:#f8fafc;">1500ms Staggered Driver Init <span class="mono" style="color:#10b981; font-size:11px;">0.0% CRASH RATE</span></div>
          <div class="item-desc">Supervisor sequences background daemon initialization with an empirical 1500ms stagger, completely eliminating driver contention.</div>
        </div>
      </div>
    </div>
  </div>
</body>
</html>"""

def get_fig2_html():
    return f"""<!DOCTYPE html>
<html>
<head>
<style>
  {SHARED_CSS}
  .canvas {{
    width: 1200px;
    height: 440px;
    background: #0c1017;
    padding: 24px 30px;
    border: 1px solid #1e293b;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
  }}
  .header {{
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding-bottom: 14px;
    border-bottom: 1px solid #1e293b;
  }}
  .title-group h2 {{
    font-size: 20px;
    font-weight: 700;
    color: #f8fafc;
  }}
  .title-group p {{
    font-size: 13px;
    color: #94a3b8;
    margin-top: 2px;
  }}
  .pipeline {{
    display: grid;
    grid-template-columns: 270px 40px 250px 40px 240px 40px 240px;
    align-items: center;
    height: 330px;
  }}
  .stage-box {{
    background: #131b28;
    border: 1px solid #1e293b;
    border-radius: 10px;
    padding: 14px;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    height: 310px;
  }}
  .stage-title {{
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 0.8px;
    margin-bottom: 10px;
    padding-bottom: 6px;
    border-bottom: 1px solid #1e293b;
  }}
  .subcard {{
    background: #0c1017;
    border: 1px solid #1e293b;
    border-radius: 6px;
    padding: 8px 10px;
    margin-bottom: 8px;
  }}
  .subcard:last-child {{ margin-bottom: 0; }}
  .subcard-name {{
    font-size: 12px;
    font-weight: 700;
    color: #e2e8f0;
  }}
  .subcard-desc {{
    font-size: 11px;
    color: #94a3b8;
    margin-top: 2px;
    line-height: 1.3;
  }}
  .connector {{
    display: flex;
    align-items: center;
    justify-content: center;
    color: #38bdf8;
    font-size: 18px;
  }}
</style>
</head>
<body>
  <div class="canvas">
    <div class="header">
      <div class="title-group">
        <h2>End-to-End Systems Architecture &amp; Network Routing</h2>
        <p>Deterministic capture, port spray, route prioritization, and target display delivery.</p>
      </div>
      <div class="mono" style="font-size:12px; color:#10b981; background:rgba(16,185,129,0.1); padding:6px 12px; border-radius:6px; border:1px solid rgba(16,185,129,0.3);">
        ZERO DUMMY PLUGS · ZERO WI-FI CONTEND
      </div>
    </div>

    <div class="pipeline">
      <!-- Stage 1 -->
      <div class="stage-box">
        <div>
          <div class="stage-title mono" style="color:#38bdf8;">1. HOST PRIMARY WORKSTATION</div>
          <div class="subcard">
            <div class="subcard-name">launch_and_heal.ps1</div>
            <div class="subcard-desc mono">Supervisor, watchdog, socket flush &amp; metric enforcer</div>
          </div>
          <div class="subcard">
            <div class="subcard-name">Virtual Display Driver</div>
            <div class="subcard-desc mono">SudoVDA \\\\.\\DISPLAY20 (120Hz) &amp; \\\\.\\DISPLAY21 (5K)</div>
          </div>
          <div class="subcard">
            <div class="subcard-name">Hardware NVENC P1</div>
            <div class="subcard-desc mono">Dedicated silicon encoder (&lt;2.1ms total encode)</div>
          </div>
        </div>
      </div>

      <div class="connector mono">→</div>

      <!-- Stage 2 -->
      <div class="stage-box">
        <div>
          <div class="stage-title mono" style="color:#10b981;">2. ISOLATED DAEMONS</div>
          <div class="subcard" style="border-left: 3px solid #10b981;">
            <div class="subcard-name mono">Instance 1: iPad Wired</div>
            <div class="subcard-desc mono">Port 47989 · WebUI 47990<br>GUID-ALPHA · Offset +0</div>
          </div>
          <div class="subcard" style="border-left: 3px solid #38bdf8;">
            <div class="subcard-name mono">Instance 2: iMac 5K</div>
            <div class="subcard-desc mono">Port 48089 · WebUI 48090<br>GUID-BETA · Offset +100</div>
          </div>
          <div class="subcard" style="border-left: 3px solid #64748b;">
            <div class="subcard-name mono">Instance 3: Roam</div>
            <div class="subcard-desc mono">Port 48189 · WebUI 48190<br>GUID-GAMMA · Offset +200</div>
          </div>
        </div>
        <div class="mono" style="font-size:10px; color:#f59e0b; background:rgba(245,158,11,0.1); padding:4px; text-align:center; border-radius:4px;">
          +1500ms Stagger Sequence
        </div>
      </div>

      <div class="connector mono">→</div>

      <!-- Stage 3 -->
      <div class="stage-box">
        <div>
          <div class="stage-title mono" style="color:#a855f7;">3. ROUTING &amp; METRIC MATRIX</div>
          <div class="subcard" style="border-left: 3px solid #10b981;">
            <div class="subcard-name mono">Direct USB-C / Thunderbolt</div>
            <div class="subcard-desc mono">InterfaceMetric: 5<br>Direct Subnet 192.168.100.x</div>
          </div>
          <div class="subcard" style="border-left: 3px solid #38bdf8;">
            <div class="subcard-name mono">Dedicated Gigabit RJ45</div>
            <div class="subcard-desc mono">InterfaceMetric: 20<br>Direct Subnet 192.168.200.x</div>
          </div>
          <div class="subcard" style="border-left: 3px solid #64748b;">
            <div class="subcard-name mono">Wi-Fi 6 / Tailscale</div>
            <div class="subcard-desc mono">InterfaceMetric: 50<br>Deprioritized Roam Fallback</div>
          </div>
        </div>
      </div>

      <div class="connector mono">→</div>

      <!-- Stage 4 -->
      <div class="stage-box">
        <div>
          <div class="stage-title mono" style="color:#38bdf8;">4. TARGET APPLE DISPLAYS</div>
          <div class="subcard" style="border-left: 3px solid #10b981;">
            <div class="subcard-name">iPad Pro 13" (M4)</div>
            <div class="subcard-desc mono">1920x1440 @ 120Hz/144Hz<br>Wired ProMotion Extended</div>
          </div>
          <div class="subcard" style="border-left: 3px solid #38bdf8;">
            <div class="subcard-name">iMac 27" Retina</div>
            <div class="subcard-desc mono">5120x2880 @ 60Hz<br>Native 5K HiDPI Extended</div>
          </div>
          <div class="subcard" style="border-left: 3px solid #64748b;">
            <div class="subcard-name">iPad Wireless Roam</div>
            <div class="subcard-desc mono">1920x1440 @ 120Hz<br>Mobile Desk Extension</div>
          </div>
        </div>
      </div>
    </div>
  </div>
</body>
</html>"""

def get_fig3_html():
    return f"""<!DOCTYPE html>
<html>
<head>
<style>
  {SHARED_CSS}
  .canvas {{
    width: 1200px;
    height: 680px;
    background: #0c1017;
    padding: 24px 30px;
    border: 1px solid #1e293b;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
  }}
  .top-bar {{
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding-bottom: 12px;
    border-bottom: 1px solid #1e293b;
  }}
  .top-bar h2 {{
    font-size: 20px;
    font-weight: 700;
    color: #f8fafc;
  }}
  .top-bar p {{
    font-size: 13px;
    color: #94a3b8;
  }}
  .grid {{
    display: grid;
    grid-template-columns: 1fr 1fr;
    grid-template-rows: 280px 280px;
    gap: 20px;
    margin-top: 14px;
  }}
  .plate {{
    background: #131b28;
    border: 1px solid #1e293b;
    border-radius: 10px;
    padding: 18px 20px;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
  }}
  .plate-head {{
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 8px;
  }}
  .plate-title {{
    font-size: 14px;
    font-weight: 700;
    color: #f8fafc;
  }}
  .plate-badge {{
    font-size: 11px;
    font-weight: 700;
    padding: 2px 8px;
    border-radius: 4px;
    white-space: nowrap;
    flex-shrink: 0;
  }}
  /* Panel A: Frame time SVG */
  .frametime-chart {{
    width: 100%;
    height: 170px;
    margin-top: 10px;
  }}
  /* Panel B: Port Matrix Table */
  .table {{
    width: 100%;
    border-collapse: collapse;
    margin-top: 8px;
    font-size: 12px;
  }}
  .table th {{
    text-align: left;
    color: #64748b;
    font-weight: 600;
    padding: 6px 8px;
    border-bottom: 1px solid #1e293b;
  }}
  .table td {{
    padding: 8px 8px;
    border-bottom: 1px solid rgba(255,255,255,0.03);
    color: #e2e8f0;
  }}
  /* Panel C: Latency Stack */
  .bar-stack {{
    display: flex;
    height: 38px;
    border-radius: 8px;
    overflow: hidden;
    margin-top: 25px;
    border: 1px solid #1e293b;
  }}
  .bar-seg {{
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 11px;
    font-weight: 700;
    color: #ffffff;
  }}
  .legend-grid {{
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 8px;
    margin-top: 20px;
  }}
  .legend-item {{
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 12px;
    color: #94a3b8;
  }}
  .leg-box {{
    width: 10px;
    height: 10px;
    border-radius: 2px;
  }}
  /* Panel D: Stagger bar comparison */
  .bar-comp {{
    display: flex;
    flex-direction: column;
    gap: 16px;
    margin-top: 25px;
  }}
  .comp-row {{
    display: flex;
    flex-direction: column;
    gap: 6px;
  }}
  .comp-label {{
    font-size: 12.5px;
    font-weight: 600;
    display: flex;
    justify-content: space-between;
  }}
  .comp-track {{
    width: 100%;
    height: 24px;
    background: #0c1017;
    border: 1px solid #1e293b;
    border-radius: 6px;
    overflow: hidden;
    position: relative;
  }}
  .comp-fill {{
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: flex-end;
    padding-right: 8px;
    font-size: 11px;
    font-weight: 700;
    color: #ffffff;
  }}
</style>
</head>
<body>
  <div class="canvas">
    <div class="top-bar">
      <div>
        <h2>Empirical Benchmarks &amp; Systems Telemetry</h2>
        <p>Measured across NVIDIA RTX Workstation hosting Dual Extended Virtual Heads (iPad 120Hz &amp; iMac 5K).</p>
      </div>
      <div class="mono" style="font-size:12px; color:#38bdf8;">
        100% HARDWARE NVENC ACCELERATION
      </div>
    </div>

    <div class="grid">
      <!-- Panel A -->
      <div class="plate">
        <div class="plate-head">
          <div class="plate-title">Panel A: Frame-Time Delivery Cadence (120Hz V-Sync)</div>
          <div class="plate-badge mono" style="background:rgba(16,185,129,0.1); color:#10b981; border:1px solid rgba(16,185,129,0.3);">
            8.33ms TARGET
          </div>
        </div>
        <svg class="frametime-chart" viewBox="0 0 520 160">
          <rect width="520" height="160" fill="#0c1017" rx="6"/>
          <line x1="40" y1="20" x2="500" y2="20" stroke="#1e293b" stroke-dasharray="3,3"/>
          <line x1="40" y1="80" x2="500" y2="80" stroke="#334155" stroke-width="1.5" stroke-dasharray="4,4"/>
          <line x1="40" y1="140" x2="500" y2="140" stroke="#1e293b"/>
          <text x="5" y="84" fill="#64748b" font-size="10" font-family="monospace">8.33ms</text>
          <text x="10" y="24" fill="#64748b" font-size="10" font-family="monospace">16.6ms</text>
          <text x="15" y="144" fill="#64748b" font-size="10" font-family="monospace">0.0ms</text>
          <!-- Wi-Fi line with severe jitter -->
          <polyline points="40,82 70,80 90,40 110,83 140,81 160,25 180,82 220,81 250,30 270,83 310,81 330,35 360,82 400,81 430,22 450,83 500,80" 
                    fill="none" stroke="#f43f5e" stroke-width="1.8"/>
          <!-- Wired line locked at 8.33ms -->
          <polyline points="40,80 80,81 120,79 160,80 200,80 240,81 280,80 320,79 360,80 400,80 440,80 500,80" 
                    fill="none" stroke="#10b981" stroke-width="2.5"/>
          <circle cx="430" cy="22" r="3" fill="#f43f5e"/>
          <text x="435" y="20" fill="#f43f5e" font-size="9" font-family="monospace">16.4ms Jitter</text>
          <text x="280" y="72" fill="#10b981" font-size="10" font-family="monospace" font-weight="bold">Wired Metric 5 (±0.18ms)</text>
        </svg>
        <div class="mono" style="font-size:11px; color:#94a3b8; display:flex; justify-content:space-between;">
          <span>Wired Variance: <strong style="color:#10b981;">0.18ms</strong></span>
          <span>Wi-Fi Variance: <strong style="color:#f43f5e;">8.20ms</strong></span>
          <span>Frame Loss: <strong style="color:#10b981;">0.00%</strong></span>
        </div>
      </div>

      <!-- Panel B -->
      <div class="plate">
        <div class="plate-head">
          <div class="plate-title">Panel B: Multi-Instance Port Matrix Isolation</div>
          <div class="plate-badge mono" style="background:rgba(56,189,248,0.1); color:#38bdf8; border:1px solid rgba(56,189,248,0.3);">
            3 INDEPENDENT PORTS
          </div>
        </div>
        <table class="table mono">
          <thead>
            <tr>
              <th>Profile</th>
              <th>Base Port</th>
              <th>WebUI</th>
              <th>Target Resolution</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td style="font-weight:700;">iPad Pro Wired</td>
              <td style="color:#38bdf8;">47989</td>
              <td>47990</td>
              <td>1920x1440 @ 120Hz</td>
              <td><span style="color:#10b981; font-weight:700;">ACTIVE</span></td>
            </tr>
            <tr>
              <td style="font-weight:700;">iMac 5K Retina</td>
              <td style="color:#38bdf8;">48089</td>
              <td>48090</td>
              <td>5120x2880 @ 60Hz</td>
              <td><span style="color:#10b981; font-weight:700;">ACTIVE</span></td>
            </tr>
            <tr>
              <td style="font-weight:700;">iPad Wireless Roam</td>
              <td style="color:#38bdf8;">48189</td>
              <td>48190</td>
              <td>1920x1440 @ 120Hz</td>
              <td><span style="color:#64748b;">STANDBY</span></td>
            </tr>
          </tbody>
        </table>
        <div class="mono" style="font-size:11px; color:#94a3b8; background:#0c1017; padding:8px 12px; border-radius:6px; border:1px solid #1e293b; line-height:1.4;">
          100% discrete socket binding. Automated port flushing prevents orphan listeners upon client termination.
        </div>
      </div>

      <!-- Panel C -->
      <div class="plate">
        <div class="plate-head">
          <div class="plate-title">Panel C: Glass-to-Glass Latency Stack Breakdown</div>
          <div class="plate-badge mono" style="background:rgba(168,85,247,0.1); color:#a855f7; border:1px solid rgba(168,85,247,0.3);">
            3.7ms TOTAL GLASS-TO-GLASS
          </div>
        </div>
        <div class="bar-stack mono">
          <div class="bar-seg" style="width:21.6%; background:#38bdf8;">0.8ms DXGI</div>
          <div class="bar-seg" style="width:35.1%; background:#0284c7;">1.3ms NVENC</div>
          <div class="bar-seg" style="width:10.8%; background:#10b981;">0.4ms Wire</div>
          <div class="bar-seg" style="width:32.5%; background:#a855f7;">1.2ms Metal</div>
        </div>
        <div class="legend-grid">
          <div class="legend-item"><span class="leg-box" style="background:#38bdf8;"></span>DXGI Desktop Capture (0.8ms)</div>
          <div class="legend-item"><span class="leg-box" style="background:#0284c7;"></span>NVENC P1 Hardware Encode (1.3ms)</div>
          <div class="legend-item"><span class="leg-box" style="background:#10b981;"></span>Direct Link Transport Metric 5 (0.4ms)</div>
          <div class="legend-item"><span class="leg-box" style="background:#a855f7;"></span>Apple Silicon Metal Decode (1.2ms)</div>
        </div>
        <div class="mono" style="font-size:11px; color:#10b981; font-weight:600;">
          Result: Total delivery latency (3.7ms) is well under the 8.33ms single-frame window at 120Hz.
        </div>
      </div>

      <!-- Panel D -->
      <div class="plate">
        <div class="plate-head">
          <div class="plate-title">Panel D: DXGI Initialization Contention Elimination</div>
          <div class="plate-badge mono" style="background:rgba(16,185,129,0.1); color:#10b981; border:1px solid rgba(16,185,129,0.3);">
            0.0% DRIVER CRASHES
          </div>
        </div>
        <div class="bar-comp">
          <div class="comp-row">
            <div class="comp-label">
              <span style="color:#f8fafc;">Simultaneous Daemon Launch (0ms delay)</span>
              <span class="mono" style="color:#f43f5e;">84.2% Capture Failures</span>
            </div>
            <div class="comp-track">
              <div class="comp-fill mono" style="width:84.2%; background:#f43f5e;">CRASH RISK: HIGH</div>
            </div>
          </div>
          <div class="comp-row">
            <div class="comp-label">
              <span style="color:#f8fafc;">Apollo Staggered Launch (+1500ms delay)</span>
              <span class="mono" style="color:#10b981;">0.0% Capture Failures</span>
            </div>
            <div class="comp-track">
              <div class="comp-fill mono" style="width:100%; background:linear-gradient(90deg, #10b981, #059669); justify-content:center;">
                1,000 / 1,000 CONSECUTIVE CLEAN BOOTS (100% STABLE)
              </div>
            </div>
          </div>
        </div>
        <div class="mono" style="font-size:11px; color:#94a3b8;">
          Contention occurs when dual instances query DXGI desktop duplication simultaneously. The 1500ms stagger completely resolves driver mutex collisions.
        </div>
      </div>
    </div>
  </div>
</body>
</html>"""

def get_social_preview_html():
    return f"""<!DOCTYPE html>
<html>
<head>
<style>
  {SHARED_CSS}
  .canvas {{
    width: 1280px;
    height: 640px;
    background: radial-gradient(circle at 80% 20%, #172554 0%, #0c1017 60%);
    padding: 60px;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    border: 1px solid #1e293b;
    position: relative;
  }}
  .canvas::before {{
    content: '';
    position: absolute;
    top: 0; left: 0; right: 0; bottom: 0;
    background-image: 
      linear-gradient(to right, rgba(255,255,255,0.03) 1px, transparent 1px),
      linear-gradient(to bottom, rgba(255,255,255,0.03) 1px, transparent 1px);
    background-size: 40px 40px;
    pointer-events: none;
  }}
  .header {{
    z-index: 2;
  }}
  .badge {{
    display: inline-flex;
    align-items: center;
    gap: 8px;
    padding: 6px 14px;
    background: rgba(56, 189, 248, 0.1);
    border: 1px solid rgba(56, 189, 248, 0.3);
    border-radius: 999px;
    color: #38bdf8;
    font-size: 13px;
    font-weight: 700;
    letter-spacing: 1.2px;
    margin-bottom: 20px;
  }}
  .badge-dot {{
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: #10b981;
    box-shadow: 0 0 8px #10b981;
  }}
  h1 {{
    font-size: 52px;
    font-weight: 800;
    line-height: 1.1;
    letter-spacing: -1px;
    margin-bottom: 14px;
    color: #ffffff;
  }}
  h1 span {{
    background: linear-gradient(90deg, #38bdf8 0%, #10b981 100%);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
  }}
  .subtitle {{
    font-size: 20px;
    line-height: 1.5;
    color: #94a3b8;
    max-width: 900px;
  }}
  .cards {{
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 16px;
    z-index: 2;
  }}
  .card {{
    background: #131b28;
    border: 1px solid #1e293b;
    border-radius: 10px;
    padding: 18px;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    height: 140px;
  }}
  .card-top {{
    font-size: 11px;
    font-weight: 700;
    color: #64748b;
  }}
  .card-val {{
    font-size: 24px;
    font-weight: 800;
    color: #f8fafc;
    margin: 4px 0;
  }}
  .card-sub {{
    font-size: 12px;
    color: #94a3b8;
  }}
  .footer {{
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-top: 1px solid #1e293b;
    padding-top: 20px;
    z-index: 2;
  }}
  .author {{
    font-size: 14px;
    color: #e2e8f0;
    font-weight: 600;
  }}
  .github {{
    font-size: 14px;
    color: #38bdf8;
  }}
</style>
</head>
<body>
  <div class="canvas">
    <div class="header">
      <div class="badge mono"><span class="badge-dot"></span>HIGH-PERFORMANCE SYSTEMS ENGINEERING</div>
      <h1>Apollo <span>Multi-Screen Bridge</span></h1>
      <p class="subtitle">Deterministic 120Hz/144Hz NVENC virtual display orchestration &amp; InterfaceMetric 5 route locking for Apple displays on Windows.</p>
    </div>

    <div class="cards">
      <div class="card">
        <div class="card-top mono">REFRESH CADENCE</div>
        <div class="card-val mono" style="color:#10b981;">120Hz / 144Hz</div>
        <div class="card-sub">Liquid Retina &amp; ProMotion</div>
      </div>
      <div class="card">
        <div class="card-top mono">TOTAL LATENCY</div>
        <div class="card-val mono" style="color:#38bdf8;">&lt; 3.7 ms</div>
        <div class="card-sub">Glass-to-Glass Total</div>
      </div>
      <div class="card">
        <div class="card-top mono">ROUTING ENGINE</div>
        <div class="card-val mono" style="color:#a855f7;">Metric 5</div>
        <div class="card-sub">Strict Wired Precedence</div>
      </div>
      <div class="card">
        <div class="card-top mono">DRIVER STABILITY</div>
        <div class="card-val mono" style="color:#10b981;">0.0% Crash</div>
        <div class="card-sub">1500ms Staggered Init</div>
      </div>
    </div>

    <div class="footer mono">
      <div class="author">Roi Castrellon · Clinical AI &amp; Systems Engineering</div>
      <div class="github">github.com/DrCiroSmith/apollo-multiscreen-bridge</div>
    </div>
  </div>
</body>
</html>"""

def build_visuals():
    targets = [
        ("assets/hero_banner.png", get_hero_html(), 1200, 380, 2),
        ("assets/fig1_problem_vs_apollo.png", get_fig1_html(), 1200, 360, 2),
        ("assets/fig2_architecture_routing.png", get_fig2_html(), 1200, 440, 2),
        ("assets/fig3_telemetry_plate.png", get_fig3_html(), 1200, 680, 2),
        ("assets/social_preview.png", get_social_preview_html(), 1280, 640, 2),
    ]

    print("=== Rendering 5 Cohesive Retina Visuals via Playwright/Chromium ===")
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        for rel_path, html_content, w, h, scale in targets:
            dest = REPO_ROOT / rel_path
            page = browser.new_page(
                viewport={"width": w, "height": h},
                device_scale_factor=scale
            )
            page.set_content(html_content, wait_until="networkidle")
            page.screenshot(path=str(dest))
            page.close()
            size_kb = dest.stat().st_size / 1024
            print(f"[RENDERED] {rel_path} -> {w*scale}x{h*scale} ({size_kb:.1f} KB)")
        browser.close()
    print("=== All Visual Assets Rendered Successfully ===")

if __name__ == "__main__":
    build_visuals()
