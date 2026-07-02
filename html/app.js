// App State Data Store
const state = {
  activeTab: 'growing',
  activePlant: 'M2', // M1 or M2
  selectedRoomNum: null,
  activeRole: 'Growing Lead', // Default user role
  language: 'vi', // 'vi' or 'en'
  roomFilter: 'all',
  tasksSelectedRoomNum: null,
  activeChatContact: null,
  
  // Rooms Database
  rooms: {}, // key: room number (string), value: Room Object
  
  // Picking Plans sent from Cool Room
  pickingPlans: [], // { id, roomNum, plant, button, medium, open, sentAt }
  
  // Warehouse Stock
  stock: {
    button: 120,
    medium: 240,
    open: 95
  },
  
  // Orders List
  orders: [
    { id: 'ORD-001', customer: 'Aeon Mall', req: 'Button: 50kg, Medium: 100kg', total: 150, status: 'Pending' },
    { id: 'ORD-002', customer: 'Lotte Mart', req: 'Medium: 80kg, Open: 30kg', total: 110, status: 'Pending' },
    { id: 'ORD-003', customer: 'Costa Supply', req: 'Open: 50kg', total: 50, status: 'Delivered' }
  ],
  
  // Maintenance Logs
  maintenanceJobs: [
    { id: 'MNT-101', title: 'Khử trùng quạt hút gió', plant: 'M2', room: '33', assignee: 'Nam T.', priority: 'normal', status: 'inprog', notes: 'Bảo trì bộ lọc khuẩn định kỳ.' },
    { id: 'MNT-102', title: 'Cân chỉnh cảm biến độ ẩm', plant: 'M1', room: '12', assignee: 'Lợi P.', priority: 'high', status: 'todo', notes: 'Cảm biến lệch 5% so với đo tay.' }
  ],
  
  // Chat History
  chats: {
    'Growing Crew': [
      { sender: 'Minh T.', text: 'Đã hoàn thành tưới nước phòng 33 sáng nay.', time: '08:30', role: 'Growing Specialist' },
      { sender: 'Vinh', text: 'Tốt lắm, kiểm tra độ ẩm phòng 34 luôn nhé.', time: '08:45', role: 'Growing Lead' }
    ],
    'Sarah (Sales)': [
      { sender: 'Sarah', text: 'Aeon Mall cần gấp 150kg nấm cỡ vừa vào chiều nay, kho đủ hàng không Trúc ơi?', time: '09:15', role: 'Sales Lead' },
      { sender: 'Trúc', text: 'Để mình lập kế hoạch picking gấp gửi cho Harvest.', time: '09:20', role: 'Cool Room Manager' }
    ],
    'Mike (Site Manager)': [
      { sender: 'Mike', text: 'Đã cập nhật hệ thống báo động an toàn cho branch mới.', time: '07:00', role: 'Site Manager' }
    ]
  },
  
  // Safety Logs
  safetyLogs: [
    { empId: 'EMP001', empName: 'Minh T.', room: '33', role: 'Growing Specialist', time: '08:00', action: 'Check-in', solo: false },
    { empId: 'EMP003', empName: 'Hùng V.', room: '44', role: 'Harvest Picker', time: '08:15', action: 'Check-in', solo: false }
  ],
  
  emergencyActive: false
};

// Employee ID Registry Helper
const EMPLOYEES = {
  'EMP001': { name: 'Minh T.', role: 'Growing Specialist' },
  'EMP002': { name: 'Lan N.', role: 'Growing Specialist' },
  'EMP003': { name: 'Hùng V.', role: 'Harvest Picker' },
  'EMP004': { name: 'Phúc D.', role: 'Harvest Picker' },
  'EMP005': { name: 'Nam T.', role: 'Maintenance Specialist' },
  'EMP006': { name: 'Lợi P.', role: 'Maintenance Specialist' }
};

// Translations Dictionary
const TRANSLATIONS = {
  vi: {
    'growing': 'Trồng trọt (Growing)',
    'harvest': 'Thu hoạch (Harvest)',
    'coolroom': 'Kho lạnh (Cool Room)',
    'maintenance': 'Bảo trì (Maintenance)',
    'tasks': 'Công việc (Tasks)',
    'chat': 'Trò chuyện (Chat)',
    'safety': 'An toàn (Safety)',
    'growing_desc': 'Plant M2 — Rooms 33–66',
    'total_rooms': 'Tổng số phòng',
    'active_jobs': 'Đang hoạt động',
    'completed': 'Hoàn thành hôm nay',
    'pending_handover': 'Chờ thu hoạch'
  },
  en: {
    'growing': 'Growing Department',
    'harvest': 'Harvest Department',
    'coolroom': 'Cool Room Warehouse',
    'maintenance': 'Maintenance Log',
    'tasks': 'Project & Tasks',
    'chat': 'Encrypted Chat',
    'safety': 'Safety Dashboard',
    'growing_desc': 'Plant M2 — Rooms 33–66',
    'total_rooms': 'Total Rooms',
    'active_jobs': 'Active Jobs',
    'completed': 'Completed Today',
    'pending_handover': 'Pending Handover'
  }
};

// Generate list of rooms based on Plant M1 and M2 definitions
function initRooms() {
  // Plant M1: 1-6, 6A, 6B, 7-22, 22A, 23-32
  const m1Rooms = [];
  for (let i = 1; i <= 6; i++) m1Rooms.push(String(i));
  m1Rooms.push('6A', '6B');
  for (let i = 7; i <= 22; i++) m1Rooms.push(String(i));
  m1Rooms.push('22A');
  for (let i = 23; i <= 32; i++) m1Rooms.push(String(i));
  
  // Plant M2: 33-52, 52A, 53-66
  const m2Rooms = [];
  for (let i = 33; i <= 52; i++) m2Rooms.push(String(i));
  m2Rooms.push('52A');
  for (let i = 53; i <= 66; i++) m2Rooms.push(String(i));

  const stages = ['filling', 'airing', 'watering', 'prochloraz', 'packuptree', 'idle'];

  m1Rooms.forEach((r, idx) => {
    state.rooms[r] = createRoomObject(r, 'M1', stages[idx % stages.length], idx);
  });
  
  m2Rooms.forEach((r, idx) => {
    state.rooms[r] = createRoomObject(r, 'M2', stages[idx % stages.length], idx);
  });
}

