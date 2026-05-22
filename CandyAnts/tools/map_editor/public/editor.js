// CandyAnts Web Map Editor logic

const CELL_SIZE_PX = 24; // Visual pixel size for each grid cell in canvas
const GRID_COLUMNS = 60;
const GRID_ROWS = 34;
const MAX_PLATFORM_ROW = 27; // Rows 28+ are blocked for platforms

// Editor state
let tileMap = {}; // Key: "x,y", Value: "solid" | "slope_left" | "slope_right"
let homeCell = { x: 12, y: 27 };
let candyCell = { x: 44, y: 27 };
let cameraCell = { x: 30, y: 17 };
let currentBrush = 'solid'; // solid, slope_left, slope_right, erase, home, candy, camera
let isPainting = false;
let paintButton = 0; // 1 = Left click, 3 = Right click

// Image Preloader Assets
const IMAGES = {};
const IMAGE_SOURCES = {
  tileSurface: '/assets/sprites/terrain/cookie_tile_surface.png',
  tileBg: '/assets/sprites/terrain/cookie_tile_background.png',
  tileBridge: '/assets/sprites/terrain/thin_cookie_bridge_tile.png',
  tileSegment: '/assets/sprites/terrain/cookie_platform_segment.png',
  tileThinFloor: '/assets/sprites/terrain/thin_cookie_floor_segment.png',
  tileBridgeTile: '/assets/sprites/terrain/cookie_bridge_tile.png',
  home: '/assets/sprites/home/ant_house.png',
  candy: '/assets/sprites/candy/candy_00.png'
};
let imagesLoaded = false;

function preloadImages(callback) {
  let loadedCount = 0;
  const sources = Object.entries(IMAGE_SOURCES);
  const total = sources.length;
  
  sources.forEach(([key, src]) => {
    const img = new Image();
    img.src = src;
    img.onload = () => {
      loadedCount++;
      IMAGES[key] = img;
      if (loadedCount === total) {
        imagesLoaded = true;
        callback();
      }
    };
    img.onerror = () => {
      console.warn(`Failed to load sprite asset: ${src}`);
      loadedCount++;
      if (loadedCount === total) {
        imagesLoaded = true;
        callback();
      }
    };
  });
}

// DOM Elements
const canvas = document.getElementById('editor_canvas');
const ctx = canvas.getContext('2d');
const stageSelect = document.getElementById('stage_select');
const btnRefreshStages = document.getElementById('btn_refresh_stages');
const statusToast = document.getElementById('status_toast');

// Form inputs
const inputStageId = document.getElementById('input_stage_id');
const inputDisplayName = document.getElementById('input_display_name');
const inputTotalAnts = document.getElementById('input_total_ants');
const inputCandyHp = document.getElementById('input_candy_hp');
const inputTimeLimit = document.getElementById('input_time_limit');
const inputReleaseRate = document.getElementById('input_release_rate');
const inputSpawnDirection = document.getElementById('input_spawn_direction');
const inputSpawnAlternate = document.getElementById('input_spawn_alternate');
const inputVisualTheme = document.getElementById('input_visual_theme');
const skillBuilder = document.getElementById('skill_builder');
const skillBlocker = document.getElementById('skill_blocker');
const checkRecreateScene = document.getElementById('check_recreate_scene');

// Actions
const btnSaveStage = document.getElementById('btn_save_stage');
const btnPlayStage = document.getElementById('btn_play_stage');

// Color Palette (matching design system)
const COLORS = {
  bg: '#fcfbf8',          // Cream 50
  surface: '#f6f4ed',     // Cream 100
  gridLine: 'rgba(42, 38, 30, 0.08)',
  gridLineMajor: 'rgba(42, 38, 30, 0.20)',
  blockedOverlay: 'rgba(20, 20, 20, 0.72)',
  redLine: '#ff3326',     // Red line at boundary
  ink: '#422612',         // Ink 900 chocolate
  primary: '#c76b2c',     // Peach 500
  success: '#69b03d',     // success
  successSoft: '#def0d4',
  candy: '#d83a7a',       // candy pink
  camera: '#338ce6',      // camera blue
  slopeFill: '#f0ad4e'
};

// Initialize
function init() {
  setupCanvasEvents();
  setupBrushToolbar();
  setupFormStepButtons();
  setupTemplateButtons();
  setupApiEvents();
  
  // Connect Visual Theme change event
  inputVisualTheme.addEventListener('change', () => {
    draw();
  });
  
  loadStagesList();
  applyTemplate('flat');
  
  preloadImages(() => {
    console.log("CandyAnts sprite assets loaded successfully!");
    draw();
  });
}

