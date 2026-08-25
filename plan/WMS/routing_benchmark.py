"""
=============================================================================
 So sanh cac chien luoc dinh tuyen lay hang trong kho mot khoi (single-block)
=============================================================================

MUC DICH: kiem chung bang so lieu cac nhan dinh trong `Research.txt`, dac biet
la de tra loi cau hoi "Dijkstra co giai duoc bai toan nay khong?".

KET LUAN NGAN (chay file de xem so lieu):
  - Dijkstra KHONG giai bai toan nay. No chi la BUOC TRUNG GIAN de dung ma
    tran khoang cach giua cac diem lay hang.
  - Bai toan that la TSP (chinh xac hon: Steiner TSP tren do thi kho).
  - Ratliff & Rosenthal (1983) da co loi giai CHINH XAC, thoi gian da thuc
    cho kho mot khoi — khong can heuristic.

Chay:  python3 routing_benchmark.py
=============================================================================
"""
import heapq, itertools, random, statistics
from math import inf


# ---------------------------------------------------------------------------
#  MO HINH KHO
# ---------------------------------------------------------------------------
class Warehouse:
    """Kho chu nhat mot khoi: N loi di song song, loi ngang CHI o hai dau.

    Day dung la cau hinh ma Ratliff & Rosenthal (1983) giai duoc chinh xac.
    """

    def __init__(self, n_aisles=10, slots_per_aisle=20, aisle_w=3.0, pitch=1.2):
        self.na, self.ns = n_aisles, slots_per_aisle
        self.aw, self.p = aisle_w, pitch
        self.Ymax = (slots_per_aisle + 1) * pitch
        self.nodes, self.adj = {}, {}
        self._build()

    def _add(self, key, xy):
        self.nodes[key] = xy
        self.adj.setdefault(key, [])

    def _link(self, a, b):
        (x1, y1), (x2, y2) = self.nodes[a], self.nodes[b]
        d = abs(x1 - x2) + abs(y1 - y2)          # di chuyen theo phuong truc
        self.adj[a].append((b, d))
        self.adj[b].append((a, d))

    def _build(self):
        for i in range(self.na):
            x = i * self.aw
            self._add(('F', i), (x, 0.0))            # dau loi (front)
            self._add(('B', i), (x, self.Ymax))      # cuoi loi (back)
            for j in range(1, self.ns + 1):
                self._add(('P', i, j), (x, j * self.p))
        for i in range(self.na - 1):                 # hai loi ngang
            self._link(('F', i), ('F', i + 1))
            self._link(('B', i), ('B', i + 1))
        for i in range(self.na):                     # doc trong tung loi
            prev = ('F', i)
            for j in range(1, self.ns + 1):
                self._link(prev, ('P', i, j))
                prev = ('P', i, j)
            self._link(prev, ('B', i))
        self.depot = ('F', 0)

    # -- Dijkstra: DAY moi la cho no dung viec -------------------------------
    def dijkstra(self, src):
        """Duong di ngan nhat tu src toi MOI nut khac.

        Luu y: ket qua la KHOANG CACH GIUA HAI DIEM, khong phai thu tu tham
        quan toi uu. Do la hai bai toan khac nhau.
        """
        dist = {k: inf for k in self.nodes}
        dist[src] = 0.0
        pq, seen = [(0.0, src)], set()
        while pq:
            d, u = heapq.heappop(pq)
            if u in seen:
                continue
            seen.add(u)
            for v, w in self.adj[u]:
                nd = d + w
                if nd < dist[v]:
                    dist[v] = nd
                    heapq.heappush(pq, (nd, v))
        return dist

    def dmatrix(self, pts):
        """Ma tran khoang cach (metric closure) — dau vao cho bo giai TSP."""
        return {a: self.dijkstra(a) for a in pts}


# ---------------------------------------------------------------------------
#  CAC CHIEN LUOC DINH TUYEN
# ---------------------------------------------------------------------------
def route_sshape(wh, picks):
    """S-shape (zic-zac): di xuyen suot moi loi co hang.

    Loi CUOI CUNG duoc xu ly dac biet de nguoi lay hang ket thuc o dau loi.
    """
    by = {}
    for (_, i, j) in picks:
        by.setdefault(i, []).append(j)
    aisles = sorted(by)
    if not aisles:
        return 0.0
    k = len(aisles)
    horiz = 2 * aisles[-1] * wh.aw                 # ra loi xa nhat roi ve
    if k % 2 == 1:                                  # le -> loi cuoi di vao roi ra
        vert = (k - 1) * wh.Ymax + 2 * (max(by[aisles[-1]]) * wh.p)
    else:                                           # chan -> xuyen suot het
        vert = k * wh.Ymax
    return horiz + vert


def route_largest_gap(wh, picks):
    """Largest gap: chi vao loi den truoc 'khoang trong lon nhat'.

    Loi dau va loi cuoi di xuyen suot; cac loi giua vao tu CA HAI dau,
    bo qua doan trong dai nhat. Quang duong doc moi loi giua:
        2 * (Ymax - gap_lon_nhat)
    """
    by = {}
    for (_, i, j) in picks:
        by.setdefault(i, []).append(j)
    aisles = sorted(by)
    if not aisles:
        return 0.0
    first, last = aisles[0], aisles[-1]

    if first == last:                               # chi 1 loi -> chien luoc return
        return 2 * first * wh.aw + 2 * max(by[first]) * wh.p

    horiz = first * wh.aw + (last - first) * wh.aw + last * wh.aw
    vert = 2 * wh.Ymax                              # loi dau + loi cuoi xuyen suot
    for i in aisles:
        if i in (first, last):
            continue
        ys = sorted(y * wh.p for y in by[i])
        gaps = [ys[0]] + [ys[t + 1] - ys[t] for t in range(len(ys) - 1)] \
               + [wh.Ymax - ys[-1]]
        vert += 2 * (wh.Ymax - max(gaps))
    return horiz + vert