function createRoomObject(num, plant, stage, idx) {
  const defaultJobs = [
    { id: 1, name: 'Filling', icon: 'ti-box', status: 'done', assignee: 'Minh T.', date: '14 Jun', notes: 'Giá thể nấm chuẩn chất lượng.' },
    { id: 2, name: 'Airing', icon: 'ti-wind', status: 'inprog', assignee: 'Lan N.', date: '15 Jun', notes: 'Bọc plastic giữ ẩm floor wet.' },
    { id: 3, name: 'Watering', icon: 'ti-droplet', status: 'todo', assignee: 'Hùng V.', date: '16 Jun', notes: 'Tưới nước định kỳ 2 Side.' }
  ];

  return {
    num: num,
    plant: plant,
    stage: stage,
    day: `Day ${(idx % 18) + 1}`,
    cycle: `Cycle ${(idx % 3) + 1}`,
    area: '112 m²',
    jobs: [...defaultJobs],
    crew: [], // Active pickers in room
    targetYield: 0,
    pickedYield: 0,
    pickingPlan: null // Picking requirement sizes details
  };
}

// App Initialization
window.onload = function() {
  initRooms();
  populateCheckinRoomsSelect();
  populatePickingRoomsSelect();
  populateMaintRoomsSelect();
  populateTasksRoomsSelect();
  
  // Switch to the default tab
  switchTab('growing');
  switchPlant('M2');
  renderChatInbox();
  
  // Active chat defaults
  state.activeChatContact = 'Growing Crew';
  renderChatWindow();
};

// Navigation tabs switcher
function switchTab(tabId) {
  state.activeTab = tabId;
  
  // Update navigation styling
  document.querySelectorAll('.nav-item').forEach(item => {
    if (item.getAttribute('data-tab') === tabId) {
      item.classList.add('active');
    } else {
      item.classList.remove('active');
    }
  });

  // Hide all panels
  document.querySelectorAll('.tab-panel').forEach(panel => {
    panel.classList.remove('active');
  });

  // Show active panel
  const activePanel = document.getElementById(`panel-${tabId}`);
  if (activePanel) activePanel.classList.add('active');

  // Update headers
  const pageTitle = document.getElementById('page-title');
  const pageSubtitle = document.getElementById('page-subtitle');
  
  if (tabId === 'growing') {
    pageTitle.textContent = state.language === 'vi' ? 'Trồng trọt (Growing)' : 'Growing Department';
    pageSubtitle.textContent = `Plant ${state.activePlant} — Rooms Grid`;
    renderGrowingRooms();
  } else if (tabId === 'harvest') {
    pageTitle.textContent = state.language === 'vi' ? 'Thu hoạch (Harvest)' : 'Harvest Department';
    pageSubtitle.textContent = 'Quản lý check-in và sản lượng hái thực tế';
    renderHarvestDashboard();
  } else if (tabId === 'coolroom') {
    pageTitle.textContent = state.language === 'vi' ? 'Kho lạnh (Cool Room)' : 'Cool Room Warehouse';
    pageSubtitle.textContent = 'Xuất kho và Quản lý tồn kho';
    renderCoolRoomDashboard();
  } else if (tabId === 'maintenance') {
    pageTitle.textContent = state.language === 'vi' ? 'Bảo trì (Maintenance)' : 'Maintenance Log';
    pageSubtitle.textContent = 'Quản lý sửa chữa và lịch bảo trì nông trại';
    renderMaintenanceDashboard();
  } else if (tabId === 'tasks') {
    pageTitle.textContent = state.language === 'vi' ? 'Dự án & Công việc (Tasks)' : 'Project & Tasks';
    pageSubtitle.textContent = 'Bảng Kanban & Gantt Timeline';
    
    // Set default tasks selected room
    if (!state.tasksSelectedRoomNum) {
      const defaultRoom = Object.keys(state.rooms).find(k => state.rooms[k].plant === state.activePlant);
      state.tasksSelectedRoomNum = defaultRoom;
      document.getElementById('tasks-room-selector').value = defaultRoom;
    }
    renderTasksDashboard();
  } else if (tabId === 'chat') {
    pageTitle.textContent = state.language === 'vi' ? 'Trò chuyện (Chat)' : 'Encrypted Chat';
    pageSubtitle.textContent = 'Mã hóa đầu cuối E2EE (Offline BLE / Online Relay)';
  } else if (tabId === 'safety') {
    pageTitle.textContent = state.language === 'vi' ? 'An toàn lao động (Safety)' : 'Safety Dashboard';
    pageSubtitle.textContent = 'Hệ thống giám sát Solo Worker & Báo động khẩn cấp';
    renderSafetyDashboard();
  }
}

// Switch between Plant M1 and M2
function switchPlant(plantId) {
  state.activePlant = plantId;
  
  document.getElementById('btn-plant-m2').classList.toggle('active', plantId === 'M2');
  document.getElementById('btn-plant-m1').classList.toggle('active', plantId === 'M1');
  
  const desc = document.getElementById('growing-rooms-desc');
  const totalRooms = document.getElementById('growing-total-rooms');
  
  if (plantId === 'M2') {
    desc.textContent = 'Phòng 33 – 66';
    totalRooms.textContent = '33';
  } else {
    desc.textContent = 'Phòng 1 – 32 (M1)';
    totalRooms.textContent = '35';
  }
  
  renderGrowingRooms();
}

