// Clawdmeter desk case for the `devkitc_st7796` port:
// YD-ESP32-S3 (ESP32-S3-DevKitC-1 clone) + LCDwiki MSP4031 4.0" ST7796S / FT6336U.
//
// Two printed parts, no supports needed:
//   shell — front bezel + walls + tilt wedge. Print front face down.
//   lid   — back cover. The ESP32 cradle, display pushers and the BOOT / RST
//           flex keys hang off its inner face. Print outer face down.
// Plus `fit_test`, a 30-minute slice of the bezel + display pocket. Print it
// first and check the display drops in and the window lines up with the
// picture before committing to the full shell.
// Optional `stand`: a separate cradle that reclines the case further than the
// wedge's 15° (`stand_angle`, 20-40°). The case drops into a V-shaped seat,
// rests its back on two uprights, and a small lip stops it sliding forward.
// Print it upright.
// Back-cover art: the Fluent Emoji avocado (art/, MIT, Microsoft), either
// engraved as outlines (any printer) or as flush colour inlays (`inlay_*`
// parts, for a multi-colour printer). The SVGs load relative to this file, so
// `include` it only from this folder.
//
// The lid snaps on with four clips (no screws); `lid_fix` adds M3 screw holes
// if you want them. Hardware: 1 mm foam tape for the pusher tips,
// double-sided tape under the ESP32.
//
// Frame: seen from the front, x = right, y = up, z = toward the viewer.
// The front face is z = 0 and the case extends back into -z; "depth" (d)
// below is measured from the front face, so a feature at depth d sits at z = -d.
//
// Every dimension marked "measure" is from a datasheet, not from your parts.
// Check them with calipers and re-export if they differ.

part = "assembly"; // [assembly, exploded, on_stand, shell, lid, fit_test, stand, inlay_back, inlay_skin, inlay_flesh, inlay_pit]

/* [Display: MSP4031 (LCDwiki 4.0in capacitive, ST7796S)] */
disp_w      = 108.00; // PCB long side (x). Datasheet.
disp_h      = 60.88;  // PCB short side (y). Datasheet.
disp_stack  = 5.1;    // LCD + touch glass above the PCB front face. A side photo of a real
                      // MSP4031 put it at ~3.2x the PCB thickness (1.6 mm): ~5.1 mm.
disp_pcb_t  = 1.6;
disp_hole_in = 3.0;   // mounting-hole centres from PCB edges (3.2 mm holes)
aa_w        = 83.52;  // active area
aa_h        = 55.68;
aa_left     = 9.36;   // measure: active area left edge from PCB left edge (the edge away from header J2)
win_margin  = 1.0;    // window is this much larger than the active area, top and bottom
win_margin_x = 1.5;   // ...and at the left/right ends, where aa_left is least certain
                      // (a ruler photo of a real MSP4031 put it at ~9-10 mm)
disp_back   = 2.5;    // parts on the back of the display PCB (SD slot etc.)

/* [MCU: YD-ESP32-S3 (vcc-gnd dimension drawing)] */
esp_len     = 57.15;  // PCB, USB end to antenna end
esp_w       = 27.94;
esp_pcb_t   = 1.6;
esp_ant     = 6.24;   // WROOM-1 antenna overhang past the PCB end
esp_clear   = 6.0;    // lid inner face to the ESP32 component side
wroom_h     = 3.2;
usbc_h      = 3.3;
usbc_pitch  = 11.1;   // centre-to-centre of the two USB-C ports
boot_x      = 28.4;   // BOOT centre from the USB end of the PCB
boot_y      = 5.2;    // BOOT offset from the board centre line, + = toward the case top
rst_x       = 33.7;   // RST centre from the USB end (same side line as BOOT)
rst_y       = 5.2;
btn_h       = 2.5;    // measure: tact switch height above the PCB
nub_gap     = 0.6;    // key nub clearance. Too small and BOOT/RST is held at power-up (dark screen).
wire_space  = 24.5;   // dupont housings + wire bend between the boards. Shorter wiring = thinner case.

