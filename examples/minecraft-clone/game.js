// ═══════════════════════════════════════════════════════════════
//  MiniCraft – A Minecraft-like in Three.js for Ondes Core
//  Features: Perlin terrain, caves, trees, clouds, water,
//            joystick controls, block place/break, day cycle
// ═══════════════════════════════════════════════════════════════

// ── Constants ────────────────────────────────────────────────
const CHUNK_SIZE  = 16;
const WORLD_SIZE  = 4;          // 4×4 chunks = 64×64 blocks
const MAX_HEIGHT  = 40;
const WATER_LEVEL = 12;
const SEA_FLOOR   = 8;
const CAVE_THRESHOLD  = 0.38;
const TREE_CHANCE     = 0.012;

const BLOCK = {
    AIR:    0,
    GRASS:  1,
    DIRT:   2,
    STONE:  3,
    WOOD:   4,
    LEAVES: 5,
    SAND:   6,
    WATER:  7,
    BEDROCK:8,
};

const BLOCK_COLORS = {
    [BLOCK.GRASS]:   0x5d9e3c,
    [BLOCK.DIRT]:    0x8b6914,
    [BLOCK.STONE]:   0x888888,
    [BLOCK.WOOD]:    0x8B5A2B,
    [BLOCK.LEAVES]:  0x2d8a4e,
    [BLOCK.SAND]:    0xd4c476,
    [BLOCK.WATER]:   0x3b7dd8,
    [BLOCK.BEDROCK]: 0x333333,
};

const BLOCK_NAME_MAP = {
    grass:  BLOCK.GRASS,
    dirt:   BLOCK.DIRT,
    stone:  BLOCK.STONE,
    wood:   BLOCK.WOOD,
    leaves: BLOCK.LEAVES,
    sand:   BLOCK.SAND,
    water:  BLOCK.WATER,
};

// ── Improved Perlin Noise ────────────────────────────────────
class PerlinNoise {
    constructor(seed) {
        this.perm = new Uint8Array(512);
        const p = new Uint8Array(256);
        for (let i = 0; i < 256; i++) p[i] = i;
        // Fisher-Yates shuffle with seed
        let s = seed || Math.random() * 65536;
        for (let i = 255; i > 0; i--) {
            s = (s * 16807 + 0) % 2147483647;
            const j = s % (i + 1);
            [p[i], p[j]] = [p[j], p[i]];
        }
        for (let i = 0; i < 512; i++) this.perm[i] = p[i & 255];
    }

    _fade(t) { return t * t * t * (t * (t * 6 - 15) + 10); }
    _lerp(a, b, t) { return a + t * (b - a); }
    _grad(hash, x, y, z) {
        const h = hash & 15;
        const u = h < 8 ? x : y;
        const v = h < 4 ? y : (h === 12 || h === 14 ? x : z);
        return ((h & 1) ? -u : u) + ((h & 2) ? -v : v);
    }

    noise3D(x, y, z) {
        const X = Math.floor(x) & 255, Y = Math.floor(y) & 255, Z = Math.floor(z) & 255;
        x -= Math.floor(x); y -= Math.floor(y); z -= Math.floor(z);
        const u = this._fade(x), v = this._fade(y), w = this._fade(z);
        const p = this.perm;
        const A = p[X]+Y, AA = p[A]+Z, AB = p[A+1]+Z;
        const B = p[X+1]+Y, BA = p[B]+Z, BB = p[B+1]+Z;
        return this._lerp(
            this._lerp(
                this._lerp(this._grad(p[AA],x,y,z), this._grad(p[BA],x-1,y,z), u),
                this._lerp(this._grad(p[AB],x,y-1,z), this._grad(p[BB],x-1,y-1,z), u), v),
            this._lerp(
                this._lerp(this._grad(p[AA+1],x,y,z-1), this._grad(p[BA+1],x-1,y,z-1), u),
                this._lerp(this._grad(p[AB+1],x,y-1,z-1), this._grad(p[BB+1],x-1,y-1,z-1), u), v), w);
    }

    // Fractal Brownian Motion for terrain
    fbm(x, z, octaves = 4, lacunarity = 2, persistence = 0.5) {
        let value = 0, amplitude = 1, frequency = 1, max = 0;
        for (let i = 0; i < octaves; i++) {
            value += this.noise3D(x * frequency, 0, z * frequency) * amplitude;
            max += amplitude;
            amplitude *= persistence;
            frequency *= lacunarity;
        }
        return value / max;
    }

