#+build windows
package hmh

import win "core:sys/windows"
import "base:runtime"

// TODO: Remove
import "core:fmt"

Running: bool = true

Win32_WindowCallback :: proc "system" (
        window:  win.HWND,
        message: win.UINT,
        wParam:  win.WPARAM,
        lParam:  win.LPARAM) -> (result: win.LRESULT) {
    switch message {
    case win.WM_SIZE: 
        win.OutputDebugStringA("WM_SIZE")

    case win.WM_DESTROY: 
        Running = false
        win.OutputDebugStringA("WM_DESTROY")

    case win.WM_SYSKEYDOWN: fallthrough
    case win.WM_SYSKEYUP:   fallthrough
    case win.WM_KEYDOWN:    fallthrough
    case win.WM_KEYUP:
        context = runtime.default_context()
        panic("[!] Key-handling got called from implicit dispatch")

    case win.WM_CLOSE: 
        Running = false
        win.OutputDebugStringA("WM_CLOSE")

    case win.WM_ACTIVATEAPP: 
        win.OutputDebugStringA("WM_ACTIVATEAPP")

    case win.WM_PAINT: 
        paint: win.PAINTSTRUCT
        deviceContext := win.BeginPaint(window, &paint)
        defer win.EndPaint(window, &paint)

        rect := Win32_GetRect(paint.rcPaint)
        Win32_UpdateWindow(&OffscreenBuffer, deviceContext, Win32_GetClientRect(window))

    case:
        result = win.DefWindowProcW(window, message, wParam, lParam)
    }

    return result
}

main :: proc() {
    win.QueryPerformanceFrequency(&PerformanceQueryFrequency)

    Win32_ResizeDIBSection(&OffscreenBuffer, {1280, 720})

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

        Win32_InitDSound()

        gameMemory: Game_Memory
        {
            storageSize:uint = 64 * runtime.Megabyte
            ptr: rawptr = win.VirtualAlloc(nil, storageSize, win.MEM_RESERVE|win.MEM_COMMIT, win.PAGE_READWRITE)
            assert(ptr != nil)
            gameMemory.permanentStorage = (cast([^]byte)(ptr))[:storageSize]

            storageSize = 2 * runtime.Gigabyte
            ptr = win.VirtualAlloc(nil, storageSize, win.MEM_RESERVE|win.MEM_COMMIT, win.PAGE_READWRITE)
            assert(ptr != nil)
            gameMemory.temporaryStorage = (cast([^]byte)(ptr))[:storageSize]
        }

        mainception := Win32_DEBUG_ReadEntireFile(#file)
        content := "Some very wholesome text\nOf course it contains a new ljne and ltos of typos!\nAnd these guys: áß÷×¤=ŁÍ\nThat's some advanced math r9ght there"
        Win32_DEBUG_WriteEntireFile("test.out", transmute([]byte)(content[:]))
        Win32_DEBUG_WriteEntireFile("attack of the clones.0D1N", mainception)

        latestCounter := Win32_GetWallClock()

        message: win.MSG
        offset := [2]u8{}

        newInput: Game_KeyInput
        oldInput: Game_KeyInput


        for Running {

            for keyInput, i in newInput.keys {
                oldInput.keys[i] = keyInput
            }
            for win.PeekMessageW(&message, nil, 0, 0, win.PM_REMOVE) {
                if message.message == win.WM_QUIT do Running = false

                switch message.message {
                case win.WM_QUIT:
                    Running = false
                case win.WM_SYSKEYDOWN: fallthrough
                case win.WM_SYSKEYUP:   fallthrough
                case win.WM_KEYDOWN:    fallthrough
                case win.WM_KEYUP:
                    keycode := u32(message.wParam)
                    wasDown := (message.lParam & (1 << 30)) != 0
                    isDown  := (message.lParam & (1 << 31)) == 0

                    // Only process keyup, when it wasn't down previous frame, and now it is, or reversed.
                    if wasDown != isDown {
                        switch keycode {
                        case 'W': newInput.keys[.UP].endedDown      = (message.message == win.WM_KEYDOWN)
                        case 'S': newInput.keys[.DOWN].endedDown    = (message.message == win.WM_KEYDOWN)
                        case 'A': newInput.keys[.LEFT].endedDown    = (message.message == win.WM_KEYDOWN)
                        case 'D': newInput.keys[.RIGHT].endedDown   = (message.message == win.WM_KEYDOWN)
                        case win.VK_ESCAPE: Running = false
                        }
                    }

                    altKeyWasDown := bool(message.lParam & (1 << 29))
                    if keycode == win.VK_F4 && altKeyWasDown {
                        Running = false
                    }
                case:
                    win.TranslateMessage(&message)
                    win.DispatchMessageW(&message)
                }

            }

            //for controlIndex: win.XUSER; controlIndex < cast(win.XUSER)win.XUSER_MAX_COUNT; controlIndex+=cast(win.XUSER)1 {
            //    controllerState: win.XINPUT_STATE
            //    sysError := win.XInputGetState(controlIndex, &controllerState)
            //
            //    if sysError == .SUCCESS {
            //        // controller plugged in
            //        gamepad := &controllerState.Gamepad
            //
            //        up              := .DPAD_UP in gamepad.wButtons
            //        down            := .DPAD_DOWN in gamepad.wButtons
            //        left            := .DPAD_LEFT in gamepad.wButtons
            //        right           := .DPAD_RIGHT in gamepad.wButtons
            //        start           := .START in gamepad.wButtons
            //        back            := .BACK in gamepad.wButtons
            //        leftShoulder    := .LEFT_SHOULDER in gamepad.wButtons
            //        rightShoulder   := .RIGHT_SHOULDER in gamepad.wButtons
            //        aButton         := .A in gamepad.wButtons
            //        bButton         := .B in gamepad.wButtons
            //        xButton         := .X in gamepad.wButtons
            //        yButton         := .Y in gamepad.wButtons
            //
            //        stickX := gamepad.sThumbLX
            //        stickY := gamepad.sThumbLY
            //
            //        if up   do newInput.keys[.UP]      = { halfTransitionTime = 1, endedDown = true }
            //        if down do newInput.keys[.DOWN]    = { halfTransitionTime = 1, endedDown = true }
            //        if right do newInput.keys[.RIGHT]  = { halfTransitionTime = 1, endedDown = true }
            //        if left do newInput.keys[.LEFT]    = { halfTransitionTime = 1, endedDown = true }
            //
            //    } else {
            //        // controller not available
            //    }
            //}

            deviceContext := win.GetDC(window)
            Game_UpdateAndRender(
                &gameMemory,
                Game_OffscreenBuffer{
                    memory = OffscreenBuffer.memory,
                    height = OffscreenBuffer.height,
                    width  = OffscreenBuffer.width,
                    pitch  = OffscreenBuffer.pitch,
                },
                newInput,
            )
            Win32_UpdateWindow(&OffscreenBuffer, deviceContext, Win32_GetClientRect(window))

            offset += {1, 1}

            endCounter := Win32_GetWallClock()
            elapsedCounter := endCounter - latestCounter

            millisecondsPerFrame := (1000*elapsedCounter) / PerformanceQueryFrequency
            framesPerSecond := PerformanceQueryFrequency / elapsedCounter
            fmt.println(millisecondsPerFrame, "ms/Frame\t|\t", framesPerSecond, "FPS")

            latestCounter = endCounter
        }
    } else do panic("[!] Failed to register window")
}
