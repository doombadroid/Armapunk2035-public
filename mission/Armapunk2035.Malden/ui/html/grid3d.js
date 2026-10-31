/* GRID3D -- the shared terrain/building/satellite renderer behind MALDEN GRID
   (ui/html/map.html) and the HUD minimap (ui/html/hud.html).

   Loaded by A3API.RequestFile + eval, never <script src>: these pages have no
   resolvable base URL and a src quietly resolves to nothing. Idempotent -- a
   second eval replaces the global with an identical one and breaks nothing.

   It owns EVERYTHING that is the same on both screens: the heightfield, the
   terrain mesh, the sea, the satellite atlas and its fetch pump, the mesh
   library and the building batcher. It owns NOTHING about how a screen looks:
   no camera, no input, no blips, no chrome. create() takes the page's own GL
   context because the two canvases are created with different attributes.

   EVERY function below was MOVED OUT OF map.html BYTE-FOR-BYTE, original
   indentation included, so `diff` against the pre-extraction page still reads.
   The only edits are mechanical and exhaustively listed here:
     1. a bare `gl.` became `R.gl.` (the instance's context);
     2. `updateHero`, `evictMeshSectors` and the three draw passes took the
        camera centre as (cx, cy) / the cull reach as `radius` instead of
        reading the page's `cam` global -- the module owns no camera;
     3. the draw passes take the per-frame lighting the page already computed
        (mpp, sun, amb, fogK) as arguments;
     4. the tile pump calls R.onDirty() / R.onFirstTile() where it used to call
        the page's dirty() and hide the page's #loading label;
     5. sh() and prog() each gained one line registering the object so
        dispose() can free it.
   Nothing else changed. A behaviour change hidden inside a 900-line move is
   undiagnosable, which is why the moves are diffable.

   Calibration constants are duplicated from map.html on purpose: the page needs
   them at parse time, before this module can exist. They are literals of the
   island (12800 m, 13x13 layers, 512 px tiles, 16 px overlap) and have never
   changed; if they ever do, both copies move together.

   CALL ORDER -- this fails silently or obscurely if a consumer gets it wrong,
   so it is a contract, not a suggestion:
     1. create(gl, opts) returns R with no side effects beyond allocating state.
        opts is optional; {detail:false, hero:false} skips the two big atlases
        an instance cannot sample. See create() for why that is an option and
        not a shared cache.
     2. Set R.onDirty BEFORE the first R.drawBuildings() call. It defaults to
        a no-op, and drawBuildings relies on it to ask for another frame once
        MAX_BUILDS throttles how many mesh sectors it builds in one pass -- a
        consumer that forgets this gets a skyline that silently stops filling
        in, with no error anywhere. Set R.onFirstTile too, or the "first
        satellite tile landed" signal (used to drop a loading label) is
        swallowed the same way.
     3. Call R.initAtlases() before the first draw. Unset, the draw passes
        bind null textures -- the picture renders solid black, not broken.
        It builds whatever create()'s opts allowed, so it is still the one
        call; a consumer never decides atlas-by-atlas.
        R.tiles.loadAtlas(res, txt) fills a whole tier from one pre-composed
        image and needs the atlases to exist, so it comes after this. It is
        OPTIONAL in the strongest sense: a rejection (missing asset, wrong
        size, bad decode) leaves nothing drawn and nothing marked present, and
        the per-tile pump behaves exactly as it did before the atlas existed.
     4. Call R.loadHF(txt) before R.buildTerrain(). buildTerrain reads the
        module-local heightfield loadHF sets; calling it first throws on
        undefined.n.
     5. loadMeshLib / loadFences / loadBuildings / rebuildSectors all return
        PROMISES and none of them finishes in the turn it was called in: the
        parses and the sector build run in ~12 ms slices so an arriving
        satellite tile can decode between them (see pump). Chain them; do not
        read R.meshes or R.sectors on the next line.
        R.loadMeshLib(txt) RECORDS the library; it does not rebuild anything.
        loadBuildings decides box-vs-mesh per row from whatever R.meshes
        already holds, so a consumer that wants real silhouettes in one pass
        still calls loadMeshLib FIRST.
        A consumer that wants the opening view sooner does the opposite --
        loadBuildings first (every row a box), then loadMeshLib and
        loadFences once the picture has arrived, then R.rebuildSectors() to
        re-split the rows it kept. Both setters only RECORD, so a screen that
        wants both pays one rebuild, not two. Forgetting rebuildSectors() is not a broken screen: the sectors
        stay as they are, which is boxes, which is exactly what a client whose
        PBO predates the mesh library sees. Re-splitting the SAME rows in the
        SAME order rebuilds byte-identical sectors -- that identity is what
        scratchpad/grid3d_harness asserts, and it is why the rows are kept
        rather than the text.
     R.buildWater() has no ordering dependency. The three draw calls
     (R.drawTerrain / R.drawWater / R.drawBuildings) are safe no-ops before
     their feed lands -- they each guard on the buffer/sector state existing
     -- so only the five points above are load-bearing. */