    // 3D noise for caves
    cave(x, y, z, scale = 0.07) {
        return (this.noise3D(x * scale, y * scale, z * scale) + 1) / 2;
    }
}

// ── World data ───────────────────────────────────────────────
const worldWidth  = CHUNK_SIZE * WORLD_SIZE;
const worldDepth  = CHUNK_SIZE * WORLD_SIZE;
const blocks = new Uint8Array(worldWidth * MAX_HEIGHT * worldDepth);

function idx(x, y, z) {
    return x * MAX_HEIGHT * worldDepth + y * worldDepth + z;
}
function getBlock(x, y, z) {
    if (x < 0 || x >= worldWidth || y < 0 || y >= MAX_HEIGHT || z < 0 || z >= worldDepth) return BLOCK.AIR;
    return blocks[idx(x, y, z)];
}
function setBlock(x, y, z, type) {
    if (x < 0 || x >= worldWidth || y < 0 || y >= MAX_HEIGHT || z < 0 || z >= worldDepth) return;
    blocks[idx(x, y, z)] = type;
}

// ── Terrain generation ───────────────────────────────────────
const perlin = new PerlinNoise(Date.now());
const perlinCave = new PerlinNoise(Date.now() + 1337);

function generateTerrain(onProgress) {
    const total = worldWidth * worldDepth;
    let done = 0;

    for (let x = 0; x < worldWidth; x++) {
        for (let z = 0; z < worldDepth; z++) {
            // Height map using fBm
            const nx = x / worldWidth;
            const nz = z / worldDepth;
            const continentalness = perlin.fbm(nx * 3, nz * 3, 5, 2.2, 0.45);
            const detail = perlin.fbm(nx * 8 + 100, nz * 8 + 100, 3, 2, 0.4) * 0.3;
            const rawHeight = (continentalness + detail + 1) / 2;
            const height = Math.floor(rawHeight * (MAX_HEIGHT - 10)) + 5;

            // Bedrock
            setBlock(x, 0, z, BLOCK.BEDROCK);

            for (let y = 1; y < MAX_HEIGHT; y++) {
                if (y > height) {
                    // Water fill
                    if (y <= WATER_LEVEL) {
                        setBlock(x, y, z, BLOCK.WATER);
                    }
                    continue;
                }

                // Cave carving (3D noise)
                const caveVal = perlinCave.cave(x, y, z, 0.08);
                const caveVal2 = perlinCave.cave(x + 500, y + 500, z + 500, 0.06);
                const isCave = (caveVal > (1 - CAVE_THRESHOLD)) && (caveVal2 > 0.4) && y > 2 && y < height - 2;

                if (isCave) {
                    setBlock(x, y, z, BLOCK.AIR);
                    continue;
                }

                // Beach / sand near water
                const isBeach = height <= WATER_LEVEL + 2 && height >= WATER_LEVEL - 1;

                if (y === height) {
                    setBlock(x, y, z, isBeach ? BLOCK.SAND : BLOCK.GRASS);
                } else if (y > height - 4) {
                    setBlock(x, y, z, isBeach ? BLOCK.SAND : BLOCK.DIRT);
                } else if (y > 3) {
                    setBlock(x, y, z, BLOCK.STONE);
                } else {
                    setBlock(x, y, z, BLOCK.STONE);
                }
            }

            done++;
            if (done % (worldWidth * 4) === 0 && onProgress) {
                onProgress(done / total * 0.6);
            }
        }
    }
}

// ── Tree generation ──────────────────────────────────────────
function generateTrees(onProgress) {
    const treePositions = [];
    for (let x = 3; x < worldWidth - 3; x++) {
        for (let z = 3; z < worldDepth - 3; z++) {
            // Find surface
            let surfaceY = -1;
            for (let y = MAX_HEIGHT - 1; y >= 0; y--) {
                if (getBlock(x, y, z) === BLOCK.GRASS) { surfaceY = y; break; }
            }
            if (surfaceY < 0 || surfaceY <= WATER_LEVEL) continue;

            // Check minimum distance from other trees
            const pseudoRand = perlin.noise3D(x * 0.5, 0, z * 0.5);
            if (pseudoRand < 1 - TREE_CHANCE * 100) continue;

            const tooClose = treePositions.some(t =>
                Math.abs(t[0] - x) < 4 && Math.abs(t[1] - z) < 4
            );
            if (tooClose) continue;

            treePositions.push([x, z]);
            buildTree(x, surfaceY, z);
        }
    }
    if (onProgress) onProgress(0.8);
}

