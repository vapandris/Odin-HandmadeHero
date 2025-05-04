package hmh

import win "core:sys/windows"

windowCallback :: proc "system" (
        window:  win.HWND,
        message: win.UINT,
        wParam:  win.WPARAM,
        lParam:  win.LPARAM) -> (result: win.LRESULT) {
    switch message {
        case win.WM_SIZE: {
            win.OutputDebugStringA("WM_SIZE")
        }
        case win.WM_DESTROY: {
            win.OutputDebugStringA("WM_DESTROY")
        }
        case win.WM_CLOSE: {
            win.OutputDebugStringA("WM_CLOSE")
        }
        case win.WM_ACTIVATEAPP: {
            win.OutputDebugStringA("WM_ACTIVATEAPP")
        }
        case win.WM_PAINT: {
            paint: win.PAINTSTRUCT
            deviceContext := win.BeginPaint(window, &paint)
            defer win.EndPaint(window, &paint)

            winX := paint.rcPaint.left
            winY := paint.rcPaint.top
            winWidth  := paint.rcPaint.right - paint.rcPaint.left
            winHeight := paint.rcPaint.bottom - paint.rcPaint.top

            win.PatBlt(deviceContext, winX, winY, winWidth, winHeight, win.BLACKNESS)
        }
        case: {
            result = win.DefWindowProcA(window, message, wParam, lParam)
        }
    }

    return result;
}

main :: proc() {
    currInstance := win.HINSTANCE(win.GetModuleHandleW(nil))
    assert(currInstance != nil, "[!] Failed to fetch current instance")

    className := win.L("HandmadeHeroWindowClass")

    windowClass := win.WNDCLASSW {
        hInstance       = currInstance,
        style           = win.CS_OWNDC | win.CS_HREDRAW | win.CS_VREDRAW,
        lpfnWndProc     = windowCallback,
        lpszClassName   = className,
    }

    if atom := win.RegisterClassW(&windowClass); atom != 0 {
        window: win.HWND = win.CreateWindowExW(
            lpClassName     = windowClass.lpszClassName,
            lpWindowName    = win.L("Very WOW Window"),
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
        for {
            if msgResult := win.GetMessageW(&message, nil, 0, 0); i32(msgResult) > 0 {
                win.TranslateMessage(&message)
                win.DispatchMessageW(&message)

            } else do break

        }
    } else do panic("[!] Failed to register window")
}