/* [Case] */
wall        = 2.4;
bezel_t     = 2.0;
lid_t       = 2.4;
margin      = 4.0;    // gap around the display that houses the lid screw bosses
clear       = 0.5;    // display pocket clearance per side
corner_r    = 4.0;
tilt        = 15;     // degrees the screen leans back; 0 = plain upright box
chamfer     = 0.8;    // front edge chamfer (also hides elephant's foot)
boss_d      = 6.4;
pilot_d     = 2.6;    // M3 pilot for self-tapping / thread-forming screws
screw_d     = 3.4;    // M3 clearance in the lid
pusher_d    = 6.5;
pusher_gap  = 0.8;    // filled by 1 mm foam tape on each pusher tip
usb_slot_w  = 24.5;   // covers both USB-C ports
usb_slot_h  = 9.5;
button_style = "flex"; // [flex, hole, none] how BOOT and RST are reached through the lid
side_labels = true;   // engrave UART / USB next to the port slot

/* [Lid fixing] */
lid_fix     = "snap"; // [snap, screws, both] snap = four press-on clips, no screws
snap_w      = 10;     // clip width
snap_len    = 14;     // clip arm length; longer = softer
snap_t      = 1.5;    // clip arm thickness
snap_hook   = 0.9;    // how far the hook sticks out
snap_gap    = 0.2;    // arm to wall

/* [Back-cover art] */
lid_art     = "avocado"; // [avocado, text, none]
art_style   = "engrave"; // [engrave, inlay] engrave = outline grooves, any printer; inlay = flush colour pockets + inlay_* parts
art_size    = 56;     // mm for the emoji's 32-unit box; the avocado itself comes out ~49 mm
art_x       = 80;     // art centre (case x; seen from behind this is left of centre, clear of the keys)
art_y       = 37;
art_depth   = 0.6;    // groove / inlay depth
art_groove  = 0.8;    // outline groove width
lid_text    = "Clawdmeter";  // used when lid_art = "text"

/* [Stand] */
stand_angle  = 30;    // [20:1:40] screen recline on the stand (the wedge alone gives `tilt`)
stand_seat   = 3;     // plastic under the case's back-bottom edge
stand_rest_h = 30;    // how far up the back cover the uprights reach
stand_rest_t = 4;     // upright thickness behind the back cover
stand_lip_h  = 3;     // front lip height, up the case front
stand_lip_t  = 3;
stand_foot   = 22;    // base run behind the uprights (resists tipping when you tap the screen)
stand_cheek_w = 12;   // width of each side frame
stand_cheek_in = 9;   // side frame inset from the case sides (clears the lid screws)
stand_bar_d  = 10;    // front / back tie bars
stand_bar_h  = 4;
stand_clear  = 0.3;

$fn = 48;
eps = 0.01;

// ---------------------------------------------------------------- derived
cav_w = disp_w + 2 * clear + 2 * margin;
cav_h = disp_h + 2 * clear + 2 * margin;
W = cav_w + 2 * wall;
H = cav_h + 2 * wall;

px0 = wall + margin + clear;          // display PCB lower-left corner (front view)
py0 = wall + margin + clear;

d_pcb_front = bezel_t + disp_stack;
d_pcb_back  = d_pcb_front + disp_pcb_t;
d_frame     = d_pcb_front + 1.0;      // pocket walls stop partway up the PCB edge
D  = d_pcb_back + disp_back + wire_space + esp_pcb_t + esp_clear;   // shell depth
DT = D + lid_t;                       // overall depth
chin = tan(tilt) * DT;                // wedge height under the front edge

// desk plane: y of the case bottom at depth d
function floor_y(d) = -chin * (1 - d / DT);

boss_in = 1.6;                        // boss centre from the cavity walls
boss_pts = [[wall + boss_in, wall + boss_in], [W - wall - boss_in, wall + boss_in],
            [wall + boss_in, H - wall - boss_in], [W - wall - boss_in, H - wall - boss_in]];