function buildTree(x, surfaceY, z) {
    const trunkHeight = 4 + Math.floor(Math.random() * 3);

    // Trunk
    for (let y = surfaceY + 1; y <= surfaceY + trunkHeight; y++) {
        setBlock(x, y, z, BLOCK.WOOD);
    }

    // Leaves (sphere-ish shape)
    const leafStart = surfaceY + trunkHeight - 1;
    const leafEnd   = surfaceY + trunkHeight + 2;
    for (let ly = leafStart; ly <= leafEnd; ly++) {
        const radius = ly === leafEnd ? 1 : (ly === leafStart ? 2 : 2);
        for (let lx = -radius; lx <= radius; lx++) {
            for (let lz = -radius; lz <= radius; lz++) {
                if (lx === 0 && lz === 0 && ly < leafEnd) continue; // trunk
                if (Math.abs(lx) === radius && Math.abs(lz) === radius && Math.random() > 0.5) continue;
                const bx = x + lx, bz = z + lz;
                if (getBlock(bx, ly, bz) === BLOCK.AIR) {
                    setBlock(bx, ly, bz, BLOCK.LEAVES);
                }
            }
        }
    }
}

// ── Mesh building (Greedy-ish, face culling) ─────────────────
const blockGeometries = {};
const blockMaterials  = {};

function getBlockMaterial(type) {
    if (!blockMaterials[type]) {
        const isWater = type === BLOCK.WATER;
        blockMaterials[type] = new THREE.MeshLambertMaterial({
            color: BLOCK_COLORS[type],
            transparent: isWater,
            opacity: isWater ? 0.6 : 1.0,
            side: isWater ? THREE.DoubleSide : THREE.FrontSide,
        });
    }
    return blockMaterials[type];
}

// Build instanced meshes per block type for performance
function buildWorldMesh(scene, onProgress) {
    // Count blocks per type
    const counts = {};
    for (let x = 0; x < worldWidth; x++) {
        for (let y = 0; y < MAX_HEIGHT; y++) {
            for (let z = 0; z < worldDepth; z++) {
                const b = getBlock(x, y, z);
                if (b === BLOCK.AIR) continue;

                // Face culling: only add if at least one adjacent is air/transparent
                if (hasVisibleFace(x, y, z, b)) {
                    counts[b] = (counts[b] || 0) + 1;
                }
            }
        }
    }

    const geo = new THREE.BoxGeometry(1, 1, 1);
    const meshes = {};

    for (const type in counts) {
        const mat = getBlockMaterial(parseInt(type));
        const mesh = new THREE.InstancedMesh(geo, mat, counts[type]);
        mesh.castShadow = parseInt(type) !== BLOCK.WATER;
        mesh.receiveShadow = true;
        meshes[type] = { mesh, index: 0 };
        scene.add(mesh);
    }

    const dummy = new THREE.Object3D();

    for (let x = 0; x < worldWidth; x++) {
        for (let y = 0; y < MAX_HEIGHT; y++) {
            for (let z = 0; z < worldDepth; z++) {
                const b = getBlock(x, y, z);
                if (b === BLOCK.AIR) continue;
                if (!hasVisibleFace(x, y, z, b)) continue;

                const entry = meshes[b];
                if (!entry) continue;

                dummy.position.set(x, y, z);
                dummy.updateMatrix();
                entry.mesh.setMatrixAt(entry.index, dummy.matrix);
                entry.index++;
            }
        }
    }

    // Finalize
    for (const type in meshes) {
        meshes[type].mesh.instanceMatrix.needsUpdate = true;
    }

    if (onProgress) onProgress(1.0);
    return meshes;
}

function isTransparent(type) {
    return type === BLOCK.AIR || type === BLOCK.WATER || type === BLOCK.LEAVES;
}

function hasVisibleFace(x, y, z, type) {
    const dirs = [[1,0,0],[-1,0,0],[0,1,0],[0,-1,0],[0,0,1],[0,0,-1]];
    for (const [dx,dy,dz] of dirs) {
        const neighbor = getBlock(x+dx, y+dy, z+dz);
        if (neighbor === BLOCK.AIR) return true;
        if (type !== BLOCK.WATER && neighbor === BLOCK.WATER) return true;
        if (type !== BLOCK.LEAVES && neighbor === BLOCK.LEAVES) return true;
    }
    return false;
}

