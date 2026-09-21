#pragma once
#include <stdbool.h>

void idle_init(void);
void idle_tick(void);
void idle_note_activity(void);

// Set the "awake" brightness target (0..255). idle owns display brightness
// (it fades between this and 0), so user brightness control routes through
// here. Applied immediately if the screen is currently fully awake; otherwise
// picked up by the next fade-in. See brightness.{h,cpp}.
void idle_set_awake_brightness(uint8_t level);

// Returns true if this press was consumed as a wake-up (caller MUST skip the
// button's normal action). Returns false when already awake — also notes the
// activity, so callers don't need a separate idle_note_activity() call.
bool idle_consume_wake_press(void);

// Fade the panel out now (a user "screen off" key). Unlike the idle timeout,
// this sleep also holds while USB power is present; any wake through
// idle_consume_wake_press() (button or touch) or idle_note_activity() ends it.
void idle_sleep_now(void);

// Touch should NOT count as activity (avoids accidental wakes from pets,
// sleeves, etc.). Callers use this to silently drop touch events while the
// panel is dark.
bool idle_is_asleep(void);