hole_pts = [[px0 + disp_hole_in, py0 + disp_hole_in],
            [px0 + disp_w - disp_hole_in, py0 + disp_hole_in],
            [px0 + disp_hole_in, py0 + disp_h - disp_hole_in],
            [px0 + disp_w - disp_hole_in, py0 + disp_h - disp_hole_in]];

ex0 = wall + 1.0;                     // USB end of the ESP32 PCB (USB-C faces the left wall)
ey  = H / 2;                          // ESP32 centre line
d_comp = D - esp_clear;               // ESP32 component side (faces the lid)
d_usb  = d_comp + usbc_h / 2;         // USB-C port centre

bx = ex0 + boot_x;                    // BOOT button
by = ey + boot_y;
rx = ex0 + rst_x;                     // RST button
ry = ey + rst_y;
// Flex keys. BOOT and RST sit 5.3 mm apart, too close for two keys side by
// side, so they interlock: BOOT's key hangs down from above, RST's reaches up
// from below, and the two tips meet across the buttons. Local key frame:
// u across the key (+ = toward the other button), v along it (+ = toward the
// hinge), nub at u = v = 0.
key_len = 18;  key_t = 1.2;  key_gap = 1.0;  key_tip = 2.0;  key_out = 6;
key_in  = (abs(rx - bx) - key_gap) / 2;
keys = [[bx, by, sign(rx - bx), 1, "BOOT"], [rx, ry, sign(bx - rx), -1, "RST"]];

// Sanity checks: the lid screw bosses must clear the display as it drops in.
assert(norm([margin - boss_in, margin - boss_in]) > boss_d / 2,
       "margin too small: screw bosses would block the display");
assert(d_frame <= d_pcb_back, "disp_stack/disp_pcb_t mismatch");

// ---------------------------------------------------------------- helpers
// Geometry between depths d0 < d1.
module slab(d0, d1) translate([0, 0, -d1]) linear_extrude(d1 - d0) children();

module rrect(x0, y0, x1, y1, r) {
    rr = min(r, (x1 - x0) / 2 - eps, (y1 - y0) / 2 - eps);
    if (rr <= 0) translate([x0, y0]) square([x1 - x0, y1 - y0]);
    else translate([x0 + rr, y0 + rr]) offset(r = rr) square([x1 - x0 - 2 * rr, y1 - y0 - 2 * rr]);
}

module tube(x, y, d0, d1, od, id = 0) translate([x, y, 0]) slab(d0, d1) difference() {
    circle(d = od);
    if (id > 0) circle(d = id);
}

// ---------------------------------------------------------------- shell
module outer_body() hull() {
    slab(0, eps) rrect(chamfer, floor_y(0) + chamfer, W - chamfer, H - chamfer, corner_r - chamfer);
    slab(chamfer, chamfer + eps) rrect(0, floor_y(chamfer), W, H, corner_r);
    slab(D - eps, D) rrect(0, floor_y(D), W, H, corner_r);
}

module window() {
    wx0 = px0 + aa_left - win_margin_x;
    wy0 = py0 + (disp_h - aa_h) / 2 - win_margin;
    wx1 = wx0 + aa_w + 2 * win_margin_x;
    wy1 = wy0 + aa_h + 2 * win_margin;
    ch = min(1.2, bezel_t - 0.6);     // 45° lead-in so fingers reach the screen edge
    slab(-1, bezel_t + 1) rrect(wx0, wy0, wx1, wy1, 1);
    hull() {
        slab(-1 - eps, -1) rrect(wx0 - ch - 1, wy0 - ch - 1, wx1 + ch + 1, wy1 + ch + 1, 1 + ch + 1);
        slab(ch, ch + eps) rrect(wx0, wy0, wx1, wy1, 1);
    }
}

