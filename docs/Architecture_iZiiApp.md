iZiiApp Architecture Blueprint
Special Focus: Smart Mushroom Production Module (Costa M2)
Target Audience: Plant Directors, Operations Managers, and Production Supervisors
System Version: iZiiApp Enterprise v1.0.0

1. Executive Summary & System Vision
iZiiApp is an edge-first, industrial-grade mobile and kiosk enterprise application designed specifically for high-intensity manufacturing and agricultural environments. Within the Costa Mushroom M2 facility (33 Grow Rooms), iZiiApp addresses critical operational challenges:



+-----------------------------------------------------------------------------------+
|                              CORE VALUE DRIVERS                                   |
+--------------------------+--------------------------+-----------------------------+
| 100% Offline-First Edge  | Worker Safety Compliance | End-to-End Farm Visibility  |
| Full operational uptime  | Real-time Solo Worker    | Integrated 8-step pipeline, |
| in shielded/humid rooms  | CO/CO2 & time-limit SOS  | harvest planning & yield    |
+--------------------------+--------------------------+-----------------------------+
Key Business Highlights for Factory Leadership:
Zero Downtime (Offline-First Architecture): Operates without continuous Wi-Fi/Internet; synchronizes automatically via local mesh and background SQLite/P2P sync when connectivity is available.
Zero-Harm Safety Protocol (Solo Worker System): Eliminates unmonitored lone-worker risks in dangerous grow room environments through automated time limits, CO/CO2 threshold monitoring, and supervisor escalation trees.
Precision Labor & Harvest Yield Optimization: Links yield surveys, color-coded picker teams, NFC-based smart attendance, and job performance tracking against standardized operational cycle times.
2. Enterprise Edge System Topology
iZiiApp utilizes a distributed edge architecture designed to withstand concrete walls, steel racking, and RF-shielded cold/grow rooms.

Mermaid diagram
3. Layered Software Architecture
iZiiApp is structured around clean, domain-driven boundaries using the BLoC (Business Logic Component) pattern for reactive UI updates and Drift ORM for transactional integrity.

Mermaid diagram
4. Deep-Dive: Mushroom Module Functional Architecture
The Mushroom module is specifically tailored for Costa Mushroom M2 operations across six interconnected pillars:



+-----------------------------------------------------------------------------------+
|                        MUSHROOM MODULE FUNCTIONAL PILLARS                         |
+------------------------+--------------------------+-------------------------------+
| 1. Cultivation Control | 2. Alone Worker Safety   | 3. Harvest & Yield Planning   |
| 33 rooms, 8-step cycle | CO/CO2 threshold alerts, | Yield surveys, team color     |
| & real-time monitoring | countdown & escalation   | allocation, box targets       |
+------------------------+--------------------------+-------------------------------+
| 4. Smart Attendance    | 5. Maintenance & Cooling | 6. Performance Analytics      |
| NFC badges, breaks,    | Cool room temp checks,   | On-time rate, vs-plan KPI,    |
| automated timesheets   | corrective work orders   | daily PDF & Excel reports     |
+------------------------+--------------------------+-------------------------------+
4.1. 33-Room Cultivation Lifecycle (The 8-Step Standard Pipeline)
Every grow room follows a strict operational pipeline tracked down to the exact minute:

Mermaid diagram
Dynamic Recipe Parameters: Stores watering volume (e.g., 2 Side 2L/m²) and chemical dosage (e.g., Prochloraz 1.3g/m²).
3D Visual Map: Interactive 3D visualization showing live room status, room temperature, and worker assignments.
4.2. Solo Worker & Alone-Worker Safety System
Working in confined grow rooms with elevated 
CO
2
CO 
2
​
  or pesticide fumes poses major workplace safety risks. iZiiApp provides an automated life-safety guardian:

Mermaid diagram
Safety Rules & Configuration:
Pre-job Environmental Check: Worker/Supervisor logs 
CO
CO and 
CO
2
CO 
2
​
  ppm upon entering.
