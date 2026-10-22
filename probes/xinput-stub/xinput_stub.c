/* XInput stub for the M0 feasibility test. Reports a synthetic controller 0 and logs rumble calls.
 * Self-contained: no xinput headers, imports only kernel32.dll. */
#include <windows.h>

#define STUB_ERROR_EMPTY 4306
#define BTN_A 0x1000

typedef struct { WORD wButtons; BYTE bLeftTrigger, bRightTrigger; SHORT sThumbLX, sThumbLY, sThumbRX, sThumbRY; } PAD;
typedef struct { DWORD dwPacketNumber; PAD Gamepad; } STATE;
typedef struct { WORD wLeftMotorSpeed, wRightMotorSpeed; } VIBRATION;
typedef struct { BYTE Type, SubType; WORD Flags; PAD Gamepad; VIBRATION Vibration; } CAPS;
typedef struct { BYTE BatteryType, BatteryLevel; } BATTERY;
typedef struct { WORD VirtualKey; WCHAR Unicode; WORD Flags; BYTE UserIndex, HidCode; } KEYSTROKE;

static volatile LONG g_lock = 0;   /* spinlock; avoids any init in DllMain */
static char g_logPath[MAX_PATH + 32];
static int g_logPathReady = 0;
static LONG g_packet = 0;
static LONG g_getStateCalls = 0;

/* Tiny buffer builder so the stub needs no C runtime (imports KERNEL32 only). */
typedef struct { char buf[480]; int n; } LINE;
static void put_s(LINE *l, const char *s) {
    while (*s && l->n < (int)sizeof l->buf - 3) l->buf[l->n++] = *s++;
}
static void put_u(LINE *l, unsigned long long v, int minDigits) {
    char tmp[24];
    int i = 0;
    do { tmp[i++] = (char)('0' + (int)(v % 10)); v /= 10; } while (v && i < 23);
    while (i < minDigits && i < 23) tmp[i++] = '0';
    while (i > 0 && l->n < (int)sizeof l->buf - 3) l->buf[l->n++] = tmp[--i];
}