module usb_slot() {
    r = 2;
    d0 = d_usb - usb_slot_h / 2;      // closed (front) end; the slot is open to the back edge
    hull() {
        for (s = [-1, 1])
            translate([-1, ey + s * (usb_slot_w / 2 - r), -(d0 + r)]) rotate([0, 90, 0])
                cylinder(r = r, h = wall + 2);
        translate([-1, ey - usb_slot_w / 2, -(D + 1)]) cube([wall + 2, usb_slot_w, 1]);
    }
}

// Engraving on the left wall, readable from the left: +z is the reader's right.
module side_label(txt, y, u0) multmatrix([[0, 0, -1, 0], [0, 1, 0, 0], [1, 0, 0, 0], [0, 0, 0, 1]])
    translate([u0, y, -0.5]) linear_extrude(2)
        text(txt, size = 3, font = "Liberation Sans:style=Bold", halign = "left", valign = "center");

module shell() difference() {
    union() {
        difference() {
            outer_body();
            slab(d_frame, D + 1) rrect(wall, wall, W - wall, H - wall, 1);
            slab(bezel_t, d_frame + eps)
                translate([px0 - clear, py0 - clear]) square([disp_w + 2 * clear, disp_h + 2 * clear]);
            window();
        }
        for (p = boss_pts) tube(p[0], p[1], d_frame, D, boss_d);
    }
    for (p = boss_pts) tube(p[0], p[1], D - 12, D + 1, pilot_d);
    usb_slot();
    if (lid_fix != "screws") {
        for (x = snap_xs) { snap_recess(x); translate([0, H, 0]) mirror([0, 1, 0]) snap_recess(x); }
        pry_notch();
    }
    if (side_labels) {
        u0 = -(d_usb - usb_slot_h / 2) + 1.5;
        side_label("UART", ey + usbc_pitch / 2, u0);   // CH343 serial port (toward the top)
        side_label("USB",  ey - usbc_pitch / 2, u0);   // native USB
    }
}

// ---------------------------------------------------------------- lid
module lid_body() hull() {
    slab(D, D + eps) rrect(0, floor_y(D), W, H, corner_r);
    slab(DT - eps, DT) rrect(0, floor_y(DT), W, H, corner_r);
}

// Engraving on the lid's outer face, readable from behind (mirrored in x).
module lid_label(txt, x, y, size) translate([x, y, 0]) slab(DT - 0.6, DT + 1) mirror([1, 0, 0])
    text(txt, size = size, font = "Liberation Sans:style=Bold", halign = "center", valign = "center");

// ---- back-cover art
// Fluent Emoji "Avocado" (flat), split into its four colour layers in paint
// order; each later layer covers the ones before it.
art_layers = ["art/avocado_1_back.svg", "art/avocado_2_skin.svg",
              "art/avocado_3_flesh.svg", "art/avocado_4_pit.svg"];
art_colors = ["#44911B", "#008463", "#C3EF3C", "#6D4534"];
n_art = len(art_layers);

module art_layer(i) import(art_layers[i]);
// The visible part of colour layer i.
module art_region(i) difference() {
    art_layer(i);
    if (i < n_art - 1) for (j = [i + 1 : n_art - 1]) art_layer(j);
}
// Placed on the lid, mirrored so it reads correctly from behind.
module art_place() translate([art_x, art_y]) mirror([1, 0, 0]) scale(art_size / 32) translate([-16, -16])
    children();
module band(w) difference() { offset(r = w / 2) children(); offset(r = -w / 2) children(); }

// The outer face prints on the bed, so a big sunk area would have to be
// bridged. Engrave the colour boundaries as narrow grooves instead, and sink
// only the pit.
module art_engrave() slab(DT - art_depth, DT + 1) {
    for (i = [0 : n_art - 2]) band(art_groove) art_place() art_region(i);
    art_place() art_region(n_art - 1);
}
module art_pocket() slab(DT - art_depth, DT + 1) art_place() for (i = [0 : n_art - 1]) art_layer(i);
module art_inlay(i) slab(DT - art_depth, DT) art_place() art_region(i);

