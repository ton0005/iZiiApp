import os
import subprocess

html_content = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>iZiiApp Architecture Blueprint - Costa Mushroom M2</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap');

  @page {
    size: A4 portrait;
    margin: 12mm 15mm 15mm 15mm;
    @bottom-right {
      content: counter(page);
    }
  }

  * {
    box-sizing: border-box;
    -webkit-print-color-adjust: exact !important;
    print-color-adjust: exact !important;
  }

  body {
    font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
    color: #1e293b;
    background-color: #ffffff;
    line-height: 1.5;
    font-size: 11pt;
    margin: 0;
    padding: 0;
  }

  .header-card {
    background: linear-gradient(135deg, #0f172a 0%, #1e3a8a 100%);
    color: #ffffff;
    padding: 24px 28px;
    border-radius: 12px;
    margin-bottom: 24px;
    box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
  }

  .header-badge {
    display: inline-block;
    background: #10b981;
    color: #ffffff;
    font-size: 8.5pt;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    padding: 4px 10px;
    border-radius: 6px;
    margin-bottom: 10px;
  }

  .header-title {
    font-size: 22pt;
    font-weight: 800;
    line-height: 1.2;
    margin: 0 0 6px 0;
    letter-spacing: -0.02em;
  }

  .header-subtitle {
    font-size: 13pt;
    font-weight: 400;
    color: #93c5fd;
    margin: 0 0 14px 0;
  }

  .header-meta {
    display: flex;
    gap: 20px;
    font-size: 9pt;
    color: #cbd5e1;
    border-top: 1px solid rgba(255, 255, 255, 0.15);
    padding-top: 10px;
  }

  .header-meta span strong {
    color: #ffffff;
  }

  h2 {
    font-size: 14pt;
    font-weight: 700;
    color: #0f172a;
    border-left: 4px solid #10b981;
    padding-left: 10px;
    margin: 22px 0 12px 0;
    page-break-after: avoid;
  }

  h3 {
    font-size: 11.5pt;
    font-weight: 600;
    color: #1e3a8a;
    margin: 16px 0 8px 0;
    page-break-after: avoid;
  }

  p {
    margin: 0 0 10px 0;
    text-align: justify;
  }

  .card-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 12px;
    margin: 14px 0 18px 0;
    page-break-inside: avoid;
  }

  .card {
    background: #f8fafc;
    border: 1px solid #e2e8f0;
    border-radius: 8px;
    padding: 12px 14px;
  }

  .card-title {
    font-weight: 700;
    font-size: 10pt;
    color: #0f172a;
    margin-bottom: 4px;
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .card-desc {
    font-size: 8.8pt;
    color: #475569;
    line-height: 1.4;
  }

  .highlight-box {
    background: #ecfdf5;
    border: 1px solid #a7f3d0;
    border-left: 4px solid #10b981;
    border-radius: 6px;
    padding: 10px 14px;
    font-size: 9.5pt;
    color: #065f46;
    margin: 12px 0;
    page-break-inside: avoid;
  }

  .warning-box {
    background: #fffbeb;
    border: 1px solid #fde68a;
    border-left: 4px solid #f59e0b;
    border-radius: 6px;
    padding: 10px 14px;
    font-size: 9.5pt;
    color: #92400e;
    margin: 12px 0;
    page-break-inside: avoid;
  }

  .diagram-container {
    background: #f8fafc;
    border: 1px solid #cbd5e1;
    border-radius: 8px;
    padding: 14px;
    margin: 14px 0 18px 0;
    page-break-inside: avoid;
  }

  .diagram-title {
    font-size: 9pt;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: #64748b;
    margin-bottom: 10px;
    text-align: center;
  }

  /* Table styling */
  table {
    width: 100%;
    border-collapse: collapse;
    margin: 14px 0 18px 0;
    font-size: 9pt;
    page-break-inside: avoid;
  }

  th, td {
    padding: 8px 10px;
    text-align: left;
    border-bottom: 1px solid #e2e8f0;
  }

  th {
    background: #f1f5f9;
    color: #0f172a;
    font-weight: 700;
    border-top: 1px solid #cbd5e1;
    border-bottom: 2px solid #cbd5e1;
  }

  tr:nth-child(even) td {
    background: #fafafa;
  }

  .badge {
    display: inline-block;
    padding: 2px 7px;
    border-radius: 4px;
    font-size: 8pt;
    font-weight: 600;
  }

  .badge-emerald { background: #d1fae5; color: #065f46; }
  .badge-blue { background: #dbeafe; color: #1e40af; }
  .badge-amber { background: #fef3c7; color: #92400e; }
  .badge-purple { background: #f3e8ff; color: #6b21a8; }

  .page-break {
    page-break-before: always;
  }

  /* SVG Diagram Specifics */
  svg {
    display: block;
    margin: 0 auto;
    max-width: 100%;
    height: auto;
  }

  .footer-note {
    font-size: 8pt;
    color: #94a3b8;
    text-align: center;
    margin-top: 24px;
    border-top: 1px solid #e2e8f0;
    padding-top: 10px;
  }
</style>
</head>
<body>

<!-- Header Banner -->
<div class="header-card">
  <div class="header-badge">Enterprise System Architecture Blueprint</div>
  <h1 class="header-title">iZiiApp Mushroom Production Architecture</h1>
  <div class="header-subtitle">Optimized for Costa Mushroom M2 Facility &middot; 33 Grow Rooms</div>
  <div class="header-meta">
    <span><strong>Target Audience:</strong> Plant Leadership & Operations Directors</span>
    <span><strong>Platform Version:</strong> 1.0.0 (Offline-First Edge)</span>
    <span><strong>Scope:</strong> Cultivation, Safety, Harvest & Labor</span>
  </div>
</div>

<!-- Section 1 -->
<h2>1. Executive Summary & Value Proposition</h2>
<p>
  <strong>iZiiApp</strong> delivers an enterprise-grade, edge-first mobile and kiosk software platform built specifically for high-humidity, RF-shielded agricultural facilities like the <strong>Costa Mushroom M2 plant</strong>. Operating seamlessly with or without factory Wi-Fi, iZiiApp coordinates 33 grow rooms, automated worker safety protocols, and daily yield harvesting.
</p>

<div class="card-grid">
  <div class="card">
    <div class="card-title">
      <span class="badge badge-emerald">100% Offline Edge</span>
    </div>
    <div class="card-desc">Zero operational downtime. Local SQLite + P2P BLE mesh enables full function inside reinforced grow sheds without network latency.</div>
  </div>
  <div class="card">
    <div class="card-title">
      <span class="badge badge-amber">Solo Worker Safety</span>
    </div>
    <div class="card-desc">Life-critical alone worker protection: automated countdown timers, CO/CO<sub>2</sub> thresholds, in-app alarms, and supervisor escalations.</div>
  </div>
  <div class="card">
    <div class="card-title">
      <span class="badge badge-blue">Precision Harvest</span>
    </div>
    <div class="card-desc">End-to-end yield surveys, color team allocations, automated box target distribution, and standardized cycle tracking.</div>
  </div>
</div>

<!-- Section 2 -->
<h2>2. Edge-First Enterprise Topology</h2>
<p>
  The system architecture separates physical plant floor operations from central IT dependencies using local edge nodes and auto-syncing mobile units.
</p>

<div class="diagram-container">
  <div class="diagram-title">Costa M2 Distributed Edge Architecture</div>
  <svg width="680" height="240" viewBox="0 0 680 240" xmlns="http://www.w3.org/2000/svg">
    <!-- Background grid / boundaries -->
    <rect x="10" y="10" width="190" height="220" rx="8" fill="#eff6ff" stroke="#93c5fd" stroke-width="1.5" />
    <text x="105" y="30" font-size="11" font-weight="700" fill="#1e3a8a" text-anchor="middle">1. Floor Edge Devices</text>
    
    <rect x="20" y="45" width="170" height="40" rx="6" fill="#ffffff" stroke="#cbd5e1" />
    <text x="105" y="62" font-size="9.5" font-weight="600" fill="#0f172a" text-anchor="middle">Wall Kiosks & Terminals</text>
    <text x="105" y="76" font-size="8" fill="#64748b" text-anchor="middle">NFC Scanner & Shift Display</text>

    <rect x="20" y="95" width="170" height="40" rx="6" fill="#ffffff" stroke="#cbd5e1" />
    <text x="105" y="112" font-size="9.5" font-weight="600" fill="#0f172a" text-anchor="middle">Supervisor Mobiles</text>
    <text x="105" y="126" font-size="8" fill="#64748b" text-anchor="middle">Flutter App + Local SQLite</text>

    <rect x="20" y="145" width="170" height="40" rx="6" fill="#ffffff" stroke="#cbd5e1" />
    <text x="105" y="162" font-size="9.5" font-weight="600" fill="#0f172a" text-anchor="middle">Badges & Gas Probes</text>
    <text x="105" y="176" font-size="8" fill="#64748b" text-anchor="middle">Staff Badges, CO / CO2 Probes</text>

    <!-- Center Engine -->
    <rect x="245" y="10" width="190" height="220" rx="8" fill="#ecfdf5" stroke="#6ee7b7" stroke-width="1.5" />
    <text x="340" y="30" font-size="11" font-weight="700" fill="#065f46" text-anchor="middle">2. Local iZii Engine & Mesh</text>

    <rect x="255" y="45" width="170" height="40" rx="6" fill="#ffffff" stroke="#cbd5e1" />
    <text x="340" y="62" font-size="9.5" font-weight="600" fill="#0f172a" text-anchor="middle">P2P BLE Sync Mesh</text>
    <text x="340" y="76" font-size="8" fill="#64748b" text-anchor="middle">Noise Protocol Cryptography</text>

    <rect x="255" y="95" width="170" height="40" rx="6" fill="#ffffff" stroke="#cbd5e1" />
    <text x="340" y="112" font-size="9.5" font-weight="600" fill="#0f172a" text-anchor="middle">Drift SQLite Local DB</text>
    <text x="340" y="126" font-size="8" fill="#64748b" text-anchor="middle">Full ACID Local Persistence</text>

    <rect x="255" y="145" width="170" height="40" rx="6" fill="#ffffff" stroke="#cbd5e1" />
    <text x="340" y="162" font-size="9.5" font-weight="600" fill="#0f172a" text-anchor="middle">Outbox Sync Engine</text>
    <text x="340" y="176" font-size="8" fill="#64748b" text-anchor="middle">Guaranteed Delivery Queue</text>

    <!-- Central Hub -->
    <rect x="480" y="10" width="190" height="220" rx="8" fill="#f8fafc" stroke="#cbd5e1" stroke-width="1.5" />
    <text x="575" y="30" font-size="11" font-weight="700" fill="#0f172a" text-anchor="middle">3. Central Plant Hub & ERP</text>

    <rect x="490" y="55" width="170" height="50" rx="6" fill="#ffffff" stroke="#cbd5e1" />
    <text x="575" y="75" font-size="9.5" font-weight="600" fill="#0f172a" text-anchor="middle">Farm Central Server</text>
    <text x="575" y="90" font-size="8" fill="#64748b" text-anchor="middle">Consolidated Backups & History</text>

    <rect x="490" y="125" width="170" height="50" rx="6" fill="#ffffff" stroke="#cbd5e1" />
    <text x="575" y="145" font-size="9.5" font-weight="600" fill="#0f172a" text-anchor="middle">ERP & Payroll Connector</text>
    <text x="575" y="160" font-size="8" fill="#64748b" text-anchor="middle">Automated Excel/PDF Exports</text>

    <!-- Connectors -->
    <line x1="200" y1="65" x2="245" y2="65" stroke="#3b82f6" stroke-width="2" stroke-dasharray="4,2" />
    <line x1="200" y1="115" x2="245" y2="115" stroke="#3b82f6" stroke-width="2" />
    <line x1="200" y1="165" x2="245" y2="165" stroke="#3b82f6" stroke-width="2" stroke-dasharray="4,2" />

    <line x1="435" y1="80" x2="480" y2="80" stroke="#10b981" stroke-width="2" />
    <line x1="435" y1="150" x2="480" y2="150" stroke="#10b981" stroke-width="2" />
  </svg>
</div>

<div class="page-break"></div>

<!-- Section 3 -->
<h2>3. Layered Software Architecture (Mushroom Subsystem)</h2>
<p>
  The Mushroom module adheres to high-cohesion, loose-coupling design principles, ensuring sub-second response times and rock-solid reliability across all UI screens.
</p>

<div class="diagram-container">
  <div class="diagram-title">iZiiApp Clean Architecture Stack</div>
  <svg width="680" height="260" viewBox="0 0 680 260" xmlns="http://www.w3.org/2000/svg">
    <!-- Layer 1 UI -->
    <rect x="20" y="10" width="640" height="48" rx="6" fill="#1e293b" />
    <text x="340" y="28" font-size="10.5" font-weight="700" fill="#f8fafc" text-anchor="middle">1. Presentation & UI Layer (Flutter Framework)</text>
    <text x="340" y="44" font-size="8.5" fill="#94a3b8" text-anchor="middle">3D Grow Room Matrix &middot; Harvest Planner &middot; Solo Safety HUD &middot; Performance Board &middot; NFC Kiosk</text>

    <!-- Layer 2 BLoC -->
    <rect x="20" y="70" width="640" height="48" rx="6" fill="#1e3a8a" />
    <text x="340" y="88" font-size="10.5" font-weight="700" fill="#ffffff" text-anchor="middle">2. State Management & Coordination Layer (BLoC Pattern)</text>
    <text x="340" y="104" font-size="8.5" fill="#bfdbfe" text-anchor="middle">MushroomsBloc &middot; SoloSafetyBloc &middot; AttendanceBloc &middot; PerformanceAnalyticsBloc</text>

    <!-- Layer 3 Domain -->
    <rect x="20" y="130" width="640" height="52" rx="6" fill="#047857" />
    <text x="340" y="148" font-size="10.5" font-weight="700" fill="#ffffff" text-anchor="middle">3. Domain Services & Industrial Business Rules</text>
    <text x="340" y="164" font-size="8.5" fill="#a7f3d0" text-anchor="middle">8-Stage Pipeline Engine &middot; Safety Countdown & Escalation &middot; Timesheet Engine &middot; PDF/Excel Exporter</text>

    <!-- Layer 4 Data Access -->
    <rect x="20" y="194" width="640" height="54" rx="6" fill="#334155" />
    <text x="340" y="212" font-size="10.5" font-weight="700" fill="#ffffff" text-anchor="middle">4. Persistence & Security Layer (Drift ORM & SQLite)</text>
    <text x="340" y="228" font-size="8.5" fill="#cbd5e1" text-anchor="middle">Tables: GrowRooms (33 rooms) &middot; MushroomJobs &middot; HarvestPlans &middot; AttendanceEvents &middot; Payroll</text>
  </svg>
</div>

<!-- Section 4 -->
<h2>4. Core Operational Pillars in Costa M2 Plant</h2>

<h3>4.1. 33-Room Cultivation Lifecycle (The 8-Stage Standard Pipeline)</h3>
<p>
  Every grow room follows a strictly timed, quality-controlled pipeline. Custom recipe settings (e.g. Watering <code>2 Side 2L/m²</code>, Prochloraz <code>1.3g/m²</code>) are validated at each stage transition:
</p>

<div class="diagram-container">
  <div class="diagram-title">Standardized 8-Stage Cultivation Pipeline</div>
  <svg width="680" height="90" viewBox="0 0 680 90" xmlns="http://www.w3.org/2000/svg">
    <!-- Stages 1 to 8 -->
    <!-- S1 -->
    <rect x="10" y="15" width="72" height="60" rx="6" fill="#ecfdf5" stroke="#10b981" stroke-width="1.5"/>
    <text x="46" y="35" font-size="9" font-weight="700" fill="#065f46" text-anchor="middle">1. Filling</text>
    <text x="46" y="52" font-size="8" fill="#047857" text-anchor="middle">60 mins</text>

    <!-- S2 -->
    <rect x="94" y="15" width="72" height="60" rx="6" fill="#f0fdf4" stroke="#22c55e" stroke-width="1.5"/>
    <text x="130" y="35" font-size="9" font-weight="700" fill="#14532d" text-anchor="middle">2. Airing</text>
    <text x="130" y="52" font-size="8" fill="#15803d" text-anchor="middle">20 mins</text>

    <!-- S3 -->
    <rect x="178" y="15" width="72" height="60" rx="6" fill="#eff6ff" stroke="#3b82f6" stroke-width="1.5"/>
    <text x="214" y="35" font-size="9" font-weight="700" fill="#1e40af" text-anchor="middle">3. Floor Wet</text>
    <text x="214" y="52" font-size="8" fill="#2563eb" text-anchor="middle">25 mins</text>

    <!-- S4 -->
    <rect x="262" y="15" width="72" height="60" rx="6" fill="#faf5ff" stroke="#a855f7" stroke-width="1.5"/>
    <text x="298" y="35" font-size="9" font-weight="700" fill="#6b21a8" text-anchor="middle">4. Clean Rm</text>
    <text x="298" y="52" font-size="8" fill="#7e22ce" text-anchor="middle">45 mins</text>

    <!-- S5 -->
    <rect x="346" y="15" width="72" height="60" rx="6" fill="#eff6ff" stroke="#0284c7" stroke-width="1.5"/>
    <text x="382" y="35" font-size="9" font-weight="700" fill="#0369a1" text-anchor="middle">5. Watering</text>
    <text x="382" y="52" font-size="8" fill="#0284c7" text-anchor="middle">25 mins</text>

    <!-- S6 -->
    <rect x="430" y="15" width="72" height="60" rx="6" fill="#fdf4ff" stroke="#d946ef" stroke-width="1.5"/>
    <text x="466" y="35" font-size="9" font-weight="700" fill="#86198f" text-anchor="middle">6. Clean Bed</text>
    <text x="466" y="52" font-size="8" fill="#a21caf" text-anchor="middle">35 mins</text>

    <!-- S7 -->
    <rect x="514" y="15" width="72" height="60" rx="6" fill="#fff7ed" stroke="#f97316" stroke-width="1.5"/>
    <text x="550" y="35" font-size="9" font-weight="700" fill="#9a3412" text-anchor="middle">7. Prochloraz</text>
    <text x="550" y="52" font-size="8" fill="#c2410c" text-anchor="middle">30 mins</text>

    <!-- S8 -->
    <rect x="598" y="15" width="72" height="60" rx="6" fill="#fef2f2" stroke="#ef4444" stroke-width="1.5"/>
    <text x="634" y="35" font-size="9" font-weight="700" fill="#991b1b" text-anchor="middle">8. Packup</text>
    <text x="634" y="52" font-size="8" fill="#b91c1c" text-anchor="middle">50 mins</text>
  </svg>
</div>

<h3>4.2. Solo Worker & Alone-Worker Safety Protocol</h3>
<p>
  Confined grow rooms with elevated CO<sub>2</sub> or chemical treatments require absolute safety adherence. iZiiApp enforces an automated lifecycle that alerts the worker and escalates to supervisors if a check-in is missed.
</p>

<div class="diagram-container">
  <div class="diagram-title">Solo Safety Escalation Logic</div>
  <svg width="680" height="110" viewBox="0 0 680 110" xmlns="http://www.w3.org/2000/svg">
    <!-- Step 1 -->
    <circle cx="60" cy="55" r="28" fill="#dbeafe" stroke="#2563eb" stroke-width="2"/>
    <text x="60" y="52" font-size="8.5" font-weight="700" fill="#1e40af" text-anchor="middle">Check-In</text>
    <text x="60" y="64" font-size="7" fill="#1e3a8a" text-anchor="middle">CO / CO2 Log</text>

    <!-- Arrow -->
    <line x1="90" y1="55" x2="160" y2="55" stroke="#64748b" stroke-width="2" marker-end="url(#arrow)" />

    <!-- Step 2 -->
    <circle cx="195" cy="55" r="28" fill="#fef3c7" stroke="#d97706" stroke-width="2"/>
    <text x="195" y="52" font-size="8.5" font-weight="700" fill="#92400e" text-anchor="middle">Active Timer</text>
    <text x="195" y="64" font-size="7" fill="#78350f" text-anchor="middle">30-45m Limit</text>

    <!-- Arrow -->
    <line x1="225" y1="55" x2="295" y2="55" stroke="#64748b" stroke-width="2" />

    <!-- Step 3 -->
    <circle cx="330" cy="55" r="28" fill="#fed7aa" stroke="#ea580c" stroke-width="2"/>
    <text x="330" y="52" font-size="8.5" font-weight="700" fill="#9a3412" text-anchor="middle">Grace Period</text>
    <text x="330" y="64" font-size="7" fill="#7c2d12" text-anchor="middle">+5 Min Alert</text>

    <!-- Arrow -->
    <line x1="360" y1="55" x2="430" y2="55" stroke="#64748b" stroke-width="2" />

    <!-- Step 4 -->
    <circle cx="465" cy="55" r="28" fill="#fee2e2" stroke="#dc2626" stroke-width="2"/>
    <text x="465" y="52" font-size="8.5" font-weight="700" fill="#991b1b" text-anchor="middle">ALARM</text>
    <text x="465" y="64" font-size="7" fill="#7f1d1d" text-anchor="middle">In-App Siren</text>

    <!-- Arrow -->
    <line x1="495" y1="55" x2="565" y2="55" stroke="#dc2626" stroke-width="2" />

    <!-- Step 5 -->
    <circle cx="600" cy="55" r="28" fill="#991b1b" stroke="#7f1d1d" stroke-width="2"/>
    <text x="600" y="52" font-size="8.5" font-weight="700" fill="#ffffff" text-anchor="middle">Escalation</text>
    <text x="600" y="64" font-size="7" fill="#fecaca" text-anchor="middle">Supervisor SOS</text>
  </svg>
</div>

<div class="page-break"></div>

<h3>4.3. Harvest Planning, Team Colors & Precision Logistics</h3>
<p>
  iZiiApp connects pre-harvest <strong>Yield Surveys</strong> (Button, Cup, Flat strains) with daily retailer orders to generate actionable shift plans:
</p>
<ul>
  <li><strong>Color-Coded Picker Squads:</strong> Ivory, Pearl, Purple, Sapphire squads allocated according to required pick-speed curves.</li>
  <li><strong>Trolley & Quality Directives:</strong> Specific instructions (SSA - Single Stemming, Clumps removal) dynamically linked to each grow room.</li>
  <li><strong>Auto-Generated Shift Documents:</strong> Single-click export of the Daily Job Plan PDF and Excel spreadsheets for factory floor notice boards.</li>
</ul>

<h3>4.4. Smart Attendance, NFC Badging & Break Policy Control</h3>
<p>
  Workers tap their NFC badges on plant kiosks during entry, breaks, and departure. The timesheet engine automates break deduction policies (e.g. 30 min standard + 5 min grace), flag abnormal overtime, and prepares pre-payroll calculations for management review.
</p>

<!-- Section 5 -->
<h2>5. Executive Performance Metrics & Operational Benchmarks</h2>

<table>
  <thead>
    <tr>
      <th>Operational KPI</th>
      <th>Standard Target</th>
      <th>Business Impact for Management</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>On-Time Job Completion Rate</strong></td>
      <td><span class="badge badge-emerald">&ge; 92.0%</span></td>
      <td>Guarantees climate and watering timing, eliminating mushroom quality degradation.</td>
    </tr>
    <tr>
      <td><strong>Actual vs. Plan Duration Variance</strong></td>
      <td><span class="badge badge-blue">&plusmn; 5.0%</span></td>
      <td>Detects equipment failure or labor under-allocation before daily bottleneck occurs.</td>
    </tr>
    <tr>
      <td><strong>Break Compliance Rate</strong></td>
      <td><span class="badge badge-amber">&le; 35 mins</span></td>
      <td>Enforces transparent labor compliance and eliminates unapproved overtime costs.</td>
    </tr>
    <tr>
      <td><strong>Solo Safety Unhandled Incidents</strong></td>
      <td><span class="badge badge-emerald">0 Incidents</span></td>
      <td>100% auditable workplace safety record for WorkCover & SafeWork regulatory bodies.</td>
    </tr>
    <tr>
      <td><strong>Yield Forecast Accuracy</strong></td>
      <td><span class="badge badge-purple">&lt; 3.0% Error</span></td>
      <td>Maximizes supermarket delivery fulfillment and prevents over/under picking penalties.</td>
    </tr>
  </tbody>
</table>

<!-- Section 6 -->
<h2>6. Role-Based Governance & Security Matrix</h2>

<table>
  <thead>
    <tr>
      <th>Role</th>
      <th>Core Permissions & Operational Responsibilities</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Plant Director / General Manager</strong></td>
      <td>Plant-wide executive dashboards, cross-department KPI analytics, payroll sign-off, system policy setup.</td>
    </tr>
    <tr>
      <td><strong>Shift & Operations Supervisor</strong></td>
      <td>Daily harvest plan publishing, job reassignments, on-time overrides, solo safety emergency resolution.</td>
    </tr>
    <tr>
      <td><strong>Growing Specialist</strong></td>
      <td>8-step cycle execution, recipe parameter entry (prochloraz, watering volume), CO/CO<sub>2</sub> gas logging.</td>
    </tr>
    <tr>
      <td><strong>Harvest Team Leader</strong></td>
      <td>Picker team supervision, room trolley dispatch, real-time box counting and quality verification.</td>
    </tr>
    <tr>
      <td><strong>Picker / Floor Operator</strong></td>
      <td>NFC check-in/out, break logging, interactive task checklist confirmation.</td>
    </tr>
  </tbody>
</table>

<!-- Section 7 -->
<h2>7. Strategic ROI & Leadership Conclusion</h2>
<div class="highlight-box">
  <strong>Key ROI Deliverables:</strong>
  <ul>
    <li><strong>15–20% Reduction in Supervisory Overhead:</strong> Automated shift assignment and PDF/Excel generation save up to 2 hours per shift.</li>
    <li><strong>100% Lone Worker Compliance:</strong> Full audit trail of gas readings and check-in logs protects the business from safety liability.</li>
    <li><strong>Maximum Crop Yield Consistency:</strong> Strict 8-step adherence delivers higher crop weight and uniform button mushroom grading.</li>
  </ul>
</div>

<div class="footer-note">
  iZiiApp Enterprise Architecture Document &middot; Confidential &middot; Prepared for Costa Mushroom M2 Leadership
</div>

</body>
</html>
"""

html_path = r"c:\Users\CHANH\OneDrive\Documents\Downloads\Compressed\izii_app\iZiiApp_Mushroom_Architecture.html"
pdf_path = r"c:\Users\CHANH\OneDrive\Documents\Downloads\Compressed\izii_app\iZiiApp_Mushroom_Module_Architecture.pdf"

with open(html_path, "w", encoding="utf-8") as f:
    f.write(html_content)

print(f"HTML written to {html_path}")

# Run headless Edge to generate PDF
edge_bin = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
cmd = [
    edge_bin,
    "--headless",
    "--disable-gpu",
    "--run-all-compositor-stages-before-draw",
    f"--print-to-pdf={pdf_path}",
    "--no-pdf-header-footer",
    html_path
]

result = subprocess.run(cmd, capture_output=True, text=True)
print("Return code:", result.returncode)
if os.path.exists(pdf_path):
    size_kb = os.path.getsize(pdf_path) / 1024
    print(f"SUCCESS: PDF generated at {pdf_path} ({size_kb:.2f} KB)")
else:
    print("Error generating PDF:", result.stderr)
