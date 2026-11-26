// UK Train Departure Display - case v2
//
// Station-style housing for a 3.12" SSD1322 256x64 OLED and a Raspberry Pi Zero,
// with a panel-mount barrel jack on the back and swappable hanging rods / desk stand.
//
// Parts (set `part`, or use the command line: openscad -D 'part="body"' ...):
//   "assembly_hanging"  preview with ceiling rods
//   "assembly_stand"    preview with desk stand
//   "body"              main housing, printed face-down (no supports)
//   "back"              rear panel with Pi Zero standoffs + barrel jack hole
//   "hanger"            two hanger rods, printed ceiling-disc-down
//   "stand"             desk stand
//   "hood"              sun hood, bolts on top under the rods (printed top-down)
//   "assembly_monitor"  preview hanging under a monitor (BenQ PD2500Q defaults)
//   "hanger_monitor"    two short hanger rods for the monitor clamp
//   "monitor_clamp"     clamp that hooks over the monitor's bottom edge
//
// Hardware:
//   4x M2.5 x 6  self-tapping/machine screws  OLED -> body standoffs
//   4x M2.5 x 6  screws                       Pi Zero -> back panel standoffs
//   2x M2.5 x 8  screws                       side walls -> back panel tabs
//   4x M3 nuts   pressed into the top/bottom wall pockets (from inside)
//   2x M3 x 12 socket cap bolts               rods -> body through the hood (x10 without hood)
//   2x M3 x 10 socket cap bolts               stand -> body  (M3 x 8 to hold the hood on top)
//   4x M3 x 8  countersunk self-tappers       short rods -> monitor clamp
//   2x M3 x 16 thumbscrews + 2x M3 nuts       monitor clamp grip (pad the tips)
//   1x 5.5x2.1 mm threaded panel-mount DC jack
//
// Coordinates: X = width, Y = depth (front face at y=0, back at y=depth),
// Z = height, origin on the centre of the OLED mounting-hole pattern.

part = "assembly_monitor";

$fa = 1;
$fs = 0.4;

/* ---------- OLED module (MEASURE YOURS) ---------- */
pcb_w        = 100.5;   // OLED PCB width
pcb_h        = 34;      // OLED PCB height
pcb_t        = 1.6;
oled_hole_dx = 94;      // mounting hole spacing (from the v1 case pins)
oled_hole_dz = 29;
win_w        = 71.10;   // visible window (from the v1 bezel)
win_h        = 19.26;
win_z        = 1.47;    // window centre above the hole-pattern centre
screen_gap   = 3;       // front wall -> PCB front face (clears the glass)

/* ---------- Pi Zero ---------- */
pi_hole_dx   = 58;
pi_hole_dz   = 23;
pi_w         = 65;
pi_h         = 30;
pi_cx        = -11.5;   // Pi centre on the back panel
pi_cz        = 0;
pi_standoff  = 4;

/* ---------- Barrel jack ---------- */
jack_d       = 7.8;     // hole for the threaded jack body
jack_x       = 34;
jack_z       = 0;

/* ---------- Housing ---------- */
clear        = 0.75;    // PCB -> inner wall clearance each side
side_t       = 3;
tb_t         = 4.5;     // top/bottom walls (thick enough for captive M3 nuts)
front_t      = 3;
back_t       = 3;
depth        = 32;      // overall depth front to back
corner_r     = 3.5;
fit          = 0.25;    // back panel clearance in the opening

in_w  = pcb_w + 2*clear;
in_h  = pcb_h + 2*clear;
out_w = in_w + 2*side_t;
out_h = in_h + 2*tb_t;

/* ---------- Fasteners ---------- */
m25_pilot    = 2.1;
m25_clear    = 2.9;
m3_clear     = 3.4;
m3_nut_af    = 5.8;     // across flats, slightly over 5.5 for a press fit
m3_nut_t     = 2.6;
mount_x      = 35;      // rods / stand posts, either side of centre
mount_y      = depth/2;

/* ---------- Back panel tabs ---------- */
tab_t = 4;
tab_w = 12;
tab_h = 10;
side_screw_y = depth - back_t - tab_h/2;

/* ---------- Hanger / stand ---------- */
rod_d        = 10;
rod_len      = 60;      // display top -> ceiling
bore_d       = 6.5;     // lets an M3 socket head and a hex key down the rod
seat_t       = 3;
foot_d       = 16;
ceil_d       = 36;
stand_post_h = 20;
stand_base_t = 5;
stand_w      = 110;
stand_d      = 50;