module esp_cradle() {
    d_rail = d_comp - esp_pcb_t / 2;  // rails reach halfway up the PCB edge
    // side rails along the long edges (outside the header solder joints)
    for (s = [-1, 1])
        translate([ex0 + 3, ey + s * (esp_w / 2 + 0.3) - (s < 0 ? 1.2 : 0), 0])
            slab(d_rail, D + eps) square([esp_len - 5, 1.2]);
    // end stop at the antenna tip: push the board against it and the keys line up
    translate([ex0 + esp_len + esp_ant + 0.1, ey - 11, 0]) slab(d_rail, D + eps) square([1.5, 22]);
    // pads on the WROOM shield — put double-sided tape here
    for (x = [44, 53]) translate([ex0 + x - 1, ey - 6, 0]) slab(d_comp + wroom_h, D + eps) square([2, 12]);
    // pads behind the USB-C receptacles so plugging in doesn't flex the board
    for (s = [-1, 1]) translate([ex0 + 1, ey + s * usbc_pitch / 2 - 3, 0])
        slab(d_comp + usbc_h, D + eps) square([5, 6]);
}

module pushers() for (p = hole_pts) tube(p[0], p[1], d_pcb_back + pusher_gap, D + eps, pusher_d, 2.8);

module key_frame(k) translate([k[0], k[1], 0]) scale([k[2], k[3], 1]) children();

// Cantilever cut out of the lid; its nub sits just above the button.
module key_cut(k) key_frame(k) {
    // U-shaped slot through the lid
    slab(D - 1, DT + 1) difference() {
        translate([-key_out - key_gap, -key_tip - key_gap])
            square([key_out + key_in + 2 * key_gap, key_len + key_gap]);
        translate([-key_out, -key_tip]) square([key_out + key_in, key_len + 1]);
    }
    // thin the key from the inside so it flexes; this also clears the cradle rail over it
    slab(d_comp - 1, DT - key_t) translate([-key_out - key_gap, -key_tip - key_gap])
        square([key_out + key_in + 2 * key_gap, key_len + key_gap + 2]);
    // finger dot on the outside, 7 mm back from the tip
    translate([(key_in - key_out) / 2, 5, 0]) slab(DT - 0.4, DT + 1) circle(d = 3);
}

module key_nub(k) {
    tip = d_comp + btn_h + nub_gap;
    translate([k[0], k[1], 0]) hull() {
        slab(tip + 0.5, DT - key_t + eps) circle(d = 3.0);
        slab(tip, tip + eps) circle(d = 2.0);
    }
}

// ---- snap clips
// Two clips on each long wall. Each is an arm hanging off the lid just inside
// the wall, with a hook that clicks into a recess in the wall. The hook's back
// face is sloped, so the lid stays put against the foam but pries off with a
// coin at the notch on the right side.
snap_xs   = [W * 0.3 - snap_w / 2, W * 0.7 - snap_w / 2];
snap_lead = 2.5;  snap_flat = 0.4;  snap_ret = 1.2;   // hook profile along the arm
d_snap    = D - snap_len;                              // arm tip depth

// Hook cross-section: u = outward from the arm face, v = from the arm tip toward the lid.
module snap_hook_2d() polygon([[0, 0], [snap_hook, snap_lead], [snap_hook, snap_lead + snap_flat],
                               [0, snap_lead + snap_flat + snap_ret]]);

// Clip on the bottom wall (the top one is its mirror image).
module snap_arm(x0) {
    translate([x0, wall + snap_gap, 0]) slab(d_snap, D + eps) square([snap_w, snap_t]);
    multmatrix([[0, 0, 1, x0], [-1, 0, 0, wall + snap_gap], [0, -1, 0, -d_snap], [0, 0, 0, 1]])
        linear_extrude(snap_w) snap_hook_2d();
}

// Matching recess in the bottom wall. Its back edge sits where the hook's
// sloped face crosses the wall, so the seated lid has no play.
module snap_recess(x0) {
    v_top = snap_lead + snap_flat + snap_ret * (1 - snap_gap / snap_hook) + 0.1;
    translate([x0 - 0.3, wall - (snap_hook - snap_gap) - 0.3, -(d_snap + v_top)])
        cube([snap_w + 0.6, snap_hook - snap_gap + 0.3 + eps, v_top + 0.3]);
}