// ── Clouds ───────────────────────────────────────────────────
function createClouds(scene) {
    const cloudGeo = new THREE.BoxGeometry(1, 0.5, 1);
    const cloudMat = new THREE.MeshLambertMaterial({ color: 0xffffff, transparent: true, opacity: 0.85 });

    const cloudGroup = new THREE.Group();
    const cloudNoise = new PerlinNoise(42);

    for (let x = -10; x < worldWidth + 10; x += 2) {
        for (let z = -10; z < worldDepth + 10; z += 2) {
            const v = cloudNoise.noise3D(x * 0.04, 0, z * 0.04);
            if (v > 0.15) {
                const thickness = v > 0.35 ? 2 : 1;
                for (let t = 0; t < thickness; t++) {
                    const mesh = new THREE.Mesh(cloudGeo, cloudMat);
                    mesh.position.set(x, MAX_HEIGHT + 8 + t * 0.5, z);
                    mesh.scale.set(2 + Math.random(), 1, 2 + Math.random());
                    cloudGroup.add(mesh);
                }
            }
        }
    }

    scene.add(cloudGroup);
    return cloudGroup;
}

// ── Three.js Setup ───────────────────────────────────────────
let scene, camera, renderer, clock;
let worldMeshes, cloudGroup;
let playerPos, playerVel, playerYaw, playerPitch;
let isJumping = false, onGround = false;
let breakingBlock = false, placingBlock = false, wantsToPlace = false;

// Joystick state
let joystickActive = false, joystickVec = { x: 0, y: 0 };

// Look state
let lookActive = false, lastLookX = 0, lastLookY = 0;

// Selected block
let selectedBlockType = BLOCK.GRASS;

// Raycaster for block interaction
const raycaster = new THREE.Raycaster();
raycaster.far = 6;

function init() {
    // Scene
    scene = new THREE.Scene();
    scene.background = new THREE.Color(0x87CEEB);
    scene.fog = new THREE.FogExp2(0x87CEEB, 0.012);

    // Camera (vertical / portrait)
    camera = new THREE.PerspectiveCamera(65, window.innerWidth / window.innerHeight, 0.1, 200);

    // Renderer
    renderer = new THREE.WebGLRenderer({ antialias: false, powerPreference: 'high-performance' });
    renderer.setSize(window.innerWidth, window.innerHeight);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    document.body.prepend(renderer.domElement);

    // Lighting – Sun
    const ambientLight = new THREE.AmbientLight(0x8899aa, 0.6);
    scene.add(ambientLight);

    const sunLight = new THREE.DirectionalLight(0xfff5e0, 1.0);
    sunLight.position.set(worldWidth / 2, MAX_HEIGHT + 20, worldWidth / 2);
    sunLight.castShadow = true;
    sunLight.shadow.mapSize.width = 1024;
    sunLight.shadow.mapSize.height = 1024;
    sunLight.shadow.camera.left = -40;
    sunLight.shadow.camera.right = 40;
    sunLight.shadow.camera.top = 40;
    sunLight.shadow.camera.bottom = -40;
    sunLight.shadow.camera.near = 1;
    sunLight.shadow.camera.far = 100;
    scene.add(sunLight);
    scene.userData.sun = sunLight;

    // Hemisphere light for sky color
    const hemiLight = new THREE.HemisphereLight(0x87CEEB, 0x5d9e3c, 0.3);
    scene.add(hemiLight);

    // Clock
    clock = new THREE.Clock();

    // Player
    const spawnX = worldWidth / 2;
    const spawnZ = worldDepth / 2;
    let spawnY = MAX_HEIGHT;
    for (let y = MAX_HEIGHT - 1; y >= 0; y--) {
        if (getBlock(spawnX, y, spawnZ) !== BLOCK.AIR && getBlock(spawnX, y, spawnZ) !== BLOCK.WATER) {
            spawnY = y + 2;
            break;
        }
    }
    playerPos = new THREE.Vector3(spawnX, spawnY, spawnZ);
    playerVel = new THREE.Vector3(0, 0, 0);
    playerYaw   = 0;
    playerPitch = -0.2;

    // Resize
    window.addEventListener('resize', () => {
        camera.aspect = window.innerWidth / window.innerHeight;
        camera.updateProjectionMatrix();
        renderer.setSize(window.innerWidth, window.innerHeight);
    });

    // Setup input
    setupJoystick();
    setupLookControls();
    setupButtons();
}

