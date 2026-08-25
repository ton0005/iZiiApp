"""
=============================================================================
 BAN VE CAD — KHO LANH TU DONG COSTA MUSHROOM
=============================================================================
 Nha kho:  30,00 m (rong)  x  53,33 m (sau)  =  1.600 m²  |  cao thong thuy 8,00 m
 Day chuyen: Palletizer robot -> Quan mang -> Can tu dong -> Dan nhan SSCC
             -> Lam lanh so bo -> Ke con thoi xuyen suot -> 2 cua xuat container

 Xuat ra:
   costa_coldstore.dxf         — file CAD (AutoCAD/LibreCAD/BricsCAD)
   dwg01_ga_plan.png           — mat bang tong the
   dwg02_section.png           — mat cat A-A (chieu cao, 4 tang ke)
   dwg03_palletiser_cell.png   — chi tiet cell robot xep pallet

 Chay:  python3 generate_cad.py
=============================================================================
"""
import math, os
import ezdxf
from ezdxf import units
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, Circle, FancyArrow, Wedge, Polygon

OUT = os.path.dirname(os.path.abspath(__file__))

# ---------------------------------------------------------------------------
#  1. THAM SO THIET KE   (moi kich thuoc deu tinh ra tu day)
# ---------------------------------------------------------------------------
W, D, H = 30.00, 53.33, 8.00          # rong, sau, cao thong thuy  [m]

