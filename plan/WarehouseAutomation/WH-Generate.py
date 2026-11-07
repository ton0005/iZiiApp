"""
=============================================================================
 CAD DRAWING — COSTA MUSHROOM AUTOMATED COLD STORE (REV4 - 80 TONS/DAY)
=============================================================================
 Warehouse: 20.00 m (wide) x 40.00 m (deep) = 800 m² | 8.00 m clear height
 Peak capacity: 80 tons/day (~20,000 boxes/day | ~240 pallets/day | 20 pallets/hour)
 Optimized process line (Cold Chain & WMS):
   1. Two infeed lines (M1 & M2) -> Dynamic checkweighers + 360° barcode scanning
   2. 4-axis robot + dual-box EOAT (14-15 cycles/min) -> P1..P4
   3. Infeed lift -> 2-level pre-cool room (2 x 12 = 24 pallets, negative-pressure airflow)
   4. Outfeed lift -> All-in-One station (pallet weighing + net wrapping + SSCC labeling)
   5. RGV / Mother Shuttle automatically distributes pallets to 13 FIFO shuttle-rack lanes

 Outputs:
   costa_coldstore.dxf         — CAD file (AutoCAD/LibreCAD/BricsCAD)
   dwg01_ga_plan.png           — general arrangement plan (REV4)
   dwg02_section.png           — section A-A (4 rack levels + 2-level pre-cool section)
   dwg03_palletiser_cell.png   — Dual-EOAT robot cell & M1/M2 infeed detail

 Run:  python3 generate_cad.py
=============================================================================
"""
import math, os
import ezdxf
from ezdxf import units
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, Circle, Wedge

OUT = os.path.dirname(os.path.abspath(__file__))

# ---------------------------------------------------------------------------
#  1. DESIGN PARAMETERS (REV4 - OPTIMIZED FOR 80 TONS/DAY)
# ---------------------------------------------------------------------------
W, D, H = 20.00, 40.00, 8.00          # width, depth, clear height [m]