Continuous Countdown Timer: Tracks elapsed time vs. standard limit (e.g., 30–45 min).
Automated Escalation Tree: If check-in is missed (+5 min grace), system escalates directly to Shift Supervisor and plant emergency panel.
4.3. Harvest Planning & Labor Coordination
Mermaid diagram
Color Team Hierarchy: Pickers organized under Team Leaders with specialized picking speed profiles.
Room Instructions: Specific guidelines attached per room (e.g., Single-Stemming SSA, Clumps extraction).
4.4. Smart Attendance & Timesheet Processing
Mermaid diagram
5. Performance Analytics & Executive Decision Support
The Performance Board provides plant management with real-time KPI visibility:

Metric	Target / Benchmark	Impact on Operations
On-Time Job Completion Rate	
≥
92
%
≥92%	Prevents crop delays across subsequent watering and airing cycles
Actual vs. Plan Duration	
±
5
%
±5% of standard	Detects staffing bottlenecks or equipment failure early
Break Compliance Rate	
≤
30
 min
+
5
 min grace
≤30 min+5 min grace	Reduces unmonitored overtime and maintains consistent shift cadence
Solo Job Alarm Incident Rate	
0
 unhandled alarms
0 unhandled alarms	Ensures 
100
%
100% compliance with workplace health & safety regulations
Yield Variance (Target vs. Actual)	
<
3
%
<3% deviation	Enhances order fulfillment accuracy for major supermarket clients
6. Security, Governance & Role-Based Access Control (RBAC)
iZiiApp ensures strict data governance across all operational tiers:



+------------------------------------------------------------------------------------+
|                         ROLE-BASED PERMISSION HIERARCHY                            |
+-------------------+----------------------------------------------------------------+
| Plant Director /  | Full system oversight, cross-department KPI analytics,         |
| Operations Mgr    | payroll approval, system configuration                         |
+-------------------+----------------------------------------------------------------+
| Shift Supervisor  | Harvest plan creation, job assignment, solo worker safety      |
|                   | override, timesheet verification                               |
+-------------------+----------------------------------------------------------------+
| Growing / Mnt     | 8-step pipeline execution, gas level inputs, maintenance       |
| Specialist        | ticket creation & completion                                   |
+-------------------+----------------------------------------------------------------+
| Team Leader       | Color team coordination, trolley allocation, room pick tracking|
+-------------------+----------------------------------------------------------------+
| Picker / Operator | NFC badge check-in/out, task completion confirmation           |
+-------------------+----------------------------------------------------------------+
Noise Protocol P2P Handshake: Cryptographically secured peer-to-peer communication between edge devices without open network vulnerabilities.
Audit Trail: Immutable event logs for all critical changes (on-time overrides, safety alarm clearances, payroll adjustments).
7. Summary of Business Benefits for Plant Leadership


                      +---------------------------------------+
                      |       iZiiApp Mushroom Module         |
                      +---------------------------------------+
                                          |
         +--------------------------------+--------------------------------+
         |                                |                                |
         v                                v                                v
+------------------+             +------------------+             +------------------+
| Labor Efficiency |             | Workplace Safety |             | Crop Predictable |
| 15-20% time saved|             | 100% Lone-Worker |             | Consistent yield |
| via auto planning|             | visibility & SOS |             | via 8-step cycle |
+------------------+             +------------------+             +------------------+
Direct Cost Savings: Automated daily job sheets and Excel/PDF generation eliminate 1.5–2 hours of supervisor manual entry per shift.
Regulatory & Audit Readiness: Full historical traceability of chemical sprays (Prochloraz), gas levels (
CO
/
CO
2
CO/CO 
2
​
 ), and employee shift hours.
Scalability: Modular design ready to scale from 33 rooms to multi-shed and multi-site enterprise operations seamlessly.