// ── Joystick ─────────────────────────────────────────────────
function setupJoystick() {
    const zone  = document.getElementById('joystick-zone');
    const base  = document.getElementById('joystick-base');
    const thumb = document.getElementById('joystick-thumb');

    const maxDist = 35;
    let activeTouchId = null;

    function handleMove(clientX, clientY) {
        const rect = base.getBoundingClientRect();
        const cx = rect.left + rect.width / 2;
        const cy = rect.top  + rect.height / 2;
        let dx = clientX - cx;
        let dy = clientY - cy;
        const dist = Math.sqrt(dx * dx + dy * dy);
        if (dist > maxDist) {
            dx = dx / dist * maxDist;
            dy = dy / dist * maxDist;
        }
        thumb.style.transform = `translate(${dx}px, ${dy}px)`;
        joystickVec.x =  dx / maxDist;
        joystickVec.y = -dy / maxDist; // invert Y
    }

    zone.addEventListener('touchstart', (e) => {
        e.preventDefault();
        e.stopPropagation();
        if (activeTouchId !== null) return; // already tracking a finger
        const t = e.changedTouches[0];
        activeTouchId = t.identifier;
        joystickActive = true;
        handleMove(t.clientX, t.clientY);
    }, { passive: false });

    zone.addEventListener('touchmove', (e) => {
        e.preventDefault();
        e.stopPropagation();
        for (let i = 0; i < e.changedTouches.length; i++) {
            const t = e.changedTouches[i];
            if (t.identifier === activeTouchId) {
                handleMove(t.clientX, t.clientY);
                break;
            }
        }
    }, { passive: false });

    const endJoystick = (e) => {
        for (let i = 0; i < e.changedTouches.length; i++) {
            if (e.changedTouches[i].identifier === activeTouchId) {
                activeTouchId = null;
                joystickActive = false;
                joystickVec.x = 0;
                joystickVec.y = 0;
                thumb.style.transform = 'translate(0px, 0px)';
                break;
            }
        }
    };
    zone.addEventListener('touchend', endJoystick, { passive: false });
    zone.addEventListener('touchcancel', endJoystick, { passive: false });

    // Keyboard fallback (desktop testing)
    const keys = {};
    window.addEventListener('keydown', (e) => { keys[e.key.toLowerCase()] = true; });
    window.addEventListener('keyup',   (e) => { keys[e.key.toLowerCase()] = false; });
    window._keys = keys;
}

// ── Look controls (full screen background, lowest z-index) ───
function setupLookControls() {
    const zone = document.getElementById('look-zone');
    let lookTouchId = null;

    zone.addEventListener('touchstart', (e) => {
        e.preventDefault();
        if (lookTouchId !== null) return;
        const t = e.changedTouches[0];
        lookTouchId = t.identifier;
        lookActive = true;
        lastLookX = t.clientX;
        lastLookY = t.clientY;
    }, { passive: false });

    zone.addEventListener('touchmove', (e) => {
        e.preventDefault();
        if (!lookActive) return;
        for (let i = 0; i < e.changedTouches.length; i++) {
            const t = e.changedTouches[i];
            if (t.identifier === lookTouchId) {
                const dx = t.clientX - lastLookX;
                const dy = t.clientY - lastLookY;
                playerYaw   -= dx * 0.004;
                playerPitch -= dy * 0.004;
                playerPitch  = Math.max(-Math.PI / 2 + 0.1, Math.min(Math.PI / 2 - 0.1, playerPitch));
                lastLookX = t.clientX;
                lastLookY = t.clientY;
                break;
            }
        }
    }, { passive: false });

    const endLook = (e) => {
        for (let i = 0; i < e.changedTouches.length; i++) {
            if (e.changedTouches[i].identifier === lookTouchId) {
                lookTouchId = null;
                lookActive = false;
                break;
            }
        }
    };
    zone.addEventListener('touchend', endLook, { passive: false });
    zone.addEventListener('touchcancel', endLook, { passive: false });

    // Mouse fallback for desktop
    let mouseDown = false;
    zone.addEventListener('mousedown', (e) => {
        mouseDown = true;
        lastLookX = e.clientX;
        lastLookY = e.clientY;
    });
    window.addEventListener('mousemove', (e) => {
        if (!mouseDown) return;
        const dx = e.clientX - lastLookX;
        const dy = e.clientY - lastLookY;
        playerYaw   -= dx * 0.003;
        playerPitch -= dy * 0.003;
        playerPitch  = Math.max(-Math.PI / 2 + 0.1, Math.min(Math.PI / 2 - 0.1, playerPitch));
        lastLookX = e.clientX;
        lastLookY = e.clientY;
    });
    window.addEventListener('mouseup', () => { mouseDown = false; });
}

