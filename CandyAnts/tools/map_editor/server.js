import express from 'express';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { exec } from 'child_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = 3000;

// Resolve paths to CandyAnts directories
const PROJECT_ROOT = path.resolve(__dirname, '../..');
const STAGES_DIR = path.join(PROJECT_ROOT, 'data/stages');
const LAYOUTS_DIR = path.join(PROJECT_ROOT, 'data/stage_layouts');
const SCENES_DIR = path.join(PROJECT_ROOT, 'scenes/stages');
const DESIGN_UI_DIR = path.resolve(PROJECT_ROOT, '../design_handoff_candyants_ui');

app.use(express.json({ limit: '10mb' }));
app.use(express.static(path.join(__dirname, 'public')));
app.use('/design_ui', express.static(DESIGN_UI_DIR));
app.use('/assets', express.static(path.join(PROJECT_ROOT, 'assets')));

// Helper: Find Godot executable
function findGodot() {
  if (process.env.GODOT_BIN && fs.existsSync(process.env.GODOT_BIN)) {
    return process.env.GODOT_BIN;
  }
  const candidates = [
    'D:/Godot_v4.6.2-stable_win64.exe',
    'D:/Godot_v4.6.2-stable_win64_console.exe',
    path.join(process.env.USERPROFILE || '', 'AppData/Local/Programs/Godot/Godot_console.exe'),
    path.join(process.env.USERPROFILE || '', 'AppData/Local/Programs/Godot/Godot.exe'),
    'C:/Program Files/Godot/Godot_console.exe',
    'C:/Program Files/Godot/Godot.exe'
  ];
  for (const c of candidates) {
    if (fs.existsSync(c)) {
      return c;
    }
  }
  return 'godot'; // Fallback to PATH
}

// Helper: Parse Stage tres file
function parseStageTres(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const metadata = {
    id: 0,
    display_name: 'Unnamed Stage',
    total_ants: 10,
    candy_hp: 10,
    time_limit_seconds: 120,
    release_rate_initial: 30,
    available_skills: [],
    skill_inventory: {}
  };

  const idMatch = content.match(/id\s*=\s*(\d+)/);
  if (idMatch) metadata.id = parseInt(idMatch[1]);

  const nameMatch = content.match(/display_name\s*=\s*"([^"]+)"/);
  if (nameMatch) metadata.display_name = nameMatch[1];

  const antsMatch = content.match(/total_ants\s*=\s*(\d+)/);
  if (antsMatch) metadata.total_ants = parseInt(antsMatch[1]);

  const candyHpMatch = content.match(/candy_hp\s*=\s*(\d+)/);
  if (candyHpMatch) metadata.candy_hp = parseInt(candyHpMatch[1]);

  const timeLimitMatch = content.match(/time_limit_seconds\s*=\s*([\d.]+)/);
  if (timeLimitMatch) metadata.time_limit_seconds = parseFloat(timeLimitMatch[1]);

  const releaseRateMatch = content.match(/release_rate_initial\s*=\s*(\d+)/);
  if (releaseRateMatch) metadata.release_rate_initial = parseInt(releaseRateMatch[1]);

  const skillsMatch = content.match(/available_skills\s*=\s*\[([^\]]*)\]/);
  if (skillsMatch && skillsMatch[1].trim()) {
    metadata.available_skills = skillsMatch[1]
      .split(',')
      .map(s => s.trim().replace(/"/g, ''))
      .filter(Boolean);
  }

  const inventoryMatch = content.match(/skill_inventory\s*=\s*\{([^}]*)\}/);
  if (inventoryMatch && inventoryMatch[1].trim()) {
    const parts = inventoryMatch[1].split(',');
    for (const part of parts) {
      const [k, v] = part.split(':').map(s => s.trim());
      if (k && v) {
        const skillKey = k.replace(/"/g, '');
        metadata.skill_inventory[skillKey] = parseInt(v);
      }
    }
  }

  return metadata;
}

// Helper: Parse StageLayout tres file
function parseLayoutTres(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const layout = {
    cell_size: 32,
    home_cell: { x: 12, y: 27 },
    candy_cell: { x: 44, y: 27 },
    camera_cell: { x: 30, y: 17 },
    spawn_direction: 1,
    spawn_direction_alternate: false,
    theme: 'cookie_crust',
    tile_map: {}
  };

  const cellSizeMatch = content.match(/cell_size\s*=\s*(\d+)/);
  if (cellSizeMatch) layout.cell_size = parseInt(cellSizeMatch[1]);

  const homeCellMatch = content.match(/home_cell\s*=\s*Vector2i\((\d+),\s*(\d+)\)/);
  if (homeCellMatch) {
    layout.home_cell = { x: parseInt(homeCellMatch[1]), y: parseInt(homeCellMatch[2]) };
  }

  const candyCellMatch = content.match(/candy_cell\s*=\s*Vector2i\((\d+),\s*(\d+)\)/);
  if (candyCellMatch) {
    layout.candy_cell = { x: parseInt(candyCellMatch[1]), y: parseInt(candyCellMatch[2]) };
  }

  const cameraCellMatch = content.match(/camera_cell\s*=\s*Vector2i\((\d+),\s*(\d+)\)/);
  if (cameraCellMatch) {
    layout.camera_cell = { x: parseInt(cameraCellMatch[1]), y: parseInt(cameraCellMatch[2]) };
  }

  const spawnDirMatch = content.match(/spawn_direction\s*=\s*(-?\d+)/);
  if (spawnDirMatch) layout.spawn_direction = parseInt(spawnDirMatch[1]);

  const spawnAltMatch = content.match(/spawn_direction_alternate\s*=\s*(true|false)/);
  if (spawnAltMatch) layout.spawn_direction_alternate = spawnAltMatch[1] === 'true';

  const themeMatch = content.match(/theme\s*=\s*"([^"]+)"/);
  if (themeMatch) layout.theme = themeMatch[1];

  // Parse tile_map
  // Match block tile_map = { ... }
  const tileMapBlockMatch = content.match(/tile_map\s*=\s*\{([^}]*)\}/);
  if (tileMapBlockMatch) {
    const block = tileMapBlockMatch[1];
    const lines = block.split('\n');
    for (const line of lines) {
      const match = line.match(/"([^"]+)":\s*"([^"]+)"/);
      if (match) {
        layout.tile_map[match[1]] = match[2];
      }
    }
  }

  return layout;
}