PAL_W, PAL_L = 1.165, 1.165           # Australian AS 4068 pallet
PAL_LOAD_H   = 9 * 0.130              # 9 box layers x 130 mm = 1.170 m
PAL_UNIT_H   = 0.150 + PAL_LOAD_H     # pallet + load = 1.320 m
SHUTTLE_H    = 0.25                   # shuttle + rail
LVL_CLEAR    = 0.10
LVL_PITCH    = PAL_UNIT_H + SHUTTLE_H + LVL_CLEAR   # 1.670 m
TOP_RESERVE  = 0.80                   # sprinklers + roof structure + lights
MAX_LEVELS   = 3
N_LEVELS     = min(MAX_LEVELS, int((H - TOP_RESERVE) // LVL_PITCH))

LANE_PITCH   = 1.40                   # rack lane pitch along the X axis
SIDE_CLEAR   = 0.30
LANE_DEPTH   = 14.00                  # rack lane length
PAL_PITCH_IN_LANE = 1.215

# --- Zones along the Y axis (Y=0 is the wall with the dispatch doors) ---
Z = {
    'dispatch' : (0.00,  6.00, 'DISPATCH & STAGING AREA',           '#FFE8CC'),
    'aisle_out': (6.00, 10.00, 'PICKING AISLE (4.0 m)',             '#F2F2F2'),
    'racking'  : (10.00, 24.00,'THROUGH-FLOW SHUTTLE RACK (FIFO)',  '#DCE9F7'),
    'aisle_in' : (24.00, 28.00,'INFEED & RGV AISLE (4.0 m)',        '#F2F2F2'),
    'precool'  : (28.00, 31.50,'2-LEVEL PRE-COOL ROOM (2-4 °C)',    '#D6F0E0'),
    'pallet'   : (31.50, D,    'ROBOT PALLETIZING AREA (8-12 °C)',  '#FFF6D6'),
}

N_LANES = int((W - 2 * SIDE_CLEAR) // LANE_PITCH)          # 13 lanes
N_POS   = int(LANE_DEPTH // PAL_PITCH_IN_LANE)             # 11 positions/lane
CAP_FULL  = N_LANES * N_POS * N_LEVELS
PHASE1_LANES = 8
CAP_PHASE1 = PHASE1_LANES * N_POS * N_LEVELS

DOCKS = [5.00, 15.00]
DOCK_W = 2.70

# --- Palletizing area equipment (Y = 31.50 -> 40.00) ---
CELL        = (1.20, 31.80, 9.20, 7.80)    # x, y, w, h — cell robot
ROBOT       = (5.80, 35.80)                # 4-axis robot center
ROBOT_REACH = 3.15
EOAT_PICK   = 2                            # Dual pick: 2 boxes/cycle (~14 cycles/min)
BUILD_POS   = [(2.30, 32.90), (4.30, 32.90), (7.30, 32.90), (9.30, 32.90)]

# Two box infeed conveyors from M1 & M2 + dynamic checkweighers
INFEED_M1_Y = 38.20
INFEED_M2_Y = 36.80
MERGE_X     = 11.20
PICK_POS    = (8.00, 37.50)                # Position where EOAT picks two boxes

# --- 2-level pre-cool room equipment (Y = 28.00 -> 31.50) ---
PRECOOL_LEVELS   = 2
LIFT_IN          = (1.80, 28.80, 1.60, 1.60)   # Pallet lift into pre-cool
LIFT_OUT         = (16.80, 28.80, 1.60, 1.60)  # Pallet lift out of pre-cool
PRECOOL_LANE_X0  = 3.60
PRECOOL_LANE_W   = 13.00                       # Accumulation lane width (~11-12 pallets/level)
PRECOOL_LANE_Y   = 28.90
PRECOOL_PAL_LV   = int(PRECOOL_LANE_W // 1.18) # 11-12 pallets/level -> 22-24 pallets across 2 levels
PLENUM_WALL      = (3.60, 30.50, 13.00, 0.70)  # Forced-air plenum wall

# --- All-in-One station at the cold-store entrance (Y = 24.00 -> 28.00) ---
# Directly below the outfeed lift: pallet weighing + net wrapping + SSCC labeling
ALL_IN_ONE = (16.10, 25.00, 3.00, 2.50)
RGV_RAIL_Y = 24.50                             # RGV transfer route along 13 rack lanes


# ---------------------------------------------------------------------------
#  2. EXPORT DXF FILE
# ---------------------------------------------------------------------------
def build_dxf(path):
    doc = ezdxf.new('R2010', setup=True)
    doc.units = units.M
    msp = doc.modelspace()

    lay = [('00-WALL', 7), ('01-ZONE', 8), ('02-RACK', 5), ('03-EQUIPMENT', 3),
           ('04-CONVEYOR', 1), ('05-DOOR', 2), ('06-DIMENSIONS', 4),
           ('07-TEXT', 7), ('08-SAFETY', 1), ('09-FLOW', 6)]
    for n, c in lay:
        doc.layers.add(n, color=c)

    def rect(x, y, w, h, layer, closed=True):
        msp.add_lwpolyline([(x, y), (x + w, y), (x + w, y + h), (x, y + h)],
                           close=closed, dxfattribs={'layer': layer})

    def txt(s, x, y, hgt=0.40, layer='07-TEXT', rot=0):
        t = msp.add_text(s, height=hgt, rotation=rot, dxfattribs={'layer': layer})
        t.set_placement((x, y))

    # -- perimeter walls --
    rect(0, 0, W, D, '00-WALL')
    rect(-0.20, -0.20, W + 0.40, D + 0.40, '00-WALL')

    # -- functional zones --
    for k, (y0, y1, name, _) in Z.items():
        rect(0, y0, W, y1 - y0, '01-ZONE')
        txt(name, 0.4, y1 - 0.8, 0.38, '01-ZONE')

    # -- shuttle rack lanes --
    ry0 = Z['racking'][0]
    for i in range(N_LANES):
        x = SIDE_CLEAR + i * LANE_PITCH
        rect(x, ry0, PAL_W, LANE_DEPTH, '02-RACK')
        if i < PHASE1_LANES:
            msp.add_lwpolyline([(x, ry0), (x + PAL_W, ry0 + LANE_DEPTH)],
                               dxfattribs={'layer': '02-RACK'})
    txt(f'{N_LANES} lanes x {N_POS} positions x {N_LEVELS} levels = {CAP_FULL} pallets (80 tons/day)',
        0.4, ry0 - 1.2, 0.40, '07-TEXT')

    # -- container dispatch doors --
    for cx in DOCKS:
        rect(cx - DOCK_W / 2, -0.25, DOCK_W, 0.50, '05-DOOR')
        txt('CONTAINER DOOR', cx - 1.5, -1.3, 0.38, '05-DOOR')

    # -- robot cell + dual-pick EOAT --
    rect(*CELL, '08-SAFETY')
    msp.add_circle(ROBOT, 0.55, dxfattribs={'layer': '03-EQUIPMENT'})
    msp.add_circle(ROBOT, ROBOT_REACH, dxfattribs={'layer': '08-SAFETY'})
    txt('4-AXIS ROBOT (DUAL-EOAT)', ROBOT[0] - 1.8, ROBOT[1] + 0.8, 0.35, '03-EQUIPMENT')
    for i, (bx, by) in enumerate(BUILD_POS, 1):
        rect(bx - PAL_W / 2, by - PAL_L / 2, PAL_W, PAL_L, '03-EQUIPMENT')
        txt(f'P{i}', bx - 0.25, by - 0.15, 0.32, '03-EQUIPMENT')

    # -- two M1 & M2 infeed lines + checkweighers --
    msp.add_lwpolyline([(W, INFEED_M1_Y), (MERGE_X, INFEED_M1_Y)], dxfattribs={'layer': '04-CONVEYOR'})
    msp.add_lwpolyline([(W, INFEED_M2_Y), (MERGE_X, INFEED_M2_Y)], dxfattribs={'layer': '04-CONVEYOR'})
    msp.add_lwpolyline([(MERGE_X, INFEED_M1_Y), (PICK_POS[0], PICK_POS[1])], dxfattribs={'layer': '04-CONVEYOR'})
    msp.add_lwpolyline([(MERGE_X, INFEED_M2_Y), (PICK_POS[0], PICK_POS[1])], dxfattribs={'layer': '04-CONVEYOR'})
    rect(15.0, INFEED_M1_Y - 0.3, 2.2, 0.6, '03-EQUIPMENT')
    rect(15.0, INFEED_M2_Y - 0.3, 2.2, 0.6, '03-EQUIPMENT')
    txt('DYNAMIC WEIGHING + M1 SCAN', 14.5, INFEED_M1_Y + 0.45, 0.28, '03-EQUIPMENT')
    txt('DYNAMIC WEIGHING + M2 SCAN', 14.5, INFEED_M2_Y - 0.65, 0.28, '03-EQUIPMENT')

    # -- 2-level pre-cool room --
    rect(*LIFT_IN, '03-EQUIPMENT')
    rect(*LIFT_OUT, '03-EQUIPMENT')
    rect(PRECOOL_LANE_X0, PRECOOL_LANE_Y, PRECOOL_LANE_W, 1.40, '04-CONVEYOR')
    rect(*PLENUM_WALL, '03-EQUIPMENT')
    txt('INFEED LIFT', LIFT_IN[0] + 0.1, LIFT_IN[1] + 0.6, 0.28, '03-EQUIPMENT')
    txt('OUTFEED LIFT', LIFT_OUT[0] + 0.1, LIFT_OUT[1] + 0.6, 0.28, '03-EQUIPMENT')
    txt(f'2-LEVEL PRE-COOL CONVEYOR ({PRECOOL_PAL_LV*2} PALLETS) + AIRFLOW WALL',
        PRECOOL_LANE_X0 + 1.0, PRECOOL_LANE_Y + 0.5, 0.32, '03-EQUIPMENT')

    # -- All-in-One station (weighing + wrapping + SSCC) & RGV rail --
    rect(*ALL_IN_ONE, '03-EQUIPMENT')
    txt('PALLET WEIGHING + WRAPPING + SSCC', ALL_IN_ONE[0] - 1.2, ALL_IN_ONE[1] + 1.1, 0.30, '03-EQUIPMENT')
    msp.add_lwpolyline([(0.5, RGV_RAIL_Y), (W - 0.5, RGV_RAIL_Y)], dxfattribs={'layer': '09-FLOW'})
    txt('RGV RAIL / MOTHER SHUTTLE AUTOMATICALLY DISTRIBUTES TO 13 RACK LANES', 2.5, RGV_RAIL_Y + 0.25, 0.30, '09-FLOW')

    # -- overall dimensions --
    dim = msp.add_linear_dim(base=(0, -3.0), p1=(0, 0), p2=(W, 0), dxfattribs={'layer': '06-DIMENSIONS'})
    dim.render()
    dim2 = msp.add_linear_dim(base=(-3.0, 0), p1=(0, 0), p2=(0, D), angle=90, dxfattribs={'layer': '06-DIMENSIONS'})
    dim2.render()

    txt('COSTA MUSHROOM AUTOMATED COLD STORE (REV4 - 80 TONS/DAY)', 0.0, D + 2.4, 0.80)
    txt(f'{W:.2f} m x {D:.2f} m = {W*D:.0f} m2  |  clear height {H:.2f} m', 0.0, D + 1.4, 0.45)
    doc.saveas(path)
    return path


# ---------------------------------------------------------------------------
#  3. DRAWING 01 — GENERAL ARRANGEMENT PLAN (REV4)
# ---------------------------------------------------------------------------
NAVY, ACC, AMB, RED, GRN = '#1F3864', '#2E74B5', '#BF9000', '#C00000', '#275317'

def dwg_plan(path):
    fig, ax = plt.subplots(figsize=(13.5, 20), dpi=150)
    ax.set_xlim(-5.5, W + 5.5); ax.set_ylim(-6.5, D + 5.5)
    ax.set_aspect('equal'); ax.axis('off')

    for k, (y0, y1, name, col) in Z.items():
        ax.add_patch(Rectangle((0, y0), W, y1 - y0, fc=col, ec='#9AA6B4', lw=0.8))
        ax.text(0.35, y1 - 0.65, name, fontsize=8.2, color=NAVY, fontweight='bold')
        ax.text(W - 0.35, y1 - 0.65, f'{W*(y1-y0):.0f} m²', fontsize=7.5, color='#5B6B7C', ha='right')

    ax.add_patch(Rectangle((0, 0), W, D, fill=False, ec=NAVY, lw=2.6))

    # -- 13 shuttle rack lanes --
    ry0 = Z['racking'][0]
    for i in range(N_LANES):
        x = SIDE_CLEAR + i * LANE_PITCH
        ph1 = i < PHASE1_LANES
        ax.add_patch(Rectangle((x, ry0), PAL_W, LANE_DEPTH,
                               fc=('#9DC3E6' if ph1 else '#EAF1FA'), ec=ACC, lw=0.5))
    dtop = Z['aisle_out'][0]
    ax.text(0.5, dtop - 2.2,
            f'SHUTTLE RACK: {N_LANES} lanes x {N_POS} positions x {N_LEVELS} levels = {CAP_FULL} pallets',
            fontsize=8.8, color=NAVY, fontweight='bold')
    ax.text(0.5, dtop - 3.2,
            f'Capacity 80 tons/day (~240 pallets/day) -> ~2.4 days of rotating storage (Phase 1: {CAP_PHASE1} pallets)',
            fontsize=8.0, color=ACC)

    # -- container doors --
    for cx in DOCKS:
        ax.add_patch(Rectangle((cx - DOCK_W/2, -0.35), DOCK_W, 0.70, fc='#FFFFFF', ec=RED, lw=2.2))
        ax.annotate('', xy=(cx, -3.6), xytext=(cx, -0.5), arrowprops=dict(arrowstyle='-|>', color=RED, lw=2.0))
        ax.text(cx, -4.4, 'CONTAINER\n40 ft', fontsize=8, color=RED, ha='center', fontweight='bold')

    # -- robot cell + dual-pick EOAT --
    ax.add_patch(Rectangle(CELL[:2], CELL[2], CELL[3], fc='#FFFFFF', ec=RED, lw=1.6, ls='--'))
    ax.add_patch(Wedge(ROBOT, ROBOT_REACH, 0, 360, fc=AMB, alpha=.13, ec=AMB, ls=':'))
    ax.add_patch(Circle(ROBOT, 0.55, fc=NAVY, ec=NAVY))
    ax.text(ROBOT[0], ROBOT[1] + 0.9, '4-AXIS ROBOT\n(Dual-grip, 2 boxes)', fontsize=7.2,
            ha='center', color=NAVY, fontweight='bold')
    for i, (bx, by) in enumerate(BUILD_POS, 1):
        ax.add_patch(Rectangle((bx - PAL_W/2, by - PAL_L/2), PAL_W, PAL_L, fc='#BDD7EE', ec=NAVY, lw=1.0))
        ax.text(bx, by, f'P{i}', fontsize=8, ha='center', va='center', color=NAVY, fontweight='bold')

    # -- two M1 & M2 infeed lines + checkweighers --
    for y_in, lbl in [(INFEED_M1_Y, 'Infeed M1 (14 boxes/min)'), (INFEED_M2_Y, 'Infeed M2 (14 boxes/min)')]:
        ax.annotate('', xy=(MERGE_X, y_in), xytext=(W - 0.2, y_in),
                    arrowprops=dict(arrowstyle='-|>', color=AMB, lw=2.5))
        ax.add_patch(Rectangle((14.8, y_in - 0.32), 2.4, 0.64, fc='#FCE4D6', ec=RED, lw=1.2))
        ax.text(16.0, y_in, 'DYNAMIC WEIGHING\n+ 360° SCAN', fontsize=5.8, ha='center', va='center', color=RED, fontweight='bold')
        ax.text(18.5, y_in + 0.4, lbl, fontsize=6.5, ha='center', color='#7F6000')

    ax.annotate('', xy=PICK_POS, xytext=(MERGE_X, (INFEED_M1_Y + INFEED_M2_Y)/2),
                arrowprops=dict(arrowstyle='-|>', color=AMB, lw=3.0))
    ax.add_patch(Rectangle((PICK_POS[0]-0.45, PICK_POS[1]-0.35), 0.9, 0.7, fc=AMB, ec='#7F6000'))
    ax.text(PICK_POS[0], PICK_POS[1]+0.65, 'DUAL PICK POINT\n(2 boxes/cycle)', fontsize=6.5, ha='center', color='#7F6000', fontweight='bold')

    # -- 2-level pre-cool room (Y = 28.0 -> 31.5) --
    ax.add_patch(Rectangle(LIFT_IN[:2], LIFT_IN[2], LIFT_IN[3], fc='#D6E4F5', ec=NAVY, lw=1.4))
    ax.text(LIFT_IN[0]+0.8, LIFT_IN[1]+0.8, 'INFEED\nLIFT', fontsize=6.8, ha='center', va='center', color=NAVY, fontweight='bold')
    ax.add_patch(Rectangle(LIFT_OUT[:2], LIFT_OUT[2], LIFT_OUT[3], fc='#D6E4F5', ec=NAVY, lw=1.4))
    ax.text(LIFT_OUT[0]+0.8, LIFT_OUT[1]+0.8, 'OUTFEED\nLIFT', fontsize=6.8, ha='center', va='center', color=NAVY, fontweight='bold')

    # 11-12 pallet positions in the pre-cool tunnel
    ax.add_patch(Rectangle((PRECOOL_LANE_X0, PRECOOL_LANE_Y), PRECOOL_LANE_W, 1.35, fc='#A9D18E', ec=GRN, lw=1.2))
    for p_i in range(PRECOOL_PAL_LV):
        px = PRECOOL_LANE_X0 + 0.1 + p_i * 1.18
        ax.add_patch(Rectangle((px, PRECOOL_LANE_Y + 0.1), 1.10, 1.15, fc='#E2F0D9', ec=GRN, lw=0.6))
    ax.text(PRECOOL_LANE_X0 + PRECOOL_LANE_W/2, PRECOOL_LANE_Y + 0.67,
            f'2-LEVEL ACCUMULATION TUNNEL: 2 x {PRECOOL_PAL_LV} = {PRECOOL_PAL_LV*2} PALLETS (65-75 min cooling)',
            fontsize=7.2, ha='center', va='center', color=GRN, fontweight='bold')

    # Negative-pressure forced-air plenum wall
    ax.add_patch(Rectangle(PLENUM_WALL[:2], PLENUM_WALL[2], PLENUM_WALL[3], fc='#375623', ec=GRN))
    ax.text(PLENUM_WALL[0] + PLENUM_WALL[2]/2, PLENUM_WALL[1] + 0.35,
            'NEGATIVE-PRESSURE FORCED-AIR PLENUM WALL', fontsize=6.5, ha='center', va='center', color='white', fontweight='bold')

    # Pallet flow arrows: P1-P4 -> infeed lift -> pre-cool -> outfeed lift
    ax.annotate('', xy=(LIFT_IN[0]+0.8, LIFT_IN[1]+LIFT_IN[3]), xytext=(2.6, 32.1),
                arrowprops=dict(arrowstyle='-|>', color=GRN, lw=2.2))
    ax.annotate('', xy=(LIFT_OUT[0], PRECOOL_LANE_Y+0.67), xytext=(LIFT_IN[0]+LIFT_IN[2], PRECOOL_LANE_Y+0.67),
                arrowprops=dict(arrowstyle='-|>', color=GRN, lw=2.0, ls='--'))

    # -- All-in-One station (weighing + wrapping + SSCC) in the infeed aisle --
    ax.add_patch(Rectangle(ALL_IN_ONE[:2], ALL_IN_ONE[2], ALL_IN_ONE[3], fc='#FCE4D6', ec=RED, lw=1.6))
    ax.text(ALL_IN_ONE[0] + 1.5, ALL_IN_ONE[1] + 1.25,
            'ALL-IN-ONE STATION\n1. Automatic pallet weighing\n2. Net wrapping\n3. SSCC labeling',
            fontsize=6.6, ha='center', va='center', color=RED, fontweight='bold')
    ax.annotate('', xy=(ALL_IN_ONE[0]+1.5, ALL_IN_ONE[1]+ALL_IN_ONE[3]), xytext=(LIFT_OUT[0]+0.8, LIFT_OUT[1]),
                arrowprops=dict(arrowstyle='-|>', color=RED, lw=2.2))

    # -- RGV / Mother Shuttle route distributing to 13 rack lanes --
    ax.plot([0.6, W - 0.6], [RGV_RAIL_Y, RGV_RAIL_Y], color=ACC, lw=2.8, ls='-.')
    ax.annotate('', xy=(10.0, RGV_RAIL_Y), xytext=(ALL_IN_ONE[0]+1.5, ALL_IN_ONE[1]),
                arrowprops=dict(arrowstyle='-|>', color=ACC, lw=2.2))
    ax.text(8.5, RGV_RAIL_Y + 0.35, 'RGV RAIL / MOTHER SHUTTLE + LIFT (AUTOMATIC DISTRIBUTION TO 13 LANES)',
            fontsize=7.0, ha='center', color=ACC, fontweight='bold')

    # -- dimensions --
    def dim_h(x0, x1, y, lbl):
        ax.annotate('', xy=(x1, y), xytext=(x0, y), arrowprops=dict(arrowstyle='<|-|>', color=NAVY, lw=1.1))
        ax.text((x0+x1)/2, y + .35, lbl, fontsize=8.5, ha='center', color=NAVY)
    def dim_v(y0, y1, x, lbl):
        ax.annotate('', xy=(x, y1), xytext=(x, y0), arrowprops=dict(arrowstyle='<|-|>', color=NAVY, lw=1.1))
        ax.text(x - .5, (y0+y1)/2, lbl, fontsize=8.5, va='center', color=NAVY, rotation=90, ha='center')
    dim_h(0, W, D + 1.6, f'{W:.2f} m')
    dim_v(0, D, -2.2, f'{D:.2f} m')
    for k, (y0, y1, *_) in Z.items():
        dim_v(y0, y1, W + 2.4, f'{y1-y0:.2f}')

    ax.text(0, D + 4.4, 'DRAWING 01 — GENERAL ARRANGEMENT PLAN (REV4: 80 TONS/DAY)', fontsize=14.5, color=NAVY, fontweight='bold')
    ax.text(0, D + 3.2, f'Costa Mushroom automated cold store  |  {W:.2f} x {D:.2f} m = {W*D:.0f} m²  |  2-level pre-cool ({PRECOOL_PAL_LV*2} pallets)  |  Dual-EOAT',
            fontsize=8.8, color='#5B6B7C')
    plt.tight_layout(pad=.4)
    plt.savefig(path, dpi=150, bbox_inches='tight', facecolor='white')
    plt.close()


# ---------------------------------------------------------------------------
#  4. DRAWING 02 — SECTION A-A (3-LEVEL SHUTTLE RACK & 2-LEVEL PRE-COOL)
# ---------------------------------------------------------------------------
def dwg_section(path):
    fig, ax = plt.subplots(figsize=(16, 7.5), dpi=150)
    ax.set_xlim(-5.5, W + 16.0); ax.set_ylim(-1.6, H + 3.4)
    ax.set_aspect('equal'); ax.axis('off')

    ax.add_patch(Rectangle((0, 0), W, H, fc='#F7F9FC', ec=NAVY, lw=2.4))
    ax.add_patch(Rectangle((-0.25, -0.35), W + 0.5, 0.35, fc='#BFBFBF', ec='#7F7F7F'))

    for lv in range(N_LEVELS):
        y = lv * LVL_PITCH
        ax.plot([SIDE_CLEAR, W - SIDE_CLEAR], [y, y], color='#7F7F7F', lw=2.2)
        for i in range(N_LANES):
            x = SIDE_CLEAR + i * LANE_PITCH
            fc = '#9DC3E6' if i < PHASE1_LANES else '#EAF1FA'
            ax.add_patch(Rectangle((x + .04, y + SHUTTLE_H), PAL_W - .08, PAL_UNIT_H, fc=fc, ec=ACC, lw=.5))
        ax.text(W + .4, y + PAL_UNIT_H/2 + SHUTTLE_H, f'Rack level {lv+1} (+{y:.2f}m)', fontsize=8, color=NAVY, va='center')

    # 2-level pre-cool specification callout on the right
    bx, by = W + 5.2, H - 1.2
    ax.text(bx, by + 0.8, '2-LEVEL PRE-COOL ROOM SPECIFICATIONS', fontsize=9, color=GRN, fontweight='bold')
    precool_specs = [
        f'- Level 1 (+0.00m): {PRECOOL_PAL_LV} pallets (ZPA roller conveyor)',
        f'- Level 2 (+2.00m): {PRECOOL_PAL_LV} pallets (ZPA roller conveyor)',
        f'- Total capacity  : {PRECOOL_PAL_LV*2} pallets simultaneously',
        f'- Peak throughput : 20 pallets/hour (80 tons/day)',
        f'- Cooling time    : ~66 - 72 min (2-4 °C)',
        f'- Exhaust fan     : Negative pressure 150-250 Pa'
    ]
    for idx, s in enumerate(precool_specs):
        ax.text(bx, by + 0.25 - idx*0.45, s, fontsize=7.8, color='#375623', family='monospace')

    ax.text(bx, by - 2.9, 'SHUTTLE RACK LEVEL CONSTRUCTION', fontsize=9, color=NAVY, fontweight='bold')
    for i, s in enumerate([f'9 box layers x 130 = {PAL_LOAD_H*1000:.0f} mm',
                           f'AS 4068 pallet   =  150 mm',
                           f'Shuttle + rail   =  {SHUTTLE_H*1000:.0f} mm',
                           f'LEVEL PITCH      = {LVL_PITCH*1000:.0f} mm']):
        ax.text(bx, by - 3.4 - i*.42, s, fontsize=7.6, color=NAVY, family='monospace')

    ax.text(0, H + 2.4, 'DRAWING 02 — SECTION A-A & 2-LEVEL PRE-COOL STRUCTURE', fontsize=15, color=NAVY, fontweight='bold')
    ax.text(0, H + 1.5, f'{N_LEVELS}-level rack ({CAP_FULL} pallets)  |  2-level pre-cool ({PRECOOL_PAL_LV*2} pallets)  |  Clear height {H:.2f} m',
            fontsize=9, color='#5B6B7C')
    plt.tight_layout(pad=.4)
    plt.savefig(path, dpi=150, bbox_inches='tight', facecolor='white')
    plt.close()


# ---------------------------------------------------------------------------
#  5. DRAWING 03 — DUAL-EOAT ROBOT CELL & DUAL INFEED DETAIL
# ---------------------------------------------------------------------------
def dwg_cell(path):
    fig, ax = plt.subplots(figsize=(13, 8.5), dpi=150)
    x0, y0 = 0.0, 30.8
    ax.set_xlim(x0, W + 0.5); ax.set_ylim(y0, D + 1.2)
    ax.set_aspect('equal'); ax.axis('off')

    ax.add_patch(Rectangle(CELL[:2], CELL[2], CELL[3], fc='#FFFDF5', ec=RED, lw=2.0, ls='--'))
    ax.text(CELL[0] + .2, CELL[1] + CELL[3] - .45,
            'AS/NZS 4024 CAT. 3 SAFETY FENCE — DUAL-EOAT ROBOT CELL', fontsize=8.5, color=RED, fontweight='bold')

    ax.add_patch(Wedge(ROBOT, ROBOT_REACH, 0, 360, fc=AMB, alpha=.14, ec=AMB, ls=':', lw=1.4))
    ax.add_patch(Circle(ROBOT, 0.55, fc=NAVY, ec=NAVY))
    ax.text(ROBOT[0], ROBOT[1] - 1.1,
            '4-AXIS ROBOT (R=3.15m)\nDual gripper: 2 boxes/cycle\nSpeed: 14-15 cycles/min (~28-30 boxes/min)',
            fontsize=8.0, ha='center', color=NAVY, fontweight='bold')

    for i, (bx, by) in enumerate(BUILD_POS, 1):
        ax.add_patch(Rectangle((bx - PAL_W/2, by - PAL_L/2), PAL_W, PAL_L, fc='#BDD7EE', ec=NAVY, lw=1.4))
        ax.text(bx, by, f'P{i}\n(SKU {i})', fontsize=9, ha='center', va='center', color=NAVY, fontweight='bold')

    # Roller conveyor supplies empty pallets and pushes full pallets to the pre-cool infeed lift
    ax.add_patch(Rectangle((CELL[0]+.2, CELL[1]+.2), CELL[2]-.4, .55, fc='#E2EFDA', ec='#70AD47', lw=1.2))
    ax.text(CELL[0]+.4, CELL[1]+.38, 'Roller conveyor: Feed empty pallets & push full pallets to pre-cool infeed lift (do not fully wrap here)',
            fontsize=7.3, color='#375623', fontweight='bold')

    # Two M1 & M2 infeed lines
    for y_in, plant_nm in [(INFEED_M1_Y, 'FROM PLANT M1 (35 GROW ROOMS)'), (INFEED_M2_Y, 'FROM PLANT M2 (35 GROW ROOMS)')]:
        ax.annotate('', xy=(MERGE_X, y_in), xytext=(W - 0.3, y_in), arrowprops=dict(arrowstyle='-|>', color=AMB, lw=3.0))
        ax.add_patch(Rectangle((14.5, y_in - 0.35), 2.8, 0.70, fc='#FCE4D6', ec=RED, lw=1.4))
        ax.text(15.9, y_in, 'DYNAMIC CHECKWEIGHER\n+ 360° BARCODE', fontsize=6.8, ha='center', va='center', color=RED, fontweight='bold')
        ax.text(18.6, y_in + 0.42, plant_nm, fontsize=7.5, ha='center', color='#7F6000', fontweight='bold')

    ax.annotate('', xy=PICK_POS, xytext=(MERGE_X, (INFEED_M1_Y + INFEED_M2_Y)/2),
                arrowprops=dict(arrowstyle='-|>', color=AMB, lw=3.2))
    ax.add_patch(Rectangle((PICK_POS[0]-0.5, PICK_POS[1]-0.4), 1.0, 0.8, fc=AMB, ec='#7F6000', lw=1.5))
    ax.text(PICK_POS[0], PICK_POS[1]+0.7, 'DUAL-PICK STATION (2 BOXES)\nClam-shell + compression (gap <= 20 mm)',
            fontsize=7.5, ha='center', color='#7F6000', fontweight='bold')

    ax.text(x0+.2, D + 0.6, 'DRAWING 03 — ROBOT CELL DETAIL (DUAL-EOAT) & M1/M2 DYNAMIC WEIGHING LINES',
            fontsize=14, color=NAVY, fontweight='bold')
    plt.tight_layout(pad=.4)
    plt.savefig(path, dpi=150, bbox_inches='tight', facecolor='white')
    plt.close()


# ---------------------------------------------------------------------------
if __name__ == '__main__':
    print("=" * 76)
    print(" GENERATING CAD DRAWINGS (REV4) — COSTA MUSHROOM AUTOMATED COLD STORE (80 TONS/DAY)")
    print("=" * 76)
    print(f"  Warehouse           : {W:.2f} x {D:.2f} m = {W*D:.0f} m2, height {H:.2f} m")
    print(f"  Peak throughput     : 80 tons/day (~20,000 boxes/day | ~240 pallets/day)")
    print(f"  Robot cell          : Dual-box EOAT (2 boxes/cycle) -> ~14-15 cycles/min")
    print(f"  Pre-cool room       : {PRECOOL_LEVELS} levels x {PRECOOL_PAL_LV} positions = {PRECOOL_PAL_LV*PRECOOL_LEVELS} pallets simultaneously")
    print(f"  Shuttle rack capacity: {N_LANES} lanes x {N_POS} positions x {N_LEVELS} levels = {CAP_FULL} pallets")
    print()
    p = build_dxf(os.path.join(OUT, 'costa_coldstore.dxf')); print("  [OK]", os.path.basename(p))
    for fn, f in (('01_ga_plan.png', dwg_plan),
                  ('02_section.png', dwg_section),
                  ('03_palletiser_cell.png', dwg_cell)):
        f(os.path.join(OUT, fn)); print("  [OK]", fn)