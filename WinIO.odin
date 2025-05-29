#+build windows
package hmh

import win "core:sys/windows"

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
