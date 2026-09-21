#include "ui_dual.h"
#include <time.h>
#include "theme.h"

LV_FONT_DECLARE(font_styrene_48);
LV_FONT_DECLARE(font_styrene_20);
LV_FONT_DECLARE(font_styrene_16);
LV_FONT_DECLARE(font_styrene_14);

// Geometry for 480x320, from the approved mockup (spec §Màn Usage).
static const int MARGIN    = 12;
static const int PANEL_Y   = 56;
static const int PANEL_W   = 222;
static const int PANEL_H   = 252;
static const int PANEL_GAP = 12;
static const int PAD       = 16;
static const int SEC_Y[2]  = {48, 152};   // % top per section
static const int BAR_DY    = 56;          // bar top below the % top
static const int RESET_DY  = 72;          // reset line below the % top
static const int BAR_H     = 10;
static const long STALE_S  = 300;

struct Section { lv_obj_t* pct; lv_obj_t* bar; lv_obj_t* reset; };
struct Column  {
    lv_obj_t* badge;
    Section   sec[2];          // 0 = 5h, 1 = Weekly
    long      stamp;           // epoch shown in the badge, 0 = none
    bool      stale_shown;
};
enum { CLAUDE = 0, CODEX = 1 };

static Column    cols[2];
static lv_obj_t* link_dot = nullptr;
static int       clock_fmt = 24;

static lv_obj_t* make_label(lv_obj_t* parent, const lv_font_t* font,
                            lv_color_t color, const char* text) {
    lv_obj_t* l = lv_label_create(parent);
    lv_label_set_text(l, text);
    lv_obj_set_style_text_font(l, font, 0);
    lv_obj_set_style_text_color(l, color, 0);
    return l;
}

static void format_reset(int mins, char* buf, size_t len) {
    if (mins < 0)           snprintf(buf, len, "---");
    else if (mins < 60)     snprintf(buf, len, "Resets in %dm", mins);
    else if (mins < 1440)   snprintf(buf, len, "Resets in %dh %02dm", mins / 60, mins % 60);
    else                    snprintf(buf, len, "Resets in %dd %02dh", mins / 1440, (mins % 1440) / 60);
}

static void format_hhmm(long epoch, char* buf, size_t len) {
    if (epoch <= 0) { snprintf(buf, len, "--:--"); return; }
    time_t t = (time_t)epoch;
    struct tm tmv;
    gmtime_r(&t, &tmv);   // epoch is already local wall-clock
    if (clock_fmt == 12) {
        int h = tmv.tm_hour % 12;
        if (h == 0) h = 12;
        snprintf(buf, len, "%d:%02d %s", h, tmv.tm_min, tmv.tm_hour < 12 ? "AM" : "PM");
    } else {
        snprintf(buf, len, "%02d:%02d", tmv.tm_hour, tmv.tm_min);
    }
}

static void build_column(lv_obj_t* group, int idx, int x, const char* name, lv_color_t accent) {
    Column& c = cols[idx];

    lv_obj_t* panel = lv_obj_create(group);
    lv_obj_set_pos(panel, x, PANEL_Y);
    lv_obj_set_size(panel, PANEL_W, PANEL_H);
    lv_obj_set_style_bg_color(panel, THEME_PANEL, 0);
    lv_obj_set_style_bg_opa(panel, LV_OPA_COVER, 0);
    lv_obj_set_style_radius(panel, 12, 0);
    lv_obj_set_style_border_width(panel, 0, 0);
    lv_obj_set_style_pad_all(panel, 0, 0);
    lv_obj_clear_flag(panel, LV_OBJ_FLAG_SCROLLABLE);
    lv_obj_add_flag(panel, LV_OBJ_FLAG_EVENT_BUBBLE);

    lv_obj_t* title = make_label(panel, &font_styrene_20, accent, name);
    lv_obj_set_pos(title, PAD, 10);

    c.badge = make_label(panel, &font_styrene_14, THEME_DIM, "--:--");
    lv_obj_set_style_bg_color(c.badge, THEME_BAR_BG, 0);
    lv_obj_set_style_bg_opa(c.badge, LV_OPA_COVER, 0);
    lv_obj_set_style_radius(c.badge, LV_RADIUS_CIRCLE, 0);
    lv_obj_set_style_pad_left(c.badge, 8, 0);
    lv_obj_set_style_pad_right(c.badge, 8, 0);
    lv_obj_set_style_pad_top(c.badge, 2, 0);
    lv_obj_set_style_pad_bottom(c.badge, 2, 0);
    lv_obj_align(c.badge, LV_ALIGN_TOP_RIGHT, -12, 12);
    c.stamp = 0;
    c.stale_shown = false;

    static const char* const names[2] = {"5h", "Weekly"};
    for (int s = 0; s < 2; s++) {
        Section& sec = c.sec[s];
        sec.pct = make_label(panel, &font_styrene_48, THEME_DIM, "--%");
        lv_obj_set_pos(sec.pct, PAD, SEC_Y[s]);

        lv_obj_t* lbl = make_label(panel, &font_styrene_14, THEME_DIM, names[s]);
        lv_obj_align(lbl, LV_ALIGN_TOP_RIGHT, -PAD, SEC_Y[s] + 4);

        sec.bar = lv_bar_create(panel);
        lv_obj_set_pos(sec.bar, PAD, SEC_Y[s] + BAR_DY);
        lv_obj_set_size(sec.bar, PANEL_W - 2 * PAD, BAR_H);
        lv_bar_set_range(sec.bar, 0, 100);
        lv_bar_set_value(sec.bar, 0, LV_ANIM_OFF);
        lv_obj_set_style_bg_color(sec.bar, THEME_BAR_BG, LV_PART_MAIN);
        lv_obj_set_style_bg_opa(sec.bar, LV_OPA_COVER, LV_PART_MAIN);
        lv_obj_set_style_radius(sec.bar, 5, LV_PART_MAIN);
        lv_obj_set_style_bg_color(sec.bar, accent, LV_PART_INDICATOR);
        lv_obj_set_style_bg_opa(sec.bar, LV_OPA_COVER, LV_PART_INDICATOR);
        lv_obj_set_style_radius(sec.bar, 5, LV_PART_INDICATOR);

        sec.reset = make_label(panel, &font_styrene_16, THEME_DIM, "No data");
        lv_obj_set_pos(sec.reset, PAD, SEC_Y[s] + RESET_DY);
    }
}