// Show Toast message
function showToast(message, isError = false) {
  statusToast.textContent = message;
  statusToast.className = isError ? 'toast-visible toast-error' : 'toast-visible toast-success';
  
  setTimeout(() => {
    statusToast.className = 'toast-hidden';
  }, 3000);
}

// Draw the Grid and Tiles
function draw() {
  // Clear canvas
  ctx.fillStyle = COLORS.bg;
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  // Draw Blocked Area (Rows > 27)
  const blockedTop = (MAX_PLATFORM_ROW + 1) * CELL_SIZE_PX;
  ctx.fillStyle = COLORS.blockedOverlay;
  ctx.fillRect(0, blockedTop, canvas.width, canvas.height - blockedTop);

  // Draw Grid Lines
  for (let x = 0; x <= GRID_COLUMNS; x++) {
    const xPos = x * CELL_SIZE_PX;
    ctx.strokeStyle = (x % 5 === 0) ? COLORS.gridLineMajor : COLORS.gridLine;
    ctx.lineWidth = (x % 5 === 0) ? 1.5 : 0.8;
    ctx.beginPath();
    ctx.moveTo(xPos, 0);
    ctx.lineTo(xPos, canvas.height);
    ctx.stroke();
  }
  for (let y = 0; y <= GRID_ROWS; y++) {
    const yPos = y * CELL_SIZE_PX;
    ctx.strokeStyle = (y % 5 === 0) ? COLORS.gridLineMajor : COLORS.gridLine;
    ctx.lineWidth = (y % 5 === 0) ? 1.5 : 0.8;
    ctx.beginPath();
    ctx.moveTo(0, yPos);
    ctx.lineTo(canvas.width, yPos);
    ctx.stroke();
  }

  // Draw Red Boundary Line (below row 27)
  ctx.strokeStyle = COLORS.redLine;
  ctx.lineWidth = 2.5;
  ctx.beginPath();
  ctx.moveTo(0, blockedTop);
  ctx.lineTo(canvas.width, blockedTop);
  ctx.stroke();

  // Draw Tiles
  for (const [key, type] of Object.entries(tileMap)) {
    const [x, y] = key.split(',').map(Number);
    if (y > MAX_PLATFORM_ROW) continue; // safety guard

    const xPos = x * CELL_SIZE_PX;
    const yPos = y * CELL_SIZE_PX;
    const theme = inputVisualTheme.value;

    if (type === 'solid') {
      if (imagesLoaded) {
        let img;
        if (theme === 'cookie_crust') {
          const aboveKey = `${x},${y - 1}`;
          const isSurface = tileMap[aboveKey] !== 'solid';
          img = isSurface ? IMAGES.tileSurface : IMAGES.tileBg;
        } else if (theme === 'cookie_segment') {
          const aboveKey = `${x},${y - 1}`;
          const isSurface = tileMap[aboveKey] !== 'solid';
          img = isSurface ? IMAGES.tileSegment : IMAGES.tileBg;
        } else if (theme === 'thin_floor') {
          const aboveKey = `${x},${y - 1}`;
          const isSurface = tileMap[aboveKey] !== 'solid';
          img = isSurface ? IMAGES.tileThinFloor : IMAGES.tileBg;
        } else if (theme === 'cookie_bridge_tile') {
          img = IMAGES.tileBridgeTile;
        } else {
          // thin_bridge
          img = IMAGES.tileBridge;
        }
        
        if (img) {
          ctx.drawImage(img, xPos, yPos, CELL_SIZE_PX, CELL_SIZE_PX);
        } else {
          ctx.fillStyle = COLORS.ink;
          ctx.fillRect(xPos + 1, yPos + 1, CELL_SIZE_PX - 2, CELL_SIZE_PX - 2);
        }
      } else {
        ctx.fillStyle = COLORS.ink;
        ctx.fillRect(xPos + 1, yPos + 1, CELL_SIZE_PX - 2, CELL_SIZE_PX - 2);
      }
    } else if (type === 'slope_left') {
      if (imagesLoaded) {
        ctx.save();
        ctx.beginPath();
        ctx.moveTo(xPos, yPos);
        ctx.lineTo(xPos, yPos + CELL_SIZE_PX);
        ctx.lineTo(xPos + CELL_SIZE_PX, yPos + CELL_SIZE_PX);
        ctx.closePath();
        ctx.clip();
        
        let img;
        if (theme === 'cookie_crust') img = IMAGES.tileSurface;
        else if (theme === 'cookie_segment') img = IMAGES.tileSegment;
        else if (theme === 'thin_floor') img = IMAGES.tileThinFloor;
        else if (theme === 'cookie_bridge_tile') img = IMAGES.tileBridgeTile;
        else img = IMAGES.tileBridge;

        if (img) ctx.drawImage(img, xPos, yPos, CELL_SIZE_PX, CELL_SIZE_PX);
        ctx.restore();

        // Border outline
        ctx.strokeStyle = COLORS.ink;
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(xPos, yPos);
        ctx.lineTo(xPos, yPos + CELL_SIZE_PX);
        ctx.lineTo(xPos + CELL_SIZE_PX, yPos + CELL_SIZE_PX);
        ctx.closePath();
        ctx.stroke();
      } else {
        ctx.fillStyle = COLORS.slopeFill;
        ctx.beginPath();
        ctx.moveTo(xPos + 1, yPos + 1);
        ctx.lineTo(xPos + 1, yPos + CELL_SIZE_PX - 1);
        ctx.lineTo(xPos + CELL_SIZE_PX - 1, yPos + CELL_SIZE_PX - 1);
        ctx.closePath();
        ctx.fill();
        ctx.strokeStyle = COLORS.ink;
        ctx.lineWidth = 1;
        ctx.stroke();
      }
    } else if (type === 'slope_right') {
      if (imagesLoaded) {
        ctx.save();
        ctx.beginPath();
        ctx.moveTo(xPos, yPos + CELL_SIZE_PX);
        ctx.lineTo(xPos + CELL_SIZE_PX, yPos + CELL_SIZE_PX);
        ctx.lineTo(xPos + CELL_SIZE_PX, yPos);
        ctx.closePath();
        ctx.clip();
        
        let img;
        if (theme === 'cookie_crust') img = IMAGES.tileSurface;
        else if (theme === 'cookie_segment') img = IMAGES.tileSegment;
        else if (theme === 'thin_floor') img = IMAGES.tileThinFloor;
        else if (theme === 'cookie_bridge_tile') img = IMAGES.tileBridgeTile;
        else img = IMAGES.tileBridge;

        if (img) ctx.drawImage(img, xPos, yPos, CELL_SIZE_PX, CELL_SIZE_PX);
        ctx.restore();

        // Border outline
        ctx.strokeStyle = COLORS.ink;
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(xPos, yPos + CELL_SIZE_PX);
        ctx.lineTo(xPos + CELL_SIZE_PX, yPos + CELL_SIZE_PX);
        ctx.lineTo(xPos + CELL_SIZE_PX, yPos);
        ctx.closePath();
        ctx.stroke();
      } else {
        ctx.fillStyle = COLORS.slopeFill;
        ctx.beginPath();
        ctx.moveTo(xPos + 1, yPos + CELL_SIZE_PX - 1);
        ctx.lineTo(xPos + CELL_SIZE_PX - 1, yPos + CELL_SIZE_PX - 1);
        ctx.lineTo(xPos + CELL_SIZE_PX - 1, yPos + 1);
        ctx.closePath();
        ctx.fill();
        ctx.strokeStyle = COLORS.ink;
        ctx.lineWidth = 1;
        ctx.stroke();
      }
    }
  }

  // Draw Viewport Camera Guide (1920x1080 screen bounds centered on camera cell)
  const layoutCellSize = 32; // Standard cell size reference
  const W_cells = 1920 / layoutCellSize;
  const H_cells = 1080 / layoutCellSize;
  const camCenterX = (cameraCell.x + 0.5) * CELL_SIZE_PX;
  const camCenterY = (cameraCell.y + 0.5) * CELL_SIZE_PX;
  const vpWidth = W_cells * CELL_SIZE_PX;
  const vpHeight = H_cells * CELL_SIZE_PX;
  const vpLeft = camCenterX - vpWidth / 2;
  const vpTop = camCenterY - vpHeight / 2;

  ctx.strokeStyle = COLORS.camera;
  ctx.lineWidth = 2.0;
  ctx.setLineDash([6, 6]);
  ctx.strokeRect(vpLeft, vpTop, vpWidth, vpHeight);
  ctx.setLineDash([]); // reset

  // Fill very subtle overlay outside viewport camera bounds
  ctx.fillStyle = 'rgba(51, 140, 230, 0.04)';
  ctx.fillRect(vpLeft, vpTop, vpWidth, vpHeight);

  // Draw Markers
  drawMarker(homeCell, COLORS.success, 'H');
  drawMarker(candyCell, COLORS.candy, 'C');
  drawMarker(cameraCell, COLORS.camera, 'K');
}

