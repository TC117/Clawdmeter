#pragma once
#include <lvgl.h>
#include "data.h"

// Landscape (W > H) live usage view: Claude and Codex side by side, each with
// 5h + Weekly and a last-update badge. The clock above them stays owned by
// ui.cpp. ui.cpp calls these only when its layout is landscape.

// Panels go in `group` (hidden with the rest of the live view); the link dot
// goes in `container` so it stays visible on the pairing / idle views.
void ui_dual_build(lv_obj_t* container, lv_obj_t* group);

// Apply an ok:true payload to the Claude column (numbers, stamp, badge text).
// now_epoch = device local wall-clock epoch (s), 0 when the daemon sends no clock.
// ok:false payloads never reach this, so the last Claude numbers stay and the
// badge ages.
void ui_dual_update_claude(const UsageData* d, long now_epoch);

// Apply any valid payload (ok or not) to the Codex column: its numbers when
// codex_ok, otherwise "No data" and a "--:--" badge. Also takes the badge hour
// format from payloads that carry a clock.
void ui_dual_update_codex(const UsageData* d);

// Re-evaluate badge staleness. Cheap when nothing changed; call every loop.
// A column only goes stale after it has had data.
void ui_dual_tick(long now_epoch, uint32_t claude_age_ms);

// Link dot: green while the live usage view shows, amber otherwise.
void ui_dual_set_live(bool live);