// RENDER GROWING DEPARTMENT
function renderGrowingRooms() {
  const container = document.getElementById('growing-rooms-list');
  container.innerHTML = '';
  
  // Filter rooms belonging to active plant
  const plantRooms = Object.values(state.rooms).filter(r => r.plant === state.activePlant);
  
  // Apply visual filter
  const filtered = plantRooms.filter(r => {
    if (state.roomFilter === 'active') return r.stage !== 'idle';
    if (state.roomFilter === 'idle') return r.stage === 'idle';
    return true;
  });

  filtered.forEach(room => {
    const isSel = state.selectedRoomNum === room.num ? 'selected' : '';
    
    let stageLabel = room.stage.toUpperCase();
    if (room.stage === 'watering') stageLabel = 'TƯỚI NƯỚC';
    if (room.stage === 'prochloraz') stageLabel = 'PHUN NẤM';
    if (room.stage === 'filling') stageLabel = 'FILLING';
    if (room.stage === 'airing') stageLabel = 'AIRING';
    if (room.stage === 'packuptree') stageLabel = 'DỌN RỄ';
    if (room.stage === 'cleanroom') stageLabel = 'DỌN PHÒNG';
    if (room.stage === 'idle') stageLabel = 'TRỐNG';

    const item = document.createElement('div');
    item.className = `room-item ${isSel}`;
    item.onclick = () => selectGrowingRoom(room.num);
    item.innerHTML = `
      <span class="room-num">Phòng ${room.num}</span>
      <span class="room-stage-badge badge-${room.stage}">${stageLabel}</span>
    `;
    container.appendChild(item);
  });
}

function filterGrowingRooms(type) {
  state.roomFilter = type;
  document.getElementById('room-filter-all').classList.toggle('active', type === 'all');
  document.getElementById('room-filter-active').classList.toggle('active', type === 'active');
  document.getElementById('room-filter-idle').classList.toggle('active', type === 'idle');
  renderGrowingRooms();
}

function selectGrowingRoom(num) {
  state.selectedRoomNum = num;
  
  // Redraw lists to show selected styling
  renderGrowingRooms();
  
  const room = state.rooms[num];
  const detailPanel = document.getElementById('growing-detail-panel');
  
  const completedJobs = room.jobs.filter(j => j.status === 'done').length;
  const progressPct = Math.round((completedJobs / room.jobs.length) * 100) || 0;

  detailPanel.innerHTML = `
    <div class="detail-header">
      <div>
        <div class="detail-title"><i class="ti ti-door"></i> Phòng ${room.num}</div>
        <div style="font-size: 12px; color: var(--text-muted); margin-top: 4px;">Plant ${room.plant} · ${room.area}</div>
      </div>
      <div class="btn-group">
        <button class="btn btn-ghost" onclick="viewGanttForRoom('${room.num}')"><i class="ti ti-timeline"></i> Timeline</button>
        <button class="btn btn-ghost" onclick="viewKanbanForRoom('${room.num}')"><i class="ti ti-layout-kanban"></i> Kanban</button>
      </div>
    </div>

    <div class="detail-meta-grid">
      <div class="detail-meta-card">
        <label>Chu kỳ (Cycle)</label>
        <span>${room.cycle}</span>
      </div>
      <div class="detail-meta-card">
        <label>Giai đoạn</label>
        <span class="room-stage-badge badge-${room.stage}">${room.stage.toUpperCase()}</span>
      </div>
      <div class="detail-meta-card">
        <label>Tiến độ</label>
        <span>${progressPct}% (${completedJobs}/${room.jobs.length})</span>
      </div>
      <div class="detail-meta-card">
        <label>Ngày</label>
        <span>${room.day}</span>
      </div>
    </div>

    <div class="job-pipeline">
      <h4 style="font-size: 13px; font-weight: 700; margin-bottom: 10px; color: var(--text-secondary);">DANH SÁCH PIPELINE CÔNG VIỆC</h4>
      ${room.jobs.map(job => `
        <div class="job-row ${job.status === 'done' ? 'done' : ''}">
          <div class="job-left">
            <input type="checkbox" ${job.status === 'done' ? 'checked' : ''} onchange="toggleJobStatus('${room.num}', ${job.id}, this.checked)">
            <div>
              <div class="job-name"><i class="ti ${job.icon}"></i> ${job.name}</div>
              <div class="job-desc">${job.notes}</div>
            </div>
          </div>
          <div class="job-right">
            <span class="job-assignee">${job.assignee}</span>
          </div>
        </div>
      `).join('')}
    </div>
  `;
}

function toggleJobStatus(roomNum, jobId, isChecked) {
  const room = state.rooms[roomNum];
  const job = room.jobs.find(j => j.id === jobId);
  if (job) {
    job.status = isChecked ? 'done' : 'todo';
    selectGrowingRoom(roomNum);
  }
}

// MODALS AND POPULATION
function openNewJobModal() {
  document.getElementById('modal-new-job').classList.add('open');
  const plantSelect = document.getElementById('new-job-plant');
  updateNewJobRoomsList(plantSelect.value);
}

function closeNewJobModal() {
  document.getElementById('modal-new-job').classList.remove('open');
}

function updateNewJobRoomsList(plantVal) {
  const roomSelect = document.getElementById('new-job-room');
  roomSelect.innerHTML = '';
  Object.values(state.rooms).filter(r => r.plant === plantVal).forEach(r => {
    roomSelect.innerHTML += `<option value="${r.num}">Phòng ${r.num}</option>`;
  });
}

function selectJobTypeCard(cardElement, jobType) {
  document.querySelectorAll('.job-type-card').forEach(c => c.classList.remove('selected'));
  cardElement.classList.add('selected');
  
  // Show/Hide subfields
  document.getElementById('job-subfield-watering').style.display = jobType === 'watering' ? 'block' : 'none';
  document.getElementById('job-subfield-prochloraz').style.display = jobType === 'prochloraz' ? 'block' : 'none';
}

function calculateTotalChemical() {
  const rate = parseFloat(document.getElementById('prochloraz-rate').value) || 0;
  const area = parseFloat(document.getElementById('prochloraz-area').value) || 0;
  const total = (rate * area).toFixed(1);
  document.getElementById('chemical-total-display').textContent = `Tổng lượng hóa chất cần chuẩn bị: ${total} g`;
}

