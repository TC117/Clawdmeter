#pragma once
#include <Arduino.h>

struct UsageData {
    float session_pct;       // utilization 0-100 (5h window Pro/Max; spending % Enterprise)
    int session_reset_mins;  // minutes until reset
    float weekly_pct;        // 7-day utilization (Pro/Max only; 0 for Enterprise)
    int weekly_reset_mins;   // minutes until weekly reset (Pro/Max only)
    char status[16];         // "allowed", "limited", etc.
    bool chime;              // play the session-reset chime; false unless daemon opts in
    bool enterprise;         // true = Enterprise spending-limit account
    int time_pct;            // 0-100: fraction of billing period elapsed (Enterprise)
    int period_days;         // total billing period length in days (Enterprise)
    char reset_date[12];     // formatted reset date e.g. "Jul 1" (Enterprise)
    long clock_epoch;        // local wall-clock epoch (s) from daemon; 0 = not provided
    int  clock_fmt;          // 12 or 24 (hour format from daemon); defaults to 24
    // Codex column (landscape dual layout). Absent payload keys → unknown.
    bool  codex_ok;                  // daemon had a Codex reading ("cok")
    float codex_session_pct;         // 5h window %, -1 = unknown / rolled over
    int   codex_session_reset_mins;  // minutes until the 5h reset, -1 = unknown
    float codex_weekly_pct;          // weekly %, -1 = unknown
    int   codex_weekly_reset_mins;   // minutes until the weekly reset, -1 = unknown
    long  codex_epoch;               // local wall-clock epoch (s) of the reading, 0 = none
    bool ok;                 // data parse succeeded
    bool valid;              // false until first successful parse
};
