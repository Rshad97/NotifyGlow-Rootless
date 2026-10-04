#pragma once
#include <stdint.h>
#define NG_PREVIEW "com.rshad.notifyglow/preview"
#define NG_PING "com.rshad.notifyglow/ping"
#define NG_REPLY "com.rshad.notifyglow/reply"
enum { NGReady=1, NGWindowCreated=2, NGNoScene=3, NGException=4 };
// Low byte is result; next byte describes installed hooks, not notification data.
static inline uint64_t NGDiagnosticState(unsigned result, unsigned hooks) {
    return ((uint64_t)102 << 16) | ((uint64_t)hooks << 8) | result;
}