function handleCreateNewJob(event) {
  event.preventDefault();
  const roomNum = document.getElementById('new-job-room').value;
  const selectedCard = document.querySelector('.job-type-card.selected');
  const jobType = selectedCard.getAttribute('data-job');
  
  let jobName = jobType.charAt(0).toUpperCase() + jobType.slice(1);
  let jobIcon = 'ti-box';
  let notes = document.getElementById('new-job-notes').value;

  if (jobType === 'watering') {
    jobIcon = 'ti-droplet';
    const plan = document.getElementById('watering-plan').value;
    const vol = document.getElementById('watering-volume').value;
    notes += ` [Phương án: ${plan === '2side' ? '2 Side' : '1 Side'} · Lượng: ${vol}L/m²]`;
  } else if (jobType === 'prochloraz') {
    jobIcon = 'ti-flask';
    const rate = document.getElementById('prochloraz-rate').value;
    const area = document.getElementById('prochloraz-area').value;
    notes += ` [Hóa chất: ${rate}g/m² · Diện tích: ${area}m²]`;
  } else if (jobType === 'airing') jobIcon = 'ti-wind';
  else if (jobType === 'cleanroom') jobIcon = 'ti-sparkles';
  else if (jobType === 'packuptree') jobIcon = 'ti-trees';

  const room = state.rooms[roomNum];
  const newJob = {
    id: room.jobs.length + 1,
    name: jobName,
    icon: jobIcon,
    status: 'todo',
    assignee: document.getElementById('new-job-assignee').value,
    date: 'Hôm nay',
    notes: notes
  };

  room.jobs.push(newJob);
  room.stage = jobType;

  closeNewJobModal();
  switchPlant(room.plant);
  selectGrowingRoom(roomNum);
}

// HARVEST LOGIC
function populateCheckinRoomsSelect() {
  const checkinRoomSelect = document.getElementById('checkin-room');
  updateCheckinRoomsList('M2');
}

function updateCheckinRoomsList(plantVal) {
  const roomSelect = document.getElementById('checkin-room');
  roomSelect.innerHTML = '';
  Object.values(state.rooms).filter(r => r.plant === plantVal).forEach(r => {
    roomSelect.innerHTML += `<option value="${r.num}">Phòng ${r.num}</option>`;
  });
}

// Check in and Solo detection
function handleHarvestCheckIn(event) {
  event.preventDefault();
  const empId = document.getElementById('checkin-emp-id').value.trim().toUpperCase();
  const roomNum = document.getElementById('checkin-room').value;
  
  const emp = EMPLOYEES[empId];
  if (!emp) {
    alert('Không tìm thấy mã số nhân viên trong hệ thống!');
    return;
  }
  
  const room = state.rooms[roomNum];
  if (room.crew.includes(emp.name)) {
    alert('Nhân viên này đã check-in vào phòng rồi!');
    return;
  }
  
  room.crew.push(emp.name);
  
  // Add safety log
  state.safetyLogs.unshift({
    empId: empId,
    empName: emp.name,
    room: roomNum,
    role: emp.role,
    time: new Date().toLocaleTimeString().slice(0, 5),
    action: 'Check-in',
    solo: room.crew.length === 1
  });
  
  // Clear input
  document.getElementById('checkin-emp-id').value = '';
  
  renderHarvestDashboard();
  renderSafetyDashboard();
}

function handleHarvestCheckOut() {
  const empId = document.getElementById('checkin-emp-id').value.trim().toUpperCase();
  const roomNum = document.getElementById('checkin-room').value;
  
  const emp = EMPLOYEES[empId];
  if (!emp) {
    alert('Không tìm thấy mã số nhân viên!');
    return;
  }
  
  const room = state.rooms[roomNum];
  const idx = room.crew.indexOf(emp.name);
  if (idx === -1) {
    alert('Nhân viên không có trong phòng này!');
    return;
  }
  
  room.crew.splice(idx, 1);
  
  // Add safety log
  state.safetyLogs.unshift({
    empId: empId,
    empName: emp.name,
    room: roomNum,
    role: emp.role,
    time: new Date().toLocaleTimeString().slice(0, 5),
    action: 'Check-out',
    solo: false
  });
  
  document.getElementById('checkin-emp-id').value = '';
  
  renderHarvestDashboard();
  renderSafetyDashboard();
}