(function () {
  "use strict";

/* ==== calibration (verbatim from map.html) ================================= */
var MAP_M = 12800, GRID = 13, TILE_PX = 512;
var OV_PX = 16;          // satellite layers are cut with an edge overlap; 16px is the TB default
var SWAP_XY = false;     // s_COL_ROW
var SPAN = MAP_M / GRID;

/* ==== lighting ============================================================
   MOVED HERE FROM map.html, verbatim, because every draw pass in this module
   takes (sun, amb, fogK) and the second consumer (the HUD minimap) would
   otherwise need its own copy of the derivation -- a second copy of a rule is
   the exact thing this module exists to prevent. Same expressions, same order,
   same literals, so the map renders byte-identically through it; that is
   asserted by scratchpad/grid3d_harness, not assumed.

   Module scope, not per-instance: these are pure functions of their arguments
   and hold no GL state, so there is nothing for an instance to own. */
function sunFromHour(h) {
  var t = (h-6)/12, elev = Math.sin(t*Math.PI);
  var az = (t-0.5)*Math.PI;                            // east→west sweep
  var sd = [Math.sin(az)*0.8, Math.max(elev, 0.06), -0.5];
  var l = 1/Math.hypot(sd[0], sd[1], sd[2]);
  var day = Math.max(0, Math.min(1, elev*2.4));
  var warm = Math.max(0, 1-Math.abs(elev)*3.2);
  return {
    dir: [sd[0]*l, sd[1]*l, sd[2]*l],
    sunC: [ (0.9+warm*0.25)*day, (0.85-warm*0.12)*day, (0.72-warm*0.3)*day ],
    amb: [ 0.30-day*0.02+0.04, 0.36+day*0.03, 0.33+day*0.01 ],
    night: 1-day
  };
}
/* The three uniforms every draw pass wants, from the two things a screen knows:
   what time it is and how far its camera is from what it is looking at.

   `overcast` is ACCEPTED AND NOT READ. map.html has carried it in `env` since
   the page was written and has never fed it into the sun; consuming it here
   would be a rendering change smuggled in under a move. It is in the signature
   so that the day it means something there is exactly one place to add it.

   `dist` is a camera property rather than a time-of-day one, but every consumer
   needs fogK on the same frame it needs sun and amb, and splitting them into
   two calls only invites one screen to compute fog its own way. */
function lighting(hour, overcast, dist) {
  var sun = sunFromHour(hour);
  var nightAmb = sun.night*0.55;
  var amb = [sun.amb[0]-nightAmb*0.20, sun.amb[1]-nightAmb*0.16, sun.amb[2]-nightAmb*0.12];
  return { sun: sun, amb: amb, fogK: 1/Math.pow(dist*5+12000, 2) };
}

/* ==== chunked work ========================================================
   JS IS SINGLE-THREADED, so a parse loop that runs for a second is a second in
   which an arriving satellite tile cannot decode, blit or upload -- measured on
   a real client, tile1 landed at 314 ms and then nothing moved until the mesh
   library's parse released the thread at ~2.1 s. Every long loop in this module
   therefore runs in slices: do work until CHUNK_MS has gone, hand the thread
   back, resume on the next turn.

   setTimeout(0), not requestAnimationFrame: IDLE IS STILL is a property both
   consumers depend on (the HUD's harness asserts it), and a parse must not be
   the reason a frame loop keeps turning. Not requestIdleCallback either -- the
   pages already use setTimeout for their fetch races, and rIC's availability in
   this webview has never been characterised.

   THE COST IS REAL AND IT IS THE POINT. Chromium clamps a setTimeout nested
   more than five deep to 4 ms, so a 850 ms parse in 12 ms slices takes ~1.1 s
   of wall clock. It is 250 ms slower and it never blocks for more than a frame,
   and every one of those gaps is a tile that gets to land. This work is off the
   critical path (see map.html's boot chain) precisely so that trade is free.

   work() does ONE grain -- a batch of rows, a model, a sector -- and returns
   true when there is nothing left. The grain has to be small enough that the
   clock is checked often enough to mean something, and big enough that the
   check is not the work. */
var CHUNK_MS = 12;
function pump(work) {
  return new Promise(function (resolve, reject) {
    function run() {
      var t0 = performance.now(), done = false;
      /* The FIRST slice runs synchronously inside the executor, so a caller
         whose input is small pays no scheduling round trip at all. */
      try { do { done = work(); } while (!done && performance.now() - t0 < CHUNK_MS); }
      catch (e) { reject(e); return; }
      if (done) resolve(); else setTimeout(run, 0);
    }
    run();
  });
}

/* create(gl, opts) -- opts is optional and every field defaults to the map's
   behaviour, so create(gl) is unchanged from Task 3.

     detail : false  do not build the 256 satellite atlas (3328², ~33 MB GL plus
                     its backing canvas). drawTerrain falls back to the 128 one
                     at every scale.
     hero   : false  do not build the hero window (3072², ~28 MB GL plus canvas).

   WHY THIS EXISTS. Every instance owns its OWN atlases -- roughly 70 MB of GL
   texture and 90 MB of 2D canvas for the full set -- and initAtlases() used to
   be all-or-nothing. The HUD minimap can never sample the hero window (HERO_MPP
   is 6 m/px and the panel sits far below it) and never gets close enough to want
   the 256 atlas either, so as a plain create(gl) it would allocate ~60 MB of
   texture it cannot use, in a webview that never closes.

   Options rather than a module-level shared cache: this module has no
   cross-instance state today, the Task 3 review specifically confirmed that
   absence, and a per-resolution reference-counted atlas is a much larger change
   that can still be made later on top of this one. This version cannot regress
   the map, because the map passes nothing. */
function create(gl, opts) {
  opts = opts || {};
  var USE_DET  = opts.detail !== false;   // the 256 atlas
  var USE_HERO = opts.hero   !== false;   // the native-resolution window
  var R = { gl: gl, hf: null, meshes: null,
            sectors: null, sectorsM: null, sectorsF: null,
            SEC: 8, bldCount: 0, _progs: [], _shaders: [] };
  /* Hooks the page installs. The renderer never touches the DOM and never
     schedules a frame: it asks, the screen decides. */
  R.onDirty = function () {};
  R.onFirstTile = function () {};
  /* Once per resolution tier, the first time a tile of that tier reaches the
     surface it belongs to -- an arriving RequestTexture or a whole composed
     atlas, the two are the same event to a screen. onFirstTile still fires
     exactly once, for the first tile overall, and fires FIRST; this is the
     finer-grained signal beside it, not a replacement. The map stamps
     [MAPTIME] t256 off res 256 with it. */
  R.onFirstTileAt = function (res) {};

/* ==== tiny mat4 ============================================================ */
function mPersp(o, fovy, asp, n, f) { var t = 1/Math.tan(fovy/2), nf = 1/(n-f);
  o[0]=t/asp;o[1]=0;o[2]=0;o[3]=0; o[4]=0;o[5]=t;o[6]=0;o[7]=0;
  o[8]=0;o[9]=0;o[10]=(f+n)*nf;o[11]=-1; o[12]=0;o[13]=0;o[14]=2*f*n*nf;o[15]=0; return o; }
function mLook(o, ex, ey, ez, cx, cy, cz, ux, uy, uz) {
  var zx = ex-cx, zy = ey-cy, zz = ez-cz, zl = 1/Math.hypot(zx,zy,zz); zx*=zl;zy*=zl;zz*=zl;
  var xx = uy*zz-uz*zy, xy = uz*zx-ux*zz, xz = ux*zy-uy*zx, xl = 1/(Math.hypot(xx,xy,xz)||1); xx*=xl;xy*=xl;xz*=xl;
  var yx = zy*xz-zz*xy, yy = zz*xx-zx*xz, yz = zx*xy-zy*xx;
  o[0]=xx;o[1]=yx;o[2]=zx;o[3]=0; o[4]=xy;o[5]=yy;o[6]=zy;o[7]=0; o[8]=xz;o[9]=yz;o[10]=zz;o[11]=0;
  o[12]=-(xx*ex+xy*ey+xz*ez); o[13]=-(yx*ex+yy*ey+yz*ez); o[14]=-(zx*ex+zy*ey+zz*ez); o[15]=1; return o; }
function mMul(o, a, b) { for (var i = 0; i < 4; i++) { var b0=b[i*4],b1=b[i*4+1],b2=b[i*4+2],b3=b[i*4+3];
  o[i*4]=a[0]*b0+a[4]*b1+a[8]*b2+a[12]*b3; o[i*4+1]=a[1]*b0+a[5]*b1+a[9]*b2+a[13]*b3;
  o[i*4+2]=a[2]*b0+a[6]*b1+a[10]*b2+a[14]*b3; o[i*4+3]=a[3]*b0+a[7]*b1+a[11]*b2+a[15]*b3; } return o; }

/* ==== GL setup (the context is the page's; the programs are ours) ========= */
function sh(type, src) { var s = R.gl.createShader(type); R.gl.shaderSource(s, src); R.gl.compileShader(s);
  if (!R.gl.getShaderParameter(s, R.gl.COMPILE_STATUS)) console.error(R.gl.getShaderInfoLog(s), src);
  R._shaders.push(s); return s; }
function prog(vs, fs) { var p = R.gl.createProgram();
  R.gl.attachShader(p, sh(R.gl.VERTEX_SHADER, vs)); R.gl.attachShader(p, sh(R.gl.FRAGMENT_SHADER, fs));
  R.gl.linkProgram(p); if (!R.gl.getProgramParameter(p, R.gl.LINK_STATUS)) console.error(R.gl.getProgramInfoLog(p));
  R._progs.push(p); return p; }

var FOG = [0.020, 0.043, 0.035];

var terrP = prog(
  "attribute vec3 aP;attribute vec3 aN;uniform mat4 uVP;uniform float uFogK;varying vec2 vUV;varying vec3 vN;varying float vFog;varying float vH;"+
  "void main(){vUV=vec2(aP.x/12800.0,(12800.0+aP.z)/12800.0);vN=aN;vH=aP.y;"+
  "vec4 cp=uVP*vec4(aP,1.0);vFog=clamp(1.0-exp(-cp.w*cp.w*uFogK),0.0,1.0);gl_Position=cp;}",
  "precision mediump float;varying vec2 vUV;varying vec3 vN;varying float vFog;varying float vH;"+
  "uniform sampler2D uSat;uniform sampler2D uHero;uniform vec4 uHeroRect;uniform float uHeroMix;"+
  "uniform vec3 uSun;uniform vec3 uSunC;uniform vec3 uAmb;uniform vec3 uFogC;"+
  // uHeroRect = (u0, v0, 1/width, 1/height) of the hero window in island UV.
  // Inside it the fragment reads the native-resolution window instead of the
  // atlas; the edge fades over ~6% of the window so the seam never shows.
  "void main(){vec3 tex=texture2D(uSat,vUV).rgb;"+
  "if(uHeroMix>0.0){vec2 hv=(vUV-uHeroRect.xy)*uHeroRect.zw;"+
  "if(hv.x>0.0&&hv.x<1.0&&hv.y>0.0&&hv.y<1.0){"+
  "vec2 e=min(hv,1.0-hv);float f=clamp(min(e.x,e.y)/0.06,0.0,1.0);"+
  "tex=mix(tex,texture2D(uHero,hv).rgb,f*uHeroMix);}}"+
  "float ndl=max(dot(normalize(vN),uSun),0.0);"+
  "vec3 col=tex*(uAmb+uSunC*ndl);"+
  "gl_FragColor=vec4(mix(col,uFogC,vFog),1.0);}");

var watP = prog(
  "attribute vec3 aP;uniform mat4 uVP;uniform float uFogK;varying vec2 vW;varying float vFog;"+
  "void main(){vW=vec2(aP.x,-aP.z);vec4 cp=uVP*vec4(aP,1.0);vFog=clamp(1.0-exp(-cp.w*cp.w*uFogK),0.0,1.0);gl_Position=cp;}",
  "precision mediump float;varying vec2 vW;varying float vFog;"+
  "uniform vec3 uAmb;uniform vec3 uFogC;uniform float uNight;"+
  "void main(){vec3 base=vec3(0.016,0.045,0.038)*(0.6+uAmb*0.8);"+
  "vec2 g=abs(fract(vW/200.0)-0.5);float ln=step(0.485,max(g.x,g.y));"+
  "base+=vec3(0.05,0.11,0.07)*ln*(0.5+uNight*0.5);"+
  "gl_FragColor=vec4(mix(base,uFogC,vFog),1.0);}");

var BLD_FS =
  "precision mediump float;varying vec3 vC;varying vec3 vN;varying float vFog;varying float vK;varying float vY;"+
  "uniform vec3 uSun;uniform vec3 uSunC;uniform vec3 uAmb;uniform vec3 uFogC;uniform float uNight;"+
  "void main(){float ndl=max(dot(normalize(vN),uSun),0.0);"+
  "vec3 col=vC*(uAmb+uSunC*ndl);"+
  "if(vK>3.5&&vK<4.5){float win=step(0.78,fract(vY*0.30))*step(0.15,abs(vN.y)<0.7?1.0:0.0);"+
  "col+=vec3(0.35,0.78,0.42)*win*uNight;col+=vec3(0.16,0.28,0.10)*uNight*0.5;}"+
  "else{col+=vec3(0.06,0.14,0.10)*uNight*(1.0-abs(vN.y))*0.6;}"+
  "gl_FragColor=vec4(mix(col,uFogC,vFog),1.0);}";
var bldP = prog(
  "attribute vec2 aXZ;attribute vec2 aBT;attribute float aUp;attribute vec3 aN;attribute float aK;"+
  "uniform mat4 uVP;uniform float uEx;uniform float uFogK;uniform vec3 uKC[6];"+
  "varying vec3 vC;varying vec3 vN;varying float vFog;varying float vK;varying float vY;"+
  "void main(){float y=aBT.x+max((aBT.y-aBT.x)*aUp*uEx,aUp*1.2);"+
  "vC=uKC[int(aK+0.5)]*(1.0+aUp*0.18);vN=aN;vK=aK;vY=y;"+
  "vec4 cp=uVP*vec4(aXZ.x,y,aXZ.y,1.0);vFog=clamp(1.0-exp(-cp.w*cp.w*uFogK),0.0,1.0);gl_Position=cp;}",
  BLD_FS);
/* the real-silhouette path (malden_msh.txt): absolute positions, per-vertex
   color; same fragment lighting as the boxes so the two tiers match. Drawn only
   fully extruded (mpp < 10) -- no uEx morph needed. */
var mshP = prog(
  "attribute vec3 aP;attribute vec3 aN;attribute vec3 aC;attribute float aK;"+
  "uniform mat4 uVP;uniform float uFogK;"+
  "varying vec3 vC;varying vec3 vN;varying float vFog;varying float vK;varying float vY;"+
  "void main(){vC=aC;vN=aN;vK=aK;vY=aP.y;"+
  "vec4 cp=uVP*vec4(aP,1.0);vFog=clamp(1.0-exp(-cp.w*cp.w*uFogK),0.0,1.0);gl_Position=cp;}",
  BLD_FS);

/* ==== heightfield ========================================================== */
var HF = null;  // {n, cell, data(Float32 n*n world-order: row 0 = SOUTH), extent}
function parseHF(txt) {
  var lines = txt.split("\n"), meta = null, i0 = 0;
  for (var i = 0; i < lines.length; i++) { var L = lines[i].trim();
    if (!L || L[0] === "#") continue;
    meta = L.split(/[\s,]+/).map(Number); i0 = i + 1; break; }
  if (!meta || meta.length < 2) return null;
  var n = meta[0]|0, cell = meta[1];
  var data = new Float32Array(n*n), row = 0;
  for (var i = i0; i < lines.length && row < n; i++) { var L = lines[i].trim(); if (!L) continue;
    var vals = L.split(","), y = n - 1 - row;             // file row 0 = north
    for (var c = 0; c < n; c++) data[y*n + c] = +vals[c] || 0;
    row++;
  }
  return { n: n, cell: cell, data: data, extent: (n-1)*cell };
}
function hAt(x, y) {                                       // bilinear, world meters
  if (!HF) return 0;
  var g = HF, fx = Math.min(Math.max(x/g.cell, 0), g.n-1.001), fy = Math.min(Math.max(y/g.cell, 0), g.n-1.001);
  var x0 = fx|0, y0 = fy|0, tx = fx-x0, ty = fy-y0, d = g.data, n = g.n;
  var a = d[y0*n+x0], b = d[y0*n+x0+1], c = d[(y0+1)*n+x0], e = d[(y0+1)*n+x0+1];
  return (a*(1-tx)+b*tx)*(1-ty) + (c*(1-tx)+e*tx)*ty;
}

var terr = { vbo: null, ibo: null, ni: 0 };
function buildTerrain() {
  var uint32 = !!R.gl.getExtension("OES_element_index_uint");
  var stride = uint32 ? 1 : Math.max(1, Math.ceil((HF.n - 1) / 254)); // full res on hardware GL
  var n = ((HF.n - 1) / stride | 0) + 1, cell = HF.cell * stride;
  var vp = new Float32Array(n*n*6);
  for (var y = 0; y < n; y++) for (var x = 0; x < n; x++) {
    var wx2 = x*cell, wy2 = y*cell, h = HF.data[(y*stride)*HF.n + x*stride];
    var hx1 = hAt(wx2+cell, wy2), hx0 = hAt(wx2-cell, wy2), hy1 = hAt(wx2, wy2+cell), hy0 = hAt(wx2, wy2-cell);
    var nx = (hx0-hx1)/(2*cell), nz2 = (hy1-hy0)/(2*cell); // gl z = -world y
    var il = 1/Math.hypot(nx, 1, nz2);
    var i = (y*n+x)*6;
    vp[i]=wx2; vp[i+1]=h; vp[i+2]=-wy2; vp[i+3]=nx*il; vp[i+4]=il; vp[i+5]=nz2*il;
  }
  var IArr = (n*n > 65535) ? Uint32Array : Uint16Array;
  var idx = new IArr((n-1)*(n-1)*6), k = 0;
  for (var y = 0; y < n-1; y++) for (var x = 0; x < n-1; x++) {
    var a = y*n+x, b = a+1, c = a+n, d2 = c+1;
    idx[k++]=a; idx[k++]=b; idx[k++]=c; idx[k++]=b; idx[k++]=d2; idx[k++]=c;   // CCW after gz=-worldY flip
  }
  terr.vbo = R.gl.createBuffer(); R.gl.bindBuffer(R.gl.ARRAY_BUFFER, terr.vbo); R.gl.bufferData(R.gl.ARRAY_BUFFER, vp, R.gl.STATIC_DRAW);
  terr.ibo = R.gl.createBuffer(); R.gl.bindBuffer(R.gl.ELEMENT_ARRAY_BUFFER, terr.ibo); R.gl.bufferData(R.gl.ELEMENT_ARRAY_BUFFER, idx, R.gl.STATIC_DRAW);
  terr.ni = k; terr.grid = n;
  terr.itype = idx.BYTES_PER_ELEMENT === 4 ? R.gl.UNSIGNED_INT : R.gl.UNSIGNED_SHORT;
}
var water = { vbo: null };
function buildWater() {
  var m = 2600, a = -m, b = MAP_M + m, y = -0.2;
  var v = new Float32Array([a,y,-a, b,y,-a, a,y,-b, b,y,-a, b,y,-b, a,y,-b]);
  water.vbo = R.gl.createBuffer(); R.gl.bindBuffer(R.gl.ARRAY_BUFFER, water.vbo); R.gl.bufferData(R.gl.ARRAY_BUFFER, v, R.gl.STATIC_DRAW);
}

/* ==== buffer helpers (also used by the screen's own holograms) ============ */
function glBuf(a) { var b = R.gl.createBuffer(); R.gl.bindBuffer(R.gl.ARRAY_BUFFER, b); R.gl.bufferData(R.gl.ARRAY_BUFFER, a, R.gl.STATIC_DRAW); return b; }
function glIbuf(a) { var b = R.gl.createBuffer(); R.gl.bindBuffer(R.gl.ELEMENT_ARRAY_BUFFER, b); R.gl.bufferData(R.gl.ELEMENT_ARRAY_BUFFER, a, R.gl.STATIC_DRAW); return b; }

/* ==== satellite atlases ==================================================== */
var A128 = { px: 128, cells: 13, size: 1664, tex: null, cv: null, g: null };
var DET_PX = 256;   // 512 → 6656² NPOT silently sampled black on real hw; 3328² is the verified ceiling
var A256 = { px: DET_PX, cells: 13, size: 13*DET_PX, tex: null, cv: null, g: null };
function initAtlas(A) {
  for (;;) {
    A.size = A.cells * A.px;
    A.cv = document.createElement("canvas"); A.cv.width = A.cv.height = A.size;
    A.g = A.cv.getContext("2d"); A.g.fillStyle = "#08120d"; A.g.fillRect(0, 0, A.size, A.size);
    A.tex = R.gl.createTexture(); R.gl.bindTexture(R.gl.TEXTURE_2D, A.tex);
    R.gl.getError();                                    // clear stale flags
    R.gl.texImage2D(R.gl.TEXTURE_2D, 0, R.gl.RGB, R.gl.RGB, R.gl.UNSIGNED_BYTE, A.cv);
    if (R.gl.getError() === 0 || A.px <= 128) break;    // silent-OOM guard: halve and retry
    R.gl.deleteTexture(A.tex); A.px >>= 1;
  }
  R.gl.texParameteri(R.gl.TEXTURE_2D, R.gl.TEXTURE_WRAP_S, R.gl.CLAMP_TO_EDGE);
  R.gl.texParameteri(R.gl.TEXTURE_2D, R.gl.TEXTURE_WRAP_T, R.gl.CLAMP_TO_EDGE);
  R.gl.texParameteri(R.gl.TEXTURE_2D, R.gl.TEXTURE_MAG_FILTER, R.gl.LINEAR);
  R.gl.texParameteri(R.gl.TEXTURE_2D, R.gl.TEXTURE_MIN_FILTER, R.gl.LINEAR);   // NPOT: never mip
}
/* HERO WINDOW. The sat tiles ship at 1024x1024 native (measured out of
   map_malden's PAAs: full mip chain 1024 down to 8), but a 13x13 atlas of them
   would be 13312 square -- the 512 attempt already proved a giant NPOT atlas
   allocates "fine" and then samples black. So the close-up detail lives in a
   SMALL POT texture instead: a 3x3 window of native tiles that follows the
   camera. 1.03 m/texel inside it against 4.1 in the 256 atlas.
   The atlas stays underneath and the window cross-fades at its edge, so a
   missing or still-loading window is never a hole -- just less detail. */
var HERO = { cells: 3, px: 1024, size: 3072, tex: null, cv: null, g: null,
             c0: -99, r0: -99, have: 0, mix: 0 };
var HERO_MPP = 6;          // only worth its bandwidth once a pixel is a few metres
function initHero() {
  for (;;) {
    HERO.size = HERO.cells * HERO.px;
    HERO.cv = document.createElement("canvas"); HERO.cv.width = HERO.cv.height = HERO.size;
    HERO.g = HERO.cv.getContext("2d");
    HERO.g.fillStyle = "#08120d"; HERO.g.fillRect(0, 0, HERO.size, HERO.size);
    HERO.tex = R.gl.createTexture(); R.gl.bindTexture(R.gl.TEXTURE_2D, HERO.tex);
    R.gl.getError();
    R.gl.texImage2D(R.gl.TEXTURE_2D, 0, R.gl.RGB, R.gl.RGB, R.gl.UNSIGNED_BYTE, HERO.cv);
    // same silent-OOM guard the atlases use: halve until an allocation verifies
    if (R.gl.getError() === 0 || HERO.px <= 256) break;
    R.gl.deleteTexture(HERO.tex); HERO.px >>= 1;
  }
  R.gl.texParameteri(R.gl.TEXTURE_2D, R.gl.TEXTURE_WRAP_S, R.gl.CLAMP_TO_EDGE);
  R.gl.texParameteri(R.gl.TEXTURE_2D, R.gl.TEXTURE_WRAP_T, R.gl.CLAMP_TO_EDGE);
  R.gl.texParameteri(R.gl.TEXTURE_2D, R.gl.TEXTURE_MAG_FILTER, R.gl.LINEAR);
  R.gl.texParameteri(R.gl.TEXTURE_2D, R.gl.TEXTURE_MIN_FILTER, R.gl.LINEAR);
}
function heroSeed(c, r) {
  /* Fill a freshly-moved window cell from whatever the atlases already hold, so
     the window is never blank while its native tiles are in flight. */
  var A = tilesHave[c+"_"+r+"_256"] ? A256 : A128;
  var dx = (c - HERO.c0) * HERO.px, dy = (r - HERO.r0) * HERO.px;
  HERO.g.drawImage(A.cv, c*A.px, r*A.px, A.px, A.px, dx, dy, HERO.px, HERO.px);
}
function heroUpload(cell) {
  /* Whole-texture upload only when the window MOVES (every cell changed); a
     single arriving tile sub-uploads its own cell -- a 3072² re-upload per tile
     would push ~28 MB nine times over for one window. */
  R.gl.bindTexture(R.gl.TEXTURE_2D, HERO.tex);
  if (!cell) { R.gl.texImage2D(R.gl.TEXTURE_2D, 0, R.gl.RGB, R.gl.RGB, R.gl.UNSIGNED_BYTE, HERO.cv); return; }
  var s = heroUpload._s || (heroUpload._s = document.createElement("canvas"));
  if (s.width !== HERO.px) { s.width = s.height = HERO.px; }
  s.getContext("2d").drawImage(HERO.cv, cell[0]*HERO.px, cell[1]*HERO.px, HERO.px, HERO.px,
                               0, 0, HERO.px, HERO.px);
  R.gl.texSubImage2D(R.gl.TEXTURE_2D, 0, cell[0]*HERO.px, cell[1]*HERO.px, R.gl.RGB, R.gl.UNSIGNED_BYTE, s);
}
function updateHero(mpp, cx, cy) {
  if (!HERO.tex) return;                  // instance built without a hero window
  if (mpp > HERO_MPP) { HERO.mix = 0; return; }
  var n = HERO.cells, half = (n - 1) / 2;
  var cc = Math.floor(cx / SPAN), cr = Math.floor((MAP_M - cy) / SPAN);
  var c0 = Math.max(0, Math.min(GRID - n, cc - half));
  var r0 = Math.max(0, Math.min(GRID - n, cr - half));
  if (c0 !== HERO.c0 || r0 !== HERO.r0) {
    HERO.c0 = c0; HERO.r0 = r0; HERO.have = 0;
    HERO.g.fillStyle = "#08120d"; HERO.g.fillRect(0, 0, HERO.size, HERO.size);
    for (var i = 0; i < n; i++) for (var j = 0; j < n; j++) heroSeed(c0+i, r0+j);
    heroUpload();
  }
  HERO.mix = 1;
  for (var a2 = 0; a2 < n; a2++) for (var b2 = 0; b2 < n; b2++) {
    var c = HERO.c0 + a2, r = HERO.r0 + b2;
    var tcx2 = c*SPAN + SPAN/2, tcy2 = MAP_M - r*SPAN - SPAN/2;
    wantTile(c, r, HERO.px, Math.hypot(tcx2-cx, tcy2-cy) - 20000);
  }
}
var tilesHave = {}, tilesPend = {}, tQueue = [], tFlight = 0, MAXFLIGHT = 6, gotOne = false;
var tFirstAt = {};                     // first tile seen per resolution tier
function pad3(n) { return ("00"+n).slice(-3); }
/* The PAA's own column/row for page cell (c, r). Both the engine request and
   the composed atlas are indexed by THIS pair, not by (c, r): tilePath asks for
   s_AAA_BBB and bake_sat_atlas.py puts s_CCC_RRR at pixel (C*px, R*px), so an
   atlas square and a RequestTexture reply are the same image and land in the
   same cell. Written once, read by both, so SWAP_XY cannot mean two things. */
function tileAB(c, r) { return SWAP_XY ? [r, c] : [c, r]; }
function tilePath(c, r) { var ab = tileAB(c, r);
  return "a3\\map_malden\\data\\layers\\s_"+pad3(ab[0])+"_"+pad3(ab[1])+"_lco.paa"; }
/* One tile reached a surface. Kept in one place so the engine path, the
   embedded-thumbnail path and the composed atlas all raise the same signals in
   the same order -- onFirstTile first, exactly as it always fired. */
function tileLanded(res) {
  if (!gotOne) { gotOne = true; R.onFirstTile(); }
  if (!tFirstAt[res]) { tFirstAt[res] = 1; R.onFirstTileAt(res); }
}
function wantTile(c, r, res, prio) {
  /* An instance that did not build the surface a resolution lands on must not
     fetch it: the pixels have nowhere to go, and blitTile would throw on a null
     2D context rather than doing nothing. Silently dropping the want is right --
     the 128 atlas always exists, so there is always something to draw. */
  if (res >= 512 && !HERO.tex) return;
  if (res >= 256 && res < 512 && !A256.tex) return;
  var key = c+"_"+r+"_"+res;
  if (tilesHave[key] || tilesPend[key]) return;
  tilesPend[key] = 1; tQueue.push([c, r, res, key, prio]);
}
function pumpTiles() {
  if (!tQueue.length) return;
  tQueue.sort(function (a, b) { return a[4]-b[4]; });
  while (tFlight < MAXFLIGHT && tQueue.length) {
    (function (q) {
      var c = q[0], r = q[1], res = q[2], key = q[3];
      /* Embedded thumbnails. window.EMB is an OPTIONAL host-page global --
         this module never defines it and only ever reads it. tools/embed_map_thumbs.py
         bakes it into ui/html/map.html (the generator's target, not this file);
         when it is present, a 128 request is answered from the page itself,
         same blit path, zero engine round-trips -- the island is textured the
         moment the page runs. A consumer with no window.EMB (hud.html today)
         just falls through to the engine fetch below: no instant first paint,
         no error, no other behaviour change. The engine still serves 256/512
         as the camera closes in either way. */
      if (res === 128 && window.EMB && EMB[c + "_" + r]) {
        var eimg = new Image();
        eimg.onload = function () {
          tilesHave[key] = 1; delete tilesPend[key];
          blitTile(eimg, c, r, res);
          tileLanded(res);
          R.onDirty();
        };
        eimg.src = EMB[c + "_" + r];
        return;
      }
      tFlight++;
      A3API.RequestTexture(tilePath(c, r), res).then(function (durl) {
        var img = new Image();
        img.onload = function () {
          tilesHave[key] = 1; delete tilesPend[key]; tFlight--;
          blitTile(img, c, r, res);
          tileLanded(res);
          R.onDirty(); pumpTiles();
        };
        img.onerror = function () { delete tilesPend[key]; tFlight--; pumpTiles(); };
        img.src = durl;
      }).catch(function () { delete tilesPend[key]; tFlight--; pumpTiles(); });
    })(tQueue.shift());
  }
}
/* THE PLACEMENT RULE, and the only copy of it. Crop the satellite layer's
   per-edge overlap -- 16 px at the 512 mip, scaled to whatever mip this source
   square is -- and stretch what is left over cell (c, r) of atlas A.
   `sx, sy, sw` describe the source square inside `img`: (0, 0, img.width) for a
   tile that arrived on its own, (a*sp, b*sp, sp) for one sliced out of the
   composed atlas. Both paths go through here so they cannot drift apart. */
function drawCell(img, sx, sy, sw, A, c, r) {
  var sc = sw / TILE_PX, ov = OV_PX * sc, iw = sw - 2*ov;
  A.g.drawImage(img, sx+ov, sy+ov, iw, iw, c*A.px, r*A.px, A.px, A.px);
}
function blitTile(img, c, r, res) {
  // crop the 16px-per-edge overlap (scaled to this mip) so atlas cells tile seamlessly
  var sc = img.width / TILE_PX, ov = OV_PX * sc, iw = img.width - 2*ov;
  if (res >= 512) {
    /* Native-resolution tile: it belongs to the hero window, and only while that
       window still covers this cell -- the camera may have moved on while the
       request was in flight, in which case the pixels are simply dropped. */
    var hc = c - HERO.c0, hr = r - HERO.r0;
    if (hc >= 0 && hr >= 0 && hc < HERO.cells && hr < HERO.cells) {
      HERO.g.drawImage(img, ov, ov, iw, iw, hc*HERO.px, hr*HERO.px, HERO.px, HERO.px);
      HERO.have++;
      heroUpload([hc, hr]);
    }
    return;
  }
  var A = res >= 256 ? A256 : A128;
  drawCell(img, 0, 0, img.width, A, c, r);
  R.gl.bindTexture(R.gl.TEXTURE_2D, A.tex);
  // sub-upload one cell via a scratch canvas (texSubImage2D from canvas region)
  var s = blitTile._s || (blitTile._s = document.createElement("canvas"));
  if (s.width !== A.px) { s.width = s.height = A.px; }
  s.getContext("2d").drawImage(A.cv, c*A.px, r*A.px, A.px, A.px, 0, 0, A.px, A.px);
  R.gl.texSubImage2D(R.gl.TEXTURE_2D, 0, c*A.px, r*A.px, R.gl.RGB, R.gl.UNSIGNED_BYTE, s);
  // 128 arriving before 256: pre-fill the 256 cell so the close atlas never has holes
  if (res === 128 && A256.g && !tilesHave[c+"_"+r+"_256"]) {
    drawCell(img, 0, 0, img.width, A256, c, r);
    R.gl.bindTexture(R.gl.TEXTURE_2D, A256.tex);
    var s2 = blitTile._s2 || (blitTile._s2 = document.createElement("canvas"));
    if (s2.width !== A256.px) { s2.width = s2.height = A256.px; }
    s2.getContext("2d").drawImage(A256.cv, c*A256.px, r*A256.px, A256.px, A256.px, 0, 0, A256.px, A256.px);
    R.gl.texSubImage2D(R.gl.TEXTURE_2D, 0, c*A256.px, r*A256.px, R.gl.RGB, R.gl.UNSIGNED_BYTE, s2);
  }
}

/* ==== the pre-composed satellite atlases ===================================
   ONE fetch and ONE decode per tier instead of 169 engine round trips.

   WHY. Measured 2026-09-08 on a real client with [MAPTIME], on the build that
   had already taken the parses off the critical path: a cold open settled at
   3537 ms, of which ~3.3 s was 245 A3API.RequestTexture round trips at ~13 ms
   each -- 169 at the 128 tier and 76 at 256. The second open cost the same,
   because the dialog is destroyed on close and the engine caches nothing across
   dialogs. tools/bake_sat_atlas.py bakes each tier into a single image shipped
   as ui/html/malden_sat<px>.txt -- a `data:` URL, because A3API.RequestFile
   returns TEXT and the string goes straight to an Image.src.

   LAYOUT AND ORIENTATION, which is the part that can silently be wrong. The
   baker puts tile s_CCC_RRR_lco.paa -- the PAA's OWN column and row -- at pixel
   (C*px, R*px) and bakes nothing about how this page lays the island out. The
   per-tile path asks tilePath(c, r) for s_AAA_BBB and then places the reply in
   cell (c, r); so the atlas square for cell (c, r) is at (a*sp, b*sp) with the
   SAME (a, b) tilePath computes -- which is why both call tileAB() rather than
   either one assuming SWAP_XY is false. The crop matches too: drawCell takes
   the layer overlap off any source square at its own mip, and an atlas square
   IS the tile at that mip, exactly what RequestTexture(path, px) hands back.
   Net: identity mapping for today's SWAP_XY = false, and still correct if it
   ever flips, with no row flip anywhere -- atlas row 0 is north and is blitted
   to canvas row 0, the same convention drawTerrain's uHeroRect comment records.

   ONE UPLOAD, NOT 169. blitTile sub-uploads each cell out of A.cv right after
   drawing it. The 169 cells tile A.cv exactly (13 * A.px == A.size, by
   construction in initAtlas), so after 169 of those every texel of the texture
   equals A.cv -- which is what a single texImage2D of A.cv does, from the same
   canvas under the same unpack state (neither this module nor either page calls
   pixelStorei, so UNPACK_FLIP_Y and UNPACK_PREMULTIPLY_ALPHA are at their false
   defaults for every upload either path makes; initAtlas already uploads the
   whole canvas and blitTile already sub-uploads regions of it, and the two have
   always agreed). Same pixels, one call.

   FAILS LOUDLY, AND THE CALLER FALLS BACK. The owner intends to replace the
   source PNG with a stylized one and re-run `encode`, so a drop-in of the wrong
   size is a thing that will happen; it must not be stretched silently over the
   island. Empty text, something that is not a data: image URL, a decode error,
   or any size that is not 13 cells of `res` REJECTS with a named reason, also
   parked on window.__apSatAtlasErr because the console is unreachable in game
   (Esc closes the dialog). Nothing is drawn and nothing is marked present on a
   rejection, so the caller's per-tile path takes over unchanged. */
function loadAtlas(res, text) {
  return new Promise(function (resolve, reject) {
    function fail(why) {
      why = "sat atlas " + res + ": " + why;
      try { window.__apSatAtlasErr = why; } catch (e) {}
      reject(new Error(why));
    }
    var A = res >= 256 ? A256 : A128;
    if (!A || !A.g) return fail("this instance has no such atlas (initAtlases first)");
    var src = (text == null ? "" : String(text)).trim();     // the asset ships with a trailing newline
    if (!src) return fail("empty");
    if (src.slice(0, 11) !== "data:image/") return fail("not a data: image URL");
    var img = new Image();
    img.onerror = function () { fail("decode failed"); };
    img.onload = function () {
      var want = GRID * res;
      if (img.naturalWidth !== want || img.naturalHeight !== want) {
        return fail(img.naturalWidth + "x" + img.naturalHeight + ", expected " +
                    want + "x" + want + " (" + GRID + " cells of " + res + ")");
      }
      var sp = want / GRID;                     // one baked square, in atlas pixels
      for (var r = 0; r < GRID; r++) for (var c = 0; c < GRID; c++) {
        var ab = tileAB(c, r);
        drawCell(img, ab[0]*sp, ab[1]*sp, sp, A, c, r);
        tilesHave[c+"_"+r+"_"+res] = 1;         // so wantTile never asks the engine for it
        /* The same pre-fill blitTile does for an arriving 128: give the close
           atlas something rather than a hole, and never over a real 256. Wasted
           work if the 256 atlas lands next, and the whole difference between a
           holed close view and a soft one if it does not. */
        if (res === 128 && A256.g && !tilesHave[c+"_"+r+"_256"]) drawCell(img, ab[0]*sp, ab[1]*sp, sp, A256, c, r);
      }
      R.gl.bindTexture(R.gl.TEXTURE_2D, A.tex);
      R.gl.texImage2D(R.gl.TEXTURE_2D, 0, R.gl.RGB, R.gl.RGB, R.gl.UNSIGNED_BYTE, A.cv);
      if (res === 128 && A256.tex) {
        R.gl.bindTexture(R.gl.TEXTURE_2D, A256.tex);
        R.gl.texImage2D(R.gl.TEXTURE_2D, 0, R.gl.RGB, R.gl.RGB, R.gl.UNSIGNED_BYTE, A256.cv);
      }
      tileLanded(res);
      R.onDirty();
      resolve(GRID * GRID);
    };
    img.src = src;
  });
}

/* the rebel outpost destroyer's box rows are dropped in parseRows and
   drawn as a hologram by whichever screen wants one. */
var SHIP = { x: 9005.09, y: 5923.77, dir: 0, scale: 0.45 };
/* ==== buildings ============================================================ */
var SEC = 8, sectors = null, sectorsM = null, sectorsF = null, bldCount = 0;
var KIND_COL = [ [0.13,0.17,0.15], [0.19,0.17,0.13], [0.15,0.18,0.19], [0.19,0.16,0.20], [0.28,0.34,0.16], [0.16,0.19,0.16] ];  // 5 = fence/wall
/* Mesh library (malden_msh.txt): per model id, the real building's own coarsest
   LOD as verts (cm ints, model frame: east/north/up, plan-centred, floor at 0)
   + tris with an rgb444 color ("-" = use the kind color). Absent or unparsable
   => MESHLIB stays null and every row renders as a box, exactly as before. */
var MESHLIB = null;
/* CHUNKED (see pump). ~1.0 s of blocked main thread on a real client before
   this was sliced, for 3.0 MB and 502 models. The loop body is the original
   one; the only change is that `i` advances explicitly instead of through a
   for-header, because a grain has to be able to stop between models. The three
   old exits map straight across: skip a non-header line (i+1), reject a bad
   count (i+3, the header plus its two payload lines), reject a payload whose
   length disagrees with the header (i+1, so the two payload lines are rescanned
   as potential headers exactly as before). */
function parseMeshLib(txt) {
  var lines = txt.split("\n"), lib = {}, n = 0, i = 0;
  return pump(function () {
    for (var g = 0; g < 8 && i < lines.length; g++) {
      if (lines[i][0] !== "M" || lines[i][1] !== " ") { i++; continue; }
      var h = lines[i].split(" "), mid = h[1]|0, nv = h[2]|0, nf = h[3]|0;
      if (!(nv > 0) || !(nf > 0)) { i += 3; continue; }
      var vt = (lines[i+1]||"").split(" "), ft = (lines[i+2]||"").split(" ");
      if (vt.length !== nv || ft.length !== nf || !nv || !nf) { i++; continue; }
      var v = new Float32Array(nv*3);
      for (var k = 0; k < nv; k++) { var p = vt[k].split(",");
        v[k*3] = p[0]/100; v[k*3+1] = p[1]/100; v[k*3+2] = p[2]/100; }
      var f = new Int32Array(nf*4);
      for (var k2 = 0; k2 < nf; k2++) { var q = ft[k2].split(",");
        f[k2*4] = +q[0]; f[k2*4+1] = +q[1]; f[k2*4+2] = +q[2];
        f[k2*4+3] = q[3] === "-" ? -1 : parseInt(q[3], 16); }
      lib[mid] = { v: v, f: f, tris: nf };
      n++; i += 3;
    }
    return i >= lines.length;
  }).then(function () { return n ? lib : null; });
}
function bucketize(rows) {
  var secW = MAP_M / SEC, buckets = [];
  for (var s = 0; s < SEC*SEC; s++) buckets.push([]);
  rows.forEach(function (b) {
    var sx2 = Math.min(SEC-1, Math.max(0, b[0]/secW|0)), sy2 = Math.min(SEC-1, Math.max(0, b[1]/secW|0));
    buckets[sy2*SEC+sx2].push(b);
  });
  return buckets;
}
/* THE PARSED ROWS ARE KEPT. The mesh library is fetched AFTER the opening view
   has settled (map.html's boot chain), so the sectors are built once from boxes
   and then rebuilt in place when the library lands. Keeping the rows -- rather
   than the 685 KB of text, or re-fetching -- is what makes the rebuild cheap
   and, more importantly, makes it produce the SAME sectors: bucketize() is
   order-sensitive within a bucket, so a re-split of the same array in the same
   order is byte-identical to the all-at-once build it replaced. */
var bldRows = null, fenRows = null;
/* CHUNKED (see pump). 17287 rows, ~0.77 s of blocked main thread on a real
   client when this was one file and one loop. */
function parseRows(txt) {
  var lines = txt.split("\n"), rows = [], i = 0;
  return pump(function () {
    var end = Math.min(lines.length, i + 256);
    for (; i < end; i++) { var L = lines[i].trim();
      if (!L || L[0] === "#") continue;
      var p = L.split(","); if (p.length < 7) continue;
      /* 8th column (bake v2): ABSOLUTE base altitude for structures the terrain
         knows nothing about -- bridges. -999 (or absent) means sit on the
         heightfield like everything else. 9th column (bake v3): mesh id into
         malden_msh.txt, -1 = no mesh (box). */
      var bx = +p[0], by = +p[1];
      /* The rebel outpost destroyer baked as two huge kind-4 boxes. It renders as
         a holographic ship model instead (drawShipHolo), so its box rows are
         dropped here rather than drawn twice. */
      if (Math.hypot(bx - SHIP.x, by - SHIP.y) < 140 && (p[6]|0) === 4 && (+p[3] > 40 || +p[4] > 40)) continue;
      rows.push([bx, by, +p[2], +p[3], +p[4], +p[5], Math.min(5, Math.max(0, p[6]|0)),
                 p.length > 7 ? +p[7] : -999,
                 // a blank or non-numeric mid must fall back to the BOX (-1);
                 // `p[8]|0` would coerce it to 0, a valid mesh id (castle bastion)
                 (p.length > 8 && /^-?\d+$/.test(p[8])) ? (p[8]|0) : -1]);
    }
    return i >= lines.length;
  }).then(function () { return rows; });
}
/* Rows -> sector sets, and the ONLY place that decision is made, so a late feed
   re-runs exactly the build the first pass did. Frees what it is replacing
   first: on a rebuild the old sectors' GL buffers are otherwise orphaned in a
   webview whose only recovery from a lost context is a full reload. */
function splitBuild() {
  freeSectors();
  /* Whose build is this. freeSectors() bumps the counter, so a rebuild -- or a
     dispose -- started while an earlier one is still slicing makes every one of
     that earlier build's remaining grains a no-op instead of pushing sectors
     into an array nobody owns any more and leaking their GL buffers. */
  var gen = buildGen;
  /* bld ++ fen, in that order, is the row sequence -- and it is a CONTRACT, not
     an implementation detail. malden_fen.txt is the kind-5 rows lifted out of
     malden_bld.txt, and bucketize() is order-sensitive within a bucket, so the
     concatenation order decides how the mesh chunks pack and how the box VBOs
     are laid out. Fix it here, once, and the picture is the same whether the
     fences arrived with the buildings or ten seconds later. */
  var rows = fenRows && fenRows.length ? bldRows.concat(fenRows) : (bldRows || []);
  bldCount = rows.length;
  /* kind 5 (fence/wall) exists only in the close tier -- zoomed out, thousands
     of fence footprints are noise. Meshless fences get their own box sectors
     (sectorsF, drawn under 10 m/px on their own draw cap so they cannot starve
     buildings); meshed ones ride sectorsM, whose box counterpart drops them
     above 10 m/px. */
  var plain = [], meshed = [], fenceBox = [];
  rows.forEach(function (b) {
    var hasMesh = MESHLIB && b[8] >= 0 && MESHLIB[b[8]];
    if (hasMesh) meshed.push(b);
    else if (b[6] === 5) fenceBox.push(b);
    else plain.push(b);
  });
  /* The arrays exist NOW and fill in slice by slice, so the draw passes have
     something to iterate from the first frame and the island appears as it is
     built rather than in one lump at the end. Empty-vs-null matches what the
     all-at-once version returned: box sectors were always an array, the other
     two were null when they had no rows. */
  sectors = [];
  sectorsF = fenceBox.length ? [] : null;
  /* Every mesh sector keeps its rows and lazily grows a BOX counterpart, so a
     sector the mesh pass skips (tri budget, or not built yet this frame) still
     renders as boxes instead of vanishing. */
  sectorsM = meshed.length ? [] : null;
  /* Captured, not re-read: by the time these continuations run the module vars
     may already belong to a newer build. The generation check inside each
     buildXInto is what actually stops the old work, but a stale array reference
     is the kind of thing that only shows up as sectors appearing on the wrong
     island, so it does not get to exist. */
  var secBox = sectors, secFen = sectorsF, secMesh = sectorsM;
  return buildBoxInto(secBox, plain, gen)
    .then(function () { return secFen ? buildBoxInto(secFen, fenceBox, gen) : null; })
    .then(function () { return secMesh ? buildMeshInto(secMesh, meshed, gen) : null; });
}
/* Every GL buffer the three sector sets own. Buffers handed out by glBuf/glIbuf
   belong to whoever asked for them and are NOT freed here -- same rule as
   dispose(), which is the other caller. */
function freeBox(s) { if (!s) return;
  if (s.vbo) R.gl.deleteBuffer(s.vbo); if (s.ibo) R.gl.deleteBuffer(s.ibo); }
var buildGen = 0;
function freeSectors() {
  buildGen++;
  [sectors, sectorsF].forEach(function (list) { if (list) list.forEach(freeBox); });
  if (sectorsM) sectorsM.forEach(function (s) {
    if (s.chunks) s.chunks.forEach(function (c) { R.gl.deleteBuffer(c.vbo); R.gl.deleteBuffer(c.ibo); });
    s.chunks = null;
    freeBox(s.boxNF); freeBox(s.boxAll); s.boxNF = undefined; s.boxAll = undefined;
  });
  sectors = null; sectorsM = null; sectorsF = null;
  /* builtSecs holds references to the sector objects just freed, and builtTris
     is the budget those references are accounted against. Left standing, the
     next evictMeshSectors() walks dead sectors and the tri budget starts the
     new sector set already spent. */
  builtSecs = []; builtTris = 0;
}
function boxCounterpart(sec, withFences) {
  var key = withFences ? "boxAll" : "boxNF";
  if (sec[key] === undefined) {
    var list = withFences ? sec.list : sec.list.filter(function (b) { return b[6] !== 5; });
    /* ONE bucket in, one out -- and it must stay synchronous: this is called
       from inside a draw pass, for a sector the mesh budget just declined, and
       a promise here would mean that sector renders as nothing for a frame. It
       is one bucket's worth of work, never the island's, because sec.list came
       out of bucketize() already. */
    sec[key] = list.length ? buildBoxBucket(list) : null;
  }
  return sec[key];
}
/* ONE bucket -> one box sector. Split out of the old buildBoxSectors so the
   island can be built a bucket at a time (see buildBoxInto); the body below is
   that function's forEach verbatim. */
function buildBoxBucket(list) {
    var nv = list.length*20, vp = new Float32Array(nv*9), idx = new Uint16Array(list.length*30);
    var vi = 0, ii = 0, minx = 1e9, maxx = -1e9, miny = 1e9, maxy = -1e9, maxh = 0;
    list.forEach(function (b) {
      var x = b[0], y = b[1], a = b[2]*Math.PI/180, hx = b[3]/2, hy = b[4]/2, hgt = b[5], kind = b[6];
      var ca = Math.cos(a), sa = Math.sin(a);
      var base = (b[7] > -900 ? b[7] : hAt(x, y)) - 1.2, top = base + hgt + 1.2;
      if (x-hx < minx) minx = x-hx; if (x+hx > maxx) maxx = x+hx;
      if (y-hy < miny) miny = y-hy; if (y+hy > maxy) maxy = y+hy;
      if (top > maxh) maxh = top;
      // corners CCW seen from above (local +y = facing dir, CW-from-north rotation)
      var cs = [[-hx,-hy],[hx,-hy],[hx,hy],[-hx,hy]].map(function (c) {
        return [x + c[0]*ca + c[1]*sa, y - c[0]*sa + c[1]*ca];
      });
      var v0 = vi/9|0;
      function put(px, py, up, nx, nz, kk) {
        vp[vi++]=px; vp[vi++]=-py; vp[vi++]=base; vp[vi++]=top; vp[vi++]=up;
        vp[vi++]=nx; vp[vi++]=0.15; vp[vi++]=nz; vi++; vp[vi-1]=kk;
      }
      for (var e = 0; e < 4; e++) {           // walls: 4 edges × (b0,b1,t1,t0)
        var p0 = cs[e], p1 = cs[(e+1)%4];
        var ex = p1[0]-p0[0], ey = p1[1]-p0[1], el = Math.hypot(ex, ey)||1;
        var nx = ey/el, nz = ex/el;           // outward in gl space (z=-y)
        put(p0[0], p0[1], 0, nx, nz, kind); put(p1[0], p1[1], 0, nx, nz, kind);
        put(p1[0], p1[1], 1, nx, nz, kind); put(p0[0], p0[1], 1, nx, nz, kind);
        var q = v0 + e*4;
        idx[ii++]=q; idx[ii++]=q+1; idx[ii++]=q+2; idx[ii++]=q; idx[ii++]=q+2; idx[ii++]=q+3;
      }
      var rq = v0 + 16;                       // roof
      for (var e2 = 0; e2 < 4; e2++) put(cs[e2][0], cs[e2][1], 1, 0, 0, kind);
      // roof normal fix: overwrite ny for the 4 roof verts
      for (var rv = 0; rv < 4; rv++) vp[(rq+rv)*9+6] = 1.0;
      idx[ii++]=rq; idx[ii++]=rq+1; idx[ii++]=rq+2; idx[ii++]=rq; idx[ii++]=rq+2; idx[ii++]=rq+3;
    });
    var vbo = R.gl.createBuffer(); R.gl.bindBuffer(R.gl.ARRAY_BUFFER, vbo); R.gl.bufferData(R.gl.ARRAY_BUFFER, vp, R.gl.STATIC_DRAW);
    var ibo = R.gl.createBuffer(); R.gl.bindBuffer(R.gl.ELEMENT_ARRAY_BUFFER, ibo); R.gl.bufferData(R.gl.ELEMENT_ARRAY_BUFFER, idx, R.gl.STATIC_DRAW);
    return { vbo: vbo, ibo: ibo, ni: ii, count: list.length,
      cx: (minx+maxx)/2, cy: (miny+maxy)/2, minx: minx, maxx: maxx, miny: miny, maxy: maxy, maxh: maxh };
}
/* Fill `out` a bucket at a time, yielding between them. `out` is the live array
   the module and the page are already holding, so a sector is drawable the
   moment it exists rather than when the last one does. Aborts silently if the
   sectors were freed under us (a second feed, or dispose) -- see buildGen. */
function buildBoxInto(out, rows, gen) {
  var bs = bucketize(rows), bi = 0;
  return pump(function () {
    if (gen !== buildGen) return true;
    while (bi < bs.length && !bs[bi].length) bi++;
    if (bi < bs.length) { out.push(buildBoxBucket(bs[bi])); bi++; }
    return bi >= bs.length;
  });
}
/* Descriptors only -- ~1.5M instance-transformed tris island-wide would cost
   seconds and tens of MB if materialized up front, so each sector's VBOs are
   built LAZILY on the first frame it enters draw range (buildMeshChunks), then
   cached. Bounds and tri counts come from the rows alone. */
function buildMeshBucket(list) {
    var minx = 1e9, maxx = -1e9, miny = 1e9, maxy = -1e9, maxh = 0, tris = 0;
    list.forEach(function (b) {
      if (b[0]-b[3]/2 < minx) minx = b[0]-b[3]/2; if (b[0]+b[3]/2 > maxx) maxx = b[0]+b[3]/2;
      if (b[1]-b[4]/2 < miny) miny = b[1]-b[4]/2; if (b[1]+b[4]/2 > maxy) maxy = b[1]+b[4]/2;
      var bs = (b[7] > -900 ? b[7] : hAt(b[0], b[1])) + b[5] + 1.2;
      if (bs > maxh) maxh = bs;
      tris += MESHLIB[b[8]].tris;
    });
    return { list: list, chunks: null, count: list.length, tris: tris,
      cx: (minx+maxx)/2, cy: (miny+maxy)/2, minx: minx, maxx: maxx, miny: miny, maxy: maxy, maxh: maxh };
}
function buildMeshInto(out, rows, gen) {
  var bs = bucketize(rows), bi = 0;
  return pump(function () {
    if (gen !== buildGen) return true;
    while (bi < bs.length && !bs[bi].length) bi++;
    if (bi < bs.length) { out.push(buildMeshBucket(bs[bi])); bi++; }
    return bi >= bs.length;
  });
}
function buildMeshChunks(sec) {
  /* One (or a few -- uint16 indices cap a chunk at 60k verts) interleaved
     VBO+IBO per sector: pos3, normal3, rgb3, kind1 = 10 floats. Verts are
     transformed at build time (built once, then cached on the sector), faces
     are flat-lit via a face normal oriented away from the building centre --
     culling is OFF for this pass, so orientation only matters for the lambert. */
  var chunks = [{ vp: [], idx: [] }];
  sec.list.forEach(function (b) {
      var m = MESHLIB[b[8]];
      var x = b[0], y = b[1], a = b[2]*Math.PI/180, kind = b[6], kc = KIND_COL[kind];
      var ca = Math.cos(a), sa = Math.sin(a);
      var base = (b[7] > -900 ? b[7] : hAt(x, y)) - 0.35;
      var nv = m.v.length/3, W = new Float32Array(nv*3);
      for (var v = 0; v < nv; v++) {
        var ex = m.v[v*3], nn = m.v[v*3+1], up = m.v[v*3+2];
        W[v*3] = x + ex*ca + nn*sa; W[v*3+1] = base + up; W[v*3+2] = -(y - ex*sa + nn*ca);
      }
      var ccx = x, ccy = base + b[5]*0.5, ccz = -y;
      var CH = chunks[chunks.length-1];
      if (CH.vp.length/10 + m.tris*3 > 60000) { CH = { vp: [], idx: [] }; chunks.push(CH); }
      var vmap = {};
      for (var f = 0; f < m.tris; f++) {
        var A = m.f[f*4], B = m.f[f*4+1], C = m.f[f*4+2], col = m.f[f*4+3];
        var cr, cg, cb;
        if (col < 0) { cr = kc[0]*1.12; cg = kc[1]*1.12; cb = kc[2]*1.12; }
        else { cr = ((col>>8)&15)/15; cg = ((col>>4)&15)/15; cb = (col&15)/15; }
        var ax=W[A*3], ay=W[A*3+1], az=W[A*3+2], bx=W[B*3], by=W[B*3+1], bz=W[B*3+2],
            cx=W[C*3], cy=W[C*3+1], cz=W[C*3+2];
        var ux=bx-ax, uy=by-ay, uz=bz-az, vx=cx-ax, vy=cy-ay, vz=cz-az;
        var nx=uy*vz-uz*vy, ny=uz*vx-ux*vz, nz=ux*vy-uy*vx;
        var nl = Math.sqrt(nx*nx+ny*ny+nz*nz)||1; nx/=nl; ny/=nl; nz/=nl;
        if (nx*((ax+bx+cx)/3-ccx) + ny*((ay+by+cy)/3-ccy) + nz*((az+bz+cz)/3-ccz) < 0) { nx=-nx; ny=-ny; nz=-nz; }
        var nq = (((nx*6)|0)+7)*225 + (((ny*6)|0)+7)*15 + (((nz*6)|0)+7);
        var vids = [A, B, C], ps = [ax,ay,az, bx,by,bz, cx,cy,cz];
        for (var e = 0; e < 3; e++) {
          var key = vids[e]+"|"+nq+"|"+col;
          var vi2 = vmap[key];
          if (vi2 === undefined) {
            vi2 = CH.vp.length/10; vmap[key] = vi2;
            CH.vp.push(ps[e*3], ps[e*3+1], ps[e*3+2], nx, ny, nz, cr, cg, cb, kind);
          }
          CH.idx.push(vi2);
        }
      }
    });
  sec.chunks = chunks.filter(function (c) { return c.idx.length; }).map(function (c) {
    var vbo = R.gl.createBuffer(); R.gl.bindBuffer(R.gl.ARRAY_BUFFER, vbo);
    R.gl.bufferData(R.gl.ARRAY_BUFFER, new Float32Array(c.vp), R.gl.STATIC_DRAW);
    var ibo = R.gl.createBuffer(); R.gl.bindBuffer(R.gl.ELEMENT_ARRAY_BUFFER, ibo);
    R.gl.bufferData(R.gl.ELEMENT_ARRAY_BUFFER, new Uint16Array(c.idx), R.gl.STATIC_DRAW);
    return { vbo: vbo, ibo: ibo, ni: c.idx.length };
  });
  // sec.list is KEPT: boxCounterpart() rebuilds boxes from it when this sector
  // is skipped by the tri budget or evicted under memory pressure.
  builtTris += sec.tris;
  builtSecs.push(sec);
}
/* Built mesh buffers are the page's largest allocation (~40 bytes/vertex). Panning
   the island at close zoom would otherwise materialize every sector permanently
   and risk a CEF context loss, whose only recovery here is a full reload. Evict
   the farthest built sectors when the budget is exceeded -- they rebuild on
   approach, and boxes cover them meanwhile. */
var builtTris = 0, builtSecs = [], BUILT_CAP = 900000;
function evictMeshSectors(cx, cy) {
  if (builtTris <= BUILT_CAP) return;
  builtSecs.sort(function (a, b) {
    return Math.hypot(b.cx-cx, b.cy-cy) - Math.hypot(a.cx-cx, a.cy-cy);
  });
  while (builtTris > BUILT_CAP * 0.8 && builtSecs.length > 1) {
    var s = builtSecs.shift();
    if (!s.chunks) continue;
    s.chunks.forEach(function (c) { R.gl.deleteBuffer(c.vbo); R.gl.deleteBuffer(c.ibo); });
    s.chunks = null; builtTris -= s.tris;
  }
}
/* ==== the module contract ================================================== */
R.mPersp = mPersp; R.mLook = mLook; R.mMul = mMul;
R.lighting = lighting;   // (hour, overcast, dist) -> {sun, amb, fogK}

/* A view-projection for a camera that sits somewhere and looks at somewhere
   else -- the whole of what a chase view needs, and the one thing the minimap
   wanted that Task 3's contract did not already have.

   ARGUMENTS ARE WORLD METRES AS TWO (x, y, altitude) TRIPLES: the eye, then the
   target. GL space here is (x, up, -y) -- see buildTerrain -- and doing that
   flip inside this function rather than at the call site is the difference
   between one place that knows the convention and two. (The brief for this
   drafted it as chaseVP(ex,ey,ez,...) with the caller shuffling arguments into
   GL order; that reads as a bug waiting to happen every time someone edits the
   call, and it duly bit during this very task -- the first version named the
   parameters eh/ch out of order from the call and the camera ended up looking
   at a point 8 km in the air, drawing a frame of pure clear colour with every
   draw call reporting success. Same shape for both triples, so a transposition
   is a transposition of like for like and not a silent type pun.)

   Up is +Y: a chase camera does not roll, and a caller that pointed it straight
   down would degenerate mLook's cross product -- which is why the minimap's
   pitch is a constant well short of vertical rather than something a payload
   can set. The scratch matrices are per-instance and reused, so a frame
   allocates nothing. */
var _cvP = new Float32Array(16), _cvV = new Float32Array(16), _cvVP = new Float32Array(16);
R.chaseVP = function (ex, ey, eAlt, tx, ty, tAlt, asp, fovy, near, far) {
  mPersp(_cvP, fovy || 50*Math.PI/180, asp, near || 4, far || 26000);
  mLook(_cvV, ex, eAlt, -ey, tx, tAlt, -ty, 0, 1, 0);
  return mMul(_cvVP, _cvP, _cvV);
};

/* R.setProjection(vp, w, h) / R.project(x, y, lift) -- a world point to a
   viewport pixel, for a consumer that positions its own DOM/2D-canvas
   overlay instead of drawing through GL. map.html's marker/label overlay is
   the original of this (projW, byte-for-byte the same formula below); the
   HUD minimap is the second consumer, and the reason it moved here rather
   than being copied -- Task 4 shipped the HUD's chase camera without it and
   left every blip positioned by a flat top-down offset that only happened to
   look right at the panel centre, wrong everywhere else and worse with
   distance. Same shape as the draw calls in spirit, different in mechanics
   because of the call pattern: drawTerrain/drawWater/drawBuildings run once
   a frame so taking VP as an argument costs nothing, but a screen calls
   project() once per marker -- so the VP and viewport it projects through
   are instance state, set with ONE call per frame (setProjection is a
   reference, not a copy: a page's own VP array can be mutated in place every
   frame and handed in once) rather than threaded through every call.

   Unset -- or a viewport of 0x0, which is what a WebGL context reports in
   the instant before a context-loss event lands -- project() returns null
   rather than dividing by zero or projecting through a stale matrix.

   project() returns null for the same reason projW did: the point is behind
   the camera (cw <= 0.01, the near-plane guard) or beyond the far plane
   (cz > cw). It does NOT clip to the viewport rectangle -- like projW, that
   is left to the caller, because map.html's overlay wants a few pixels of
   slack past the edge for labels that are only partly clipped, and a
   heading-up chase cam's caller (the HUD) has its own rim-clamp radius that
   is not the viewport edge either. A null return is not "off-screen", it is
   specifically "no screen position exists" -- callers that draw radar-style
   indicators for things behind the camera (the HUD does, for a heading-up
   view where "behind the player" is routine, not rare) need to detect this
   case and choose a substitute direction themselves; the module cannot know
   what a sane substitute is for a page it doesn't otherwise touch. */
var _pjVP = null, _pjW = 0, _pjH = 0;
R.setProjection = function (vp, w, h) { _pjVP = vp; _pjW = w; _pjH = h; };
R.project = function (x, y, lift) {
  if (!_pjVP || !_pjW || !_pjH) return null;
  var vp = _pjVP;
  var gx = x, gy = Math.max(hAt(x, y), 0) + (lift || 0), gz = -y;
  var cx = vp[0]*gx+vp[4]*gy+vp[8]*gz+vp[12], cy = vp[1]*gx+vp[5]*gy+vp[9]*gz+vp[13];
  var cw = vp[3]*gx+vp[7]*gy+vp[11]*gz+vp[15], cz = vp[2]*gx+vp[6]*gy+vp[10]*gz+vp[14];
  if (cw <= 0.01 || cz > cw) return null;
  return [ (cx/cw*0.5+0.5)*_pjW, (0.5-cy/cw*0.5)*_pjH ];
};
R.FOG = FOG;   // the horizon colour every screen clears to
R.sh = sh; R.prog = prog; R.glBuf = glBuf; R.glIbuf = glIbuf;
R.SHIP = SHIP;

R.loadHF = function (txt) { HF = parseHF(txt); R.hf = HF; return HF; };
R.hAt = hAt;
R.buildTerrain = function () { buildTerrain(); return terr; };
R.buildWater = function () { buildWater(); return water; };
R.terr = terr; R.water = water;

/* PROMISES, all three. The parses are sliced (see pump), so a caller cannot
   read R.meshes / R.sectors on the next line any more -- it chains. The map and
   the HUD both already boot through a promise chain, which is why this costs
   them a `return` each and nothing else. */
R.loadMeshLib = function (txt) {
  if (!txt) { MESHLIB = null; R.meshes = null; return Promise.resolve(null); }
  return parseMeshLib(txt).then(function (lib) { MESHLIB = lib; R.meshes = lib; return lib; });
};
/* malden_fen.txt -- the kind-5 (fence/wall) rows, which are three quarters of
   the island's 17287 and are not drawn at all above 10 m/px. RECORDS them, like
   loadMeshLib; R.rebuildSectors() is what puts them on screen. A consumer that
   never calls this has a map without fences and nothing else different, which
   is why the HUD minimap simply does not fetch the file. */
R.loadFences = function (txt) {
  if (!txt) { fenRows = null; return Promise.resolve(null); }
  return parseRows(txt).then(function (rows) { fenRows = rows; return rows; });
};
R.loadBuildings = function (txt) {
  return parseRows(txt).then(function (rows) {
    bldRows = rows;
    var done = splitBuild();
    /* Published BEFORE the build finishes, deliberately: these are the live
       arrays splitBuild is filling, so a screen that draws while the promise is
       still outstanding draws the part of the island that exists. */
    R.sectors = sectors; R.sectorsM = sectorsM; R.sectorsF = sectorsF; R.bldCount = bldCount;
    return done;
  }).then(function () { return R; });
};
/* Re-split the rows loadBuildings kept, against whatever the feeds hold NOW.
   This is how a library that arrives after the buildings replaces boxes with
   real silhouettes in place; see contract point 5. No rows, nothing to do --
   a consumer that calls this before loadBuildings has simply asked early. */
R.rebuildSectors = function () {
  if (!bldRows) return Promise.resolve(R);
  var done = splitBuild();
  R.sectors = sectors; R.sectorsM = sectorsM; R.sectorsF = sectorsF; R.bldCount = bldCount;
  return done.then(function () { return R; });
};

/* Satellite imagery. initAtlases() must run before the first draw; the two
   atlases and the hero window are this instance's only textures. */
R.initAtlases = function () {
  initAtlas(A128);                        // always: it is the fallback for both
  if (USE_DET)  initAtlas(A256);
  if (USE_HERO) initHero();
};
R.tiles = {
  want: wantTile,
  /* loadAtlas(res, text) -- fill a whole tier from one pre-composed image.
     Returns a promise: resolves with the cell count (169) once the tier is
     drawn, uploaded and marked present, REJECTS with a named reason on
     anything unexpected. A consumer that does not call it, or whose call
     rejects, gets today's per-tile path with nothing else changed -- which is
     what a client whose PBO predates the asset gets, and why the reject is
     the contract rather than a silent no-op. Call after initAtlases(). */
  loadAtlas: loadAtlas,
  /* Instrumentation: how much of the tile pump is still outstanding, and how
     many tiles have landed. Read-only; the map's [MAPTIME] line polls busy()
     to find the moment the opening view has fully arrived. */
  busy:  function () { return tQueue.length + tFlight; },
  count: function () { return Object.keys(tilesHave).length; },   // `have` below is the raw map
  /* Ask for every tile whose cell falls within `span` metres of (cx, cy), at ONE
     resolution, prioritised by distance from the centre. This is the island's
     tile geometry -- where cell (c,r) sits in world metres, and which cells a
     span covers -- and it lives here so a second screen does not have to spell
     MAP_M, GRID and SPAN out for a third time to ask a simple question.
     map.html keeps its own loop deliberately: it wants two resolutions in one
     pass with a distance condition between them, and rewriting it in terms of
     this would reorder the queue for no behavioural gain, against a byte-exact
     pixel gate. Two callers, one of them richer, is the honest shape. */
  wantAround: function (cx, cy, span, res) {
    var c0 = Math.max(0, (cx-span)/SPAN|0), c1 = Math.min(GRID-1, (cx+span)/SPAN|0);
    var r0 = Math.max(0, (MAP_M-(cy+span))/SPAN|0), r1 = Math.min(GRID-1, (MAP_M-(cy-span))/SPAN|0);
    for (var r = r0; r <= r1; r++) for (var c = c0; c <= c1; c++) {
      var tcx = c*SPAN+SPAN/2, tcy = MAP_M-r*SPAN-SPAN/2;
      wantTile(c, r, res, Math.hypot(tcx-cx, tcy-cy));
    }
  },
  pump: pumpTiles,
  updateHero: updateHero,
  atlasTex: function (res) { return (res >= 256 && A256.tex) ? A256.tex : A128.tex; },
  heroTex: function () { return HERO.tex; },
  have: tilesHave
};

R.drawTerrain = function (VP, mpp, sun, amb, fogK) {
  // terrain
  if (terr.vbo) {
    R.gl.useProgram(terrP);
    var close = mpp < 9;
    R.gl.activeTexture(R.gl.TEXTURE0);
    /* `A256.tex &&` and `HERO.tex ||` below are the whole cost of an instance
       that skipped one of them. Binding null to a sampler the program reads is
       not an error in WebGL -- the incomplete texture just returns (0,0,0,1) --
       so the failure would be a silently BLACK island, not a message. The map
       builds both, so both expressions take the branch they always did. */
    R.gl.bindTexture(R.gl.TEXTURE_2D, (close && A256.tex) ? A256.tex : A128.tex);
    R.gl.uniform1i(R.gl.getUniformLocation(terrP, "uSat"), 0);
    R.gl.activeTexture(R.gl.TEXTURE1);
    // uHeroMix is 0 without a hero window, so unit 1 is never sampled -- but it
    // still has to hold a COMPLETE texture, hence the 128 atlas as a stand-in.
    R.gl.bindTexture(R.gl.TEXTURE_2D, HERO.tex || A128.tex);
    R.gl.uniform1i(R.gl.getUniformLocation(terrP, "uHero"), 1);
    var hw = HERO.cells * SPAN / MAP_M;                 // window size in island UV
    /* vUV.v = (12800 - worldY)/12800, so v = 0 at the NORTH edge -- the same
       convention as the atlas, whose file row 0 is north and is blitted to canvas
       row 0. The window's v origin is therefore r0 directly; flipping it here put
       the window at the mirrored latitude and it silently never covered a
       fragment (measured: hero on/off renders identical to the pixel). */
    R.gl.uniform4f(R.gl.getUniformLocation(terrP, "uHeroRect"),
      HERO.c0 * SPAN / MAP_M, HERO.r0 * SPAN / MAP_M,
      1.0 / hw, 1.0 / hw);
    R.gl.uniform1f(R.gl.getUniformLocation(terrP, "uHeroMix"), HERO.mix);
    R.gl.activeTexture(R.gl.TEXTURE0);
    R.gl.uniformMatrix4fv(R.gl.getUniformLocation(terrP, "uVP"), false, VP);
    R.gl.uniform3fv(R.gl.getUniformLocation(terrP, "uSun"), sun.dir);
    R.gl.uniform3fv(R.gl.getUniformLocation(terrP, "uSunC"), sun.sunC);
    R.gl.uniform3fv(R.gl.getUniformLocation(terrP, "uAmb"), amb);
    R.gl.uniform1f(R.gl.getUniformLocation(terrP, "uFogK"), fogK);
    R.gl.uniform3fv(R.gl.getUniformLocation(terrP, "uFogC"), FOG);
    R.gl.bindBuffer(R.gl.ARRAY_BUFFER, terr.vbo);
    var aP = R.gl.getAttribLocation(terrP, "aP"), aN = R.gl.getAttribLocation(terrP, "aN");
    R.gl.enableVertexAttribArray(aP); R.gl.vertexAttribPointer(aP, 3, R.gl.FLOAT, false, 24, 0);
    R.gl.enableVertexAttribArray(aN); R.gl.vertexAttribPointer(aN, 3, R.gl.FLOAT, false, 24, 12);
    R.gl.bindBuffer(R.gl.ELEMENT_ARRAY_BUFFER, terr.ibo);
    R.gl.drawElements(R.gl.TRIANGLES, terr.ni, terr.itype, 0);
    R.gl.disableVertexAttribArray(aN);
  }
};
R.drawWater = function (VP, sun, amb, fogK) {
  // water
  if (water.vbo) {
    R.gl.useProgram(watP);
    R.gl.uniformMatrix4fv(R.gl.getUniformLocation(watP, "uVP"), false, VP);
    R.gl.uniform3fv(R.gl.getUniformLocation(watP, "uAmb"), amb);
    R.gl.uniform1f(R.gl.getUniformLocation(watP, "uFogK"), fogK);
    R.gl.uniform3fv(R.gl.getUniformLocation(watP, "uFogC"), FOG);
    R.gl.uniform1f(R.gl.getUniformLocation(watP, "uNight"), sun.night);
    R.gl.bindBuffer(R.gl.ARRAY_BUFFER, water.vbo);
    var aP2 = R.gl.getAttribLocation(watP, "aP");
    R.gl.enableVertexAttribArray(aP2); R.gl.vertexAttribPointer(aP2, 3, R.gl.FLOAT, false, 0, 0);
    R.gl.drawArrays(R.gl.TRIANGLES, 0, 6);
  }
};
/* Distance from (cx, cy) to a sector's own bounding box -- 0 while inside it.
   THE CULL USED TO TEST THE CENTROID, and that made `radius` mean something
   nobody could use. Sectors bucket on a MAP_M/SEC grid (1600 m on Malden), so a
   centroid test can reject the sector the camera is standing in unless every
   caller inflates its radius by the cell's 1131 m half-diagonal -- and the
   minimap did exactly that, asking for 2600 m to see 700 m of ground and paying
   5707 buildings a frame for it, on an always-on layer, on a software
   rasterizer. The bounds are already on every sector (buildBoxBucket /
   buildMeshBucket record them), so the honest test costs nothing and lets
   `radius` mean the ground radius the caller actually cares about.
   Bounds are the BUILDINGS' extent, not the cell's, so this is tighter than a
   half-diagonal pad would be as well as correct. Note it can only ever ADD
   sectors: a sector whose centroid is within radius has a box distance of at
   most that, so everything the old test accepted this one accepts too. */
function secDist(s, cx, cy) {
  var dx = Math.max(s.minx - cx, 0, cx - s.maxx), dy = Math.max(s.miny - cy, 0, cy - s.maxy);
  return Math.hypot(dx, dy);
}
/* Sectors whose bounding box comes within `radius` of (cx, cy). Returns what
   the caller needs for a readout: buildings drawn, sector draw calls, mesh
   triangles.
   ORDERING STILL USES THE CENTROID, deliberately. The lists below are sorted
   nearest-first and then cut by a cap (buildings, fences) or a triangle budget
   (meshes), so the sort key decides what survives the cut. Keeping it as it was
   means this change can only append sectors that were previously culled -- it
   cannot reshuffle the ones that were already drawing, which is what makes the
   full map's output provably unchanged rather than merely likely to be. */
R.drawBuildings = function (VP, mpp, sun, amb, fogK, cx, cy, radius) {
  // buildings: real silhouettes (mesh sectors) once fully zoomed in; boxes for
  // everything else -- meshless rows always, meshed rows in the morph/flat tiers
  var bldDrawn = 0, secDraws = 0, triDrawn = 0;
  var meshOn = sectorsM && mpp < 10;
  /* PLAN THE MESH PASS FIRST. Which sectors get real meshes is a budget decision
     (tri cap + how many may be built this frame), and the box pass below needs
     the answer: every mesh sector NOT chosen draws its box counterpart, so no
     building can vanish just because the budget ran out. */
  var meshPlan = [], meshSkip = [];
  if (meshOn) {
    var visM = [];
    sectorsM.forEach(function (s) {
      if (secDist(s, cx, cy) > radius) return;
      visM.push([Math.hypot(s.cx-cx, s.cy-cy), s]);
    });
    visM.sort(function (a, b) { return a[0]-b[0]; });
    var budget = 450000, builds = 0, MAX_BUILDS = 2;
    for (var ip = 0; ip < visM.length; ip++) {
      var sp = visM[ip][1];
      if (triDrawn + sp.tris > budget) { meshSkip.push(visM[ip]); continue; }
      if (!sp.chunks) {
        /* Building a sector is hundreds of ms of JS for a dense one, so only a
           couple are built per frame; the rest draw as boxes and dirty() brings
           us back next frame until the neighbourhood is resident. */
        if (builds >= MAX_BUILDS) { meshSkip.push(visM[ip]); R.onDirty(); continue; }
        buildMeshChunks(sp); builds++;
      }
      meshPlan.push(sp); triDrawn += sp.tris;
    }
    if (builds) evictMeshSectors(cx, cy);
    meshOn = meshPlan.length > 0;
  }
  if (sectors && mpp < 40) {
    var uEx = mpp < 10 ? 1 : mpp < 14 ? 1-(mpp-10)/4 : 0;   // extruded <10, morph to flat by 14
    R.gl.useProgram(bldP);
    R.gl.uniformMatrix4fv(R.gl.getUniformLocation(bldP, "uVP"), false, VP);
    R.gl.uniform3fv(R.gl.getUniformLocation(bldP, "uSun"), sun.dir);
    R.gl.uniform3fv(R.gl.getUniformLocation(bldP, "uSunC"), sun.sunC);
    R.gl.uniform3fv(R.gl.getUniformLocation(bldP, "uAmb"), amb);
    R.gl.uniform1f(R.gl.getUniformLocation(bldP, "uFogK"), fogK);
    R.gl.uniform3fv(R.gl.getUniformLocation(bldP, "uFogC"), FOG);
    R.gl.uniform1f(R.gl.getUniformLocation(bldP, "uNight"), sun.night);
    R.gl.uniform1f(R.gl.getUniformLocation(bldP, "uEx"), uEx);
    var kc = []; KIND_COL.forEach(function (k) { kc.push(k[0], k[1], k[2]); });
    R.gl.uniform3fv(R.gl.getUniformLocation(bldP, "uKC"), kc);
    var vis = [], fenceVis = [], close = mpp < 10;
    sectors.forEach(function (s) {
      if (secDist(s, cx, cy) <= radius) vis.push([Math.hypot(s.cx-cx, s.cy-cy), s]);
    });
    /* meshed rows as boxes: every mesh sector the plan above did not take, plus
       ALL of them in the morph/flat tiers where meshes never draw */
    if (sectorsM) sectorsM.forEach(function (s) {
      if (secDist(s, cx, cy) > radius) return;
      if (meshPlan.indexOf(s) >= 0) return;
      var bs = boxCounterpart(s, close);
      if (bs) vis.push([Math.hypot(s.cx-cx, s.cy-cy), bs]);
    });
    /* Fences ride their OWN cap. 11.8k fence rows sharing the building cap
       starve real buildings out of the close tier -- in dense sectors three
       quarters of the rows are fences. */
    if (close && sectorsF) sectorsF.forEach(function (s) {
      if (secDist(s, cx, cy) <= radius) fenceVis.push([Math.hypot(s.cx-cx, s.cy-cy), s]);
    });
    vis.sort(function (a, b) { return a[0]-b[0]; });
    fenceVis.sort(function (a, b) { return a[0]-b[0]; });
    var aXZ = R.gl.getAttribLocation(bldP, "aXZ"), aBT = R.gl.getAttribLocation(bldP, "aBT"),
        aUp = R.gl.getAttribLocation(bldP, "aUp"), aN3 = R.gl.getAttribLocation(bldP, "aN"),
        aK = R.gl.getAttribLocation(bldP, "aK");
    function drawBoxes(list, cap) {
      var n = 0;
      for (var i = 0; i < list.length && n < cap; i++) {
        var s = list[i][1];
        R.gl.bindBuffer(R.gl.ARRAY_BUFFER, s.vbo);
        R.gl.enableVertexAttribArray(aXZ); R.gl.vertexAttribPointer(aXZ, 2, R.gl.FLOAT, false, 36, 0);
        R.gl.enableVertexAttribArray(aBT); R.gl.vertexAttribPointer(aBT, 2, R.gl.FLOAT, false, 36, 8);
        R.gl.enableVertexAttribArray(aUp); R.gl.vertexAttribPointer(aUp, 1, R.gl.FLOAT, false, 36, 16);
        R.gl.enableVertexAttribArray(aN3); R.gl.vertexAttribPointer(aN3, 3, R.gl.FLOAT, false, 36, 20);
        R.gl.enableVertexAttribArray(aK);  R.gl.vertexAttribPointer(aK, 1, R.gl.FLOAT, false, 36, 32);
        R.gl.bindBuffer(R.gl.ELEMENT_ARRAY_BUFFER, s.ibo);
        R.gl.drawElements(R.gl.TRIANGLES, s.ni, R.gl.UNSIGNED_SHORT, 0);
        n += s.count; bldDrawn += s.count; secDraws++;
      }
    }
    drawBoxes(vis, 3200);
    drawBoxes(fenceVis, 4000);
  }
  if (meshOn) {
    R.gl.useProgram(mshP);
    R.gl.uniformMatrix4fv(R.gl.getUniformLocation(mshP, "uVP"), false, VP);
    R.gl.uniform3fv(R.gl.getUniformLocation(mshP, "uSun"), sun.dir);
    R.gl.uniform3fv(R.gl.getUniformLocation(mshP, "uSunC"), sun.sunC);
    R.gl.uniform3fv(R.gl.getUniformLocation(mshP, "uAmb"), amb);
    R.gl.uniform1f(R.gl.getUniformLocation(mshP, "uFogK"), fogK);
    R.gl.uniform3fv(R.gl.getUniformLocation(mshP, "uFogC"), FOG);
    R.gl.uniform1f(R.gl.getUniformLocation(mshP, "uNight"), sun.night);
    var aPm = R.gl.getAttribLocation(mshP, "aP"), aNm = R.gl.getAttribLocation(mshP, "aN"),
        aCm = R.gl.getAttribLocation(mshP, "aC"), aKm = R.gl.getAttribLocation(mshP, "aK");
    R.gl.disable(R.gl.CULL_FACE);   // meshes are not guaranteed closed; lambert is orientation-fixed
    for (var im = 0; im < meshPlan.length; im++) {
      var sm = meshPlan[im];
      if (!sm.chunks) continue;                 // evicted since planning
      for (var ic = 0; ic < sm.chunks.length; ic++) {
        var ch = sm.chunks[ic];
        R.gl.bindBuffer(R.gl.ARRAY_BUFFER, ch.vbo);
        R.gl.enableVertexAttribArray(aPm); R.gl.vertexAttribPointer(aPm, 3, R.gl.FLOAT, false, 40, 0);
        R.gl.enableVertexAttribArray(aNm); R.gl.vertexAttribPointer(aNm, 3, R.gl.FLOAT, false, 40, 12);
        R.gl.enableVertexAttribArray(aCm); R.gl.vertexAttribPointer(aCm, 3, R.gl.FLOAT, false, 40, 24);
        R.gl.enableVertexAttribArray(aKm); R.gl.vertexAttribPointer(aKm, 1, R.gl.FLOAT, false, 40, 36);
        R.gl.bindBuffer(R.gl.ELEMENT_ARRAY_BUFFER, ch.ibo);
        R.gl.drawElements(R.gl.TRIANGLES, ch.ni, R.gl.UNSIGNED_SHORT, 0);
      }
      bldDrawn += sm.count; secDraws++;       // triDrawn accounted at plan time
    }
    R.gl.enable(R.gl.CULL_FACE);
  }
  return { bldDrawn: bldDrawn, secDraws: secDraws, triDrawn: triDrawn };
};

/* Delete every GL object this instance owns. Buffers handed out by glBuf/glIbuf
   belong to whoever asked for them and are NOT freed here. */
R.dispose = function () {
  var g = R.gl;
  [terr.vbo, terr.ibo, water.vbo].forEach(function (b) { if (b) g.deleteBuffer(b); });
  terr.vbo = null; terr.ibo = null; terr.ni = 0; water.vbo = null;
  [A128, A256, HERO].forEach(function (A) { if (A.tex) g.deleteTexture(A.tex); A.tex = null; });
  freeSectors();
  R._progs.forEach(function (p) { g.deleteProgram(p); });
  R._shaders.forEach(function (s) { g.deleteShader(s); });
  R._progs = []; R._shaders = [];
  bldRows = null; fenRows = null;
  HF = null; MESHLIB = null;
  R.sectors = null; R.sectorsM = null; R.sectorsF = null; R.hf = null; R.meshes = null;
};

  return R;
}
  window.GRID3D = { create: create, VERSION: 1 };
})();