/* ---------- Sun hood ---------- */
hood_t       = 2.5;
hood_proj    = 14;      // how far the hood overhangs the face
hood_cheek_h = 14;      // side cheek depth at the face
hood_cheek_t = 2;

/* ---------- Monitor clamp (MEASURE YOUR MONITOR) ---------- */
// BenQ PD2500Q: 58.8 mm deep overall without stand, but the bottom edge is thinner.
mon_edge_t     = 23;    // monitor thickness front-to-back, ~10 mm up from the bottom edge
mon_front_lip  = 6;     // front lip height, must be less than the bottom bezel height
mon_rear_lip   = 22;
mon_rod_len    = 20;    // short rods: display top -> clamp
clamp_base_t   = 6;
clamp_front_t  = 3;
clamp_rear_t   = 6;
clamp_w        = 2*mount_x + ceil_d + 10;
clamp_screw_x  = 30;    // thumbscrews either side of centre
clamp_screw_z  = clamp_base_t + mon_rear_lip - 8;

/* ================= helpers ================= */

// rounded rectangle in the XZ plane, extruded along +Y from y0
module rrect_y(w, h, r, y0, len) {
    rr = min(r, w/2 - 0.01, h/2 - 0.01);
    translate([0, y0, 0]) rotate([-90, 0, 0])
        linear_extrude(len)
            offset(r = rr) square([w - 2*rr, h - 2*rr], center = true);
}

module hex_pocket(af, h) {
    rotate([0, 0, 90]) cylinder(d = af / cos(30), h = h, $fn = 6);
}

/* ================= body ================= */

module body() {
    difference() {
        union() {
            difference() {
                rrect_y(out_w, out_h, corner_r, 0, depth);
                rrect_y(in_w, in_h, 1, front_t, depth);
            }
            // OLED standoffs
            for (sx = [-1, 1], sz = [-1, 1])
                translate([sx*oled_hole_dx/2, front_t - 0.01, sz*oled_hole_dz/2])
                    rotate([-90, 0, 0]) cylinder(d = 5, h = screen_gap + 0.01);
        }

        // window with a 45 degree chamfer so the screen looks recessed
        translate([0, 0, win_z]) hull() {
            translate([0, front_t, 0]) cube([win_w, 0.02, win_h], center = true);
            translate([0, 0, 0])
                cube([win_w + 2*front_t, 0.02, win_h + 2*front_t], center = true);
        }

        // standoff pilot holes (blind, stop short of the face)
        for (sx = [-1, 1], sz = [-1, 1])
            translate([sx*oled_hole_dx/2, 1.2, sz*oled_hole_dz/2])
                rotate([-90, 0, 0]) cylinder(d = m25_pilot, h = front_t + screen_gap);

        // frame line around the face
        difference() {
            rrect_y(out_w - 7,   out_h - 7,   corner_r - 1, -0.01, 0.61);
            rrect_y(out_w - 8.6, out_h - 8.6, corner_r - 1.5, -0.02, 0.7);
        }

        // M3 mounting points top and bottom: bolt hole + captive nut pocket
        for (sx = [-1, 1], sz = [-1, 1])
            translate([sx*mount_x, mount_y, 0])
                mirror([0, 0, sz < 0 ? 1 : 0]) {
                    translate([0, 0, in_h/2 - 1]) cylinder(d = m3_clear, h = tb_t + 2);
                    translate([0, 0, in_h/2 - 0.01]) hex_pocket(m3_nut_af, m3_nut_t);
                }

        // side screws into the back panel tabs
        for (sx = [-1, 1])
            translate([sx*(in_w/2 - 1), side_screw_y, 0])
                rotate([0, sx*90, 0]) cylinder(d = m25_clear, h = side_t + 2);
    }
}

/* ================= back panel ================= */