function renderHarvestDashboard() {
  const activeTableBody = document.getElementById('harvest-active-table-body');
  activeTableBody.innerHTML = '';
  
  const pickingPlanContainer = document.getElementById('harvest-picking-plan-container');
  pickingPlanContainer.innerHTML = '';

  // Render Picking Plans List
  if (state.pickingPlans.length === 0) {
    pickingPlanContainer.innerHTML = `
      <div class="empty-state">
        <i class="ti ti-checklist"></i>
        <p>Chưa có yêu cầu thu hoạch nào từ kho lạnh.</p>
      </div>
    `;
  } else {
    state.pickingPlans.forEach(plan => {
      pickingPlanContainer.innerHTML += `
        <div class="job-row">
          <div class="job-left">
            <div>
              <div class="job-name">Phòng ${plan.roomNum} (Plant ${plan.plant})</div>
              <div class="job-desc">
                Button: ${plan.button}kg, Medium: ${plan.medium}kg, Open: ${plan.open}kg
              </div>
            </div>
          </div>
          <div class="job-right">
            <span class="job-assignee" style="background:#E0F2FE; color:#0369A1;">Target: ${plan.button + plan.medium + plan.open}kg</span>
          </div>
        </div>
      `;
    });
  }

  // Populate picking rooms table
  let alertCount = 0;
  let hasSoloWorker = false;
  let soloRoom = '';
  let soloWorkerName = '';

  Object.values(state.rooms).forEach(room => {
    if (room.crew.length > 0 || room.targetYield > 0) {
      
      const isSolo = room.crew.length === 1;
      let safetyDotClass = 'safety-ok';
      let safetyTitle = 'OK';
      
      if (isSolo) {
        safetyDotClass = 'safety-alert';
        safetyTitle = 'CẢNH BÁO SOLO';
        hasSoloWorker = true;
        soloRoom = room.num;
        soloWorkerName = room.crew[0];
        alertCount++;
      } else if (room.crew.length === 0) {
        safetyDotClass = 'safety-none';
        safetyTitle = 'Không có crew';
      }

      const row = document.createElement('tr');
      if (isSolo) row.className = 'room-row alert';
      
      row.innerHTML = `
        <td class="room-id">Phòng ${room.num}</td>
        <td><span class="flush-badge flush-2">${room.cycle}nd</span></td>
        <td class="crew-list ${isSolo ? 'crew-solo' : ''}">
          ${room.crew.length > 0 ? room.crew.join(', ') : '<span style="color:var(--text-muted);">Trống</span>'}
          ${isSolo ? ' <span class="badge badge-danger">Solo</span>' : ''}
        </td>
        <td>${room.targetYield} kg</td>
        <td>
          <input type="number" value="${room.pickedYield}" min="0" style="width:70px; padding:3px 6px;" onchange="updatePickedYield('${room.num}', this.value)">
        </td>
        <td>
          <span class="status-badge ${room.pickedYield >= room.targetYield && room.targetYield > 0 ? 'status-done' : 'status-active'}">
            ${room.pickedYield >= room.targetYield && room.targetYield > 0 ? 'Hoàn thành' : 'Đang hái'}
          </span>
        </td>
        <td><span class="safety-dot ${safetyDotClass}" title="${safetyTitle}"></span></td>
      `;
      activeTableBody.appendChild(row);
    }
  });

  const alertBanner = document.getElementById('harvest-alert-banner');
  if (hasSoloWorker) {
    alertBanner.style.display = 'block';
    document.getElementById('harvest-alert-text').innerHTML = `Phòng ${soloRoom} — <strong>${soloWorkerName}</strong> đang làm việc một mình (Solo working)`;
    document.getElementById('safety-alert-count').style.display = 'inline-block';
    document.getElementById('safety-alert-count').textContent = alertCount;
  } else {
    alertBanner.style.display = 'none';
    document.getElementById('safety-alert-count').style.display = 'none';
  }
}

function updatePickedYield(roomNum, val) {
  const room = state.rooms[roomNum];
  room.pickedYield = parseFloat(val) || 0;
  
  if (room.pickedYield >= room.targetYield && room.targetYield > 0) {
    if (room.pickingPlan) {
      state.stock.button += room.pickingPlan.button;
      state.stock.medium += room.pickingPlan.medium;
      state.stock.open += room.pickingPlan.open;
      
      room.targetYield = 0;
      room.pickedYield = 0;
      room.pickingPlan = null;
      
      state.pickingPlans = state.pickingPlans.filter(p => p.roomNum !== roomNum);
      
      renderCoolRoomDashboard();
    }
  }
  
  renderHarvestDashboard();
}

// COOL ROOM LOGIC
function populatePickingRoomsSelect() {
  const planRoomSelect = document.getElementById('plan-room');
  updatePickingRoomsList('M2');
}

function updatePickingRoomsList(plantVal) {
  const roomSelect = document.getElementById('plan-room');
  roomSelect.innerHTML = '';
  Object.values(state.rooms).filter(r => r.plant === plantVal).forEach(r => {
    roomSelect.innerHTML += `<option value="${r.num}">Phòng ${r.num}</option>`;
  });
}

function handleSendPickingPlan(event) {
  event.preventDefault();
  const roomNum = document.getElementById('plan-room').value;
  const plant = document.getElementById('plan-plant').value;
  const button = parseInt(document.getElementById('plan-size-button').value) || 0;
  const medium = parseInt(document.getElementById('plan-size-medium').value) || 0;
  const open = parseInt(document.getElementById('plan-size-open').value) || 0;

  const total = button + medium + open;
  if (total === 0) {
    alert('Vui lòng nhập sản lượng lớn hơn 0!');
    return;
  }

  const plan = {
    id: Date.now().toString(),
    roomNum,
    plant,
    button,
    medium,
    open,
    sentAt: new Date().toLocaleTimeString().slice(0, 5)
  };
  state.pickingPlans.push(plan);

  const room = state.rooms[roomNum];
  room.targetYield = total;
  room.pickingPlan = plan;

  document.getElementById('plan-size-button').value = 0;
  document.getElementById('plan-size-medium').value = 0;
  document.getElementById('plan-size-open').value = 0;

  alert(`Đã gửi kế hoạch Picking sản lượng ${total} kg tới Harvest!`);
  renderCoolRoomDashboard();
}

function renderCoolRoomDashboard() {
  document.getElementById('stock-button-qty').textContent = `${state.stock.button} kg`;
  document.getElementById('stock-medium-qty').textContent = `${state.stock.medium} kg`;
  document.getElementById('stock-open-qty').textContent = `${state.stock.open} kg`;

  const orderTableBody = document.getElementById('coolroom-orders-table-body');
  orderTableBody.innerHTML = '';

  state.orders.forEach(order => {
    const row = document.createElement('tr');
    row.innerHTML = `
      <td>${order.id}</td>
      <td>${order.customer}</td>
      <td>${order.req}</td>
      <td><strong>${order.total} kg</strong></td>
      <td>
        <span class="badge ${order.status === 'Delivered' ? 'badge-danger' : 'badge-warning'}">
          ${order.status === 'Delivered' ? 'Đã giao' : 'Đang xử lý'}
        </span>
      </td>
      <td>
        ${order.status === 'Pending' ? `<button class="btn btn-sm btn-primary" onclick="deliverOrder('${order.id}')">Giao hàng</button>` : '—'}
      </td>
    `;
    orderTableBody.appendChild(row);
  });
}