// ── Action buttons (proper JS event listeners) ───────────────
function setupButtons() {
    const btnJump  = document.getElementById('btn-jump');
    const btnBreak = document.getElementById('btn-break');
    const btnPlace = document.getElementById('btn-place');

    // Helper: attach touch with preventDefault + stopPropagation
    function onTouch(el, onStart, onEnd) {
        el.addEventListener('touchstart', (e) => {
            e.preventDefault();
            e.stopPropagation();
            onStart();
        }, { passive: false });
        el.addEventListener('touchend', (e) => {
            e.preventDefault();
            e.stopPropagation();
            onEnd();
        }, { passive: false });
        el.addEventListener('touchcancel', (e) => {
            e.preventDefault();
            e.stopPropagation();
            onEnd();
        }, { passive: false });
        // Mouse fallback
        el.addEventListener('mousedown', (e) => { e.preventDefault(); e.stopPropagation(); onStart(); });
        el.addEventListener('mouseup',   (e) => { e.preventDefault(); e.stopPropagation(); onEnd(); });
        el.addEventListener('mouseleave',(e) => { onEnd(); });
    }

    onTouch(btnJump,
        () => { isJumping = true; },
        () => { isJumping = false; }
    );

    onTouch(btnBreak,
        () => { breakingBlock = true; },
        () => { breakingBlock = false; }
    );

    // Place uses a flag that is consumed once per tap (no cancel on touchend)
    onTouch(btnPlace,
        () => { wantsToPlace = true; },
        () => { /* intentionally empty – wantsToPlace is consumed by game loop */ }
    );

    // Hotbar slot selection
    document.querySelectorAll('.slot').forEach(slot => {
        slot.addEventListener('touchstart', (e) => {
            e.preventDefault();
            e.stopPropagation();
            selectSlot(slot);
        }, { passive: false });
        slot.addEventListener('click', (e) => {
            e.preventDefault();
            e.stopPropagation();
            selectSlot(slot);
        });
    });
}

function selectSlot(el) {
    document.querySelectorAll('.slot').forEach(s => s.classList.remove('selected'));
    el.classList.add('selected');
    selectedBlockType = BLOCK_NAME_MAP[el.dataset.block] || BLOCK.GRASS;
}

// ── Physics & Collision ──────────────────────────────────────
const GRAVITY   = -18;
const JUMP_VEL  = 7;
const MOVE_SPEED = 5.5;
const PLAYER_HEIGHT = 1.7;
const PLAYER_WIDTH  = 0.3;

function isSolid(x, y, z) {
    const b = getBlock(Math.floor(x), Math.floor(y), Math.floor(z));
    return b !== BLOCK.AIR && b !== BLOCK.WATER && b !== BLOCK.LEAVES;
}

function isInWater(x, y, z) {
    return getBlock(Math.floor(x), Math.floor(y), Math.floor(z)) === BLOCK.WATER;
}

