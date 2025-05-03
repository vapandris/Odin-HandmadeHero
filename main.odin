package hmh

import win "core:sys/windows"

main :: proc() {
    win.MessageBoxW(
        nil,
        win.utf8_to_wstring("Some msg"),
        win.utf8_to_wstring("Boxxxx"),
        win.MB_OK | win.MB_ICONINFORMATION
    )
}