function deliverOrder(orderId) {
  const order = state.orders.find(o => o.id === orderId);
  if (!order) return;

  if (orderId === 'ORD-001') {
    if (state.stock.button >= 50 && state.stock.medium >= 100) {
      state.stock.button -= 50;
      state.stock.medium -= 100;
      order.status = 'Delivered';
    } else {
      alert('Không đủ nấm tồn kho trong kho lạnh! Vui lòng lập thêm kế hoạch Picking.');
      return;
    }
  } else if (orderId === 'ORD-002') {
    if (state.stock.medium >= 80 && state.stock.open >= 30) {
      state.stock.medium -= 80;
      state.stock.open -= 30;
      order.status = 'Delivered';
    } else {
      alert('Không đủ nấm tồn kho! Vui lòng lập thêm kế hoạch Picking.');
      return;
    }
  }

  renderCoolRoomDashboard();
}

// MAINTENANCE LOGIC
function populateMaintRoomsSelect() {
  updateMaintRoomsList('M2');
}

function updateMaintRoomsList(plantVal) {
  const roomSelect = document.getElementById('maint-room');
  roomSelect.innerHTML = '';
  if (plantVal === 'CoolRoom') {
    roomSelect.innerHTML = `
      <option value="CR1">Kho Lạnh 1</option>
      <option value="CR2">Kho Lạnh 2</option>
      <option value="Warehouse">Tổng kho</option>
    `;
  } else {
    Object.values(state.rooms).filter(r => r.plant === plantVal).forEach(r => {
      roomSelect.innerHTML += `<option value="${r.num}">Phòng ${r.num}</option>`;
    });
  }
}

function handleCreateMaintenanceJob(event) {
  event.preventDefault();
  const title = document.getElementById('maint-title').value.trim();
  const plant = document.getElementById('maint-plant').value;
  const room = document.getElementById('maint-room').value;
  const assignee = document.getElementById('maint-assignee').value;
  const priority = document.getElementById('maint-priority').value;
  const notes = document.getElementById('maint-notes').value;

  const newMaint = {
    id: `MNT-${Math.floor(Math.random() * 900) + 100}`,
    title,
    plant,
    room,
    assignee,
    priority,
    status: 'todo',
    notes
  };

  state.maintenanceJobs.push(newMaint);

  document.getElementById('maint-title').value = '';
  document.getElementById('maint-notes').value = '';

  alert('Đã tạo lệnh bảo trì thiết bị mới thành công!');
  renderMaintenanceDashboard();
}

function renderMaintenanceDashboard() {
  const tableBody = document.getElementById('maintenance-table-body');
  tableBody.innerHTML = '';

  state.maintenanceJobs.forEach(job => {
    const row = document.createElement('tr');
    row.innerHTML = `
      <td>
        <strong>${job.title}</strong><br>
        <span style="font-size:11px; color:var(--text-muted);">${job.notes}</span>
      </td>
      <td>${job.plant === 'CoolRoom' ? 'Kho Lạnh' : `Plant ${job.plant}`} · Phòng ${job.room}</td>
      <td>${job.assignee}</td>
      <td>
        <span class="badge ${job.priority === 'urgent' ? 'badge-danger' : 'badge-warning'}">
          ${job.priority.toUpperCase()}
        </span>
      </td>
      <td>
        <span class="badge ${job.status === 'done' ? 'badge-danger' : 'badge-warning'}" style="background-color: ${job.status === 'done' ? 'var(--success-bg)' : ''}; color: ${job.status === 'done' ? 'var(--success)' : ''};">
          ${job.status === 'done' ? 'Hoàn thành' : job.status === 'inprog' ? 'Đang sửa' : 'Chờ xử lý'}
        </span>
      </td>
      <td>
        ${job.status !== 'done' ? `
          <button class="btn btn-sm btn-ghost" onclick="toggleMaintStatus('${job.id}')">
            ${job.status === 'todo' ? 'Bắt đầu' : 'Hoàn tất'}
          </button>
        ` : '—'}
      </td>
    `;
    tableBody.appendChild(row);
  });
}

function toggleMaintStatus(id) {
  const job = state.maintenanceJobs.find(j => j.id === id);
  if (!job) return;

  if (job.status === 'todo') {
    job.status = 'inprog';
  } else if (job.status === 'inprog') {
    job.status = 'done';
  }

  renderMaintenanceDashboard();
}

// TASKS LOGIC (KANBAN & GANTT)
function populateTasksRoomsSelect() {
  const select = document.getElementById('tasks-room-selector');
  select.innerHTML = '';
  Object.keys(state.rooms).forEach(k => {
    select.innerHTML += `<option value="${k}">Phòng ${k} (${state.rooms[k].plant})</option>`;
  });
}

function handleTasksRoomChange(roomNum) {
  state.tasksSelectedRoomNum = roomNum;
  renderTasksDashboard();
}

function viewKanbanForRoom(roomNum) {
  state.tasksSelectedRoomNum = roomNum;
  document.getElementById('tasks-room-selector').value = roomNum;
  switchTab('tasks');
  switchTasksView('kanban');
}

function viewGanttForRoom(roomNum) {
  state.tasksSelectedRoomNum = roomNum;
  document.getElementById('tasks-room-selector').value = roomNum;
  switchTab('tasks');
  switchTasksView('gantt');
}

function switchTasksView(viewId) {
  document.getElementById('btn-tasks-kanban').classList.toggle('active', viewId === 'kanban');
  document.getElementById('btn-tasks-gantt').classList.toggle('active', viewId === 'gantt');
  
  document.getElementById('tasks-kanban-view').classList.toggle('active', viewId === 'kanban');
  document.getElementById('tasks-gantt-view').classList.toggle('active', viewId === 'gantt');
  
  renderTasksDashboard();
}