// Draw individual marker
function drawMarker(cell, color, label) {
  const xPos = cell.x * CELL_SIZE_PX;
  const yPos = cell.y * CELL_SIZE_PX;

  if (imagesLoaded) {
    if (label === 'H' && IMAGES.home) {
      // Home Sprite (ant_house.png) - 2x2 grid size, centered
      const sizeMultiplier = 2.0;
      const w = CELL_SIZE_PX * sizeMultiplier;
      const h = CELL_SIZE_PX * sizeMultiplier;
      const xOffset = xPos + CELL_SIZE_PX / 2 - w / 2;
      const yOffset = yPos + CELL_SIZE_PX - h; // bottom aligned to the cell
      ctx.drawImage(IMAGES.home, xOffset, yOffset, w, h);

      // Label tag
      ctx.fillStyle = COLORS.success;
      ctx.fillRect(xPos, yPos, 14, 14);
      ctx.fillStyle = '#ffffff';
      ctx.font = 'bold 9px monospace';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText('H', xPos + 7, yPos + 7);
      return;
    }
    if (label === 'C' && IMAGES.candy) {
      // Candy Sprite (candy_00.png) - 1.6x1.6 grid size, centered
      const sizeMultiplier = 1.6;
      const w = CELL_SIZE_PX * sizeMultiplier;
      const h = CELL_SIZE_PX * sizeMultiplier;
      const xOffset = xPos + CELL_SIZE_PX / 2 - w / 2;
      const yOffset = yPos + CELL_SIZE_PX - h; // bottom aligned
      ctx.drawImage(IMAGES.candy, xOffset, yOffset, w, h);

      // Label tag
      ctx.fillStyle = COLORS.candy;
      ctx.fillRect(xPos, yPos, 14, 14);
      ctx.fillStyle = '#ffffff';
      ctx.font = 'bold 9px monospace';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText('C', xPos + 7, yPos + 7);
      return;
    }
  }

  // Camera marker or fallback drawing
  ctx.strokeStyle = color;
  ctx.lineWidth = 2.5;
  ctx.strokeRect(xPos + 2, yPos + 2, CELL_SIZE_PX - 4, CELL_SIZE_PX - 4);

  // Draw circular background for letter
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.arc(xPos + CELL_SIZE_PX / 2, yPos + CELL_SIZE_PX / 2, 8, 0, 2 * Math.PI);
  ctx.fill();

  ctx.fillStyle = '#ffffff';
  ctx.font = 'bold 11px monospace';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(label, xPos + CELL_SIZE_PX / 2, yPos + CELL_SIZE_PX / 2);
}

