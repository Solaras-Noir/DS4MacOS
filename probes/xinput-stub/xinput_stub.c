/* XInput stub for the M0 feasibility test. Reports a synthetic controller 0 and logs rumble calls.
 * Self-contained: no xinput headers, imports only kernel32.dll and msvcrt.dll. */
#include <windows.h>
#include <math.h>
#include <stdio.h>

#define STUB_ERROR_EMPTY 4306
#define BTN_A 0x1000

typedef struct { WORD wButtons; BYTE bLeftTrigger, bRightTrigger; SHORT sThumbLX, sThumbLY, sThumbRX, sThumbRY; } PAD;
typedef struct { DWORD dwPacketNumber; PAD Gamepad; } STATE;
typedef struct { WORD wLeftMotorSpeed, wRightMotorSpeed; } VIBRATION;
typedef struct { BYTE Type, SubType; WORD Flags; PAD Gamepad; VIBRATION Vibration; } CAPS;
typedef struct { BYTE BatteryType, BatteryLevel; } BATTERY;
typedef struct { WORD VirtualKey; WCHAR Unicode; WORD Flags; BYTE UserIndex, HidCode; } KEYSTROKE;

static CRITICAL_SECTION g_lock;
static char g_logPath[MAX_PATH + 32];
static LONG g_packet = 0;
static LONG g_getStateCalls = 0;

static void logf_line(const char *fmt, ...) __attribute__((format(printf, 1, 2)));
static void logf_line(const char *fmt, ...) {
    char msg[384];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(msg, sizeof msg, fmt, ap);
    va_end(ap);
    SYSTEMTIME st;
    GetLocalTime(&st);
    char line[480];
    int n = snprintf(line, sizeof line, "%02d:%02d:%02d.%03d tick=%llu %s\r\n",
                     st.wHour, st.wMinute, st.wSecond, st.wMilliseconds,
                     (unsigned long long)GetTickCount64(), msg);
    if (n <= 0) return;
    if (n >= (int)sizeof line) n = (int)sizeof line - 1;
    EnterCriticalSection(&g_lock);
    HANDLE h = CreateFileA(g_logPath, FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL,
                           OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (h != INVALID_HANDLE_VALUE) {
        DWORD w;
        WriteFile(h, line, (DWORD)n, &w, NULL);
        CloseHandle(h);
    }
    LeaveCriticalSection(&g_lock);
}

BOOL WINAPI DllMain(HINSTANCE inst, DWORD reason, LPVOID reserved) {
    (void)reserved;
    if (reason == DLL_PROCESS_ATTACH) {
        InitializeCriticalSection(&g_lock);
        char dir[MAX_PATH];
        DWORD len = GetTempPathA(sizeof dir, dir);
        if (len == 0 || len >= sizeof dir) { dir[0] = 0; }
        snprintf(g_logPath, sizeof g_logPath, "%sxinput-stub.log", dir);
        char mod[MAX_PATH];
        DWORD ml = GetModuleFileNameA(inst, mod, sizeof mod);
        if (ml == 0) snprintf(mod, sizeof mod, "(unknown)");
        logf_line("DLL_PROCESS_ATTACH loaded as %s", mod);
    }
    return TRUE;
}

static void fillState(STATE *s) {
    ULONGLONG t = GetTickCount64();
    const double pi = 3.14159265358979323846;
    double ang = 2.0 * pi * (double)(t % 4000) / 4000.0;
    s->dwPacketNumber = (DWORD)InterlockedIncrement(&g_packet);
    s->Gamepad.wButtons = (t % 2000) < 1000 ? BTN_A : 0;
    s->Gamepad.bLeftTrigger = 0;
    s->Gamepad.bRightTrigger = 0;
    s->Gamepad.sThumbLX = (SHORT)(20000.0 * cos(ang));
    s->Gamepad.sThumbLY = (SHORT)(20000.0 * sin(ang));
    s->Gamepad.sThumbRX = 0;
    s->Gamepad.sThumbRY = 0;
}

static DWORD getState(DWORD idx, STATE *s, const char *name) {
    if (idx != 0) return ERROR_DEVICE_NOT_CONNECTED;
    if (!s) return ERROR_BAD_ARGUMENTS;
    fillState(s);
    LONG n = InterlockedIncrement(&g_getStateCalls);
    if (n % 500 == 0) logf_line("%s polled, %ld calls so far", name, (long)n);
    return ERROR_SUCCESS;
}

DWORD WINAPI XInputGetState(DWORD idx, STATE *s) { return getState(idx, s, "XInputGetState"); }
DWORD WINAPI XInputGetStateEx(DWORD idx, STATE *s) { return getState(idx, s, "XInputGetStateEx"); }

DWORD WINAPI XInputSetState(DWORD idx, VIBRATION *v) {
    if (idx != 0) return ERROR_DEVICE_NOT_CONNECTED;
    if (!v) return ERROR_BAD_ARGUMENTS;
    logf_line("XInputSetState left=%u right=%u", (unsigned)v->wLeftMotorSpeed, (unsigned)v->wRightMotorSpeed);
    return ERROR_SUCCESS;
}

DWORD WINAPI XInputGetCapabilities(DWORD idx, DWORD flags, CAPS *c) {
    (void)flags;
    if (idx != 0) return ERROR_DEVICE_NOT_CONNECTED;
    if (!c) return ERROR_BAD_ARGUMENTS;
    ZeroMemory(c, sizeof *c);
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