function renderTasksDashboard() {
  const roomNum = state.tasksSelectedRoomNum;
  const room = state.rooms[roomNum];
  
  const todoContainer = document.getElementById('kanban-cards-todo');
  const inprogContainer = document.getElementById('kanban-cards-inprog');
  const reviewContainer = document.getElementById('kanban-cards-review');
  const doneContainer = document.getElementById('kanban-cards-done');

  todoContainer.innerHTML = '';
  inprogContainer.innerHTML = '';
  reviewContainer.innerHTML = '';
  doneContainer.innerHTML = '';

  let todoCount = 0, inprogCount = 0, reviewCount = 0, doneCount = 0;

  room.jobs.forEach(job => {
    const card = document.createElement('div');
    card.className = 'kanban-card';
    card.onclick = () => showTaskDetails(roomNum, job.id);
    card.innerHTML = `
      <div class="kanban-card-title"><i class="ti ${job.icon}"></i> ${job.name}</div>
      <div class="kanban-card-meta">
        <span>${job.assignee}</span>
        <span>${job.date}</span>
      </div>
    `;

    if (job.status === 'todo') {
      todoContainer.appendChild(card);
      todoCount++;
    } else if (job.status === 'inprog') {
      inprogContainer.appendChild(card);
      inprogCount++;
    } else if (job.status === 'review') {
      reviewContainer.appendChild(card);
      reviewCount++;
    } else if (job.status === 'done') {
      doneContainer.appendChild(card);
      doneCount++;
    }
  });

  document.getElementById('kanban-count-todo').textContent = todoCount;
  document.getElementById('kanban-count-inprog').textContent = inprogCount;
  document.getElementById('kanban-count-review').textContent = reviewCount;
  document.getElementById('kanban-count-done').textContent = doneCount;

  renderGanttChart(room);
}

function showTaskDetails(roomNum, jobId) {
  const room = state.rooms[roomNum];
  const job = room.jobs.find(j => j.id === jobId);
  if (!job) return;

  const overlay = document.getElementById('task-detail-overlay');
  overlay.classList.add('show');
  overlay.innerHTML = `
    <div class="detail-card show" style="background:var(--surface-primary); border:1px solid var(--border-color); border-radius:var(--border-radius-lg); padding:16px;">
      <div class="dc-header">
        <div class="dc-title"><i class="ti ${job.icon}"></i> ${job.name}</div>
        <button class="dc-close" onclick="closeTaskDetails()"><i class="ti ti-x"></i></button>
      </div>
      <div class="dc-grid">
        <div class="dc-field"><label>Trạng thái</label><span>${job.status.toUpperCase()}</span></div>
        <div class="dc-field"><label>Người xử lý</label><span>${job.assignee}</span></div>
        <div class="dc-field"><label>Phòng</label><span>Phòng ${roomNum} (${room.plant})</span></div>
      </div>
      <div class="dc-note">${job.notes}</div>
      <div style="margin-top:12px; display:flex; gap:8px;">
        ${job.status !== 'done' ? `<button class="btn btn-sm btn-primary" onclick="advanceTask('${roomNum}', ${job.id})">Tiến hành tiếp <i class="ti ti-arrow-right"></i></button>` : ''}
        <button class="btn btn-sm btn-ghost" onclick="closeTaskDetails()">Đóng</button>
      </div>
    </div>
  `;
}

function closeTaskDetails() {
  document.getElementById('task-detail-overlay').classList.remove('show');
}

function advanceTask(roomNum, jobId) {
  const room = state.rooms[roomNum];
  const job = room.jobs.find(j => j.id === jobId);
  if (!job) return;

  const flow = ['todo', 'inprog', 'review', 'done'];
  const currentIdx = flow.indexOf(job.status);
  if (currentIdx < flow.length - 1) {
    job.status = flow[currentIdx + 1];
  }

  closeTaskDetails();
  renderTasksDashboard();
  
  if (state.selectedRoomNum === roomNum) {
    selectGrowingRoom(roomNum);
  }
}

function renderGanttChart(room) {
  const container = document.getElementById('gantt-chart-container');
  
  let rowsHtml = '';
  const daysTotal = 18;
  
  let daysHeader = '<div class="g-header-row" style="display:grid; grid-template-columns: 140px repeat(18, 1fr); padding: 6px 0; border-bottom:1px solid var(--border-color);">';
  daysHeader += '<span class="g-label-col">Công việc (Jobs)</span>';
  for (let i = 1; i <= daysTotal; i++) {
    daysHeader += `<span class="day-lbl" style="text-align:center; font-size:10px; font-weight:600; color:var(--text-muted);">D${i}</span>`;
  }
  daysHeader += '</div>';

  room.jobs.forEach((job, idx) => {
    const startDay = idx * 2; 
    const duration = 3;
    
    let barColor = '#E2E0DA'; 
    if (job.status === 'done') barColor = '#C0DD97';
    else if (job.status === 'inprog') barColor = '#85B7EB';
    else if (job.status === 'review') barColor = '#FAC775';

    rowsHtml += `
      <div class="g-row" style="display:grid; grid-template-columns: 140px repeat(18, 1fr); border-bottom:1px solid var(--border-color); padding:8px 0; align-items:center;">
        <span class="g-row-label" style="font-size:12px; font-weight:600;"><i class="ti ${job.icon}"></i> ${job.name}</span>
        <div class="g-track" style="grid-column: 2 / span 18; position:relative; height:24px; background:var(--surface-secondary); border-radius:4px;">
          <div class="g-bar" style="position:absolute; left:${(startDay/daysTotal)*100}%; width:${(duration/daysTotal)*100}%; background-color:${barColor}; height:18px; top:3px; border-radius:4px; font-size:10px; font-weight:700; color:#1E1E1C; display:flex; align-items:center; padding:0 6px;" onclick="showTaskDetails('${room.num}', ${job.id})">
            ${job.name}
          </div>
        </div>
      </div>
    `;
  });

  container.innerHTML = daysHeader + rowsHtml;
}

// CHAT LOGIC
function renderChatInbox() {
  const list = document.getElementById('chat-inbox-list');
  list.innerHTML = '';

  Object.keys(state.chats).forEach(contact => {
    const messages = state.chats[contact];
    const lastMsg = messages[messages.length - 1];
    const isAct = state.activeChatContact === contact ? 'active' : '';

    const item = document.createElement('div');
    item.className = `inbox-item ${isAct}`;
    item.onclick = () => selectChat(contact);
    item.innerHTML = `
      <div class="inbox-avatar">${contact.charAt(0)}</div>
      <div class="inbox-details">
        <div class="inbox-name">${contact}</div>
        <div class="inbox-msg-preview">${lastMsg ? lastMsg.text : ''}</div>
      </div>
    `;
    list.appendChild(item);
  });
}