// API: List stages
app.get('/api/stages', (req, res) => {
  try {
    if (!fs.existsSync(STAGES_DIR)) {
      return res.json([]);
    }
    const files = fs.readdirSync(STAGES_DIR).filter(f => f.startsWith('stage') && f.endsWith('.tres'));
    const stages = files.map(file => {
      const idMatch = file.match(/stage(\d+)\.tres/);
      const id = idMatch ? parseInt(idMatch[1]) : 0;
      try {
        const meta = parseStageTres(path.join(STAGES_DIR, file));
        return { id, filename: file, ...meta };
      } catch (err) {
        return { id, filename: file, display_name: `stage${id} (Parse Error)` };
      }
    });
    stages.sort((a, b) => a.id - b.id);
    res.json(stages);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// API: Get stage detail (including layout)
app.get('/api/stages/:id', (req, res) => {
  const stageId = parseInt(req.params.id);
  const idStr = String(stageId).padStart(2, '0');
  const stagePath = path.join(STAGES_DIR, `stage${idStr}.tres`);
  const layoutPath = path.join(LAYOUTS_DIR, `stage${idStr}_layout.tres`);

  if (!fs.existsSync(stagePath)) {
    return res.status(404).json({ error: `Stage ${idStr} not found` });
  }

  try {
    const meta = parseStageTres(stagePath);
    let layout = {
      cell_size: 32,
      home_cell: { x: 12, y: 27 },
      candy_cell: { x: 44, y: 27 },
      camera_cell: { x: 30, y: 17 },
      spawn_direction: 1,
      spawn_direction_alternate: false,
      theme: 'cookie_crust',
      tile_map: {}
    };
    if (fs.existsSync(layoutPath)) {
      layout = parseLayoutTres(layoutPath);
    }
    res.json({ meta, layout });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// API: Save Stage and Layout (and optionally recreate .tscn)
app.post('/api/save', (req, res) => {
  const { meta, layout, recreateScene } = req.body;
  if (!meta || !meta.id || !layout) {
    return res.status(400).json({ error: 'Missing meta or layout data' });
  }

  const stageId = meta.id;
  const idStr = String(stageId).padStart(2, '0');
  const stagePath = path.join(STAGES_DIR, `stage${idStr}.tres`);
  const layoutPath = path.join(LAYOUTS_DIR, `stage${idStr}_layout.tres`);
  const scenePath = path.join(SCENES_DIR, `Stage${idStr}.tscn`);

  try {
    // 1. Save Layout
    let layoutHeader = `[gd_resource type="Resource" script_class="StageLayoutData" format=3]`;
    if (fs.existsSync(layoutPath)) {
      const existing = fs.readFileSync(layoutPath, 'utf-8');
      const headerMatch = existing.match(/^\[gd_resource[^\]]*\]/);
      if (headerMatch) {
        layoutHeader = headerMatch[0];
      }
    }
    
    // Sort tile_map keys logically for clean serialization
    const tileKeys = Object.keys(layout.tile_map).sort((a, b) => {
      const [ax, ay] = a.split(',').map(Number);
      const [bx, by] = b.split(',').map(Number);
      return ay === by ? ax - bx : ay - by;
    });

    const platformCells = tileKeys.map(k => `Vector2i(${k.replace(',', ', ')})`).join(', ');
    const tileMapEntries = tileKeys.map(k => `"${k}": "${layout.tile_map[k]}"`).join(',\n');

    const layoutContent = `${layoutHeader}

[ext_resource type="Script" path="res://scripts/core/StageLayoutData.gd" id="1"]

[resource]
script = ExtResource("1")
cell_size = ${layout.cell_size}
platform_cells = Array[Vector2i]([${platformCells}])
tile_map = {
${tileMapEntries}
}
home_cell = Vector2i(${layout.home_cell.x}, ${layout.home_cell.y})
candy_cell = Vector2i(${layout.candy_cell.x}, ${layout.candy_cell.y})
camera_cell = Vector2i(${layout.camera_cell.x}, ${layout.camera_cell.y})
spawn_direction = ${layout.spawn_direction}
spawn_direction_alternate = ${layout.spawn_direction_alternate}
theme = "${layout.theme || 'cookie_crust'}"
`;
    fs.writeFileSync(layoutPath, layoutContent, 'utf-8');

    // 2. Save Stage Tres
    let stageHeader = `[gd_resource type="Resource" script_class="StageData" format=3]`;
    if (fs.existsSync(stagePath)) {
      const existing = fs.readFileSync(stagePath, 'utf-8');
      const headerMatch = existing.match(/^\[gd_resource[^\]]*\]/);
      if (headerMatch) {
        stageHeader = headerMatch[0];
      }
    }

    const availableSkillsStr = JSON.stringify(meta.available_skills || []);
    
    const skillInvEntries = Object.entries(meta.skill_inventory || {})
      .map(([k, v]) => `"${k}": ${v}`)
      .join(', ');
    const skillInvStr = `{ ${skillInvEntries} }`;

    const stageContent = `${stageHeader}

[ext_resource type="Script" path="res://scripts/core/StageData.gd" id="1"]
[ext_resource type="Resource" path="res://data/stage_layouts/stage${idStr}_layout.tres" id="2"]

[resource]
script = ExtResource("1")
id = ${stageId}
display_name = "${meta.display_name}"
layout = ExtResource("2")
total_ants = ${meta.total_ants}
candy_hp = ${meta.candy_hp}
time_limit_seconds = ${meta.time_limit_seconds}
available_skills = ${availableSkillsStr}
skill_inventory = ${skillInvStr}
release_rate_initial = ${meta.release_rate_initial}
release_rate_min = 1
`;
    fs.writeFileSync(stagePath, stageContent, 'utf-8');

    // 3. Recreate Scene if checked or if it doesn't exist
    if (recreateScene || !fs.existsSync(scenePath)) {
      const cellSize = layout.cell_size || 32;
      const homeX = layout.home_cell.x * cellSize + cellSize / 2;
      const homeY = layout.home_cell.y * cellSize + cellSize / 2;
      const candyX = layout.candy_cell.x * cellSize + cellSize / 2;
      const candyY = layout.candy_cell.y * cellSize + cellSize / 2;
      const cameraX = layout.camera_cell.x * cellSize + cellSize / 2;
      const cameraY = layout.camera_cell.y * cellSize + cellSize / 2;
      const spawnerY = homeY - 5;

      const hasSkills = meta.available_skills && meta.available_skills.length > 0;
      const toolbarPathProp = hasSkills ? 'toolbar_path = NodePath("SkillToolbar")' : '';
      const toolbarNode = hasSkills ? `[node name="SkillToolbar" parent="." instance=ExtResource("12_toolbar")]
stage_data = ExtResource("7")` : '';

      const sceneContent = `[gd_scene load_steps=13 format=3]

[ext_resource type="Script" path="res://scripts/core/StageRunner.gd" id="1"]
[ext_resource type="Script" path="res://scripts/core/AntSpawner.gd" id="2"]
[ext_resource type="PackedScene" path="res://scenes/entities/Home.tscn" id="3"]
[ext_resource type="PackedScene" path="res://scenes/entities/Candy.tscn" id="4"]
[ext_resource type="PackedScene" path="res://scenes/entities/Ant.tscn" id="5"]
[ext_resource type="PackedScene" path="res://scenes/ui/HUD.tscn" id="6"]
[ext_resource type="Resource" path="res://data/stages/stage${idStr}.tres" id="7"]
[ext_resource type="PackedScene" path="res://scenes/world/StageBackground.tscn" id="8"]
[ext_resource type="Script" path="res://scripts/world/StageLayoutBuilder.gd" id="9_builder"]
[ext_resource type="Resource" path="res://data/stage_layouts/stage${idStr}_layout.tres" id="10_layout"]
[ext_resource type="Script" path="res://scripts/world/Terrain.gd" id="11_terrain"]
[ext_resource type="PackedScene" path="res://scenes/ui/SkillToolbar.tscn" id="12_toolbar"]

[node name="StageRunner" type="Node"]
script = ExtResource("1")
stage_data = ExtResource("7")
candy_path = NodePath("World/Candy")
home_path = NodePath("World/Home")
spawner_path = NodePath("Spawner")
hud_path = NodePath("HUD")
${toolbarPathProp}
ant_scene = ExtResource("5")
spawn_parent_path = NodePath("World")

[node name="World" type="Node2D" parent="."]

[node name="StageLayoutBuilder" type="Node2D" parent="World"]
script = ExtResource("9_builder")
layout = ExtResource("10_layout")

[node name="Terrain" type="Node2D" parent="World"]
script = ExtResource("11_terrain")

[node name="Home" parent="World" instance=ExtResource("3")]
position = Vector2(${homeX}, ${homeY})

[node name="Candy" parent="World" instance=ExtResource("4")]
position = Vector2(${candyX}, ${candyY})
hp = ${meta.candy_hp}

[node name="Camera2D" type="Camera2D" parent="World"]
position = Vector2(${cameraX}, ${cameraY})

[node name="StageBackground" parent="." instance=ExtResource("8")]

[node name="Spawner" type="Node" parent="."]
script = ExtResource("2")
spawn_position = Vector2(${homeX}, ${spawnerY})
total = ${meta.total_ants}
release_rate = ${meta.release_rate_initial}
spawn_direction = ${layout.spawn_direction}
spawn_direction_alternate = ${layout.spawn_direction_alternate}

[node name="HUD" parent="." instance=ExtResource("6")]

${toolbarNode}
`;
      fs.writeFileSync(scenePath, sceneContent, 'utf-8');
    }

    res.json({ success: true, message: `Successfully saved Stage ${idStr}!` });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// API: Run stage playtest in Godot
app.post('/api/play/:id', (req, res) => {
  const stageId = parseInt(req.params.id);
  const idStr = String(stageId).padStart(2, '0');
  const scenePath = `res://scenes/stages/Stage${idStr}.tscn`;

  const godot = findGodot();
  // Execute Godot as a separate process in the background
  const command = `"${godot}" --path "${PROJECT_ROOT}" "${scenePath}"`;
  console.log(`Running playtest: ${command}`);

  exec(command, { cwd: PROJECT_ROOT }, (error) => {
    if (error) {
      console.error(`Godot run error: ${error}`);
    }
  });

  // Return immediately so the editor UI doesn't hang waiting for the playtest window to close
  res.json({ success: true, message: `Launched playtest for Stage ${idStr}!` });
});

app.listen(PORT, () => {
  console.log(`========================================`);
  console.log(` CandyAnts Map Editor running!`);
  console.log(` View in browser: http://localhost:${PORT}`);
  console.log(`========================================`);
});