// Canvas Event Bindings
function setupCanvasEvents() {
  // Prevent context menu
  canvas.addEventListener('contextmenu', e => e.preventDefault());

  canvas.addEventListener('mousedown', e => {
    isPainting = true;
    paintButton = e.button === 2 ? 3 : 1; // 1 = Left, 3 = Right (erase)
    applyPaintAt(e.clientX, e.clientY);
  });

  canvas.addEventListener('mousemove', e => {
    if (isPainting) {
      applyPaintAt(e.clientX, e.clientY);
    }
  });

  window.addEventListener('mouseup', () => {
    isPainting = false;
    paintButton = 0;
  });

  canvas.addEventListener('mouseleave', () => {
    isPainting = false;
  });
}

// Apply paint action based on coordinates
function applyPaintAt(clientX, clientY) {
  const rect = canvas.getBoundingClientRect();
  const x = Math.floor((clientX - rect.left) / (rect.width / canvas.width) / CELL_SIZE_PX);
  const y = Math.floor((clientY - rect.top) / (rect.height / canvas.height) / CELL_SIZE_PX);

  // Bounds safety
  if (x < 0 || x >= GRID_COLUMNS || y < 0 || y >= GRID_ROWS) return;

  const key = `${x},${y}`;

  // If using Right click, force Erase
  if (paintButton === 3 || currentBrush === 'erase') {
    if (y <= MAX_PLATFORM_ROW && tileMap[key]) {
      delete tileMap[key];
      draw();
    }
    return;
  }

  // Handle Marker placement brushes
  if (currentBrush === 'home') {
    homeCell = { x, y };
    draw();
    return;
  }
  if (currentBrush === 'candy') {
    candyCell = { x, y };
    draw();
    return;
  }
  if (currentBrush === 'camera') {
    cameraCell = { x, y };
    draw();
    return;
  }

  // Terrain brushes - respect MAX_PLATFORM_ROW
  if (y <= MAX_PLATFORM_ROW) {
    if (tileMap[key] !== currentBrush) {
      tileMap[key] = currentBrush;
      draw();
    }
  }
}

