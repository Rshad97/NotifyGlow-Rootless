#pragma once
#include <math.h>
#include <stdbool.h>
static inline double NGClamp(double value, double fallback, double lo, double hi) {
    return isfinite(value) ? fmin(hi, fmax(lo, value)) : fallback;
}
static inline bool NGShouldRender(bool enabled, bool locked, bool onLock, bool onOpen,
                                 bool screenOn, bool lowPower, bool pauseLowPower) {
    return enabled && (locked ? onLock : onOpen) && screenOn && !(lowPower && pauseLowPower);
}
static inline bool NGIsRecent(double age) { return isfinite(age) && age >= -5 && age <= 10; }
