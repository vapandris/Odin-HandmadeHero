package hmh

import "core:mem"


Game_OffscreenBuffer :: struct {
    memory: rawptr,
    height: i32,
    width:  i32,
    pitch:  i32,
}

Game_UpdateAndRender :: proc(buffer: Game_OffscreenBuffer) {
    offset: [2]u8 /* TODO: make it change over time mayhaps? */
    Game_RenderTrippyShtuff(buffer, offset)

}


@(private="file")
Game_RenderTrippyShtuff :: proc (buffer: Game_OffscreenBuffer, offset: [2]u8) {
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