// Brush Toolbar handler
function setupBrushToolbar() {
  const toolBtns = document.querySelectorAll('.tool-btn');
  toolBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      toolBtns.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      currentBrush = btn.getAttribute('data-brush');
    });
  });
}

// Step input (+/-) handlers
function setupFormStepButtons() {
  const stepBtns = document.querySelectorAll('.btn-step');
  stepBtns.forEach(btn => {
    btn.addEventListener('click', e => {
      e.preventDefault();
      const targetId = btn.getAttribute('data-target');
      const delta = parseInt(btn.getAttribute('data-delta'));
      const input = document.getElementById(targetId);
      const min = parseInt(input.min) || 0;
      const max = parseInt(input.max) || 99;
      let val = parseInt(input.value) || 0;
      val = Math.max(min, Math.min(max, val + delta));
      input.value = val;
    });
  });
}

// Template preset loader
function setupTemplateButtons() {
  const templateBtns = document.querySelectorAll('.btn-template');
  templateBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      const type = btn.getAttribute('data-template');
      applyTemplate(type);
    });
  });
}

// Apply template patterns
function applyTemplate(type) {
  tileMap = {};
  if (type === 'flat') {
    // Stage 1 default: floor at y=27
    for (let x = 0; x < 60; x++) {
      tileMap[`${x},27`] = 'solid';
    }
    homeCell = { x: 12, y: 27 };
    candyCell = { x: 44, y: 27 };
    cameraCell = { x: 30, y: 17 };
    inputSpawnDirection.value = '1';
    inputSpawnAlternate.checked = false;
  } else if (type === 'two_platforms') {
    // Two platform levels with a middle gap
    for (let x = 9; x <= 27; x++) {
      tileMap[`${x},27`] = 'solid';
    }
    for (let x = 33; x <= 51; x++) {
      tileMap[`${x},27`] = 'solid';
    }
    homeCell = { x: 12, y: 27 };
    candyCell = { x: 44, y: 27 };
    cameraCell = { x: 30, y: 17 };
    inputSpawnDirection.value = '1';
    inputSpawnAlternate.checked = false;
  } else if (type === 'reverse_long') {
    // Left-headed flow
    for (let x = 19; x <= 56; x++) {
      tileMap[`${x},27`] = 'solid';
    }
    for (let x = 14; x <= 21; x++) {
      tileMap[`${x},24`] = 'solid';
    }
    for (let x = 48; x <= 55; x++) {
      tileMap[`${x},24`] = 'solid';
    }
    homeCell = { x: 53, y: 27 };
    candyCell = { x: 22, y: 27 };
    cameraCell = { x: 38, y: 17 };
    inputSpawnDirection.value = '-1';
    inputSpawnAlternate.checked = true;
  }
  draw();
}

// Fetch Stage list and details APIs
function setupApiEvents() {
  btnRefreshStages.addEventListener('click', loadStagesList);
  
  stageSelect.addEventListener('change', () => {
    const stageId = stageSelect.value;
    if (stageId) {
      loadStageDetail(stageId);
    } else {
      // Clear forms for new stage
      inputStageId.value = 4;
      inputDisplayName.value = '새 스테이지';
      inputTotalAnts.value = 10;
      inputCandyHp.value = 10;
      inputTimeLimit.value = 180;
      inputReleaseRate.value = 30;
      inputSpawnDirection.value = '1';
      inputSpawnAlternate.checked = false;
      skillBuilder.value = 3;
      skillBlocker.value = 0;
      inputVisualTheme.value = 'cookie_crust';
      applyTemplate('flat');
    }
  });

  btnSaveStage.addEventListener('click', saveStage);
  btnPlayStage.addEventListener('click', playStage);
}

