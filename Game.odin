package hmh

import "core:mem"


Game_OffscreenBuffer :: struct {
    memory: rawptr,
    height: i32,
    width:  i32,
    pitch:  i32,
}

Game_Key :: enum {
    UP,
    DOWN,
    LEFT,
    RIGHT,
}

Game_ButtonState :: struct {
    halfTransitionTime: u8,
    endedDown: bool,
}

Game_KeyInput :: struct {
    keys: [Game_Key]Game_ButtonState,
}

Game_UpdateAndRender :: proc(buffer: Game_OffscreenBuffer, input: Game_KeyInput) {
    @static offset: [2]u8

    keys := input.keys
    if keys[.UP].endedDown          do offset.y -= 1
    else if keys[.DOWN].endedDown   do offset.y += 1
    if keys[.RIGHT].endedDown       do offset.x -= 1
    else if keys[.LEFT].endedDown   do offset.x += 1

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