function updatePlayer(dt) {
    const keys = window._keys || {};

    // ── Movement direction from joystick or keyboard
    let moveX = joystickVec.x;
    let moveZ = joystickVec.y;

    // Keyboard fallback
    if (keys['z'] || keys['w'] || keys['arrowup'])    moveZ =  1;
    if (keys['s'] || keys['arrowdown'])                moveZ = -1;
    if (keys['q'] || keys['a'] || keys['arrowleft'])   moveX = -1;
    if (keys['d'] || keys['arrowright'])                moveX =  1;
    if (keys[' ']) isJumping = true;

    // Direction relative to yaw
    const sinY = Math.sin(playerYaw);
    const cosY = Math.cos(playerYaw);
    const dirX = moveX * cosY - moveZ * sinY;
    const dirZ = moveX * sinY + moveZ * cosY;

    const speed = MOVE_SPEED * dt;
    const newX = playerPos.x + dirX * speed;
    const newZ = playerPos.z + dirZ * speed;

    // Horizontal collision
    if (!isSolid(newX + PLAYER_WIDTH, playerPos.y, playerPos.z) &&
        !isSolid(newX - PLAYER_WIDTH, playerPos.y, playerPos.z) &&
        !isSolid(newX + PLAYER_WIDTH, playerPos.y - 1, playerPos.z) &&
        !isSolid(newX - PLAYER_WIDTH, playerPos.y - 1, playerPos.z)) {
        playerPos.x = newX;
    }

    if (!isSolid(playerPos.x, playerPos.y, newZ + PLAYER_WIDTH) &&
        !isSolid(playerPos.x, playerPos.y, newZ - PLAYER_WIDTH) &&
        !isSolid(playerPos.x, playerPos.y - 1, newZ + PLAYER_WIDTH) &&
        !isSolid(playerPos.x, playerPos.y - 1, newZ - PLAYER_WIDTH)) {
        playerPos.z = newZ;
    }

    // Water physics
    const inWater = isInWater(playerPos.x, playerPos.y - 1, playerPos.z) ||
                    isInWater(playerPos.x, playerPos.y, playerPos.z);

    // Gravity
    if (inWater) {
        playerVel.y += GRAVITY * 0.3 * dt;
        playerVel.y *= 0.9; // water drag
        if (isJumping) playerVel.y = 3;
    } else {
        playerVel.y += GRAVITY * dt;
    }

    const newY = playerPos.y + playerVel.y * dt;

    // Vertical collision
    onGround = false;
    if (playerVel.y < 0) {
        // Falling
        if (isSolid(playerPos.x, newY - PLAYER_HEIGHT, playerPos.z)) {
            playerPos.y = Math.floor(newY - PLAYER_HEIGHT) + 1 + PLAYER_HEIGHT;
            playerVel.y = 0;
            onGround = true;
        } else {
            playerPos.y = newY;
        }
    } else {
        // Rising
        if (isSolid(playerPos.x, newY + 0.1, playerPos.z)) {
            playerVel.y = 0;
        } else {
            playerPos.y = newY;
        }
    }

    // Jump
    if (isJumping && onGround && !inWater) {
        playerVel.y = JUMP_VEL;
        onGround = false;
    }

    // Clamp to world bounds
    playerPos.x = Math.max(1, Math.min(worldWidth - 2, playerPos.x));
    playerPos.z = Math.max(1, Math.min(worldDepth - 2, playerPos.z));
    if (playerPos.y < 1) { playerPos.y = MAX_HEIGHT; playerVel.y = 0; } // respawn if fell through

    // Update camera
    camera.position.copy(playerPos);
    const lookDir = new THREE.Vector3(
        Math.sin(playerYaw) * Math.cos(playerPitch),
        Math.sin(playerPitch),
        Math.cos(playerYaw) * Math.cos(playerPitch)
    );
    camera.lookAt(playerPos.clone().add(lookDir));
}

// ── Block interaction ────────────────────────────────────────
let breakTimer = 0;
const BREAK_TIME = 0.3;

function updateBlockInteraction(dt) {
    // Raycast from camera center
    const dir = new THREE.Vector3(0, 0, -1);
    dir.applyQuaternion(camera.quaternion);
    raycaster.set(camera.position, dir);

    if (breakingBlock) {
        breakTimer += dt;
        if (breakTimer >= BREAK_TIME) {
            breakTimer = 0;
            // Find block to break
            const target = raycastBlock(false);
            if (target) {
                const { x, y, z } = target;
                if (getBlock(x, y, z) !== BLOCK.BEDROCK) {
                    setBlock(x, y, z, BLOCK.AIR);
                    rebuildWorld();
                    if (window.Ondes) Ondes.Device.hapticFeedback('light');
                }
            }
        }
    } else {
        breakTimer = 0;
    }

    if (placingBlock || wantsToPlace) {
        wantsToPlace = false;
        placingBlock = false;
        const target = raycastBlock(true);
        if (target) {
            const { x, y, z } = target;
            // Don't place inside player
            const px = Math.floor(playerPos.x), py = Math.floor(playerPos.y), pz = Math.floor(playerPos.z);
            if (!(x === px && z === pz && (y === py || y === py - 1))) {
                setBlock(x, y, z, selectedBlockType);
                rebuildWorld();
                if (window.Ondes) Ondes.Device.hapticFeedback('light');
            }
        }
    }
}