// Load stages list
async function loadStagesList() {
  try {
    const res = await fetch('/api/stages');
    const stages = await res.json();
    
    // Save current selected value
    const currentSelected = stageSelect.value;

    // Reset list
    stageSelect.innerHTML = '<option value="">-- 신규 스테이지 --</option>';
    stages.forEach(s => {
      const opt = document.createElement('option');
      opt.value = s.id;
      opt.textContent = `Stage ${String(s.id).padStart(2, '0')}: ${s.display_name}`;
      stageSelect.appendChild(opt);
    });

    if (currentSelected) {
      stageSelect.value = currentSelected;
    }
  } catch (err) {
    console.error('Failed to load stages', err);
    showToast('스테이지 목록 조회 실패!', true);
  }
}

// Load detail of a single stage
async function loadStageDetail(id) {
  try {
    const res = await fetch(`/api/stages/${id}`);
    if (!res.ok) throw new Error();
    const data = await res.json();

    // Populate metadata
    inputStageId.value = data.meta.id;
    inputDisplayName.value = data.meta.display_name;
    inputTotalAnts.value = data.meta.total_ants;
    inputCandyHp.value = data.meta.candy_hp;
    inputTimeLimit.value = data.meta.time_limit_seconds;
    inputReleaseRate.value = data.meta.release_rate_initial;
    
    // Skills
    skillBuilder.value = data.meta.skill_inventory.builder || 0;
    skillBlocker.value = data.meta.skill_inventory.blocker || 0;

    // Layout
    homeCell = data.layout.home_cell || { x: 12, y: 27 };
    candyCell = data.layout.candy_cell || { x: 44, y: 27 };
    cameraCell = data.layout.camera_cell || { x: 30, y: 17 };
    inputSpawnDirection.value = String(data.layout.spawn_direction || 1);
    inputSpawnAlternate.checked = !!data.layout.spawn_direction_alternate;
    inputVisualTheme.value = data.layout.theme || 'cookie_crust';
    tileMap = data.layout.tile_map || {};

    showToast(`Stage ${id} 성공적으로 로드되었습니다!`);
    draw();
  } catch (err) {
    console.error(err);
    showToast('스테이지 불러오기 실패!', true);
  }
}

// Save stage payload
async function saveStage() {
  const id = parseInt(inputStageId.value) || 1;
  const name = inputDisplayName.value.trim() || '새 스테이지';
  const ants = parseInt(inputTotalAnts.value) || 10;
  const candyHp = parseInt(inputCandyHp.value) || 10;
  const timeLimit = parseFloat(inputTimeLimit.value) || 180;
  const releaseRate = parseInt(inputReleaseRate.value) || 30;
  const spawnDir = parseInt(inputSpawnDirection.value) || 1;
  const spawnAlt = inputSpawnAlternate.checked;

  const builderCount = parseInt(skillBuilder.value) || 0;
  const blockerCount = parseInt(skillBlocker.value) || 0;

  const available_skills = [];
  const skill_inventory = {};
  if (builderCount > 0) {
    available_skills.push('builder');
    skill_inventory.builder = builderCount;
  }
  if (blockerCount > 0) {
    available_skills.push('blocker');
    skill_inventory.blocker = blockerCount;
  }

  const payload = {
    meta: {
      id,
      display_name: name,
      total_ants: ants,
      candy_hp: candyHp,
      time_limit_seconds: timeLimit,
      release_rate_initial: releaseRate,
      available_skills,
      skill_inventory
    },
    layout: {
      cell_size: 32,
      home_cell: homeCell,
      candy_cell: candyCell,
      camera_cell: cameraCell,
      spawn_direction: spawnDir,
      spawn_direction_alternate: spawnAlt,
      theme: inputVisualTheme.value,
      tile_map: tileMap
    },
    recreateScene: checkRecreateScene.checked
  };

  try {
    const res = await fetch('/api/save', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    const result = await res.json();
    if (result.success) {
      showToast(result.message);
      loadStagesList();
    } else {
      showToast('저장 중 오류 발생: ' + result.error, true);
    }
  } catch (err) {
    console.error(err);
    showToast('네트워크 저장 실패!', true);
  }
}

// Play stage playtest
async function playStage() {
  const id = parseInt(inputStageId.value) || 1;
  
  // Save first
  await saveStage();

  try {
    const res = await fetch(`/api/play/${id}`, { method: 'POST' });
    const result = await res.json();
    if (result.success) {
      showToast(result.message);
    } else {
      showToast('플레이 테스트 구동 실패: ' + result.error, true);
    }
  } catch (err) {
    console.error(err);
    showToast('플레이 테스트 네트워크 요청 실패!', true);
  }
}

// Boot up
window.onload = init;
draw();