module back_panel() {
    pw = in_w - 2*fit;
    ph = in_h - 2*fit;
    y0 = depth - back_t;
    difference() {
        union() {
            rrect_y(pw, ph, 1 - fit, y0, back_t);
            // tabs that sit against the side walls
            for (sx = [-1, 1])
                translate([sx*(pw/2 - tab_t/2), y0 - tab_h/2 + 0.01, 0])
                    cube([tab_t, tab_h + 0.02, tab_w], center = true);
            // Pi Zero standoffs
            for (sx = [-1, 1], sz = [-1, 1])
                translate([pi_cx + sx*pi_hole_dx/2, y0 + 0.01, pi_cz + sz*pi_hole_dz/2])
                    rotate([90, 0, 0]) cylinder(d = 5.5, h = pi_standoff + 0.01);
        }
        // tab pilot holes
        for (sx = [-1, 1])
            translate([sx*(pw/2 - tab_t/2), side_screw_y, 0])
                rotate([0, 90, 0]) cylinder(d = m25_pilot, h = tab_t + 2, center = true);
        // Pi standoff pilot holes (blind)
        for (sx = [-1, 1], sz = [-1, 1])
            translate([pi_cx + sx*pi_hole_dx/2, y0 + 1.5, pi_cz + sz*pi_hole_dz/2])
                rotate([90, 0, 0]) cylinder(d = m25_pilot, h = pi_standoff + 2);
        // barrel jack
        translate([jack_x, y0 - 1, jack_z])
            rotate([-90, 0, 0]) cylinder(d = jack_d, h = back_t + 2);
        // vent slots behind the Pi
        for (z = [-12 : 4 : 12])
            translate([pi_cx, y0 - 1, pi_cz + z])
                hull() for (sx = [-1, 1])
                    translate([sx*19, 0, 0]) rotate([-90, 0, 0])
                        cylinder(d = 2, h = back_t + 2);
    }
}

/* ================= hanger rod ================= */
// in use orientation: foot at z=0 sits on the display top, ceiling disc at the top

module hanger_rod(len = rod_len) {
    top = len;
    difference() {
        union() {
            cylinder(d = foot_d, h = 4);
            translate([0, 0, 4]) cylinder(d1 = foot_d, d2 = rod_d, h = (foot_d - rod_d)/2);
            cylinder(d = rod_d, h = top);
            translate([0, 0, top - 5]) cylinder(d1 = rod_d, d2 = 20, h = 5);
            translate([0, 0, top]) cylinder(d = ceil_d, h = 4);
        }
        translate([0, 0, -1]) cylinder(d = m3_clear, h = seat_t + 2);
        translate([0, 0, seat_t]) cylinder(d = bore_d, h = top + 5);
        // ceiling screws, countersunk from the underside of the disc
        for (sx = [-1, 1])
            translate([sx*14.5, 0, top - 0.01]) {
                cylinder(d = 4.2, h = 6);
                cylinder(d1 = 8.4, d2 = 4.2, h = 2.1);
            }
    }
}

/* ================= desk stand ================= */
// base on the desk at z=0, post tops touch the display bottom

module stand() {
    top = stand_base_t + stand_post_h;
    difference() {
        union() {
            hull() for (sx = [-1, 1], sy = [-1, 1])
                translate([sx*(stand_w/2 - 5), sy*(stand_d/2 - 5), 0]) {
                    cylinder(r = 5, h = stand_base_t - 1);
                    cylinder(r = 4, h = stand_base_t);
                }
            for (sx = [-1, 1]) translate([sx*mount_x, 0, 0]) {
                cylinder(d = rod_d, h = top);
                translate([0, 0, stand_base_t])
                    cylinder(d1 = foot_d, d2 = rod_d, h = (foot_d - rod_d)/2);
                translate([0, 0, top - 3 - (foot_d - rod_d)/2])
                    cylinder(d1 = rod_d, d2 = foot_d, h = (foot_d - rod_d)/2);
                translate([0, 0, top - 3]) cylinder(d = foot_d, h = 3);
            }
        }
        for (sx = [-1, 1]) translate([sx*mount_x, 0, 0]) {
            translate([0, 0, -1]) cylinder(d = bore_d, h = top - seat_t + 1);
            cylinder(d = m3_clear, h = top + 1);
        }
    }
}

/* ================= sun hood ================= */
// in body coordinates: sits on the top of the body, overhangs the face

module sun_hood() {
    z0 = out_h/2;
    difference() {
        union() {
            translate([0, 0, z0]) linear_extrude(hood_t)
                hull() for (sx = [-1, 1]) {
                    translate([sx*(out_w/2 - 3), -hood_proj + 3]) circle(r = 3);
                    translate([sx*out_w/2 - (sx > 0 ? 0.01 : 0), depth - 0.01])
                        square(0.01);
                }
            // triangular side cheeks in front of the face
            for (sx = [-1, 1])
                translate([sx*(out_w/2 - hood_cheek_t/2) - hood_cheek_t/2, 0, 0])
                    hull() {
                        translate([0, -hood_proj, z0]) cube([hood_cheek_t, hood_proj, 0.01]);
                        translate([0, -0.01, z0 - hood_cheek_h])
                            cube([hood_cheek_t, 0.01, hood_cheek_h]);
                    }
        }
        for (sx = [-1, 1])
            translate([sx*mount_x, mount_y, z0 - 1]) cylinder(d = m3_clear, h = hood_t + 2);
    }
}