/* Appends one line to %TEMP%\xinput-stub.log. Caller has filled `l` with the message. */
static void log_line(LINE *l) {
    SYSTEMTIME st;
    GetLocalTime(&st);
    LINE out;
    out.n = 0;
    put_u(&out, st.wHour, 2); put_s(&out, ":");
    put_u(&out, st.wMinute, 2); put_s(&out, ":");
    put_u(&out, st.wSecond, 2); put_s(&out, ".");
    put_u(&out, st.wMilliseconds, 3); put_s(&out, " tick=");
    put_u(&out, GetTickCount64(), 1); put_s(&out, " ");
    l->buf[l->n] = 0;
    put_s(&out, l->buf);
    out.buf[out.n++] = '\r';
    out.buf[out.n++] = '\n';
    const char *line = out.buf;
    int n = out.n;
    while (InterlockedCompareExchange(&g_lock, 1, 0) != 0) Sleep(0);
    if (!g_logPathReady) {
        char dir[MAX_PATH];
        DWORD len = GetTempPathA(sizeof dir, dir);
        if (len == 0 || len + 16 >= sizeof dir) { dir[0] = 0; len = 0; }
        const char *nm = "xinput-stub.log";
        DWORD i = 0;
        for (; i < len; i++) g_logPath[i] = dir[i];
        for (DWORD j = 0; nm[j]; j++) g_logPath[i++] = nm[j];
        g_logPath[i] = 0;
        g_logPathReady = 1;
    }
    HANDLE h = CreateFileA(g_logPath, FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL,
                           OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (h != INVALID_HANDLE_VALUE) {
        DWORD w;
        WriteFile(h, line, (DWORD)n, &w, NULL);
        CloseHandle(h);
    }
    InterlockedExchange(&g_lock, 0);
}

/* DllMain does nothing but return TRUE. It is not exported (ordinals come from the .def files). */
BOOL WINAPI DllMain(HINSTANCE inst, DWORD reason, LPVOID reserved) {
    (void)inst; (void)reason; (void)reserved;
    return TRUE;
}

/* Sine approximation (Bhaskara I), turns in [0,1): good to about 0.2%, enough for a test pattern. */
static double sin_turns(double t) {
    int neg = 0;
    if (t >= 0.5) { t -= 0.5; neg = 1; }
    double x = t * 360.0;                  /* degrees, [0,180) after the fold */
    double v = 4.0 * x * (180.0 - x) / (40500.0 - x * (180.0 - x));
    return neg ? -v : v;
}

static void fillState(STATE *s) {
    ULONGLONG t = GetTickCount64();
    double turns = (double)(t % 4000) / 4000.0;
    double c = turns + 0.25;
    if (c >= 1.0) c -= 1.0;
    s->dwPacketNumber = (DWORD)InterlockedIncrement(&g_packet);
    s->Gamepad.wButtons = (t % 2000) < 1000 ? BTN_A : 0;
    s->Gamepad.bLeftTrigger = 0;
    s->Gamepad.bRightTrigger = 0;
    s->Gamepad.sThumbLX = (SHORT)(20000.0 * sin_turns(c));   /* cos */
    s->Gamepad.sThumbLY = (SHORT)(20000.0 * sin_turns(turns));
    s->Gamepad.sThumbRX = 0;
    s->Gamepad.sThumbRY = 0;
}

static DWORD getState(DWORD idx, STATE *s, const char *name) {
    if (idx != 0) return ERROR_DEVICE_NOT_CONNECTED;
    if (!s) return ERROR_BAD_ARGUMENTS;
    fillState(s);
    LONG n = InterlockedIncrement(&g_getStateCalls);
    if (n % 500 == 0) {
        LINE l; l.n = 0;
        put_s(&l, name); put_s(&l, " polled, "); put_u(&l, (unsigned long long)n, 1); put_s(&l, " calls so far");
        log_line(&l);
    }
    return ERROR_SUCCESS;
}

DWORD WINAPI XInputGetState(DWORD idx, STATE *s) { return getState(idx, s, "XInputGetState"); }
DWORD WINAPI XInputGetStateEx(DWORD idx, STATE *s) { return getState(idx, s, "XInputGetStateEx"); }

DWORD WINAPI XInputSetState(DWORD idx, VIBRATION *v) {
    if (idx != 0) return ERROR_DEVICE_NOT_CONNECTED;
    if (!v) return ERROR_BAD_ARGUMENTS;
    LINE l; l.n = 0;
    put_s(&l, "XInputSetState left="); put_u(&l, v->wLeftMotorSpeed, 1);
    put_s(&l, " right="); put_u(&l, v->wRightMotorSpeed, 1);
    log_line(&l);
    return ERROR_SUCCESS;
}

DWORD WINAPI XInputGetCapabilities(DWORD idx, DWORD flags, CAPS *c) {
    (void)flags;
    if (idx != 0) return ERROR_DEVICE_NOT_CONNECTED;
    if (!c) return ERROR_BAD_ARGUMENTS;
    { BYTE *p = (BYTE *)c; for (size_t i = 0; i < sizeof *c; i++) p[i] = 0; }
    c->Type = 1;     /* XINPUT_DEVTYPE_GAMEPAD */
    c->SubType = 1;  /* XINPUT_DEVSUBTYPE_GAMEPAD */
    c->Gamepad.wButtons = 0xF3FF;
    c->Gamepad.bLeftTrigger = 255;
    c->Gamepad.bRightTrigger = 255;
    c->Gamepad.sThumbLX = (SHORT)-64;
    c->Gamepad.sThumbLY = (SHORT)-64;
    c->Gamepad.sThumbRX = (SHORT)-64;
    c->Gamepad.sThumbRY = (SHORT)-64;
    c->Vibration.wLeftMotorSpeed = 255;
    c->Vibration.wRightMotorSpeed = 255;
    return ERROR_SUCCESS;
}

void WINAPI XInputEnable(BOOL enable) { (void)enable; }

DWORD WINAPI XInputGetBatteryInformation(DWORD idx, BYTE devType, BATTERY *b) {
    (void)devType;
    if (idx != 0) return ERROR_DEVICE_NOT_CONNECTED;
    if (!b) return ERROR_BAD_ARGUMENTS;
    b->BatteryType = 1;   /* BATTERY_TYPE_WIRED */
    b->BatteryLevel = 3;  /* BATTERY_LEVEL_FULL */
    return ERROR_SUCCESS;
}

DWORD WINAPI XInputGetKeystroke(DWORD idx, DWORD reserved, KEYSTROKE *k) {
    (void)reserved; (void)k;
    if (idx != 0 && idx != 0xFF) return ERROR_DEVICE_NOT_CONNECTED;
    return STUB_ERROR_EMPTY;
}

DWORD WINAPI XInputGetDSoundAudioDeviceGuids(DWORD idx, void *render, void *capture) {
    (void)render; (void)capture;
    (void)idx;
    return ERROR_DEVICE_NOT_CONNECTED;
}

/* xinput1_4 only (ordinal 10). Wine marks it a stub; we report no audio devices. */
DWORD WINAPI XInputGetAudioDeviceIds(DWORD idx, void *render, void *renderCount, void *capture, void *captureCount) {
    (void)idx; (void)render; (void)renderCount; (void)capture; (void)captureCount;
    return ERROR_DEVICE_NOT_CONNECTED;
}

/* xinput1_4 only (ordinal 108). Same layout as XInputGetCapabilities plus a reserved argument. */
DWORD WINAPI XInputGetCapabilitiesEx(DWORD unk, DWORD idx, DWORD flags, void *caps) {
    (void)unk;
    return XInputGetCapabilities(idx, flags, (CAPS *)caps);
}