PAL_W, PAL_L = 1.165, 1.165           # pallet Uc AS 4068
PAL_LOAD_H   = 9 * 0.130              # 9 lop box 130 mm
PAL_UNIT_H   = 0.150 + PAL_LOAD_H     # pallet + hang = 1,320 m
SHUTTLE_H    = 0.25                   # xe con thoi + ray
LVL_CLEAR    = 0.10
LVL_PITCH    = PAL_UNIT_H + SHUTTLE_H + LVL_CLEAR   # 1,670 m
TOP_RESERVE  = 0.80                   # sprinkler + ket cau mai + den
N_LEVELS     = int((H - TOP_RESERVE) // LVL_PITCH)  # = 4

LANE_PITCH   = 1.40                   # buoc lan ke theo phuong X
SIDE_CLEAR   = 0.30
LANE_DEPTH   = 22.00                  # chieu dai lan
PAL_PITCH_IN_LANE = 1.215

# --- Phan vung theo truc Y (Y=0 la tuong co cua xuat) ---
Z = {
    'dispatch' : (0.00,  9.00, 'KHU XUAT HANG & TAP KET',        '#FFE8CC'),
    'aisle_out': (9.00, 13.00, 'LOI LAY HANG  (4,0 m)',          '#F2F2F2'),
    'racking'  : (13.00, 35.00,'KE CON THOI XUYEN SUOT',          '#DCE9F7'),
    'aisle_in' : (35.00, 39.00,'LOI NAP HANG  (4,0 m)',           '#F2F2F2'),
    'precool'  : (39.00, 44.00,'PHONG LAM LANH SO BO  2-4 °C',    '#D6F0E0'),
    'pallet'   : (44.00, D,    'KHU XEP PALLET  8-12 °C',         '#FFF6D6'),
}

N_LANES = int((W - 2 * SIDE_CLEAR) // LANE_PITCH)          # 21
N_POS   = int(LANE_DEPTH // PAL_PITCH_IN_LANE)             # 18
CAP_FULL  = N_LANES * N_POS * N_LEVELS
PHASE1_LANES = 8
CAP_PHASE1 = PHASE1_LANES * N_POS * N_LEVELS

DOCKS = [9.00, 21.00]                 # tam cua xuat container
DOCK_W = 2.70

# --- Thiet bi trong khu xep pallet ---
CELL   = (1.50, 45.00, 9.00, 8.00)    # x, y, w, h  — cell robot
ROBOT  = (6.00, 49.00)                # tam robot
ROBOT_REACH = 3.15
BUILD_POS = [(2.60, 46.10), (4.60, 46.10), (7.40, 46.10), (9.40, 46.10)]
WRAPPER = (13.00, 47.50, 3.00, 3.00)
SCALE   = (17.50, 47.50, 3.00, 3.00)
LABEL   = (21.50, 47.50, 1.60, 3.00)

CONV_Y  = 49.00                       # tim bang tai ngang
CONV_X  = 22.30                       # tim bang tai doc xuong pre-cool


# ---------------------------------------------------------------------------
#  2. XUAT FILE DXF
# ---------------------------------------------------------------------------
def build_dxf(path):
    doc = ezdxf.new('R2010', setup=True)
    doc.units = units.M
    msp = doc.modelspace()

    lay = [('00-TUONG', 7), ('01-VUNG', 8), ('02-KE', 5), ('03-THIET-BI', 3),
           ('04-BANG-TAI', 1), ('05-CUA', 2), ('06-KICH-THUOC', 4),
           ('07-CHU', 7), ('08-AN-TOAN', 1), ('09-LUONG', 6)]
    for n, c in lay:
        doc.layers.add(n, color=c)

    def rect(x, y, w, h, layer, closed=True):
        msp.add_lwpolyline([(x, y), (x + w, y), (x + w, y + h), (x, y + h)],
                           close=closed, dxfattribs={'layer': layer})

    def txt(s, x, y, hgt=0.45, layer='07-CHU', rot=0):
        t = msp.add_text(s, height=hgt, rotation=rot, dxfattribs={'layer': layer})
        t.set_placement((x, y))

    # -- tuong bao (day 0,20 m) --
    rect(0, 0, W, D, '00-TUONG')
    rect(-0.20, -0.20, W + 0.40, D + 0.40, '00-TUONG')

    # -- vung chuc nang --
    for k, (y0, y1, name, _) in Z.items():
        rect(0, y0, W, y1 - y0, '01-VUNG')
        txt(name, 0.4, y1 - 0.9, 0.42, '01-VUNG')

    # -- lan ke con thoi --
    ry0, ry1 = Z['racking'][0], Z['racking'][1]
    for i in range(N_LANES):
        x = SIDE_CLEAR + i * LANE_PITCH
        rect(x, ry0, PAL_W, LANE_DEPTH, '02-KE')
        if i < PHASE1_LANES:                       # danh dau giai doan 1
            msp.add_lwpolyline([(x, ry0), (x + PAL_W, ry0 + LANE_DEPTH)],
                               dxfattribs={'layer': '02-KE'})
    txt(f'{N_LANES} lan x {N_POS} vi tri x {N_LEVELS} tang = {CAP_FULL} pallet',
        0.4, ry0 - 1.2, 0.45, '07-CHU')

    # -- cua xuat container --
    for cx in DOCKS:
        rect(cx - DOCK_W / 2, -0.25, DOCK_W, 0.50, '05-CUA')
        txt('CUA CONTAINER', cx - 1.6, -1.4, 0.40, '05-CUA')

    # -- cell robot + hang rao an toan --
    rect(*CELL, '08-AN-TOAN')
    msp.add_circle(ROBOT, 0.55, dxfattribs={'layer': '03-THIET-BI'})
    msp.add_circle(ROBOT, ROBOT_REACH, dxfattribs={'layer': '08-AN-TOAN'})
    txt('ROBOT 4 TRUC', ROBOT[0] - 1.6, ROBOT[1] + 0.8, 0.40, '03-THIET-BI')
    for i, (bx, by) in enumerate(BUILD_POS, 1):
        rect(bx - PAL_W / 2, by - PAL_L / 2, PAL_W, PAL_L, '03-THIET-BI')
        txt(f'P{i}', bx - 0.25, by - 0.2, 0.35, '03-THIET-BI')

    # -- thiet bi day chuyen --
    for r, nm in ((WRAPPER, 'QUAN MANG'), (SCALE, 'CAN TU DONG'), (LABEL, 'DAN NHAN')):
        rect(*r, '03-THIET-BI')
        txt(nm, r[0] + 0.15, r[1] + r[3] / 2, 0.35, '03-THIET-BI')

    # -- bang tai --
    msp.add_lwpolyline([(CELL[0] + CELL[2], CONV_Y), (CONV_X, CONV_Y)],
                       dxfattribs={'layer': '04-BANG-TAI'})
    msp.add_lwpolyline([(CONV_X, CONV_Y), (CONV_X, Z['aisle_in'][1])],
                       dxfattribs={'layer': '04-BANG-TAI'})
    msp.add_lwpolyline([(W, CONV_Y + 1.6), (ROBOT[0] + 2.0, CONV_Y + 1.6)],
                       dxfattribs={'layer': '04-BANG-TAI'})
    txt('BANG TAI BOX VAO', W - 6.5, CONV_Y + 1.9, 0.38, '04-BANG-TAI')
    txt('DOC MA VACH', ROBOT[0] + 2.2, CONV_Y + 1.9, 0.38, '04-BANG-TAI')

    # -- kich thuoc tong --
    dim = msp.add_linear_dim(base=(0, -3.0), p1=(0, 0), p2=(W, 0),
                             dxfattribs={'layer': '06-KICH-THUOC'})
    dim.render()
    dim2 = msp.add_linear_dim(base=(-3.0, 0), p1=(0, 0), p2=(0, D), angle=90,
                              dxfattribs={'layer': '06-KICH-THUOC'})
    dim2.render()

    txt('KHO LANH TU DONG — COSTA MUSHROOM', 0.0, D + 2.4, 0.90)
    txt(f'{W:.2f} m x {D:.2f} m = {W*D:.0f} m2  |  cao thong thuy {H:.2f} m',
        0.0, D + 1.4, 0.50)
    doc.saveas(path)
    return path


# ---------------------------------------------------------------------------
#  3. BAN VE 01 — MAT BANG TONG THE
# ---------------------------------------------------------------------------
NAVY, ACC, AMB, RED = '#1F3864', '#2E74B5', '#BF9000', '#C00000'

def dwg_plan(path):
    fig, ax = plt.subplots(figsize=(13.5, 20), dpi=150)
    ax.set_xlim(-5.5, W + 5.5); ax.set_ylim(-6.5, D + 5.5)
    ax.set_aspect('equal'); ax.axis('off')

    for k, (y0, y1, name, col) in Z.items():
        ax.add_patch(Rectangle((0, y0), W, y1 - y0, fc=col, ec='#9AA6B4', lw=0.8))
        ax.text(0.35, y1 - 0.75, name, fontsize=8.5, color=NAVY, fontweight='bold')
        ax.text(W - 0.35, y1 - 0.75, f'{W*(y1-y0):.0f} m²', fontsize=7.5,
                color='#5B6B7C', ha='right')

    ax.add_patch(Rectangle((0, 0), W, D, fill=False, ec=NAVY, lw=2.6))

    # lan ke
    ry0 = Z['racking'][0]
    for i in range(N_LANES):
        x = SIDE_CLEAR + i * LANE_PITCH
        ph1 = i < PHASE1_LANES
        ax.add_patch(Rectangle((x, ry0), PAL_W, LANE_DEPTH,
                               fc=('#9DC3E6' if ph1 else '#EAF1FA'),
                               ec=ACC, lw=0.5))
    ax.text(0.5, 6.6,
            f'KE: {N_LANES} lan x {N_POS} vi tri x {N_LEVELS} tang = {CAP_FULL} pallet',
            fontsize=9, color=NAVY, fontweight='bold')
    ax.text(0.5, 5.6,
            f'Giai doan 1: {PHASE1_LANES} lan to dam = {CAP_PHASE1} pallet '
            f'({CAP_PHASE1/208:.1f} ngay luu)', fontsize=8.5, color=ACC)

    # cua container
    for cx in DOCKS:
        ax.add_patch(Rectangle((cx - DOCK_W/2, -0.35), DOCK_W, 0.70,
                               fc='#FFFFFF', ec=RED, lw=2.2))
        ax.annotate('', xy=(cx, -3.6), xytext=(cx, -0.5),
                    arrowprops=dict(arrowstyle='-|>', color=RED, lw=2.0))
        ax.text(cx, -4.4, 'CONTAINER\n40 ft', fontsize=8, color=RED,
                ha='center', fontweight='bold')
        ax.text(cx, 0.9, f'Cua {DOCK_W:.1f} m', fontsize=7, ha='center', color=RED)

    # cell robot
    ax.add_patch(Rectangle(CELL[:2], CELL[2], CELL[3], fc='#FFFFFF',
                           ec=RED, lw=1.8, ls='--'))
    ax.add_patch(Wedge(ROBOT, ROBOT_REACH, 0, 360, fc=AMB, alpha=.13, ec=AMB, ls=':'))
    ax.add_patch(Circle(ROBOT, 0.55, fc=NAVY, ec=NAVY))
    ax.text(ROBOT[0], ROBOT[1] + 0.95, 'ROBOT 4 TRUC', fontsize=7.5,
            ha='center', color=NAVY, fontweight='bold')
    ax.text(CELL[0], CELL[1] - 0.55,
            'CELL XEP PALLET — rao an toan Cat.3', fontsize=7.5, color=RED)
    for i, (bx, by) in enumerate(BUILD_POS, 1):
        ax.add_patch(Rectangle((bx - PAL_W/2, by - PAL_L/2), PAL_W, PAL_L,
                               fc='#BDD7EE', ec=NAVY, lw=1.0))
        ax.text(bx, by, f'P{i}', fontsize=8, ha='center', va='center',
                color=NAVY, fontweight='bold')

    # thiet bi
    for r, nm in ((WRAPPER, 'QUAN\nMANG'), (SCALE, 'CAN\nTU DONG'), (LABEL, 'DAN\nNHAN')):
        ax.add_patch(Rectangle(r[:2], r[2], r[3], fc='#D6E4F5', ec=NAVY, lw=1.3))
        ax.text(r[0] + r[2]/2, r[1] + r[3]/2, nm, fontsize=7.5, ha='center',
                va='center', color=NAVY, fontweight='bold')

    # bang tai
    def conv(x0, y0, x1, y1, lbl=None):
        ax.annotate('', xy=(x1, y1), xytext=(x0, y0),
                    arrowprops=dict(arrowstyle='-|>', color=AMB, lw=3.0))
        if lbl:
            ax.text((x0+x1)/2, (y0+y1)/2 + .55, lbl, fontsize=7,
                    color='#7F6000', ha='center')
    conv(W - 0.4, CONV_Y + 1.6, ROBOT[0] + 2.2, CONV_Y + 1.6, 'bang tai box vao')
    ax.add_patch(Circle((ROBOT[0] + 2.0, CONV_Y + 1.6), 0.34, fc=AMB, ec='#7F6000'))
    ax.text(ROBOT[0] + 2.0, CONV_Y + 2.4, 'DOC MA VACH', fontsize=7,
            ha='center', color='#7F6000', fontweight='bold')
    conv(CELL[0] + CELL[2], CONV_Y, WRAPPER[0], CONV_Y)
    conv(WRAPPER[0] + WRAPPER[2], CONV_Y, SCALE[0], CONV_Y)
    conv(SCALE[0] + SCALE[2], CONV_Y, LABEL[0], CONV_Y)
    conv(LABEL[0] + LABEL[2], CONV_Y, CONV_X, CONV_Y)
    conv(CONV_X, CONV_Y - 0.3, CONV_X, Z['aisle_in'][1], 'xuong lam lanh so bo')

    # luong hang trong kho
    ax.annotate('', xy=(W/2, Z['racking'][0] + 1), xytext=(W/2, Z['aisle_in'][0] - .3),
                arrowprops=dict(arrowstyle='-|>', color='#375623', lw=2.4, ls='--'))
    ax.text(W/2 + 0.9, (Z['racking'][0]+Z['aisle_in'][0])/2,
            'FIFO xuyen suot\nnap sau — lay truoc', fontsize=8,
            color='#375623', fontweight='bold', rotation=90, va='center')

    # kich thuoc
    def dim_h(x0, x1, y, lbl):
        ax.annotate('', xy=(x1, y), xytext=(x0, y),
                    arrowprops=dict(arrowstyle='<|-|>', color=NAVY, lw=1.1))
        ax.text((x0+x1)/2, y + .35, lbl, fontsize=8.5, ha='center', color=NAVY)
    def dim_v(y0, y1, x, lbl):
        ax.annotate('', xy=(x, y1), xytext=(x, y0),
                    arrowprops=dict(arrowstyle='<|-|>', color=NAVY, lw=1.1))
        ax.text(x - .5, (y0+y1)/2, lbl, fontsize=8.5, va='center',
                color=NAVY, rotation=90, ha='center')
    dim_h(0, W, D + 1.6, f'{W:.2f} m')
    dim_v(0, D, -2.2, f'{D:.2f} m')
    for k, (y0, y1, *_ ) in Z.items():
        dim_v(y0, y1, W + 2.4, f'{y1-y0:.2f}')

    ax.text(0, D + 4.4, 'BAN VE 01 — MAT BANG TONG THE', fontsize=15,
            color=NAVY, fontweight='bold')
    ax.text(0, D + 3.2, f'Kho lanh tu dong Costa Mushroom  |  '
            f'{W:.2f} x {D:.2f} m = {W*D:.0f} m²  |  cao thong thuy {H:.2f} m  |  ty le 1:150',
            fontsize=9, color='#5B6B7C')
    ax.text(0, -5.6, 'Ghi chu: kich thuoc tinh bang met. Vi tri thiet bi la so bo, '
            'can xac nhan sau khao sat hien truong.', fontsize=7.5,
            color='#5B6B7C', style='italic')
    plt.tight_layout(pad=.4)
    plt.savefig(path, dpi=150, bbox_inches='tight', facecolor='white')
    plt.close()


# ---------------------------------------------------------------------------
#  4. BAN VE 02 — MAT CAT A-A
# ---------------------------------------------------------------------------
def dwg_section(path):
    fig, ax = plt.subplots(figsize=(16, 7.2), dpi=150)
    ax.set_xlim(-5.5, W + 15.0); ax.set_ylim(-1.6, H + 3.4)
    ax.set_aspect('equal'); ax.axis('off')

    ax.add_patch(Rectangle((0, 0), W, H, fc='#F7F9FC', ec=NAVY, lw=2.4))
    ax.add_patch(Rectangle((-0.25, -0.35), W + 0.5, 0.35, fc='#BFBFBF', ec='#7F7F7F'))
    ax.plot([0, W], [H, H], color=NAVY, lw=2.4)

    # 4 tang ke
    for lv in range(N_LEVELS):
        y = lv * LVL_PITCH
        ax.plot([SIDE_CLEAR, W - SIDE_CLEAR], [y, y], color='#7F7F7F', lw=2.2)
        for i in range(N_LANES):
            x = SIDE_CLEAR + i * LANE_PITCH
            fc = '#9DC3E6' if i < PHASE1_LANES else '#EAF1FA'
            ax.add_patch(Rectangle((x + .04, y + SHUTTLE_H), PAL_W - .08,
                                   PAL_UNIT_H, fc=fc, ec=ACC, lw=.5))
        ax.text(W + .5, y + PAL_UNIT_H/2 + SHUTTLE_H,
                f'Tang {lv+1}  +{y:.3f}', fontsize=8, color=NAVY, va='center')

    ytop = (N_LEVELS - 1) * LVL_PITCH + SHUTTLE_H + PAL_UNIT_H
    ax.plot([0, W], [ytop, ytop], color=RED, lw=1.0, ls='--')
    ax.text(0.3, ytop + .16, f'Dinh hang tang {N_LEVELS}: +{ytop:.3f} m',
            fontsize=8, color=RED)
    ax.annotate('', xy=(W - 2.0, H), xytext=(W - 2.0, ytop),
                arrowprops=dict(arrowstyle='<|-|>', color=RED, lw=1.2))
    ax.text(W - 1.8, (H + ytop)/2, f'{H - ytop:.2f} m\nsprinkler + den',
            fontsize=7.5, color=RED, va='center')

    # kich thuoc dung
    ax.annotate('', xy=(-2.6, H), xytext=(-2.6, 0),
                arrowprops=dict(arrowstyle='<|-|>', color=NAVY, lw=1.2))
    ax.text(-3.3, H/2, f'{H:.2f} m thong thuy', fontsize=10, color=NAVY,
            rotation=90, va='center', ha='center')
    ax.annotate('', xy=(-1.2, LVL_PITCH), xytext=(-1.2, 0),
                arrowprops=dict(arrowstyle='<|-|>', color=ACC, lw=1.1))
    ax.text(-1.7, LVL_PITCH/2, f'{LVL_PITCH*1000:.0f}', fontsize=8,
            color=ACC, rotation=90, va='center', ha='center')

    # chu thich cau tao 1 tang
    bx, by = W + 5.6, H - 1.6
    ax.text(bx, by + .95, 'CAU TAO MOT TANG', fontsize=9, color=NAVY, fontweight='bold')
    for i, s in enumerate([f'Hang 9 lop x 130 = {PAL_LOAD_H*1000:.0f} mm',
                           f'Pallet AS 4068     =  150 mm',
                           f'Xe con thoi + ray  =  {SHUTTLE_H*1000:.0f} mm',
                           f'Ho ky thuat        =  {LVL_CLEAR*1000:.0f} mm',
                           f'BUOC TANG          = {LVL_PITCH*1000:.0f} mm']):
        ax.text(bx, by + .45 - i*.42, s, fontsize=7.6,
                color=(NAVY if i == 4 else '#5B6B7C'),
                fontweight=('bold' if i == 4 else 'normal'), family='monospace')

    ax.text(0, H + 2.4, 'BAN VE 02 — MAT CAT A-A  (qua khu ke)', fontsize=15,
            color=NAVY, fontweight='bold')
    ax.text(0, H + 1.5, f'{N_LEVELS} tang ke  |  buoc tang {LVL_PITCH*1000:.0f} mm  |  '
            f'suc chua ket cau {CAP_FULL} pallet  |  ty le 1:100',
            fontsize=9, color='#5B6B7C')
    ax.text(0, -1.25, 'Ghi chu: chieu cao 8,00 m chi cho phep 4 tang. '
            'Phuong an AS/RS 8 tang trong de xuat truoc doi hoi nha cao ~14 m.',
            fontsize=8, color=RED, style='italic')
    plt.tight_layout(pad=.4)
    plt.savefig(path, dpi=150, bbox_inches='tight', facecolor='white')
    plt.close()


# ---------------------------------------------------------------------------
#  5. BAN VE 03 — CHI TIET CELL XEP PALLET
# ---------------------------------------------------------------------------
def dwg_cell(path):
    fig, ax = plt.subplots(figsize=(13, 8.5), dpi=150)
    x0, y0 = CELL[0] - 1.6, CELL[1] - 2.4
    ax.set_xlim(x0, LABEL[0] + LABEL[2] + 3.2); ax.set_ylim(y0, CELL[1] + CELL[3] + 2.6)
    ax.set_aspect('equal'); ax.axis('off')

    ax.add_patch(Rectangle(CELL[:2], CELL[2], CELL[3], fc='#FFFDF5',
                           ec=RED, lw=2.2, ls='--'))
    ax.text(CELL[0] + .2, CELL[1] + CELL[3] - .5,
            'RAO AN TOAN — AS/NZS 4024, mach Category 3', fontsize=9,
            color=RED, fontweight='bold')

    ax.add_patch(Wedge(ROBOT, ROBOT_REACH, 0, 360, fc=AMB, alpha=.14, ec=AMB, ls=':', lw=1.4))
    ax.text(ROBOT[0] + ROBOT_REACH*.62, ROBOT[1] + ROBOT_REACH*.62,
            f'tam voi R{ROBOT_REACH:.2f} m', fontsize=8, color='#7F6000')
    ax.add_patch(Circle(ROBOT, 0.60, fc=NAVY, ec=NAVY))
    ax.text(ROBOT[0], ROBOT[1] - 1.15, 'ROBOT 4 TRUC\n20-30 chu ky/phut',
            fontsize=8.5, ha='center', color=NAVY, fontweight='bold')

    for i, (bx, by) in enumerate(BUILD_POS, 1):
        ax.add_patch(Rectangle((bx - PAL_W/2, by - PAL_L/2), PAL_W, PAL_L,
                               fc='#BDD7EE', ec=NAVY, lw=1.4))
        ax.text(bx, by, f'P{i}', fontsize=11, ha='center', va='center',
                color=NAVY, fontweight='bold')
    ax.text((BUILD_POS[0][0]+BUILD_POS[-1][0])/2, CELL[1] - 1.15,
            '4 vi tri xep dong thoi  (1165 x 1165 mm)', fontsize=8.5,
            ha='center', color=NAVY)

    # bang tai con lan pallet
    ax.add_patch(Rectangle((CELL[0]+.2, CELL[1]+.3), CELL[2]-.4, .5,
                           fc='#E2EFDA', ec='#70AD47', lw=1.2))
    ax.text(CELL[0]+.35, CELL[1]+.44, 'bang tai con lan — pallet rong vao / pallet day ra',
            fontsize=7.5, color='#375623')

    # infeed + doc ma vach
    ax.annotate('', xy=(ROBOT[0]+2.1, CONV_Y+1.6), xytext=(LABEL[0]+2.6, CONV_Y+1.6),
                arrowprops=dict(arrowstyle='-|>', color=AMB, lw=3.4))
    ax.add_patch(Circle((ROBOT[0]+1.9, CONV_Y+1.6), .38, fc=AMB, ec='#7F6000', lw=1.4))
    ax.text(ROBOT[0]+1.9, CONV_Y+2.35, 'DOC MA VACH\n(diem tao lien ket box -> pallet)',
            fontsize=8, ha='center', color='#7F6000', fontweight='bold')
    ax.text(LABEL[0]+1.0, CONV_Y+2.05, 'box tu khu dong goi', fontsize=8, color='#7F6000')

    for r, nm in ((WRAPPER,'QUAN MANG'), (SCALE,'CAN TU DONG\n+/- 0,5 kg'), (LABEL,'DAN NHAN\nSSCC')):
        ax.add_patch(Rectangle(r[:2], r[2], r[3], fc='#D6E4F5', ec=NAVY, lw=1.6))
        ax.text(r[0]+r[2]/2, r[1]+r[3]/2, nm, fontsize=8.5, ha='center',
                va='center', color=NAVY, fontweight='bold')
    for a, b in ((CELL[0]+CELL[2], WRAPPER[0]), (WRAPPER[0]+WRAPPER[2], SCALE[0]),
                 (SCALE[0]+SCALE[2], LABEL[0])):
        ax.annotate('', xy=(b, CONV_Y), xytext=(a, CONV_Y),
                    arrowprops=dict(arrowstyle='-|>', color=AMB, lw=3.0))
    ax.annotate('', xy=(LABEL[0]+LABEL[2]+2.4, CONV_Y), xytext=(LABEL[0]+LABEL[2], CONV_Y),
                arrowprops=dict(arrowstyle='-|>', color=AMB, lw=3.0))
    ax.text(LABEL[0]+LABEL[2]+.3, CONV_Y-.75, 'xuong phong\nlam lanh so bo',
            fontsize=8, color='#7F6000')

    ax.text(x0+.1, CELL[1]+CELL[3]+1.9, 'BAN VE 03 — CHI TIET CELL XEP PALLET',
            fontsize=15, color=NAVY, fontweight='bold')
    ax.text(x0+.1, CELL[1]+CELL[3]+1.15,
            'Tay gap kep hai ben + do day (khay ho) | khe ho <= 20 mm | ty le 1:50',
            fontsize=9, color='#5B6B7C')
    plt.tight_layout(pad=.4)
    plt.savefig(path, dpi=150, bbox_inches='tight', facecolor='white')
    plt.close()


# ---------------------------------------------------------------------------
if __name__ == '__main__':
    print("=" * 74)
    print(" SINH BAN VE CAD — KHO LANH TU DONG COSTA MUSHROOM")
    print("=" * 74)
    print(f"  Nha kho          : {W:.2f} x {D:.2f} m = {W*D:.0f} m2, cao {H:.2f} m")
    print(f"  So tang ke       : {N_LEVELS}  (buoc tang {LVL_PITCH*1000:.0f} mm)")
    print(f"  So lan           : {N_LANES}  (buoc lan {LANE_PITCH*1000:.0f} mm)")
    print(f"  Vi tri moi lan   : {N_POS}")
    print(f"  Suc chua ket cau : {CAP_FULL:,} pallet")
    print(f"  Giai doan 1      : {PHASE1_LANES} lan = {CAP_PHASE1:,} pallet"
          f"  ({CAP_PHASE1/208:.1f} ngay luu o 208 pallet/ngay)")
    print(f"  Kiem tra dien tich: " +
          " + ".join(f"{W*(v[1]-v[0]):.0f}" for v in Z.values()) +
          f" = {sum(W*(v[1]-v[0]) for v in Z.values()):.0f} m2")
    print()
    p = build_dxf(os.path.join(OUT, 'costa_coldstore.dxf')); print("  [OK]", os.path.basename(p))
    for fn, f in (('dwg01_ga_plan.png', dwg_plan),
                  ('dwg02_section.png', dwg_section),
                  ('dwg03_palletiser_cell.png', dwg_cell)):
        f(os.path.join(OUT, fn)); print("  [OK]", fn)