function raycastBlock(getAdjacentFace) {
    const dir = new THREE.Vector3(0, 0, -1);
    dir.applyQuaternion(camera.quaternion);

    const step = 0.1;
    const maxDist = 6;
    const pos = camera.position.clone();
    let prevX, prevY, prevZ;

    for (let d = 0; d < maxDist; d += step) {
        const x = Math.floor(pos.x + dir.x * d);
        const y = Math.floor(pos.y + dir.y * d);
        const z = Math.floor(pos.z + dir.z * d);

        const b = getBlock(x, y, z);
        if (b !== BLOCK.AIR && b !== BLOCK.WATER) {
            if (getAdjacentFace && prevX !== undefined) {
                return { x: prevX, y: prevY, z: prevZ };
            }
            return { x, y, z };
        }
        prevX = x; prevY = y; prevZ = z;
    }
    return null;
}

// ── World rebuild (after block changes) ──────────────────────
function rebuildWorld() {
    // Remove old meshes
    for (const type in worldMeshes) {
        scene.remove(worldMeshes[type].mesh);
        worldMeshes[type].mesh.dispose();
    }
    worldMeshes = buildWorldMesh(scene, null);
}

// ── Day/Night cycle (subtle) ─────────────────────────────────
let dayTime = 0;
function updateDayCycle(dt) {
    dayTime += dt * 0.02; // slow cycle
    const sunAngle = dayTime % (Math.PI * 2);
    const sunY = Math.sin(sunAngle);
    const sunX = Math.cos(sunAngle);

    const sun = scene.userData.sun;
    sun.position.set(
        worldWidth / 2 + sunX * 60,
        sunY * 50 + 20,
        worldDepth / 2
    );
    sun.intensity = Math.max(0.2, sunY * 0.8 + 0.5);

    // Sky color
    const skyBrightness = Math.max(0.15, (sunY + 1) / 2);
    const r = 0.53 * skyBrightness;
    const g = 0.81 * skyBrightness;
    const b = 0.92 * skyBrightness;
    scene.background.setRGB(r, g, b);
    scene.fog.color.setRGB(r, g, b);
}

// ── Cloud animation ──────────────────────────────────────────
function updateClouds(dt) {
    if (cloudGroup) {
        cloudGroup.position.x += dt * 0.5;
        if (cloudGroup.position.x > 30) cloudGroup.position.x = -30;
    }
}

// ── Game Loop ────────────────────────────────────────────────
function gameLoop() {
    requestAnimationFrame(gameLoop);
    const dt = Math.min(clock.getDelta(), 0.05); // cap delta

    updatePlayer(dt);
    updateBlockInteraction(dt);
    updateDayCycle(dt);
    updateClouds(dt);

    renderer.render(scene, camera);
}

// ── Loading & Start ──────────────────────────────────────────
function updateLoadingBar(progress) {
    const bar = document.getElementById('loading-bar');
    const text = document.getElementById('loading-text');
    bar.style.width = Math.floor(progress * 100) + '%';

    if (progress < 0.3) text.textContent = 'Sculptage du terrain...';
    else if (progress < 0.6) text.textContent = 'Creusement des grottes...';
    else if (progress < 0.8) text.textContent = 'Plantation des arbres...';
    else if (progress < 0.95) text.textContent = 'Construction des meshes...';
    else text.textContent = 'Prêt !';
}

function startGame() {
    // Use setTimeout to allow UI to update
    setTimeout(() => {
        generateTerrain(updateLoadingBar);

        setTimeout(() => {
            generateTrees(updateLoadingBar);

            setTimeout(() => {
                init();
                worldMeshes = buildWorldMesh(scene, updateLoadingBar);
                cloudGroup = createClouds(scene);

                // Hide loading screen
                const loading = document.getElementById('loading');
                loading.classList.add('hidden');
                setTimeout(() => loading.style.display = 'none', 600);

                gameLoop();
            }, 50);
        }, 50);
    }, 100);
}

// ── Ondes integration ────────────────────────────────────────
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', startGame);
} else {
    startGame();
}

document.addEventListener('OndesReady', () => {
    Ondes.UI.configureAppBar({ title: '⛏ MiniCraft', visible: true });
});
