package hmh

import "core:mem"

RELEASE :: 0
DEBUG_SPEED :: 1
DEBUG_CHECKS :: 2

BUILD_MODE :: #config(BUILD_MODE, DEBUG_SPEED)

Game_Memory :: struct {
    isInitialized: bool,
    permanentStorage: []byte, // REQUIRED to be cleared to 0 by platform
    temporaryStorage: []byte, // REQUIRED to be cleared to 0 by platform
}
Game_State :: struct {
    offset: [2]u8
}
GameState : ^Game_State

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

import "core:fmt"
Game_UpdateAndRender :: proc(memory: ^Game_Memory, buffer: Game_OffscreenBuffer, input: Game_KeyInput) {
    GameState = cast(^Game_State)(&(memory.permanentStorage[0]))

    if !memory.isInitialized {
        fmt.println(BUILD_MODE)
        when BUILD_MODE == DEBUG_CHECKS {
            // Atrocious startup time:
            for b in memory.permanentStorage do assert(b == 0)
            for b in memory.temporaryStorage do assert(b == 0)
        }
        memory.isInitialized = true
        GameState.offset = {}
    }

    keys := input.keys
    if keys[.UP].endedDown          do GameState.offset.y -= 1
    else if keys[.DOWN].endedDown   do GameState.offset.y += 1
    if keys[.RIGHT].endedDown       do GameState.offset.x -= 1
    else if keys[.LEFT].endedDown   do GameState.offset.x += 1

    Game_RenderTrippyShtuff(buffer, GameState.offset)

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
