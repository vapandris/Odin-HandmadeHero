package hmh

import win "core:sys/windows"
import "core:mem"

running: bool = true
bitmapInfo: win.BITMAPINFO
bitmapMemory: win.VOID
bitmapHeight: win.LONG
bitmapWidth:  win.LONG

Win32_Rect :: struct {
    pos:  [2]win.LONG,
    size: [2]win.LONG,
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
Win32_ResizeDIBSection :: proc "system" (windowSize: [2]win.LONG) {
    bitmapWidth = windowSize.x
    bitmapHeight = windowSize.y

    bitmapInfo.bmiHeader.biSize = size_of(bitmapInfo.bmiHeader)
    bitmapInfo.bmiHeader.biWidth = bitmapWidth
    bitmapInfo.bmiHeader.biHeight = bitmapHeight
    bitmapInfo.bmiHeader.biPlanes = 1
    bitmapInfo.bmiHeader.biBitCount = 32
    bitmapInfo.bmiHeader.biCompression = win.BI_RGB


    BYTES_PER_PX :: 4
    bitmapMemorySize : win.SIZE_T = win.SIZE_T(BYTES_PER_PX * bitmapWidth * bitmapHeight)
    if bitmapMemory != nil do win.VirtualFree(bitmapMemory, 0, win.MEM_RELEASE)
    bitmapMemory = win.VirtualAlloc(nil, bitmapMemorySize, win.MEM_COMMIT, win.PAGE_READWRITE)

    pitch := windowSize.x*BYTES_PER_PX
    row := cast(^u8)bitmapMemory
    for y in 0..<bitmapHeight {
        pixel := cast([^]u8)row
        for x in 0..<bitmapWidth {
            // BLUE
            pixel[0] = cast(u8)x
            // RED
            pixel[1] = cast(u8)y
            // GREEN
            pixel[2] = cast(u8)(x*y)
            // PADDING
            pixel[3] = 0

            pixel = mem.ptr_offset(pixel, 4)
        }
        row = mem.ptr_offset(row, pitch)
    }
}

Win32_UpdateWindow :: proc "system" (deviceContext: win.HDC, windowRect: Win32_Rect) {
    win.StretchDIBits(
        deviceContext,
        0, 0, bitmapWidth, bitmapHeight,
        0, 0, windowRect.size.x, windowRect.size.y,
        bitmapMemory,
        &bitmapInfo,
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
            Win32_ResizeDIBSection(Win32_GetClientRect(window).size)
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
            Win32_UpdateWindow(deviceContext, rect)
        }
        case: {
            result = win.DefWindowProcW(window, message, wParam, lParam)
        }
    }

    return result
}

main :: proc() {
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
        for running {
            if msgResult := win.GetMessageW(&message, nil, 0, 0); i32(msgResult) > 0 {
                win.TranslateMessage(&message)
                win.DispatchMessageW(&message)

            } else do break

        }
    } else do panic("[!] Failed to register window")
}