def _tour_cost(wh, tour, D):
    c = D[wh.depot][tour[0]]
    for a, b in zip(tour, tour[1:]):
        c += D[a][b]
    return c + D[tour[-1]][wh.depot]


def route_nn(wh, picks, D):
    """Nearest neighbour tren ma tran khoang cach."""
    cur, un, tour = wh.depot, set(picks), []
    while un:
        nxt = min(un, key=lambda p: D[cur][p])
        tour.append(nxt)
        cur = nxt
        un.discard(nxt)
    return _tour_cost(wh, tour, D)


def route_2opt(wh, picks, D, max_pass=80):
    """Nearest neighbour + cai thien 2-opt."""
    cur, un, tour = wh.depot, set(picks), []
    while un:
        nxt = min(un, key=lambda p: D[cur][p])
        tour.append(nxt)
        cur = nxt
        un.discard(nxt)
    best = _tour_cost(wh, tour, D)
    improved, it = True, 0
    while improved and it < max_pass:
        improved, it = False, it + 1
        for a in range(len(tour) - 1):
            for b in range(a + 1, len(tour)):
                nt = tour[:a] + tour[a:b + 1][::-1] + tour[b + 1:]
                c = _tour_cost(wh, nt, D)
                if c < best - 1e-9:
                    tour, best, improved = nt, c, True
    return best


def route_exact(wh, picks, D):
    """Held-Karp: TSP CHINH XAC tren metric closure.  O(2^n * n^2).

    Chi kha thi voi n nho (<= ~14). Dung lam moc so sanh.
    """
    n = len(picks)
    dep = wh.depot
    dp = {(1 << k, k): D[dep][p] for k, p in enumerate(picks)}
    for size in range(2, n + 1):
        for sub in itertools.combinations(range(n), size):
            m = 0
            for k in sub:
                m |= 1 << k
            for last in sub:
                pm = m ^ (1 << last)
                best = inf
                for prev in sub:
                    if prev == last:
                        continue
                    v = dp.get((pm, prev))
                    if v is not None:
                        c = v + D[picks[prev]][picks[last]]
                        if c < best:
                            best = c
                if best < inf:
                    dp[(m, last)] = best
    full = (1 << n) - 1
    return min(dp[(full, k)] + D[picks[k]][dep] for k in range(n))


# ---------------------------------------------------------------------------
#  THU NGHIEM
# ---------------------------------------------------------------------------
STRATS = ('S-shape', 'Largest gap', 'Nearest neighbour', 'NN + 2-opt', 'TSP chinh xac')


def run(n_orders=120, picks_per_order=8, seed=7, na=10, ns=20):
    random.seed(seed)
    wh = Warehouse(n_aisles=na, slots_per_aisle=ns)
    allp = [('P', i, j) for i in range(na) for j in range(1, ns + 1)]
    res = {k: [] for k in STRATS}
    for _ in range(n_orders):
        picks = random.sample(allp, picks_per_order)
        D = wh.dmatrix(picks + [wh.depot])
        res['S-shape'].append(route_sshape(wh, picks))
        res['Largest gap'].append(route_largest_gap(wh, picks))
        res['Nearest neighbour'].append(route_nn(wh, picks, D))
        res['NN + 2-opt'].append(route_2opt(wh, picks, D))
        res['TSP chinh xac'].append(route_exact(wh, picks, D))
    return res


def main():
    print("=" * 78)
    print(" SO SANH CHIEN LUOC DINH TUYEN LAY HANG")
    print(" Kho 10 loi x 20 vi tri | loi rong 3,0 m | buoc vi tri 1,2 m | 120 don/kich ban")
    print("=" * 78)
    for ppo in (4, 8, 12):
        r = run(n_orders=120, picks_per_order=ppo)
        base = statistics.mean(r['TSP chinh xac'])
        print(f"\n  {ppo} diem lay hang moi don:")
        print(f"  {'Chien luoc':<24}{'Quang duong TB (m)':>20}{'So voi toi uu':>17}")
        print("  " + "-" * 61)
        for k in STRATS:
            m = statistics.mean(r[k])
            print(f"  {k:<24}{m:>20.1f}{(m / base - 1) * 100:>16.1f}%")

    print("\n" + "=" * 78)
    print(" DIEU NAY NOI LEN GI")
    print("=" * 78)
    print("""
  1. Dijkstra chi dung de DUNG MA TRAN KHOANG CACH. Ban than no khong tra loi
     duoc "nen di theo thu tu nao" — do la TSP.

  2. Chenh lech giua heuristic don gian va toi uu nam trong khoang ~10-30%,
     khop voi khoang 7-34% ma tai lieu nghien cuu quoc te bao cao.

  3. Chenh lech NAY CHI CO Y NGHIA khi kho co nghiep vu lay le (piece picking).
     Kho pallet-in / pallet-out nhu Costa gan nhu khong huong loi.
""")


if __name__ == '__main__':
    main()