static void set_section(Section& s, float pct, int reset_mins) {
    if (pct < 0) {
        lv_label_set_text(s.pct, "--%");
        lv_obj_set_style_text_color(s.pct, THEME_DIM, 0);
        lv_bar_set_value(s.bar, 0, LV_ANIM_OFF);
        lv_label_set_text(s.reset, "No data");
        return;
    }
    int p = (int)(pct + 0.5f);
    lv_label_set_text_fmt(s.pct, "%d%%", p);
    lv_obj_set_style_text_color(s.pct, THEME_TEXT, 0);
    lv_bar_set_value(s.bar, p > 100 ? 100 : p, LV_ANIM_ON);
    char buf[32];
    format_reset(reset_mins, buf, sizeof(buf));
    lv_label_set_text(s.reset, buf);
}

static void set_badge_stale(Column& c, bool stale) {
    if (stale == c.stale_shown) return;
    c.stale_shown = stale;
    lv_obj_set_style_bg_color(c.badge, stale ? THEME_STALE : THEME_BAR_BG, 0);
    lv_obj_set_style_text_color(c.badge, stale ? THEME_ON_STALE : THEME_DIM, 0);
}

void ui_dual_build(lv_obj_t* container, lv_obj_t* group) {
    build_column(group, CLAUDE, MARGIN, "Claude", THEME_ACCENT);
    build_column(group, CODEX, MARGIN + PANEL_W + PANEL_GAP, "Codex", THEME_CODEX);

    link_dot = lv_obj_create(container);
    lv_obj_set_size(link_dot, 10, 10);
    lv_obj_set_pos(link_dot, 480 - MARGIN - 8 - 10, 19);
    lv_obj_set_style_radius(link_dot, LV_RADIUS_CIRCLE, 0);
    lv_obj_set_style_border_width(link_dot, 0, 0);
    lv_obj_set_style_bg_opa(link_dot, LV_OPA_COVER, 0);
    lv_obj_set_style_bg_color(link_dot, THEME_STALE, 0);
    lv_obj_clear_flag(link_dot, LV_OBJ_FLAG_SCROLLABLE);
    lv_obj_add_flag(link_dot, LV_OBJ_FLAG_EVENT_BUBBLE);
}

void ui_dual_update(const UsageData* d, long now_epoch) {
    clock_fmt = d->clock_fmt;

    set_section(cols[CLAUDE].sec[0], d->session_pct, d->session_reset_mins);
    set_section(cols[CLAUDE].sec[1], d->weekly_pct, d->weekly_reset_mins);
    cols[CLAUDE].stamp = now_epoch;

    if (d->codex_ok) {
        set_section(cols[CODEX].sec[0], d->codex_session_pct, d->codex_session_reset_mins);
        set_section(cols[CODEX].sec[1], d->codex_weekly_pct, d->codex_weekly_reset_mins);
    } else {
        set_section(cols[CODEX].sec[0], -1.0f, -1);
        set_section(cols[CODEX].sec[1], -1.0f, -1);
    }
    cols[CODEX].stamp = d->codex_ok ? d->codex_epoch : 0;

    char buf[12];
    for (Column& c : cols) {
        format_hhmm(c.stamp, buf, sizeof(buf));
        lv_label_set_text(c.badge, buf);
    }
    ui_dual_tick(now_epoch, 0);
}

void ui_dual_tick(long now_epoch, uint32_t claude_age_ms) {
    set_badge_stale(cols[CLAUDE], claude_age_ms > (uint32_t)STALE_S * 1000u);
    const long codex_ts = cols[CODEX].stamp;
    set_badge_stale(cols[CODEX], codex_ts > 0 && now_epoch > 0 && now_epoch - codex_ts > STALE_S);
}

void ui_dual_set_live(bool live) {
    if (link_dot) lv_obj_set_style_bg_color(link_dot, live ? THEME_GREEN : THEME_STALE, 0);
}
