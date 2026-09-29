// Clawdmeter desk case for the `devkitc_st7796` port:
// YD-ESP32-S3 (ESP32-S3-DevKitC-1 clone) + LCDwiki MSP4031 4.0" ST7796S / FT6336U.
//
// Two printed parts, no supports needed:
//   shell — front bezel + walls + tilt wedge. Print front face down.
//   lid   — back cover. The ESP32 cradle, display pushers and the BOOT flex
//           button hang off its inner face. Print outer face down.
// Plus `fit_test`, a 30-minute slice of the bezel + display pocket. Print it
// first and check the display drops in and the window lines up with the
// picture before committing to the full shell.
//
// Hardware: 4x M3x10 screws (self-tapping or machine, into printed pilots),
// 1 mm foam tape for the pusher tips, double-sided tape under the ESP32.
//
// Frame: seen from the front, x = right, y = up, z = toward the viewer.
// The front face is z = 0 and the case extends back into -z; "depth" (d)
// below is measured from the front face, so a feature at depth d sits at z = -d.
//
// Every dimension marked "measure" is from a datasheet, not from your parts.
// Check them with calipers and re-export if they differ.

part = "assembly"; // [assembly, exploded, shell, lid, fit_test]

/* [Display: MSP4031 (LCDwiki 4.0in capacitive, ST7796S)] */
disp_w      = 108.00; // PCB long side (x). Datasheet.
disp_h      = 60.88;  // PCB short side (y). Datasheet.
disp_stack  = 4.2;    // measure: LCD + touch glass above the PCB front face
disp_pcb_t  = 1.6;
disp_hole_in = 3.0;   // mounting-hole centres from PCB edges (3.2 mm holes)
aa_w        = 83.52;  // active area
aa_h        = 55.68;
aa_left     = 9.36;   // measure: active area left edge from PCB left edge (the edge away from header J2)
win_margin  = 1.0;    // window is this much larger than the active area on each side
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
btn_h       = 2.5;    // measure: tact switch height above the PCB
nub_gap     = 0.6;    // BOOT nub clearance. Too small and BOOT is held at power-up (bootloader, dark screen).
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
boot_style  = "flex"; // [flex, hole, none]
lid_text    = "Clawdmeter";
side_labels = true;   // engrave UART / USB next to the port slot

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
tab_w = 7;  tab_len = 18;  tab_t = 1.2;  tab_gap = 1.0;

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
    wx0 = px0 + aa_left - win_margin;
    wy0 = py0 + (disp_h - aa_h) / 2 - win_margin;
    wx1 = wx0 + aa_w + 2 * win_margin;
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

module esp_cradle() {
    d_rail = d_comp - esp_pcb_t / 2;  // rails reach halfway up the PCB edge
    // side rails along the long edges (outside the header solder joints)
    for (s = [-1, 1])
        translate([ex0 + 3, ey + s * (esp_w / 2 + 0.3) - (s < 0 ? 1.2 : 0), 0])
            slab(d_rail, D + eps) square([esp_len - 5, 1.2]);
    // end stop just past the antenna tip
    translate([ex0 + esp_len + esp_ant + 0.4, ey - 11, 0]) slab(d_rail, D + eps) square([1.5, 22]);
    // pads on the WROOM shield — put double-sided tape here
    for (x = [42, 52]) translate([ex0 + x - 1, ey - 6, 0]) slab(d_comp + wroom_h, D + eps) square([2, 12]);
    // pads behind the USB-C receptacles so plugging in doesn't flex the board
    for (s = [-1, 1]) translate([ex0 + 1, ey + s * usbc_pitch / 2 - 3, 0])
        slab(d_comp + usbc_h, D + eps) square([5, 6]);
}

module pushers() for (p = hole_pts) tube(p[0], p[1], d_pcb_back + pusher_gap, D + eps, pusher_d, 2.8);

// Cantilever cut out of the lid; its nub sits just above the BOOT key.
module boot_tab_cut() {
    xt = bx + 2.5;                    // free end, past the nub
    xr = xt - tab_len;                // hinge
    // U-shaped slot through the lid
    slab(D - 1, DT + 1) difference() {
        translate([xr, by - tab_w / 2 - tab_gap]) square([tab_len + tab_gap, tab_w + 2 * tab_gap]);
        translate([xr - 1, by - tab_w / 2]) square([tab_len + 1, tab_w]);
    }
    // thin the tab from the inside so it flexes
    slab(D - 1, DT - tab_t) translate([xr - 2, by - tab_w / 2]) square([tab_len + 2, tab_w]);
}

module boot_nub() {
    tip = d_comp + btn_h + nub_gap;
    translate([bx, by, 0]) hull() {
        slab(tip + 0.5, DT - tab_t + eps) circle(d = 3.2);
        slab(tip, tip + eps) circle(d = 2.2);
    }
}

module lid() {
    difference() {
        union() {
            lid_body();
            pushers();
            esp_cradle();
        }
        for (p = boss_pts) tube(p[0], p[1], D - 1, DT + 1, screw_d);
        if (boot_style == "flex") boot_tab_cut();
        if (boot_style == "hole") tube(bx, by, D - 1, DT + 1, 6);
        if (len(lid_text) > 0) lid_label(lid_text, W / 2, H * 0.24, 8);
        if (boot_style != "none") lid_label("BOOT", bx - 6, by - tab_w / 2 - tab_gap - 3.5, 3);
    }
    if (boot_style == "flex") boot_nub();
}

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
    color("#e0e0e0") translate([bx - 1.5, by - 2, 0]) slab(d_comp, d_comp + btn_h) square([3, 4]);
    // headers + dupont housings on the pin side
    for (s = [-1, 1]) color("#e8c200") translate([ex0 + 0.64, ey + s * (esp_w / 2 - 1.27) - 1.27, 0])
        slab(d_comp - esp_pcb_t - 2.5, d_comp - esp_pcb_t) square([55.88, 2.54]);
    for (s = [-1, 1]) color("#333") translate([ex0 + 0.64, ey + s * (esp_w / 2 - 1.27) - 1.27, 0])
        slab(d_comp - esp_pcb_t - 16.5, d_comp - esp_pcb_t - 2.5) square([55.88, 2.54]);
}

// ---------------------------------------------------------------- output
if (part == "shell")    rotate([180, 0, 0]) shell();
if (part == "lid")      translate([0, 0, DT]) lid();
if (part == "fit_test") rotate([180, 0, 0]) intersection() {
    shell();
    translate([-1, 0, -(d_frame + 2)]) cube([W + 2, H + 1, d_frame + 2 + eps]);   // chin left off
}
// Preview parts stand the case on the desk: z up, screen facing -y.
if (part == "assembly" || part == "exploded") rotate([90 - tilt, 0, 0]) {
    gap = part == "exploded" ? 45 : 0;
    color("#e9e4da") shell();
    display_dummy();
    translate([0, 0, -gap]) { color("#d8d2c4") lid(); esp_dummy(); }
}

echo(str("Case outer: ", W, " x ", H + chin, " (front face) x ", DT, " mm deep; chin ", chin, " mm"));
