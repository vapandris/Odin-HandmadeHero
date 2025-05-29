#+build windows
package hmh

import win "core:sys/windows"

DirectSoundCreate :: #type proc "system" (win.LPCGUID, rawptr, win.LPUNKNOWN) -> win.HRESULT
Win32_InitDSound :: proc () {
    directSoundLib := win.LoadLibraryW(win.L("dsound.dll"))
    if directSoundLib == nil do return

    directSoundCreate := cast(DirectSoundCreate)win.GetProcAddress(directSoundLib, "DirectSoundCreate")
    if directSoundCreate == nil do return
}
