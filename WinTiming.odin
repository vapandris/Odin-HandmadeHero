#+build windows
package hmh

import win "core:sys/windows"

PerformanceQueryFrequency: win.LARGE_INTEGER

Win32_GetSecondsElapsed :: proc(start: win.LARGE_INTEGER, end: win.LARGE_INTEGER) -> f32 {
    return f32(end - start) / f32(PerformanceQueryFrequency)
}

Win32_GetWallClock :: proc() -> (result: win.LARGE_INTEGER) {
    win.QueryPerformanceCounter(&result)
    return result
}
