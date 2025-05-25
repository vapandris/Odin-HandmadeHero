#+build windows
package hmh

import win "core:sys/windows"
import "core:mem"
import "core:fmt"
import "base:runtime"

Running: bool = true

Win32_OffscreenBuffer :: struct {
    info: win.BITMAPINFO,
    memory: win.VOID,
    height: win.LONG,
    width:  win.LONG,
    pitch:  win.LONG,
}
OffscreenBuffer: Win32_OffscreenBuffer
WindowSize: [2]win.LONG

Win32_Rect :: struct {
    pos:  [2]win.LONG,
    size: [2]win.LONG,
}

DirectSoundCreate :: #type proc "system" (win.LPCGUID, rawptr, win.LPUNKNOWN) -> win.HRESULT
Win32_InitDSound :: proc () {
    directSoundLib := win.LoadLibraryW(win.L("dsound.dll"))
    if directSoundLib == nil do return

    directSoundCreate := cast(DirectSoundCreate)win.GetProcAddress(directSoundLib, "DirectSoundCreate")
    if directSoundCreate == nil do return
}

Win32_RenderTrippyShtuff :: proc "system" (buffer: Win32_OffscreenBuffer, offset: [2]u8) {
    row := cast(^u8)buffer.memory
    for y in 0..<buffer.height {
        pixel := cast(^u32)row
        for x in 0..<buffer.width {
            // BLUE
            blue  := cast(u8)x + offset.x
            red   := cast(u8)(x*y)
            green := cast(u8)y + offset.y

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

Win32_DEBUG_ReadEntireFile :: proc(fileName: string) -> []byte {
    fileHandle := win.CreateFileW(
        win.utf8_to_wstring(fileName),
        win.GENERIC_READ,
        win.FILE_SHARE_READ,
        nil,
        win.OPEN_EXISTING,
        0, nil
    )

    if fileHandle == win.INVALID_HANDLE_VALUE do panic("[!] Failed to open file")

    fileSizeBig: win.LARGE_INTEGER
    if !win.GetFileSizeEx(fileHandle, &fileSizeBig) do panic("[!] Failed to get FileSize")

    assert(fileSizeBig <= 0xFFFFFFFF)
    fileSize := u32(fileSizeBig)

    mem: rawptr = win.VirtualAlloc(nil, uint(fileSize), win.MEM_RESERVE|win.MEM_COMMIT, win.PAGE_READWRITE)
    assert(mem != nil)

    bytesRead: win.DWORD
    if win.ReadFile(fileHandle, mem, fileSize, &bytesRead, nil) == false {
        Win32_DEBUG_FreeFileMemory(mem)
        mem = nil
    }
    assert(bytesRead == fileSize)

    win.CloseHandle(fileHandle)

    return (cast([^]byte)(mem))[:fileSize]
}

Win32_DEBUG_FreeFileMemory :: proc(memory: rawptr) {
    win.VirtualFree(memory, 0, win.MEM_RELEASE)
}

Win32_DEBUG_WriteEntireFile :: proc(fileName: string, memory: []byte) -> (ok: bool) {
    fileHandle := win.CreateFileW(
        win.utf8_to_wstring(fileName),
        win.GENERIC_WRITE,
        0,
        nil,
        win.CREATE_ALWAYS,
        0, nil
    )

    if fileHandle == win.INVALID_HANDLE_VALUE do panic("[!] Failed to open file")

    bytesWritten: win.DWORD
    if win.WriteFile(fileHandle, &(memory[0]), u32(len(memory)), &bytesWritten, nil) == true {
        ok = true
    } else {
        panic("[!] Failed to write file")
    }
    assert(u32(len(memory)) == bytesWritten)

    return ok
}


NewInput: Game_KeyInput
OldInput: Game_KeyInput

Win32_ProcessKeyboardMessage :: proc() {

}

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
    performanceCountPerSecond: win.LARGE_INTEGER
    win.QueryPerformanceFrequency(&performanceCountPerSecond)

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

        latestCounter: win.LARGE_INTEGER
        win.QueryPerformanceCounter(&latestCounter)

        message: win.MSG
        offset := [2]u8{}
        for Running {
            NewInput = {}
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
                        NewInput.keys[.UP].endedDown = (keycode == 'W')
                        NewInput.keys[.DOWN].endedDown = (keycode == 'S')
                        NewInput.keys[.LEFT].endedDown = (keycode == 'A')
                        NewInput.keys[.RIGHT].endedDown = (keycode == 'D')
                        if keycode == win.VK_ESCAPE {
                            Running = false
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

            for controlIndex: win.XUSER; controlIndex < cast(win.XUSER)win.XUSER_MAX_COUNT; controlIndex+=cast(win.XUSER)1 {
                controllerState: win.XINPUT_STATE
                sysError := win.XInputGetState(controlIndex, &controllerState)

                if sysError == .SUCCESS {
                    // controller plugged in
                    gamepad := &controllerState.Gamepad

                    up              := .DPAD_UP in gamepad.wButtons
                    down            := .DPAD_DOWN in gamepad.wButtons
                    left            := .DPAD_LEFT in gamepad.wButtons
                    right           := .DPAD_RIGHT in gamepad.wButtons
                    start           := .START in gamepad.wButtons
                    back            := .BACK in gamepad.wButtons
                    leftShoulder    := .LEFT_SHOULDER in gamepad.wButtons
                    rightShoulder   := .RIGHT_SHOULDER in gamepad.wButtons
                    aButton         := .A in gamepad.wButtons
                    bButton         := .B in gamepad.wButtons
                    xButton         := .X in gamepad.wButtons
                    yButton         := .Y in gamepad.wButtons

                    stickX := gamepad.sThumbLX
                    stickY := gamepad.sThumbLY

                    if up   do NewInput.keys[.UP]      = { halfTransitionTime = 1, endedDown = true }
                    if down do NewInput.keys[.DOWN]    = { halfTransitionTime = 1, endedDown = true }
                    if right do NewInput.keys[.RIGHT]  = { halfTransitionTime = 1, endedDown = true }
                    if left do NewInput.keys[.LEFT]    = { halfTransitionTime = 1, endedDown = true }

                } else {
                    // controller not available
                }
            }

            deviceContext := win.GetDC(window)
            Game_UpdateAndRender(
                &gameMemory,
                Game_OffscreenBuffer{
                    memory = OffscreenBuffer.memory,
                    height = OffscreenBuffer.height,
                    width  = OffscreenBuffer.width,
                    pitch  = OffscreenBuffer.pitch,
                },
                NewInput,
            )
            Win32_UpdateWindow(&OffscreenBuffer, deviceContext, Win32_GetClientRect(window))

            offset += {1, 1}

            endCounter: win.LARGE_INTEGER
            win.QueryPerformanceCounter(&endCounter)
            elapsedCounter := endCounter - latestCounter

            millisecondsPerFrame := (1000*elapsedCounter) / performanceCountPerSecond
            framesPerSecond := performanceCountPerSecond / elapsedCounter
            fmt.println(millisecondsPerFrame, "ms/Frame\t|\t", framesPerSecond, "FPS")

            latestCounter = endCounter
        }
    } else do panic("[!] Failed to register window")
}