function selectChat(contact) {
  state.activeChatContact = contact;
  renderChatInbox();
  renderChatWindow();
}

function changeActiveRole(roleVal) {
  state.activeRole = roleVal;
}

function renderChatWindow() {
  const panel = document.getElementById('chat-window-panel');
  const contact = state.activeChatContact;
  if (!contact) return;

  const messages = state.chats[contact];

  panel.innerHTML = `
    <div class="chat-header">
      <div class="chat-header-title"><i class="ti ti-lock"></i> Kênh mật mã: ${contact}</div>
      <div class="chat-header-role" style="font-size:11px; color:var(--text-muted);">
        Đang gửi với vai trò: <strong>${state.activeRole}</strong>
      </div>
    </div>
    
    <div class="chat-messages-area" id="chat-msg-area">
      ${messages.map(msg => {
        const isSent = msg.sender === 'Vinh' && state.activeRole === 'Growing Lead' ||
                       msg.sender === 'Hải' && state.activeRole === 'Harvest Supervisor' ||
                       msg.sender === 'Trúc' && state.activeRole === 'Cool Room Manager' ||
                       msg.sender === 'Nam' && state.activeRole === 'Maintenance Lead';
        
        return `
          <div class="chat-bubble ${isSent ? 'sent' : 'received'}">
            <div style="font-size: 10px; font-weight:700; opacity:0.8; margin-bottom: 2px;">${msg.sender} (${msg.role})</div>
            <div>${msg.text}</div>
            <span class="chat-bubble-meta">${msg.time} · E2EE <i class="ti ti-shield-lock"></i></span>
          </div>
        `;
      }).join('')}
    </div>

    <form class="chat-input-bar" onsubmit="handleSendMessage(event)">
      <input type="text" placeholder="Nhập tin nhắn bảo mật mã hóa..." id="chat-input-field" required style="flex:1;">
      <button type="submit" class="btn btn-primary"><i class="ti ti-send"></i></button>
    </form>
  `;

  const area = document.getElementById('chat-msg-area');
  area.scrollTop = area.scrollHeight;
}

function handleSendMessage(event) {
  event.preventDefault();
  const input = document.getElementById('chat-input-field');
  const text = input.value.trim();
  if (!text) return;

  const contact = state.activeChatContact;
  const messages = state.chats[contact];

  let senderName = 'Vinh';
  if (state.activeRole === 'Harvest Supervisor') senderName = 'Hải';
  else if (state.activeRole === 'Cool Room Manager') senderName = 'Trúc';
  else if (state.activeRole === 'Maintenance Lead') senderName = 'Nam';

  messages.push({
    sender: senderName,
    text: text,
    time: new Date().toLocaleTimeString().slice(0, 5),
    role: state.activeRole
  });

  input.value = '';
  
  renderChatInbox();
  renderChatWindow();
  
  setTimeout(() => {
    if (contact === 'Sarah (Sales)' && text.toLowerCase().includes('picking')) {
      messages.push({
        sender: 'Sarah',
        text: 'Tuyệt vời! Đã nhận thông tin kế hoạch picking. Mình báo lại cho Aeon Mall nhé.',
        time: new Date().toLocaleTimeString().slice(0, 5),
        role: 'Sales Lead'
      });
      renderChatInbox();
      if (state.activeChatContact === contact) renderChatWindow();
    }
  }, 1500);
}

// SAFETY LOGIC
function renderSafetyDashboard() {
  const tableBody = document.getElementById('safety-logs-table-body');
  tableBody.innerHTML = '';

  state.safetyLogs.forEach(log => {
    const row = document.createElement('tr');
    if (log.solo) row.className = 'room-row alert';
    
    row.innerHTML = `
      <td><strong>${log.empName}</strong> (${log.empId})</td>
      <td>Phòng ${log.room}</td>
      <td>${log.role}</td>
      <td>${log.time}</td>
      <td>
        <span class="badge ${log.action === 'Check-in' ? 'badge-danger' : 'badge-warning'}" style="background-color: ${log.action === 'Check-in' ? 'var(--success-bg)' : ''}; color: ${log.action === 'Check-in' ? 'var(--success)' : ''};">
          ${log.action}
        </span>
      </td>
      <td>
        ${log.solo ? '<span class="alert-dot" style="vertical-align:middle; display:inline-block;"></span> <strong style="color:var(--danger);">Solo Timer: 45m</strong>' : 'Không có'}
      </td>
    `;
    tableBody.appendChild(row);
  });
}

function triggerEmergencyAlarm() {
  state.emergencyActive = true;
  document.getElementById('global-emergency-bar').classList.add('active');
  document.getElementById('emergency-text').textContent = `CẢNH BÁO BÁO ĐỘNG ĐỎ KHẨN CẤP: Yêu cầu di tản toàn bộ nông trại ngay lập tức!`;
}

function dismissEmergency() {
  state.emergencyActive = false;
  document.getElementById('global-emergency-bar').classList.remove('active');
}

function triggerSafetyCheck(roomNum) {
  alert(`Đang gửi tín hiệu yêu cầu xác minh an toàn tới thiết bị di động trong Phòng ${roomNum}...`);
}

function triggerSafetyCheckAll() {
  alert('Đang gửi tín hiệu yêu cầu check-in định kỳ khẩn cấp tới toàn bộ nhân sự nông trại.');
}

function resetSafetyStats() {
  alert('Đã khôi phục các chỉ số an toàn về trạng thái bình thường.');
  dismissEmergency();
  renderHarvestDashboard();
  renderSafetyDashboard();
}

function toggleLanguage() {
  state.language = state.language === 'vi' ? 'en' : 'vi';
  
  const currentLangSpan = document.getElementById('current-lang');
  currentLangSpan.textContent = state.language === 'vi' ? 'Tiếng Việt' : 'English';
  
  switchTab(state.activeTab);
}
