// Petit compagnon pixel-art qui vit dans le fond d'écran (pixel-world.png).
//  - il se balade, saute sur les îles, code sur son laptop, boit son café, dort,
//    prend le tuyau, chasse les bugs, monte sur l'horloge et la pousse.
//  - clic : il râle. Glisser : tu le portes, lâcher : il tombe (tu peux le lancer).
//  - clic droit : phrase du jour.
// Lancer : qs -c buddy -d   |   Phrases du jour : phrases.txt   |   Décor : tools/make_world.py
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "Frames.js" as Fr

ShellRoot {
    id: root

    // ---------- données ----------
    property var phrases: []
    property string today: ""
    property var scene: null
    property var clock: null          // {x, y, size, free}
    property bool covered: false      // bureau caché par des fenêtres -> on met en pause

    readonly property string iiConfig: Quickshell.env("HOME") + "/.config/illogical-impulse/config.json"

    function hash(s) {
        let h = 2166136261;
        for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = (h * 16777619) >>> 0; }
        return h;
    }
    function dailyPhrase() { return phrases.length ? phrases[hash(today) % phrases.length] : "Hello, World!"; }
    function randomPhrase() { return phrases.length ? pick(phrases) : "Hello, World!"; }
    function pick(a) { return a[Math.floor(Math.random() * a.length)]; }
    function rand(a, b) { return a + Math.random() * (b - a); }

    signal newDay()
    function checkDay() {
        const d = Qt.formatDate(new Date(), "yyyy-MM-dd");
        if (d !== today) { today = d; newDay(); }
    }

    FileView {
        path: Qt.resolvedUrl("phrases.txt")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.phrases = text().split("\n").map(l => l.trim()).filter(l => l.length > 0 && !l.startsWith("#"));
            root.checkDay();
        }
    }
    FileView {
        path: Qt.resolvedUrl("scene.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.scene = JSON.parse(text()); } catch (e) {} }
    }
    FileView {
        path: root.iiConfig
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const c = JSON.parse(text()).background.widgets.clock;
                root.clock = { x: c.x, y: c.y, size: 230, free: c.enable && c.placementStrategy === "free" };
            } catch (e) {}
        }
    }
    Timer { interval: 60000; running: true; repeat: true; onTriggered: root.checkDay() }

    // déplace l'horloge de ii (écrit sa position dans la config, ii anime le déplacement)
    Process {
        id: clockWriter
        property int nx: 0
        property int ny: 0
        command: ["bash", "-c", "f=\"$1\"; jq --argjson x " + nx + " --argjson y " + ny
            + " '.background.widgets.clock.x=$x | .background.widgets.clock.y=$y' \"$f\" > \"$f.buddy\" && mv \"$f.buddy\" \"$f\"",
            "_", root.iiConfig]
    }
    property real clockVX: 0
    property real clockVY: 0
    property real lastLiveT: 0
    property bool clockDragging: false
    signal clockLiveMoved(real dx, real dy)
    SocketServer {
        active: true
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/qs-buddy.sock"
        handler: Socket {
            parser: SplitParser { onRead: data => root.clockLive(data) }
        }
    }
    function clockLive(line) {
        line = line.trim();
        if (line === "end") { clockDragging = false; clockVX = 0; clockVY = 0; return; }
        const v = line.split(" ").map(Number);
        if (v.length < 4 || v.some(isNaN)) return;
        const now = Date.now(), dt = Math.max(8, now - lastLiveT) / 1000;
        lastLiveT = now;
        const old = clock;
        const dx = old ? v[0] - old.x : 0, dy = old ? v[1] - old.y : 0;
        if (clockDragging && old) { clockVX = clockVX * 0.5 + dx / dt * 0.5; clockVY = clockVY * 0.5 + dy / dt * 0.5; }
        clockDragging = true;
        clock = { x: v[0], y: v[1], size: v[2], free: true };
        clockLiveMoved(dx, dy);
    }
    function moveClock(nx, ny) {
        nx = Math.round(Math.max(0, Math.min(1920 - 230, nx)));
        ny = Math.round(Math.max(50, Math.min(1080 - 300, ny)));
        clock = { x: nx, y: ny, size: 230, free: true };
        clockWriter.nx = nx; clockWriter.ny = ny;
        clockWriter.running = false; clockWriter.running = true;
    }

    // ---------- pause quand des fenêtres couvrent le bureau ----------
    Process {
        id: coverCheck
        command: ["bash", "-c", "hyprctl -j monitors | jq -c --argjson c \"$(hyprctl -j clients)\" '[.[] | select(.focused) | .activeWorkspace.id as $w | .specialWorkspace.id as $s | any($c[]; (.workspace.id == $w or .workspace.id == $s) and (.floating | not) and .mapped and (.hidden | not))] | any'"]
        stdout: StdioCollector { onStreamFinished: root.covered = text.trim() === "true" }
    }
    Timer { id: coverDebounce; interval: 150; onTriggered: coverCheck.running = true }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            // le fond de ii vient d'être (re)créé : on repasse au-dessus de lui
            if (event.name === "openlayer" && event.data.trim() === "quickshell:background") remap.restart();
            if (["openwindow", "closewindow", "movewindow", "movewindowv2", "workspace", "workspacev2", "focusedmon",
                 "changefloatingmode", "activespecial", "fullscreen"].includes(event.name))
                coverDebounce.restart();
        }
    }
    Component.onCompleted: coverCheck.running = true
    Timer { id: remap; interval: 400; onTriggered: { win.visible = false; win.visible = true; } }

    // =====================================================================
    PanelWindow {
        id: win
        screen: Quickshell.screens[0]
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell:buddy"
        exclusionMode: ExclusionMode.Ignore
        anchors { left: true; right: true; top: true; bottom: true }
        color: "transparent"
        mask: Region {
            x: buddy.x + 16; y: buddy.y + 4; width: 64; height: 120
            Region { x: boombox.x; y: boombox.y; width: boombox.width; height: boombox.height }
        }

        readonly property int sc: 4                    // taille d'un pixel de sprite
        readonly property real g: 2600                 // gravité px/s²
        readonly property real maxUp: 380              // hauteur de saut max
        readonly property bool running: !root.covered

        // ---------- état du bonhomme ----------
        property real bx: 1500                         // centre (x) des pieds
        property real by: 988                          // pieds (y)
        property real vx: 0
        property real vy: 0
        property int dir: -1
        property string mode: "idle"                   // idle | walk | air | drag | act
        property string surfId: "ground"
        property string pose: "idle"
        property real tilt: 0
        property real wiggle: 0
        property real spin: 0
        property int anger: 0
        property bool gunOut: false
        property bool thrown: false
        property bool bounced: false
        property real lastHit: 0
        property real dragStart: 0
        // danse
        property int danceI: -1
        property bool danceMirror: false
        property real danceDy: 0
        property bool auraOn: false
        property int auraTotal: 0
        property int pendingDance: -1
        property real squash: 1
        property real clipY: 99999                     // pour disparaître dans un tuyau
        property bool hidden: false

        property real goalX: 0
        property real walkSpeed: 80
        property var walkCb: null
        property var airCb: null
        property var actCb: null

        property var seq: []
        property int seqI: 0

        // agacement
        property int pokes: 0
        property real lastPoke: 0
        property real lastInteraction: Date.now()

        // ---------- surfaces ----------
        function surfaces() {
            const s = [];
            const sc = root.scene;
            s.push({ id: "ground", x1: 60, x2: width - 60, y: sc ? sc.ground : 988 });
            if (sc) {
                sc.platforms.forEach((p, i) => s.push({ id: "p" + i, x1: p.x1 + 12, x2: p.x2 - 12, y: p.y }));
                sc.pipes.forEach((p, i) => s.push({ id: "pipe" + i, x1: p.x + 6, x2: p.x + 90, y: p.y - 96, pipe: i }));
            }
            const c = root.clock;
            if (c && c.free) s.push({ id: "clock", x1: c.x + 40, x2: c.x + c.size - 40, y: c.y + 14 });
            return s;
        }
        function surf(id) { return surfaces().find(s => s.id === id) ?? surfaces()[0]; }
        function reach(a, b) {
            if (a.id === b.id) return false;
            const gap = Math.max(0, Math.max(a.x1, b.x1) - Math.min(a.x2, b.x2));
            return (a.y - b.y) <= maxUp - 30 && gap < 700;
        }
        function path(fromId, toId) {           // BFS sur les surfaces atteignables
            const all = surfaces();
            const prev = {}; prev[fromId] = null;
            const q = [fromId];
            while (q.length) {
                const cur = q.shift();
                if (cur === toId) break;
                const a = all.find(s => s.id === cur);
                if (!a) continue;
                for (const b of all)
                    if (!(b.id in prev) && reach(a, b)) { prev[b.id] = cur; q.push(b.id); }
            }
            if (!(toId in prev)) return null;
            const p = [];
            for (let c = toId; c !== null; c = prev[c]) p.unshift(c);
            return p;
        }

        // ---------- outils d'animation ----------
        function setPose(p) { animT.stop(); pose = p; }
        function loop(list, ms) { seq = list; seqI = 0; pose = list[0]; animT.interval = ms; animT.restart(); }
        function after(ms, fn) { actCb = fn; actT.interval = ms; actT.restart(); }
        function cancelAll() {
            actT.stop(); animT.stop(); actCb = null; walkCb = null; airCb = null;
            emitter.stop(); hidden = false; clipY = 99999;
            danceT.stop(); auraOn = false; danceMirror = false; danceDy = 0; danceI = -1;
            gunOut = false;
            if (mode !== "air" && mode !== "drag") mode = "idle";
        }
        Timer { id: animT; repeat: true; running: false
            onTriggered: { win.seqI = (win.seqI + 1) % win.seq.length; win.pose = win.seq[win.seqI]; } }
        Timer { id: actT; onTriggered: { const f = win.actCb; win.actCb = null; if (f) f(); } }

        // clignement naturel
        Timer {
            interval: 3200; repeat: true; running: win.running
            onTriggered: {
                interval = 2500 + Math.random() * 3500;
                const map = { idle: "blink", sit: "sitBlink", type0: "typeBlink", type1: "typeBlink" };
                if (map[win.pose] && !animT.running) {
                    const back = win.pose; win.pose = map[back];
                    unblink.back = back; unblink.restart();
                }
            }
        }
        Timer { id: unblink; interval: 140; property string back: "idle"
            onTriggered: if (win.pose === "blink" || win.pose === "sitBlink" || win.pose === "typeBlink") win.pose = back }

        // ---------- déplacements ----------
        function walkTo(x, cb, speed) {
            const s = surf(surfId);
            goalX = Math.max(s.x1, Math.min(s.x2, x));
            walkSpeed = speed ?? 80;
            walkCb = cb ?? null;
            if (Math.abs(goalX - bx) < 4) { mode = "idle"; setPose("idle"); const f = walkCb; walkCb = null; if (f) f(); return; }
            dir = goalX > bx ? 1 : -1;
            mode = "walk";
            loop(["walk0", "walk1", "walk2", "walk3"], walkSpeed > 120 ? 90 : 130);
        }
        function jumpTo(s, tx, cb) {
            tx = Math.max(s.x1 + 10, Math.min(s.x2 - 10, tx));
            const apex = Math.max(by, s.y) - Math.min(by, s.y) + 70;
            const up = by - Math.min(by, s.y) + 70;          // montée depuis la position actuelle
            const v0 = Math.sqrt(2 * g * up);
            const t1 = v0 / g;
            const t2 = Math.sqrt(2 * (s.y - (by - up)) / g);
            dir = tx > bx ? 1 : -1;
            setPose("crouch");
            after(130, () => {
                vx = (tx - bx) / (t1 + t2); vy = -v0;
                airCb = cb ?? null;
                mode = "air"; surfId = ""; setPose("jump");
            });
        }
        function goTo(targetId, x, cb) {   // marche + sauts jusqu'à une surface
            if (targetId === surfId) { walkTo(x, cb); return; }
            const p = path(surfId, targetId);
            if (!p || p.length < 2) { if (cb) cb(false); return; }
            const a = surf(surfId), b = surf(p[1]);
            const take = Math.max(a.x1 + 10, Math.min(a.x2 - 10, Math.max(b.x1 - 80, Math.min(b.x2 + 80, bx))));
            const land = Math.max(b.x1 + 20, Math.min(b.x2 - 20, p.length === 2 ? x : take));
            walkTo(take, () => jumpTo(b, land, () => goTo(targetId, x, cb)));
        }

        function land(s, impact) {
            if (thrown && impact > 2400 && !bounced) {      // grosse chute : il rebondit
                bounced = true; by = s.y - 1; vy = -impact * 0.3; vx *= 0.5;
                squashAnim.restart(); return;
            }
            by = s.y; vy = 0; vx = 0; mode = "idle"; surfId = s.id;
            spinAnim.stop(); spin = 0;
            squashAnim.restart();
            const f = airCb; airCb = null;
            const wasThrown = thrown, big = bounced;
            thrown = false; bounced = false;
            if (pendingDance >= 0) { const d = pendingDance; pendingDance = -1; startDance(d); return; }
            if (wasThrown && (impact > 1300 || big)) { reactLanding(big); return; }
            setPose("idle");
            if (f) f(); else after(400, think);
        }

        // boucle physique : ne tourne que quand il bouge (économise le CPU)
        FrameAnimation {
            running: win.running && (win.mode === "walk" || win.mode === "air" || bug.active || (win.mode === "dance" && win.danceI >= 0 && !!win.dances[win.danceI].moon))
            onTriggered: {
                const dt = Math.min(0.05, frameTime);
                if (win.mode === "walk") {
                    const step = win.walkSpeed * dt;
                    if (Math.abs(win.goalX - win.bx) <= step) {
                        win.bx = win.goalX; win.mode = "idle"; win.setPose("idle");
                        const f = win.walkCb; win.walkCb = null;
                        if (f) f(); else win.after(300, win.think);
                    } else win.bx += win.dir * step;
                } else if (win.mode === "air") {
                    const prevY = win.by;
                    win.vy += win.g * dt;
                    win.bx += win.vx * dt;
                    win.by += win.vy * dt;
                    if (win.bx < 60) { win.bx = 60; win.vx = Math.abs(win.vx) * 0.5; }
                    if (win.bx > win.width - 60) { win.bx = win.width - 60; win.vx = -Math.abs(win.vx) * 0.5; }
                    if (win.by < 60) { win.by = 60; win.vy = Math.abs(win.vy) * 0.3; }
                    const gnd = win.surfaces()[0];
                    if (win.by >= gnd.y && prevY >= gnd.y - 1) { win.land(gnd, win.vy); return; }
                    if (win.vy > 0) {
                        win.pose = win.vy > 900 ? "fall" : win.pose;
                        for (const s of win.surfaces())
                            if (prevY <= s.y + 1 && win.by >= s.y && win.bx >= s.x1 && win.bx <= s.x2) {
                                win.land(s, win.vy); break;
                            }
                    }
                }
                if (win.mode === "dance" && win.danceI >= 0 && win.dances[win.danceI].moon) {   // moonwalk : recule
                    const s = win.surf(win.surfId);
                    win.bx -= win.dir * 55 * dt;
                    if (win.bx < s.x1 + 20 || win.bx > s.x2 - 20) { win.dir = -win.dir; win.bx = Math.max(s.x1 + 20, Math.min(s.x2 - 20, win.bx)); }
                }
                if (bug.active) bug.step(dt);
            }
        }

        // ---------- cerveau ----------
        function think() {
            if (mode === "drag" || mode === "air" || mode === "dance") return;
            if (surfId === "") { mode = "air"; setPose("fall"); return; }   // pas de sol sous les pieds -> il tombe
            mode = "act";
            const here = surf(surfId);
            if (bug.active && Math.random() < 0.8) { chaseBug(); return; }
            const idleFor = (Date.now() - lastInteraction) / 1000;
            const opts = [
                [3, wander], [2, standAround], [3, code], [2, coffee],
                [idleFor > 300 ? 3 : 1, sleep], [2, hop], [1, wave],
            ];
            if (here.pipe === undefined && root.scene && surfaces().some(s => s.pipe !== undefined && path(surfId, s.id))) opts.push([1, takePipe]);
            if (here.pipe !== undefined) opts.push([4, enterPipe]);
            if (root.clock && root.clock.free) {
                if (surfId === "clock") opts.push([3, stompClock]);
                else if (path(surfId, "clock")) opts.push([2, climbClock]);
                const c = root.clock;
                if (surfId !== "clock" && here.y - (c.y + c.size) < maxUp - 40 && here.y > c.y + c.size
                    && c.x + c.size / 2 > here.x1 && c.x + c.size / 2 < here.x2) opts.push([3, bumpClock]);
            }
            let total = opts.reduce((a, o) => a + o[0], 0), r = Math.random() * total;
            for (const [w, fn] of opts) { if ((r -= w) <= 0) { fn(); return; } }
            standAround();
        }
        function done(ms) { mode = "act"; after(ms ?? root.rand(800, 2500), think); }

        function wander() {
            const s = surf(surfId);
            walkTo(root.rand(s.x1 + 20, s.x2 - 20), () => done());
        }
        function standAround() { setPose("idle"); done(root.rand(3000, 8000)); }
        function wave() {
            loop(["wave0", "wave1"], 220);
            if (Math.random() < 0.4) say(root.randomPhrase());
            after(2200, () => { setPose("idle"); done(); });
        }
        function hop() {
            const s = surf(surfId);
            const opts = surfaces().filter(o => o.id !== s.id && o.id !== "clock" && path(s.id, o.id));
            if (!opts.length) { wander(); return; }
            const t = root.pick(opts);
            goTo(t.id, root.rand(t.x1 + 20, t.x2 - 20), ok => done());
        }
        function code() {
            setPose("sit");
            after(500, () => {
                loop(["type0", "type1"], 260);
                emitter.kind = "code"; emitter.restart();
                after(root.rand(15000, 35000), () => {
                    emitter.stop();
                    if (Math.random() < 0.35) {
                        setPose("facepalm");
                        say(root.pick(bugPhrases));
                        after(2600, () => { setPose("idle"); done(); });
                    } else {
                        loop(["cheer", "idle"], 250);
                        if (Math.random() < 0.4) say(root.pick(codePhrases));
                        after(1400, () => { setPose("idle"); done(); });
                    }
                });
            });
        }
        function coffee() {
            setPose("sit");
            let sips = 0;
            const sip = () => {
                setPose("mugHigh");
                after(1300, () => {
                    setPose("mugLow");
                    emitter.kind = "steam"; emitter.restart();
                    if (++sips < 3) after(root.rand(2500, 5000), sip);
                    else after(2500, () => {
                        emitter.stop();
                        if (Math.random() < 0.35) say(root.pick(coffeePhrases));
                        setPose("idle"); done();
                    });
                });
            };
            after(500, () => { setPose("mugLow"); after(1500, sip); });
        }
        function sleep() {
            setPose("sit");
            after(800, () => {
                loop(["sleep0", "sleep1"], 900);
                emitter.kind = "z"; emitter.restart();
                after(root.rand(20000, 45000), wakeUp);
            });
        }
        function wakeUp() {
            emitter.stop();
            setPose("sitBlink");
            after(400, () => { loop(["cheer", "idle"], 300); after(1200, () => { setPose("idle"); done(); }); });
        }

        // tuyau : il saute dedans et ressort par l'autre
        function takePipe() {
            const p = surfaces().find(s => s.pipe !== undefined && path(surfId, s.id));
            if (!p) { wander(); return; }
            goTo(p.id, (p.x1 + p.x2) / 2, ok => ok === false ? done() : enterPipe());
        }
        function enterPipe() {
            const here = surf(surfId);
            if (here.pipe === undefined) { done(); return; }
            walkTo((here.x1 + here.x2) / 2, () => {
                setPose("crouch");
                after(300, () => {
                    setPose("jump");
                    clipY = here.y;
                    sinkAnim.from = by; sinkAnim.to = by + 130; sinkAnim.cb = () => {
                        const to = root.scene.pipes[root.scene.pipes[here.pipe].to];
                        const t = surfaces().find(s => s.pipe === root.scene.pipes[here.pipe].to);
                        bx = (t.x1 + t.x2) / 2; clipY = t.y; by = t.y + 130; surfId = t.id;
                        after(600, () => {
                            sinkAnim.from = by; sinkAnim.to = t.y; sinkAnim.cb = () => {
                                clipY = 99999;
                                const side = surfaces().filter(s => s.id !== t.id && s.pipe === undefined && t.x1 >= s.x1 - 60 && t.x2 <= s.x2 + 60 && s.y >= t.y)
                                    .sort((a, b) => a.y - b.y)[0];
                                if (side) jumpTo(side, bx + (Math.random() < .5 ? -110 : 110), () => { setPose("cheer"); done(900); });
                                else done();
                            };
                            sinkAnim.restart();
                        });
                    };
                    sinkAnim.restart();
                });
            });
        }
        NumberAnimation {
            id: sinkAnim
            target: win; property: "by"; duration: 550; easing.type: Easing.InOutQuad
            property var cb: null
            onFinished: { const f = cb; cb = null; if (f) f(); }
        }

        // horloge
        function climbClock() {
            const c = surf("clock");
            goTo("clock", root.rand(c.x1 + 20, c.x2 - 20), ok => {
                if (ok === false) { done(); return; }
                (Math.random() < 0.5 ? code : sleep)();
            });
        }
        function stompClock() {
            const c = root.clock;
            setPose("crouch");
            after(200, () => {
                setPose("jump"); vy = -700; vx = 0; mode = "air"; surfId = "";
                airCb = () => {
                    const shift = (Math.random() < 0.5 ? -1 : 1) * root.rand(80, 200);
                    say(root.pick(clockPhrases));
                    rideAnim.from = bx; rideAnim.to = bx + shift; rideAnim.restart();
                    root.moveClock(c.x + shift, c.y);
                    setPose("cheer");
                    after(1200, () => { setPose("idle"); done(); });
                };
            });
        }
        Timer { id: clockSettle; interval: 350; property real nx; property real ny; onTriggered: root.moveClock(nx, ny) }
        NumberAnimation { id: rideAnim; target: win; property: "bx"; duration: 500; easing.type: Easing.OutCubic }
        function bumpClock() {
            const c = root.clock;
            walkTo(c.x + c.size / 2 + root.rand(-30, 30), () => {
                setPose("crouch");
                after(150, () => {
                    const h = by - (c.y + c.size) + 10;
                    vy = -Math.sqrt(2 * g * h); vx = 0; mode = "air"; surfId = ""; setPose("cheer");
                    bumpCheck.restart();
                    airCb = () => { setPose("idle"); done(); };
                });
            });
        }
        Timer { // détecte le coup de tête sous l'horloge
            id: bumpCheck; interval: 16; repeat: true
            onTriggered: {
                const c = root.clock;
                if (win.mode !== "air" || !c) { stop(); return; }
                if (win.vy >= 0) { stop(); return; }
                if (win.by - 120 <= c.y + c.size) {
                    stop();
                    win.vy = 200;
                    const shift = (Math.random() < 0.5 ? -1 : 1) * root.rand(100, 260);
                    const cx = c.x, cy = c.y;
                    root.moveClock(cx + shift * 0.3, cy - 40);   // petit saut de l'horloge…
                    clockSettle.nx = cx + shift; clockSettle.ny = cy; clockSettle.restart();   // …puis elle retombe plus loin
                    win.say(root.pick(win.clockPhrases));
                }
            }
        }

        // bug à chasser
        function chaseBug() {
            goTo(bug.surfId, bug.bxPos, ok => {
                if (ok === false || !bug.active || bug.surfId !== surfId) { done(); return; }
                if (Math.abs(bug.bxPos - bx) > 40) { chaseBug(); return; }
                setPose("crouch");
                after(150, () => {
                    vy = -650; vx = (bug.bxPos - bx) * 2; mode = "air"; surfId = ""; setPose("jump");
                    airCb = () => {
                        bug.squash();
                        loop(["cheer", "idle"], 200);
                        say(root.pick(bugFixedPhrases));
                        after(1600, () => { setPose("idle"); done(); });
                    };
                });
            });
        }

        // ---------- réactions ----------
        readonly property var angryPhrases: ["Eh ! Me touche pas !", "Je code là !", "Aïe ! Ça va pas ?", "Arrête de me cliquer dessus 😤",
            "Je vais le dire à Linus !", "Tu cliques sur moi comme sur un bouton ?!", "C'est pas un bouton ici !", "Oh ! Respecte le dev !",
            "Je suis pas un raccourci clavier !", "Encore un clic et je fais un rm -rf.", "Mais laisse-moi tranquille !"]
        readonly property var veryAngryPhrases: ["BON. ÇA SUFFIT.", "Je me casse.", "Ticket ouvert : utilisateur relou.", "Ok, plus jamais je te parle."]
        readonly property var gunPhrases: ["Arrête. Tout de suite.", "Encore un clic et je tire.", "Tu me cherches là ?", "Pose cette souris. LENTEMENT.",
            "Dernier avertissement.", "Les mains en l'air. Loin du clavier.", "Recule. Je suis armé (de code)."]
        readonly property var calmPhrases: ["Bon. On se calme.", "Ok… on va dire que ça va.", "T'as de la chance.", "Je t'ai à l'œil."]
        readonly property var bangPhrases: ["…c'était un faux. La prochaine fois, non.", "BANG ! Haha, t'as eu peur.", "Pistolet à drapeau. Mais ça marche, hein ?"]
        readonly property var holdPhrases: ["Lâche-moi !!", "Repose-moi !!", "Je vais vomir…", "C'est un kidnapping !", "Au secours, on m'enlève !",
            "J'ai pas signé pour ça !", "Je suis un dev, pas un jouet !", "Je mords, je te préviens !"]
        readonly property var highPhrases: ["J'ai le vertige !!", "C'est trop haut !!", "Me lâche pas ici !!", "Je vois la lune de trop près !"]
        readonly property var boredPhrases: ["Bon… t'as fini ?", "Je m'ennuie là-haut.", "Ça fait long là.", "J'ai du code qui m'attend…"]
        readonly property var bigLandPhrases: ["MES LUNETTES !!", "J'ai cassé un pixel…", "Appelle le SAMU… ou Stack Overflow.", "Kernel panic.", "Je sens plus mes sprites."]
        readonly property var hitPhrases: ["AÏE ! L'HORLOGE !", "Eh ! Fais gaffe avec ça !", "Tu m'as frappé avec l'heure ?!", "C'est l'heure de te calmer !", "Ouch ! Timing parfait…"]
        readonly property var squishPhrases: ["Hmpf !!", "Je… respire… plus…", "Écrasé par le temps.", "Mmmh mmmh !!"]
        readonly property var dancePokePhrases: ["Laisse-moi danser !", "+500 aura pour moi", "Tu peux pas test.", "Regarde et apprends."]
        readonly property var danceEndPhrases: ["+1000 aura ✨", "Aura maximale.", "Battle gagnée.", "Personne peut test.", "Trop facile."]
        readonly property var wakePhrases: ["Je dormais !!", "Hein ?! Quoi ? J'ai pas dormi.", "Laisse-moi encore 5 minutes…"]
        readonly property var dragPhrases: ["Lâche-moi !!", "Waaah !", "Repose-moi !", "J'ai le vertige !", "Au secours !", "On n'est pas dans un jeu !"]
        readonly property var landPhrases: ["Aïe… mes lunettes.", "Ouch. Segfault.", "Ça va, ça va…", "J'ai vu des étoiles.", "Merci hein…"]
        readonly property var bugPhrases: ["Encore un bug !!", "Segmentation fault…", "Pourquoi ça marche pas ?!", "NullPointerException…", "Ça marchait il y a 5 min !"]
        readonly property var codePhrases: ["Ça compile !!", "git push ✔", "Tests au vert !", "Done. On déploie vendredi ?", "Je suis un génie."]
        readonly property var coffeePhrases: ["Ahh… le café ☕", "Café = code", "Encore une tasse ?", "Rechargement : 100%"]
        readonly property var clockPhrases: ["Hop ! Un peu plus loin.", "Elle était mal placée.", "Je range le bureau.", "C'est l'heure… de bouger !", "Tic-tac, pousse-toi."]
        readonly property var bugFixedPhrases: ["Bug fixé ✔", "Écrasé !", "Un de moins !", "Et hop, patch appliqué."]

        function poke(right) {
            lastInteraction = Date.now();
            if (right) { cancelAll(); setPose("talk"); say(root.dailyPhrase()); after(4000, () => { setPose("idle"); done(); }); return; }
            if (gunOut) { bang(); return; }
            if (mode === "dance") { say(root.pick(dancePokePhrases)); auraTotal += 500; return; }
            const wasSleeping = pose === "sleep0" || pose === "sleep1";
            cancelAll();
            if (mode === "air") return;
            annoy(1);
            mode = "act";
            shakeAnim.restart();
            if (anger >= 4) { threaten(); return; }
            if (wasSleeping) { setPose("shout"); say(root.pick(wakePhrases)); after(1800, () => { setPose("angry"); after(800, () => done()); }); return; }
            if (anger >= 3) {
                setPose("shout"); say(root.pick(veryAngryPhrases));
                after(1300, () => {
                    const s = surf(surfId);
                    walkTo(bx < (s.x1 + s.x2) / 2 ? s.x2 - 10 : s.x1 + 10, () => done(4000), 190);
                });
                return;
            }
            loop(anger >= 2 ? ["shout", "angry"] : ["angry", "shout"], 260);
            say(root.pick(angryPhrases));
            after(1600, () => { setPose("angry"); after(900, () => { setPose("idle"); done(); }); });
        }
        function reactLanding(big) {
            mode = "act";
            setPose("land");
            stars.restart();
            if (big) { annoy(1); flatAnim.restart(); }
            say(root.pick(big ? bigLandPhrases : landPhrases));
            after(big ? 2600 : 1500, () => {
                setPose("dizzy");
                after(1200, () => { if (anger >= 4) threaten(); else { setPose("idle"); done(); } });
            });
        }
        function annoy(n) { anger = Math.min(9, anger + n); lastInteraction = Date.now(); }
        Timer { interval: 15000; repeat: true; running: true; onTriggered: if (win.anger > 0 && !win.gunOut) win.anger-- }

        // il sort un flingue (pointé vers toi) si tu insistes trop
        function threaten() {
            cancelAll(); mode = "act"; gunOut = true;
            loop(["aim0", "aim1"], 320);
            say(root.pick(gunPhrases));
            after(6000, () => {
                gunOut = false; anger = 1;
                setPose("angry"); say(root.pick(calmPhrases));
                after(1600, () => { setPose("idle"); done(); });
            });
        }
        function bang() {
            cancelAll(); mode = "act"; anger = 0;
            setPose("aim1");
            bangAnim.restart();
            after(900, () => {
                setPose("aim0"); say(root.pick(bangPhrases));
                after(3200, () => { setPose("idle"); done(); });
            });
        }

        // l'horloge le percute
        function clockCollide() {
            const c = root.clock;
            if (!c || surfId === "clock" || mode === "drag" || hidden || !root.clockDragging) return;
            if (Date.now() - lastHit < 700) return;
            const r = c.size * 0.45, cx = c.x + c.size / 2, cy = c.y + c.size / 2;
            const px = Math.max(bx - 26, Math.min(bx + 26, cx)), py = Math.max(by - 116, Math.min(by, cy));
            if (Math.hypot(px - cx, py - cy) > r) return;
            lastHit = Date.now();
            const sp = Math.hypot(root.clockVX, root.clockVY);
            const wasAir = mode === "air";
            cancelAll(); annoy(2);
            if (!wasAir && root.clockVY > 250 && cy < by - 90) { squish(); return; }
            const d = bx >= cx ? 1 : -1;
            vx = d * Math.max(450, Math.min(2000, Math.abs(root.clockVX) * 0.9 + 300));
            vy = -Math.max(500, Math.min(1500, sp * 0.45 + 350));
            surfId = ""; mode = "air"; thrown = true; bounced = false;
            setPose("fall"); spinAnim.to = 360 * d; spinAnim.restart();
            say(root.pick(hitPhrases));
        }
        function squish() {
            mode = "act"; setPose("land"); flatAnim.restart(); stars.restart();
            say(root.pick(squishPhrases));
            after(2000, () => {
                setPose("shout"); say(root.pick(hitPhrases));
                after(1400, () => {
                    if (anger >= 4) { threaten(); return; }
                    const c = root.clock;
                    if (c) walkTo(bx < c.x + c.size / 2 ? c.x - 60 : c.x + c.size + 60, () => { setPose("angry"); done(1500); }, 170);
                    else done();
                });
            });
        }

        // ---------- danses ----------
        readonly property var dances: [
            { name: "Aura Farming ⛵", ms: 420, aura: true, steps: [["auraL", 0, 0], ["auraIdle", 0, 4], ["auraL", 1, 0], ["auraIdle", 1, 4]] },
            { name: "Danse Vampira 🦇", ms: 460, aura: true, steps: [["vampA", 0, 0], ["vampC", 0, 4], ["vampA", 1, 0], ["vampC", 1, 4]] },
            { name: "Floss", ms: 170, steps: [["flossL", 0, 0], ["flossL", 1, 0]] },
            { name: "Dab", ms: 520, steps: [["crouch", 0, 0], ["dabL", 0, 0], ["idle", 0, 0], ["dabL", 1, 0]] },
            { name: "Gangnam Style", ms: 190, steps: [["reins", 0, 0], ["reinsLift", 0, -8], ["reins", 1, 0], ["reinsLift", 1, -8]] },
            { name: "Macarena", ms: 380, steps: [["reins", 0, 0], ["armsOut", 0, 0], ["headHappy", 0, 0], ["hipsHappy", 0, 0], ["hipsHappy", 1, 0], ["cheer", 0, -12]] },
            { name: "Griddy", ms: 120, steps: [["walk0", 0, 0], ["walk1", 0, -6], ["walk2", 0, 0], ["walk3", 0, -6]] },
            { name: "Moonwalk 🌙", ms: 140, moon: true, steps: [["walk0", 0, 0], ["walk1", 0, 0], ["walk2", 0, 0], ["walk3", 0, 0]] },
        ]
        property int danceStep: 0
        function startDance(i) {
            if (mode === "air" || mode === "drag") { pendingDance = i; return; }
            cancelAll();
            danceI = ((i % dances.length) + dances.length) % dances.length;
            mode = "dance"; danceStep = -1;
            const d = dances[danceI];
            auraOn = !!d.aura || Math.random() < 0.3;
            danceT.interval = d.ms; danceT.restart(); danceT.triggered();
            say("♪ " + d.name + " ♪");
            after(15000, stopDance);
        }
        function stopDance() {
            const wasDancing = mode === "dance";
            danceT.stop(); auraOn = false; danceMirror = false; danceDy = 0; danceI = -1;
            if (!wasDancing) return;
            mode = "act";
            loop(["cheer", "idle"], 220);
            say(root.pick(danceEndPhrases));
            after(1600, () => { setPose("idle"); done(); });
        }
        Timer {
            id: danceT; repeat: true
            onTriggered: {
                if (win.danceI < 0) { stop(); return; }
                const d = win.dances[win.danceI];
                win.danceStep = (win.danceStep + 1) % d.steps.length;
                const st = d.steps[win.danceStep];
                win.pose = st[0]; win.danceMirror = st[1] === 1; win.danceDy = st[2];
                boomPulse.restart();
            }
        }

        // ---------- bulle ----------
        function say(text) { bubble.full = text; bubble.shown = ""; typer.restart(); bubbleHide.interval = 2500 + text.length * 70; bubbleHide.restart(); }
        Timer { id: bubbleHide; onTriggered: bubble.full = "" }
        Timer {
            id: typer; interval: 30; repeat: true
            onTriggered: {
                if (bubble.shown.length < bubble.full.length) bubble.shown = bubble.full.slice(0, bubble.shown.length + 1);
                else stop();
            }
        }

        Connections {
            target: root
            function onNewDay() { greet.restart(); }
            function onClockLiveMoved(dx, dy) {
                if (win.surfId === "clock" && win.mode !== "drag" && win.mode !== "air") {
                    const sp = Math.hypot(root.clockVX, root.clockVY);
                    if (sp > 2200) {      // trop rapide : il tombe
                        win.cancelAll(); win.surfId = ""; win.mode = "air"; win.thrown = true;
                        win.vx = root.clockVX * 0.5; win.vy = Math.min(0, root.clockVY * 0.4);
                        win.setPose("fall"); win.say("WAAAAH !!");
                        return;
                    }
                    win.bx += dx; win.by = root.clock.y + 14;
                    if (sp > 900 && Math.random() < 0.05) win.say(root.pick(["Wooo !", "Doucement !!", "Taxi !", "Yihaaa !"]));
                    return;
                }
                win.clockCollide();
            }
            function onClockChanged() {   // l'horloge a bougé sous ses pieds
                if (win.surfId !== "clock" || win.mode === "drag") return;
                const s = win.surf("clock");
                if (!root.clock || !root.clock.free || win.bx < s.x1 - 10 || win.bx > s.x2 + 10 || Math.abs(win.by - s.y) > 4) {
                    if (rideAnim.running) { win.by = s.y; return; }
                    win.cancelAll(); win.mode = "air"; win.surfId = ""; win.vx = 0; win.vy = 0; win.setPose("fall");
                }
            }
        }
        Timer { // bonjour + phrase du jour
            id: greet; interval: 2500
            onTriggered: {
                if (win.mode === "drag" || win.mode === "air") { restart(); return; }
                win.cancelAll(); win.mode = "act";
                win.loop(["wave0", "wave1"], 220);
                win.say(root.dailyPhrase());
                win.after(3500, () => { win.setPose("idle"); win.done(); });
            }
        }
        Component.onCompleted: {
            bx = 1500;
            by = root.scene ? root.scene.ground : 988;
            greet.restart();
        }

        // qs -c buddy ipc call buddy act <code|coffee|sleep|wave|hop|pipe|clock|stomp|bump|bug|poke|drop>
        IpcHandler {
            target: "buddy"
            function act(name: string): string {
                if (win.mode === "drag" || (win.mode === "air" && name !== "drop")) return "occupé (en l'air)";
                win.cancelAll();
                win.mode = "act";
                const m = { code: win.code, coffee: win.coffee, sleep: win.sleep, wave: win.wave, hop: win.hop,
                    pipe: win.takePipe, dance: () => win.startDance(win.danceI >= 0 ? win.danceI + 1 : Math.floor(Math.random() * win.dances.length)),
                    gun: win.threaten, clock: win.climbClock, stomp: win.stompClock, bump: win.bumpClock,
                    bug: () => { bug.spawn(); win.chaseBug(); }, poke: () => win.poke(false),
                    drop: () => { win.by = 200; win.bx = 960; win.vy = 0; win.vx = 300; win.surfId = ""; win.thrown = true; win.bounced = false; win.mode = "air"; win.setPose("fall"); } };
                if (!m[name]) return "inconnu : " + Object.keys(m).join(", ");
                m[name]();
                return "ok";
            }
            function say(text: string): void { win.say(text); }
            function dance(name: string): string {
                const i = win.dances.findIndex(d => d.name.toLowerCase().includes(name.toLowerCase()));
                if (i < 0) return "danses : " + win.dances.map(d => d.name).join(", ");
                win.startDance(i); return "ok";
            }
            function state(): string { return JSON.stringify({ mode: win.mode, pose: win.pose, surf: win.surfId, x: Math.round(win.bx), y: Math.round(win.by) }); }
        }

        // =================== RENDU ===================

        // lucioles (mouvement saccadé façon pixel-art, peu coûteux)
        Repeater {
            model: 8
            Rectangle {
                id: fly
                required property int index
                property real baseX: [180, 420, 700, 980, 1250, 1500, 1700, 300][index]
                property real baseY: [880, 700, 900, 760, 880, 400, 930, 560][index]
                width: 4; height: 4
                color: "#d9ff9e"
                x: baseX; y: baseY
                opacity: 0.0
                Timer {
                    interval: 140 + fly.index * 13; repeat: true; running: win.running
                    property real t: Math.random() * 100
                    onTriggered: {
                        t += 0.14;
                        fly.x = Math.round((fly.baseX + 40 * Math.sin(t * 0.5 + fly.index) + 18 * Math.sin(t * 1.3)) / 4) * 4;
                        fly.y = Math.round((fly.baseY + 22 * Math.sin(t * 0.7 + fly.index * 2)) / 4) * 4;
                        fly.opacity = Math.max(0, Math.sin(t * 0.9 + fly.index)) * 0.85;
                    }
                }
            }
        }

        // scintillement des cristaux
        Item {
            id: glint
            width: 12; height: 12
            opacity: 0
            Rectangle { x: 4; width: 4; height: 12; color: "white" }
            Rectangle { y: 4; width: 12; height: 4; color: "white" }
            SequentialAnimation {
                id: glintAnim
                NumberAnimation { target: glint; property: "opacity"; to: 0.9; duration: 220 }
                NumberAnimation { target: glint; property: "opacity"; to: 0; duration: 420 }
            }
            Timer {
                interval: 5000; repeat: true; running: win.running && root.scene !== null
                onTriggered: {
                    interval = 3000 + Math.random() * 6000;
                    const c = root.pick(root.scene.crystals);
                    glint.x = Math.round((c[0] + Math.random() * c[2]) / 4) * 4 - 6;
                    glint.y = Math.round((c[1] + Math.random() * c[3] * 0.6) / 4) * 4 - 6;
                    glintAnim.restart();
                }
            }
        }

        // étoile filante (rare)
        Rectangle {
            id: shooting
            width: 64; height: 4; color: "#e8e4ff"; opacity: 0; rotation: 20
            ParallelAnimation {
                id: shootAnim
                NumberAnimation { target: shooting; property: "x"; from: shooting.sx; to: shooting.sx + 520; duration: 800; easing.type: Easing.InQuad }
                NumberAnimation { target: shooting; property: "y"; from: shooting.sy; to: shooting.sy + 190; duration: 800; easing.type: Easing.InQuad }
                SequentialAnimation {
                    NumberAnimation { target: shooting; property: "opacity"; to: 0.8; duration: 200 }
                    NumberAnimation { target: shooting; property: "opacity"; to: 0; duration: 600 }
                }
            }
            property real sx: 0
            property real sy: 0
            Timer {
                interval: 90000; repeat: true; running: win.running
                onTriggered: { interval = 60000 + Math.random() * 180000; shooting.sx = 200 + Math.random() * 1000; shooting.sy = 60 + Math.random() * 160; shootAnim.restart(); }
            }
        }

        // ----- le bug -----
        Item {
            id: bug
            property bool active: false
            property string surfId: "ground"
            property real x0: 0
            property real bxPos: 0
            property int bdir: 1
            property bool dead: false
            property int f: 0
            width: 48; height: 28
            visible: active
            z: 2
            Image {
                anchors.fill: parent
                source: Qt.resolvedUrl("assets/props.png")
                sourceClipRect: Qt.rect(24 + (bug.dead ? 2 : bug.f) * 12, 0, 12, 7)
                smooth: false
                mirror: bug.bdir < 0
            }
            Binding on x { value: bug.bxPos - 24 }
            Binding on y { value: win.surf(bug.surfId).y - 28 }
            function step(dt) {
                if (dead) return;
                const s = win.surf(surfId);
                bxPos += bdir * 35 * dt;
                if (bxPos < s.x1 + 10 || bxPos > s.x2 - 10) { bdir = -bdir; bxPos = Math.max(s.x1 + 10, Math.min(s.x2 - 10, bxPos)); }
            }
            function spawn() {
                const ss = win.surfaces().filter(s => s.pipe === undefined && s.id !== "clock");
                const s = root.pick(ss);
                surfId = s.id; bxPos = root.rand(s.x1 + 30, s.x2 - 30); bdir = Math.random() < 0.5 ? 1 : -1;
                dead = false; active = true;
            }
            function squash() { dead = true; bugGone.restart(); }
            Timer { interval: 220; repeat: true; running: bug.active && !bug.dead && win.running; onTriggered: bug.f = 1 - bug.f }
            Timer { id: bugGone; interval: 1200; onTriggered: bug.active = false }
            Timer { // un bug apparaît de temps en temps
                interval: 120000; repeat: true; running: win.running
                onTriggered: { interval = 150000 + Math.random() * 240000; if (!bug.active) bug.spawn(); }
            }
        }

        // ----- le bonhomme -----
        Item {
            id: buddy
            width: Fr.W * win.sc
            height: Fr.H * win.sc
            x: Math.round(win.bx - width / 2)
            y: Math.round(win.by - 124 + win.danceDy)
            z: 3
            visible: !win.hidden
            property real tiltS: win.tilt
            Behavior on tiltS { NumberAnimation { duration: 120 } }
            transform: [
                Scale { origin.x: buddy.width / 2; origin.y: buddy.height; yScale: win.squash; xScale: 2 - win.squash },
                Rotation { origin.x: buddy.width / 2; origin.y: win.spin !== 0 ? buddy.height / 2 : 8; angle: buddy.tiltS + win.wiggle + win.spin },
                Translate { x: win.shakeX }
            ]

            // ombre au sol
            Rectangle {
                width: 44; height: 8; radius: 4; color: "black"; opacity: win.mode === "air" || win.mode === "drag" ? 0 : 0.3
                x: (buddy.width - width) / 2; y: 120
            }
            Item { // découpe (pour rentrer dans le tuyau)
                width: parent.width
                height: Math.max(0, Math.min(parent.height, win.clipY - buddy.y))
                clip: true
                Image {
                    width: buddy.width; height: buddy.height
                    source: Qt.resolvedUrl("assets/sprite.png")
                    sourceClipRect: Qt.rect((Fr.F[win.pose] ?? 4) * Fr.W, 0, Fr.W, Fr.H)
                    smooth: false
                    mirror: (win.dir < 0) !== win.danceMirror
                }
            }

            // zone cliquable (seule partie qui capte la souris)
            MouseArea {
                id: hit
                x: 16; y: 4; width: 64; height: 120
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: win.mode === "drag" ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                property point start
                property bool dragging: false
                property real lastT: 0
                property real lastX: 0
                property real lastY: 0
                property real velX: 0
                property real velY: 0
                onPressed: mouse => {
                    const p = mapToItem(win.contentItem, mouse.x, mouse.y);
                    start = p; dragging = false;
                    lastX = p.x; lastY = p.y; lastT = Date.now(); velX = 0; velY = 0;
                }
                onPositionChanged: mouse => {
                    if (!(mouse.buttons & Qt.LeftButton)) return;
                    const p = mapToItem(win.contentItem, mouse.x, mouse.y);
                    if (!dragging && Math.hypot(p.x - start.x, p.y - start.y) > 8) {
                        dragging = true;
                        const wasSleeping = win.pose === "sleep0" || win.pose === "sleep1";
                        const armed = win.gunOut;
                        win.cancelAll(); win.mode = "drag"; win.surfId = "";
                        win.thrown = false; win.bounced = false; spinAnim.stop(); win.spin = 0;
                        win.annoy(1); win.dragStart = Date.now();
                        win.loop(["dangle0", "dangle2", "dangle1", "dangle2"], 150);
                        win.say(armed ? "Repose-moi ou je tire !!" : wasSleeping ? "Hein ?! Pose-moi !!" : root.pick(win.holdPhrases));
                        dragTalk.restart();
                    }
                    if (!dragging) return;
                    const now = Date.now(), dt = Math.max(1, now - lastT) / 1000;
                    velX = velX * 0.6 + ((p.x - lastX) / dt) * 0.4;
                    velY = velY * 0.6 + ((p.y - lastY) / dt) * 0.4;
                    lastX = p.x; lastY = p.y; lastT = now;
                    win.bx = p.x;
                    win.by = Math.min(win.surfaces()[0].y, p.y + 112);
                    win.tilt = Math.max(-35, Math.min(35, -velX / 45));
                }
                onReleased: mouse => {
                    if (dragging) {
                        dragging = false;
                        win.tilt = 0; dragTalk.stop();
                        win.vx = Math.max(-1800, Math.min(1800, velX));
                        win.vy = Math.max(-1600, Math.min(1200, velY));
                        win.setPose("fall");
                        win.thrown = true; win.bounced = false;
                        win.mode = "air";
                    } else {
                        win.poke(mouse.button === Qt.RightButton);
                    }
                }
            }
        }
        // tant qu'on le tient : il gigote et parle
        Timer {
            id: dragTalk; interval: 2300; repeat: true; running: false
            onTriggered: {
                if (win.mode !== "drag") { stop(); return; }
                const held = (Date.now() - win.dragStart) / 1000;
                win.say(root.pick(win.by < 450 ? win.highPhrases : held > 9 ? win.boredPhrases : win.holdPhrases));
            }
        }
        Timer {
            interval: 70; repeat: true; running: win.mode === "drag"
            property real t: 0
            onTriggered: { t += 0.07; win.wiggle = 9 * Math.sin(t * 14); win.tilt *= 0.85; }
            onRunningChanged: if (!running) win.wiggle = 0
        }
        NumberAnimation { id: spinAnim; target: win; property: "spin"; from: 0; to: 360; duration: 650 }
        SequentialAnimation {
            id: flatAnim
            NumberAnimation { target: win; property: "squash"; to: 0.4; duration: 80 }
            PauseAnimation { duration: 1300 }
            NumberAnimation { target: win; property: "squash"; to: 1; duration: 350; easing.type: Easing.OutBack }
        }
        property real shakeX: 0
        SequentialAnimation {
            id: shakeAnim
            NumberAnimation { target: win; property: "shakeX"; to: 6; duration: 40 }
            NumberAnimation { target: win; property: "shakeX"; to: -6; duration: 60 }
            NumberAnimation { target: win; property: "shakeX"; to: 4; duration: 60 }
            NumberAnimation { target: win; property: "shakeX"; to: 0; duration: 60 }
        }
        SequentialAnimation {
            id: squashAnim
            NumberAnimation { target: win; property: "squash"; to: 0.8; duration: 70 }
            NumberAnimation { target: win; property: "squash"; to: 1; duration: 220; easing.type: Easing.OutBack }
        }

        // tuyaux (devant le bonhomme pour qu'il disparaisse dedans)
        Repeater {
            model: root.scene ? root.scene.pipes : []
            Image {
                required property var modelData
                z: 4
                x: modelData.x; y: modelData.y - 96
                width: 96; height: 96
                source: Qt.resolvedUrl("assets/props.png")
                sourceClipRect: Qt.rect(0, 0, 24, 24)
                smooth: false
            }
        }

        // étoiles quand il tombe fort
        Item {
            id: starsItem
            z: 5
            x: buddy.x + buddy.width / 2; y: buddy.y + 6
            opacity: 0
            property real a: 0
            Repeater {
                model: 3
                Text {
                    required property int index
                    text: "✦"; color: "#ffe680"; font.pixelSize: 16
                    x: 30 * Math.cos(starsItem.a + index * 2.09) - 8
                    y: 8 * Math.sin(starsItem.a + index * 2.09) - 8
                }
            }
            ParallelAnimation {
                id: stars
                NumberAnimation { target: starsItem; property: "a"; from: 0; to: 12; duration: 2400 }
                SequentialAnimation {
                    NumberAnimation { target: starsItem; property: "opacity"; to: 1; duration: 150 }
                    PauseAnimation { duration: 1900 }
                    NumberAnimation { target: starsItem; property: "opacity"; to: 0; duration: 350 }
                }
            }
        }

        // particules : code, vapeur, Zzz
        Component {
            id: particle
            Text {
                id: pt
                z: 5
                property int sz: 15
                font.family: "JetBrains Mono"; font.pixelSize: sz; font.bold: true
                property real dx: 0
                ParallelAnimation {
                    running: true
                    NumberAnimation { target: pt; property: "y"; to: pt.y - 70; duration: 1800; easing.type: Easing.OutQuad }
                    NumberAnimation { target: pt; property: "x"; to: pt.x + pt.dx; duration: 1800 }
                    SequentialAnimation {
                        NumberAnimation { target: pt; property: "opacity"; from: 0; to: 0.85; duration: 300 }
                        NumberAnimation { target: pt; property: "opacity"; to: 0; duration: 1500 }
                    }
                    onFinished: pt.destroy()
                }
            }
        }
        Timer {
            id: emitter
            property string kind: "code"
            interval: kind === "z" ? 1500 : kind === "steam" ? 500 : 1100
            repeat: true
            running: false
            onTriggered: {
                if (!win.running) return;
                const k = kind;
                const t = k === "code" ? root.pick(["{ }", "</>", "01", ";", "( )", "=>", "#!", "++", "git", "fn"])
                        : k === "z" ? root.pick(["z", "Z", "z"]) : "~";
                const col = k === "code" ? root.pick(["#9ee6ff", "#cdb4ff", "#9df0b0", "#ffb3de"]) : k === "z" ? "#cdd6ff" : "#e8e8f0";
                particle.createObject(win.contentItem, {
                    text: t, color: col,
                    x: win.bx + (k === "z" ? 16 * win.dir : k === "steam" ? 20 * win.dir - 6 : root.rand(-30, 20)),
                    y: win.by - (k === "z" ? 120 : k === "steam" ? 96 : 100),
                    dx: k === "z" ? 24 * win.dir : root.rand(-14, 14),
                    sz: k === "z" ? root.pick([14, 18, 22]) : 15
                });
            }
        }

        // ----- radio : bouton danse -----
        Item {
            id: boombox
            z: 2
            width: 80; height: 48
            x: 660; y: (root.scene ? root.scene.ground : 988) - 48
            Image {
                anchors.fill: parent
                source: Qt.resolvedUrl("assets/props.png")
                sourceClipRect: Qt.rect(0, 26, 20, 12)
                smooth: false
                transform: Scale { id: boomScale; origin.x: 40; origin.y: 48; yScale: 1 }
            }
            SequentialAnimation {
                id: boomPulse
                NumberAnimation { target: boomScale; property: "yScale"; to: 1.12; duration: 60 }
                NumberAnimation { target: boomScale; property: "yScale"; to: 1; duration: 120 }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: -22
                visible: win.auraTotal > 0 || bmouse.containsMouse
                text: bmouse.containsMouse && win.mode !== "dance" ? "▶ danse" : "AURA " + win.auraTotal
                color: "#e6d2ff"; opacity: 0.8
                font.family: "JetBrains Mono"; font.pixelSize: 12; font.bold: true
            }
            MouseArea {
                id: bmouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) { win.stopDance(); return; }
                    win.lastInteraction = Date.now();
                    win.startDance(win.danceI >= 0 ? win.danceI + 1 : Math.floor(Math.random() * win.dances.length));
                }
            }
            Timer { // notes de musique
                interval: 600; repeat: true; running: win.mode === "dance" && win.running
                onTriggered: particle.createObject(win.contentItem, {
                    text: root.pick(["♪", "♫", "♬"]), color: root.pick(["#ffb3de", "#cdb4ff", "#9ee6ff"]),
                    x: boombox.x + root.rand(10, 60), y: boombox.y - 10, dx: root.rand(-30, 30), sz: 20 })
            }
        }

        // ----- aura (battle d'aura) -----
        Item {
            id: aura
            z: 2
            visible: win.auraOn
            x: buddy.x; y: buddy.y
            width: buddy.width; height: buddy.height
            Rectangle { // halo doux
                anchors.centerIn: parent
                width: 120; height: 150; radius: 60
                color: "#8a5cff"; opacity: 0.16 + 0.06 * Math.sin(auraFlames.t * 3)
            }
            Repeater {
                model: 10
                Rectangle {
                    required property int index
                    width: 8; height: 8
                    color: ["#b388ff", "#e040fb", "#7c4dff", "#ea80fc"][index % 4]
                    property real ph: index * 0.63
                    property real life: ((auraFlames.t * 60 + index * 15) % 140)
                    x: Math.round((48 + 40 * Math.cos(ph * 2.3) + 6 * Math.sin(auraFlames.t * 4 + index)) / 4) * 4 - 4
                    y: Math.round((128 - life) / 4) * 4
                    opacity: 0.8 * (1 - life / 140)
                }
            }
            Timer {
                id: auraFlames
                property real t: 0
                interval: 90; repeat: true; running: win.auraOn && win.running
                onTriggered: t += 0.09
            }
            Timer { // +aura
                interval: 1400; repeat: true; running: win.auraOn && win.running
                onTriggered: {
                    const n = root.pick([100, 500, 1000, 1000, 9000]);
                    win.auraTotal += n;
                    particle.createObject(win.contentItem, { text: "+" + n + " aura", color: root.pick(["#ffe680", "#e6c3ff"]),
                        x: win.bx + root.rand(-60, 30), y: win.by - 140, dx: root.rand(-20, 20), sz: 14 });
                }
            }
        }

        // ----- drapeau BANG du faux pistolet -----
        Item {
            id: bangFlag
            z: 7
            x: win.bx - 4; y: win.by - 100
            scale: 0; transformOrigin: Item.Bottom
            Rectangle { x: 2; y: -40; width: 4; height: 40; color: "#5a4636" }
            Rectangle {
                x: 6; y: -42; width: 76; height: 28; color: "#fff4e0"; border.color: "#1a1420"; border.width: 3
                Text { anchors.centerIn: parent; text: "BANG!"; color: "#e0304a"; font.family: "JetBrains Mono"; font.pixelSize: 16; font.bold: true }
            }
            SequentialAnimation {
                id: bangAnim
                NumberAnimation { target: bangFlag; property: "scale"; from: 0; to: 1; duration: 220; easing.type: Easing.OutBack }
                PauseAnimation { duration: 2200 }
                NumberAnimation { target: bangFlag; property: "scale"; to: 0; duration: 200 }
            }
        }

        // ----- bulle -----
        Item {
            id: bubble
            z: 6
            property string full: ""
            property string shown: ""
            visible: opacity > 0
            opacity: full.length > 0 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            width: Math.min(340, bubbleText.implicitWidth + 28)
            height: bubbleText.implicitHeight + 20
            x: Math.round(Math.max(10, Math.min(win.width - width - 10, win.bx - width / 2)))
            y: Math.round(Math.max(48, buddy.y - height - 4))

            Rectangle {
                id: tail
                width: 14; height: 14; rotation: 45
                color: "#211a2b"; border.color: "#cdb4ff"; border.width: 2
                x: Math.max(12, Math.min(bubble.width - 26, win.bx - bubble.x - 7))
                y: bubble.height - 8
            }
            Rectangle { anchors.fill: parent; radius: 12; color: "#211a2b"; border.color: "#cdb4ff"; border.width: 2 }
            Rectangle { width: 20; height: 4; color: "#211a2b"; x: tail.x - 3; y: bubble.height - 3 }
            Text {
                id: bubbleText
                anchors.centerIn: parent
                width: Math.min(implicitWidth, 312)
                text: bubble.shown
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                color: "#f0e8ff"
                font.family: "JetBrains Mono"; font.pixelSize: 14; font.weight: Font.Medium
            }
        }
    }
}