// Notch in the rim on the right side: a coin goes in here to pry the lid off.
module pry_notch() translate([W - 1.0, H / 2 - 6, -(D + 1)]) cube([2, 12, 2.2]);

module lid() {
    difference() {
        union() {
            lid_body();
            pushers();
            esp_cradle();
            if (lid_fix != "screws")
                for (x = snap_xs) { snap_arm(x); translate([0, H, 0]) mirror([0, 1, 0]) snap_arm(x); }
        }
        if (lid_fix != "snap") for (p = boss_pts) tube(p[0], p[1], D - 1, DT + 1, screw_d);
        for (k = keys) {
            if (button_style == "flex") key_cut(k);
            if (button_style == "hole") tube(k[0], k[1], D - 1, DT + 1, 4);
            if (button_style != "none")   // beside the key's press area, on its outer side
                lid_label(k[4], k[0] - k[2] * (key_out + key_gap + 6), k[1] + k[3] * 8, 3);
        }
        if (lid_art == "avocado") { if (art_style == "inlay") art_pocket(); else art_engrave(); }
        if (lid_art == "text" && len(lid_text) > 0) lid_label(lid_text, W / 2, H * 0.24, 8);
    }
    if (button_style == "flex") for (k = keys) key_nub(k);
}

// ---------------------------------------------------------------- stand
// Side view: Y = back, Z = up, desk at Z = 0. The case's back-bottom edge
// (y = 0 at the lid, depth DT) sits at [0, stand_seat].
function st_up(t)   = [sin(t), cos(t)];       // case +y
function st_back(t) = [cos(t), -sin(t)];      // case +depth
function st_pt(y, d) = [0, stand_seat] + y * st_up(stand_angle) + (d - DT) * st_back(stand_angle);

module stand_profile() {
    assert(stand_angle >= tilt + 5, "stand_angle must be at least tilt + 5 (the wedge alone gives tilt)");
    F  = st_pt(floor_y(0), 0);                // chin front-bottom edge: the case's frontmost point
    lip_y = F[0] - stand_clear;               // vertical lip face; the reclined front leans away above F
    lip_z = F[1] + stand_lip_h;
    T  = st_pt(stand_rest_h, DT);             // top of the uprights, on the back cover
    Tb = T + stand_rest_t * st_back(stand_angle);
    G  = [Tb[0] + stand_foot, 0];
    difference() {
        hull() polygon([[lip_y - stand_lip_t, 0], [lip_y - stand_lip_t, lip_z], [lip_y, lip_z],
                        T, Tb, [G[0], stand_bar_h], G]);
        offset(delta = stand_clear) polygon([F, st_pt(floor_y(DT), DT), st_pt(H, DT), st_pt(H, 0)]);
    }
}

function stand_front() = st_pt(floor_y(0), 0)[0] - stand_clear - stand_lip_t;
function stand_back()  = (st_pt(stand_rest_h, DT) + stand_rest_t * st_back(stand_angle))[0] + stand_foot;

module stand() {
    y0 = stand_front();
    y1 = stand_back();
    for (x = [stand_cheek_in, W - stand_cheek_in - stand_cheek_w])
        translate([x, 0, 0]) rotate([90, 0, 90]) linear_extrude(stand_cheek_w) stand_profile();
    for (y = [y0, y1 - stand_bar_d])
        translate([stand_cheek_in, y, 0]) cube([W - 2 * stand_cheek_in, stand_bar_d, stand_bar_h]);
}

module art_preview() if (lid_art == "avocado" && art_style == "inlay")
    for (i = [0 : n_art - 1]) color(art_colors[i]) art_inlay(i);

// Case pose on the stand, in the stand's frame.
module on_stand_pose() translate([0, -DT * cos(stand_angle), stand_seat + DT * sin(stand_angle)])
    rotate([90 - stand_angle, 0, 0]) children();

