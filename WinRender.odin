#+build windows
package hmh

import win "core:sys/windows"

WindowSize: [2]win.LONG

Win32_Rect :: struct {
    pos:  [2]win.LONG,
    size: [2]win.LONG,
}

Win32_OffscreenBuffer :: struct {
    info: win.BITMAPINFO,
    memory: win.VOID,
    height: win.LONG,
    width:  win.LONG,
    pitch:  win.LONG,
}
OffscreenBuffer: Win32_OffscreenBuffer

// DIB is Device Independent Bitmap
Win32_ResizeDIBSection :: proc "system" (buffer: ^Win32_OffscreenBuffer, windowSize: [2]win.LONG) {
    WindowSize = windowSize
    buffer.width = windowSize.x
    buffer.height = windowSize.y


    buffer.info.bmiHeader.biSize = size_of(buffer.info.bmiHeader)
    buffer.info.bmiHeader.biWidth = buffer.width
    buffer.info.bmiHeader.biHeight = buffer.height
    buffer.info.bmiHeader.biPlanes = 1
    buffer.info.bmiHeader.biBitCount = 32
    buffer.info.bmiHeader.biCompression = win.BI_RGB


    BYTES_PER_PX :: 4
    bitmapMemorySize : win.SIZE_T = win.SIZE_T(BYTES_PER_PX * buffer.width * buffer.height)
    if buffer.memory != nil do win.VirtualFree(buffer.memory, 0, win.MEM_RELEASE)
    buffer.memory = win.VirtualAlloc(nil, bitmapMemorySize, win.MEM_COMMIT, win.PAGE_READWRITE)

    buffer.pitch = WindowSize.x*BYTES_PER_PX
}

Win32_UpdateWindow :: proc "system" (buffer: ^Win32_OffscreenBuffer, deviceContext: win.HDC, clientRect: Win32_Rect) {
    win.StretchDIBits(
        deviceContext,
        0, 0, clientRect.size.x, clientRect.size.y,
        0, 0, buffer.width, buffer.height,
        buffer.memory,
        &buffer.info,
        win.DIB_RGB_COLORS,
        win.SRCCOPY,
    )
}

// Following functions are typicly used for rendering but not necessarily limited to it.
Win32_GetRect :: #force_inline proc "system" (rect: win.RECT) -> Win32_Rect {
    return {
        pos = { rect.left, rect.top },
        size = {
            rect.right - rect.left,
            rect.bottom - rect.top,
        }
    }
}

Win32_GetClientRect :: proc "system" (window: win.HWND) -> Win32_Rect {
    rect: win.RECT
    win.GetClientRect(window, &rect)
    return Win32_GetRect(rect)
}
