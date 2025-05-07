package hmh

import win "core:sys/windows"
import "core:mem"

running: bool = true

Win32_OffscreenBuffer :: struct {
    info: win.BITMAPINFO,
    memory: win.VOID,
    height: win.LONG,
    width:  win.LONG,
    pitch:  win.LONG,
}
offscreenBuffer: Win32_OffscreenBuffer
globalWindowSize: [2]win.LONG

Win32_Rect :: struct {
    pos:  [2]win.LONG,
    size: [2]win.LONG,
}

Win32_RenderTrippyShtuff :: proc "system" (buffer: Win32_OffscreenBuffer, offset: [2]i32) {
    row := cast(^u8)buffer.memory
    for y in 0..<buffer.height {
        pixel := cast(^u32)row
        for x in 0..<buffer.width {
            // BLUE
            blue  := cast(u8)(x + offset.x)
            red   := cast(u8)(x*y)
            green := cast(u8)(y + offset.y)

            pixel^ = u32(red) << 16
            pixel^ |= u32(green) << 8
            pixel^ |= u32(blue) << 0

            pixel = mem.ptr_offset(pixel, 1)
        }
        row = mem.ptr_offset(row, buffer.pitch)
    }
}

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

// DIB is Device Independent Bitmap
Win32_ResizeDIBSection :: proc "system" (buffer: ^Win32_OffscreenBuffer, windowSize: [2]win.LONG) {
    globalWindowSize = windowSize
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

    buffer.pitch = globalWindowSize.x*BYTES_PER_PX
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

Win32_WindowCallback :: proc "system" (
        window:  win.HWND,
        message: win.UINT,
        wParam:  win.WPARAM,
        lParam:  win.LPARAM) -> (result: win.LRESULT) {
    switch message {
        case win.WM_SIZE: {
            win.OutputDebugStringA("WM_SIZE")
        }
        case win.WM_DESTROY: {
            running = false
            win.OutputDebugStringA("WM_DESTROY")
        }
        case win.WM_CLOSE: {
            running = false
            win.OutputDebugStringA("WM_CLOSE")
        }
        case win.WM_ACTIVATEAPP: {
            win.OutputDebugStringA("WM_ACTIVATEAPP")
        }
        case win.WM_PAINT: {
            paint: win.PAINTSTRUCT
            deviceContext := win.BeginPaint(window, &paint)
            defer win.EndPaint(window, &paint)

            rect := Win32_GetRect(paint.rcPaint)
            Win32_UpdateWindow(&offscreenBuffer, deviceContext, Win32_GetClientRect(window))
        }
        case: {
            result = win.DefWindowProcW(window, message, wParam, lParam)
        }
    }

    return result
}

main :: proc() {
    Win32_ResizeDIBSection(&offscreenBuffer, {1280, 720})

    currInstance := win.HINSTANCE(win.GetModuleHandleW(nil))
    assert(currInstance != nil, "[!] Failed to fetch current instance")

    className := win.L("HandmadeHeroWindowClass")
    title := win.L("Very WOW Window")

    windowClass := win.WNDCLASSW {
        hInstance       = currInstance,
        style           = win.CS_OWNDC | win.CS_HREDRAW | win.CS_VREDRAW,
        lpfnWndProc     = Win32_WindowCallback,
        lpszClassName   = className,
    }

    if atom := win.RegisterClassW(&windowClass); atom != 0 {
        window: win.HWND = win.CreateWindowExW(
            lpClassName     = windowClass.lpszClassName,
            lpWindowName    = title,
            dwStyle         = win.WS_OVERLAPPEDWINDOW | win.WS_VISIBLE,
            X               = win.CW_USEDEFAULT,
            Y               = win.CW_USEDEFAULT,
            nWidth          = win.CW_USEDEFAULT,
            nHeight         = win.CW_USEDEFAULT,
            hInstance       = currInstance,
            dwExStyle = 0, hWndParent = nil, hMenu = nil, lpParam = nil,
        )

        if window == nil do panic("[!] Failed to create window!")

        message: win.MSG
        offset := [2]i32{}
        for running {
            for win.PeekMessageW(&message, nil, 0, 0, win.PM_REMOVE) {
                if message.message == win.WM_QUIT do running = false

                win.TranslateMessage(&message)
                win.DispatchMessageW(&message)
            }

            offset.x += 1
            if offset.x == 255 {
                offset.x = 0
                offset.y += 1
            }

            if offset.y == 255 {
                offset = {}
            }
            Win32_RenderTrippyShtuff(offscreenBuffer, offset)

            deviceContext := win.GetDC(window)
            Win32_UpdateWindow(&offscreenBuffer, deviceContext, Win32_GetClientRect(window))
        }
    } else do panic("[!] Failed to register window")
}