// ---------------------------------------------------------------- stand-ins (preview only)
module display_dummy() {
    color("#1d4e89") translate([px0, py0, 0]) slab(d_pcb_front, d_pcb_back) square([disp_w, disp_h]);
    color("#111") translate([px0 + 6.7, py0, 0]) slab(bezel_t, d_pcb_front) square([disp_w - 15.2, disp_h]);
    color("#3fa7e0") translate([px0 + aa_left, py0 + (disp_h - aa_h) / 2, 0])
        slab(bezel_t - 0.05, bezel_t) square([aa_w, aa_h]);
    // J2 header + dupont housings on the back
    color("#222") translate([px0 + disp_w - 4.3, py0 + disp_h / 2 - 17.8, 0])
        slab(d_pcb_back, d_pcb_back + 16.5) square([2.54, 35.56]);
}

module esp_dummy() {
    color("#222") translate([ex0, ey - esp_w / 2, 0]) slab(d_comp - esp_pcb_t, d_comp) square([esp_len, esp_w]);
    color("#c9c9c9") translate([ex0 + esp_len + esp_ant - 25.5, ey - 9, 0]) slab(d_comp, d_comp + wroom_h) square([25.5, 18]);
    for (s = [-1, 1]) color("#aaa") translate([ex0 - 0.7, ey + s * usbc_pitch / 2 - 4.47, 0])
        slab(d_comp, d_comp + usbc_h) square([7.4, 8.94]);
    for (p = [[bx, by], [rx, ry]]) color("#e0e0e0") translate([p[0] - 1.5, p[1] - 2, 0])
        slab(d_comp, d_comp + btn_h) square([3, 4]);
    // headers + dupont housings on the pin side
    for (s = [-1, 1]) color("#e8c200") translate([ex0 + 0.64, ey + s * (esp_w / 2 - 1.27) - 1.27, 0])
        slab(d_comp - esp_pcb_t - 2.5, d_comp - esp_pcb_t) square([55.88, 2.54]);
    for (s = [-1, 1]) color("#333") translate([ex0 + 0.64, ey + s * (esp_w / 2 - 1.27) - 1.27, 0])
        slab(d_comp - esp_pcb_t - 16.5, d_comp - esp_pcb_t - 2.5) square([55.88, 2.54]);
}

// ---------------------------------------------------------------- output
if (part == "shell")    rotate([180, 0, 0]) shell();
if (part == "lid")      translate([0, 0, DT]) lid();
// Colour inlays for art_style = "inlay": load them with the lid as one
// multi-part object and give each its own filament.
for (i = [0 : n_art - 1])
    if (part == ["inlay_back", "inlay_skin", "inlay_flesh", "inlay_pit"][i]) translate([0, 0, DT]) art_inlay(i);
if (part == "fit_test") rotate([180, 0, 0]) intersection() {
    shell();
    translate([-1, 0, -(d_frame + 2)]) cube([W + 2, H + 1, d_frame + 2 + eps]);   // chin left off
}
// Preview parts stand the case on the desk: z up, screen facing -y.
if (part == "stand") stand();
if (part == "on_stand") {
    color("#d8d2c4") stand();
    on_stand_pose() { color("#e9e4da") shell(); display_dummy(); color("#d8d2c4") lid(); art_preview(); esp_dummy(); }
}
if (part == "assembly" || part == "exploded") rotate([90 - tilt, 0, 0]) {
    gap = part == "exploded" ? 45 : 0;
    color("#e9e4da") shell();
    display_dummy();
    translate([0, 0, -gap]) { color("#d8d2c4") lid(); art_preview(); esp_dummy(); }
}

echo(str("Case outer: ", W, " x ", H + chin, " (front face) x ", DT, " mm deep; chin ", chin, " mm"));
echo(str("Stand @ ", stand_angle, " deg: ", W - 2 * stand_cheek_in, " x ", stand_back() - stand_front(), " mm footprint"));