/* ================= monitor clamp ================= */
// in use orientation: base underside at z=0, monitor edge sits in the gap centred
// on y=0, front of the monitor towards -y. Rods screw to the underside.

module monitor_clamp() {
    yf = -mon_edge_t/2;
    yr =  mon_edge_t/2;
    nut_d = m3_nut_af / cos(30);
    difference() {
        union() {
            // base
            translate([-clamp_w/2, yf - clamp_front_t, 0])
                cube([clamp_w, mon_edge_t + clamp_front_t + clamp_rear_t, clamp_base_t]);
            // front lip
            translate([-clamp_w/2, yf - clamp_front_t, 0])
                cube([clamp_w, clamp_front_t, clamp_base_t + mon_front_lip]);
            // rear lip
            translate([-clamp_w/2, yr, 0])
                cube([clamp_w, clamp_rear_t, clamp_base_t + mon_rear_lip]);
        }
        // soften the front lip top edge
        translate([0, yf - clamp_front_t, clamp_base_t + mon_front_lip])
            rotate([45, 0, 0]) cube([clamp_w + 2, 2, 2], center = true);
        // thumbscrews through the rear lip with nuts dropped in from the top
        for (sx = [-1, 1]) translate([sx*clamp_screw_x, 0, clamp_screw_z]) {
            translate([0, yr - 1, 0]) rotate([-90, 0, 0])
                cylinder(d = m3_clear, h = clamp_rear_t + 2);
            translate([-m3_nut_af/2, yr + clamp_rear_t/2 - 1.4, -nut_d/2])
                cube([m3_nut_af, 2.8, mon_rear_lip]);
        }
        // pilot holes for the rod ceiling-disc screws (blind)
        for (rx = [-1, 1], sx = [-1, 1])
            translate([rx*mount_x + sx*14.5, 0, -1])
                cylinder(d = 2.5, h = clamp_base_t);
    }
}

/* ================= output ================= */

module display() {
    color([0.12, 0.12, 0.13]) body();
    color([0.2, 0.2, 0.22]) back_panel();
    // screen preview
    %translate([0, front_t + screen_gap + pcb_t/2, 0]) cube([pcb_w, pcb_t, pcb_h], center = true);
}

if (part == "assembly_hanging") {
    display();
    color([0.16, 0.16, 0.17]) sun_hood();
    color([0.25, 0.25, 0.27])
        for (sx = [-1, 1])
            translate([sx*mount_x, mount_y, out_h/2 + hood_t]) hanger_rod();
} else if (part == "assembly_monitor") {
    clamp_z = out_h/2 + hood_t + mon_rod_len + 4;
    display();
    color([0.16, 0.16, 0.17]) sun_hood();
    color([0.25, 0.25, 0.27]) {
        for (sx = [-1, 1])
            translate([sx*mount_x, mount_y, out_h/2 + hood_t]) hanger_rod(mon_rod_len);
        translate([0, mount_y, clamp_z]) monitor_clamp();
    }
    // stand-in for the bottom of the monitor
    %translate([-150, mount_y - mon_edge_t/2, clamp_z + clamp_base_t])
        cube([300, mon_edge_t, 60]);
} else if (part == "assembly_stand") {
    display();
    color([0.16, 0.16, 0.17]) sun_hood();
    color([0.25, 0.25, 0.27])
        translate([0, mount_y, -out_h/2 - stand_base_t - stand_post_h]) stand();
} else if (part == "hood") {
    translate([0, 0, out_h/2 + hood_t]) rotate([180, 0, 0]) sun_hood();   // top face down
} else if (part == "hanger_monitor") {
    for (sx = [-1, 1])
        translate([sx*25, 0, mon_rod_len + 4]) rotate([180, 0, 0]) hanger_rod(mon_rod_len);
} else if (part == "monitor_clamp") {
    monitor_clamp();                                 // base down, lips up
} else if (part == "body") {
    rotate([90, 0, 0]) body();                       // face down
} else if (part == "back") {
    translate([0, 0, depth]) rotate([-90, 0, 0]) back_panel();   // outside face down
} else if (part == "hanger") {
    for (sx = [-1, 1])
        translate([sx*25, 0, rod_len + 4]) rotate([180, 0, 0]) hanger_rod();
} else if (part == "stand") {
    stand();
}
