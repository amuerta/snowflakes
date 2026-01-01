package main;
import "core:fmt"
import "core:math"
import "vendor:raylib"

print :: fmt.print;
cos   :: math.cos;
abs   :: math.abs;

InitWindow :: raylib.InitWindow;
CloseWindow :: raylib.CloseWindow;
WindowShouldClose :: raylib.WindowShouldClose;
BeginDrawing :: raylib.BeginDrawing;
EndDrawing :: raylib.EndDrawing;
ClearBackground :: raylib.ClearBackground;
GetScreenWidth :: raylib.GetScreenWidth;
GetScreenHeight :: raylib.GetScreenHeight;
GetFrameTime :: raylib.GetFrameTime;
DrawText :: raylib.DrawText;
TextFormat :: raylib.TextFormat;
CheckCollisionPointRec :: raylib.CheckCollisionPointRec
DrawLineEx :: raylib.DrawLineEx;
SetTargetFPS :: raylib.SetTargetFPS;
Vector2Add :: raylib.Vector2Add;
Vector2Rotate :: raylib.Vector2Rotate;
GetRandomValue :: raylib.GetRandomValue;
IsKeyPressed :: raylib.IsKeyPressed;
SetWindowSize :: raylib.SetWindowSize;
SetWindowPosition :: raylib.SetWindowPosition
GetCurrentMonitor :: raylib.GetCurrentMonitor
GetMonitorHeight :: raylib.GetMonitorHeight
GetMonitorWidth :: raylib.GetMonitorWidth

KEY_D :: raylib.KeyboardKey.D;
KEY_F :: raylib.KeyboardKey.F;
KEY_EQUAL :: raylib.KeyboardKey.EQUAL;
KEY_MINUS :: raylib.KeyboardKey.MINUS;

Color :: raylib.Color;
Vector2 :: raylib.Vector2;
Rectangle :: raylib.Rectangle;

WHITE :: Color {255,255,255,255};
GRAY :: Color {100,100,100,255};
DEG2RAD :: raylib.DEG2RAD;

SNOWFLAKE_MAX_COUNT :: 256;
SNOWFLAKE_THICKNESS_DECAY :: 1.5
SNOWFLAKE_SIZE_DECAY      :: 2
SNOWFLAKE_MAX_ALIVE_COUNT :: SNOWFLAKE_MAX_COUNT / 2
SNOWFLAKE_SPAWN_CHANCE :: 10
SNOWFLAKE_GRAVITY_VELOCITY :: 4
SNOWFLAKE_WIND_LEFT_LIMIT :: -8
SNOWFLAKE_WIND_RIGHT_LIMIT :: 8

Entites :: [SNOWFLAKE_MAX_COUNT]Entity;
Entity  :: struct {
    used: bool,
    pos: Vector2,
    rotation: f32,
    angular_velocity: f32,
    time_alive: f32,
    data: struct {
        branches: i32,
        branch_length: i32,
        branch_thickness: i32,
        splits: i32,
    }
}

WIND_COUNT :: 10;
Context :: struct {
    ents_count: u32,
    ents:       Entites,
    wind:       f32,
    bounds:     Rectangle

}


draw_flake :: proc(anchor: Vector2, 
    count: i32, 
    depth: i32, 
    size: i32, 
    thick: i32,
    default_rotation: f32,
    ) 
{
    if depth <= 0 { return }
    angle       := cast(f32) 0.0
    rotation    := cast(f32) (360/count)
    for b in 0..=count {
        branch := Vector2 {0, auto_cast (-1 * size)}
        branch = Vector2Rotate(branch, (angle + default_rotation) * DEG2RAD)
        tip := Vector2Add(anchor, branch)
        DrawLineEx(anchor, tip, cast(f32)thick, WHITE)
        draw_flake(tip, count, depth-1, 
             auto_cast ( cast(f32) size  / SNOWFLAKE_SIZE_DECAY),
             auto_cast ( cast(f32) thick / SNOWFLAKE_THICKNESS_DECAY),
             default_rotation // no rotation for every other one
        )
        angle += rotation
    }
}

draw_snowflake :: proc (e: Entity) {
    size        := e.data.branch_length
    branches    := e.data.branches
    assert(branches > 0)
    angle       := cast(f32) 0.0
    rotation    := cast(f32) (360/branches)
    thick       := cast(f32) e.data.branch_thickness
    splits      := e.data.splits
    draw_flake(e.pos, branches, splits, size, cast(i32) thick, e.rotation)
}

spawn_random_snowflake :: proc(ctx: ^Context) {
    
    // break early if cannot spawn
    if ctx.ents_count > SNOWFLAKE_MAX_ALIVE_COUNT { return }

    // roll for a chance, if rolled succesfully spawn it
    if GetRandomValue(0, 100) > SNOWFLAKE_SPAWN_CHANCE { return }

    snowflake := Entity {
        used = true,
        pos = {
            ctx.bounds.x + auto_cast GetRandomValue(0, cast(i32)ctx.bounds.width),
            ctx.bounds.y
        },
        rotation = cast(f32) GetRandomValue(-180, 180),
        angular_velocity = cast(f32) GetRandomValue(-1, 1),
        data = {
            branches = GetRandomValue(6, 8),
            branch_length = GetRandomValue(10, 25),
            branch_thickness = GetRandomValue(3,4),
            splits = GetRandomValue(1,2),
        }
    }

    if (snowflake.data.splits == 1) {
        length := cast(f32) snowflake.data.branch_length
        length *= 0.75
        snowflake.data.branch_length = cast(i32) length
    } 

    // make sure it rotates
    if  0.5 > abs(snowflake.angular_velocity) {
        snowflake.angular_velocity = 1
    }

    // put it somewhere in empty slot
    for &ent in ctx.ents {
        if !ent.used {
            ent = snowflake
            break
        }
    }
}


get_bounds :: proc() -> Rectangle {
    r := Rectangle {
        -100, -200,  
        cast(f32) GetScreenWidth() + 200,  
        cast(f32) GetScreenHeight() + 400 
    }; return r
}

snowflake_despawn :: proc(e: ^Entity) {
    e^ = Entity {}
}

random_float :: proc () -> f32 {
    di := cast(f32) GetRandomValue(-(1<<30), 1<<30)
    de := cast(f32)(1 << 30)
    if di == 0 { di = 1 }
    if de == 0 { de = 1 }
    return  di / de;
}

SNOWFLAKE_WIND_STRENGTH :: 1.0/20.0

update :: proc(ctx: ^Context) {
    ctx.ents_count = 0;
    ctx.bounds = get_bounds()

    spawn_random_snowflake(ctx)

    // change base velocity to simulate "wind"
    // keep in LEFT to RIGHT limit range
    wind := random_float() * SNOWFLAKE_WIND_STRENGTH
    if wind < SNOWFLAKE_WIND_LEFT_LIMIT {
        wind = abs(wind)
    } else if wind > SNOWFLAKE_WIND_RIGHT_LIMIT  {
        wind = -abs(wind) 
    }
    ctx.wind += wind

    for &ent in ctx.ents {
        if !ent.used { continue }
        if !CheckCollisionPointRec(ent.pos, ctx.bounds) {
            snowflake_despawn(&ent)
        }

        ent.time_alive += GetFrameTime()
        ent.rotation   += ent.angular_velocity
        ctx.ents_count += 1
        ent.pos = Vector2Add(ent.pos, 
            Vector2 { 
                ctx.wind + cos(ent.time_alive), // x
                SNOWFLAKE_GRAVITY_VELOCITY
            }
        )
    }
}

draw :: proc(ctx: Context) {
    for ent in ctx.ents {
        if !ent.used { continue }
        draw_snowflake(ent);
    }
}

main :: proc() {

    debug := false
    borderless_fullscreen := false
    font_size := cast(i32) 9
    resolutions := []Vector2 { 
        // x, y
        {400, 300},
        {500, 400},
        {600, 360},
        {800, 600},
        {900, 450},
        {1280,720},
        {1440,900},
        {1680,1050},
        {1920,1080},
        {2560,1440}
    }
    current_resolution := len(resolutions)/2
    resolution := resolutions[current_resolution]

    // window init
    SetTargetFPS(60);
    InitWindow(auto_cast resolution.x,auto_cast resolution.y, "Snowflakes");

    // ctx needs to created after the window
    // since get_bounds needs window context to get resolution
    ctx := Context {
        bounds = get_bounds()
    }

    for !WindowShouldClose() {
        resize := false
        BeginDrawing()
        ClearBackground(Color { 20,20,20,255 })


        if IsKeyPressed(KEY_D) { debug = !debug }
        if IsKeyPressed(KEY_EQUAL) { 
            if current_resolution < len(resolutions)-1 { 
                current_resolution += 1
            }
            resize = true
        }
        if IsKeyPressed(KEY_F) {
            resize = true
            borderless_fullscreen = !borderless_fullscreen
        }
        if IsKeyPressed(KEY_MINUS) { 
            if current_resolution > 0 {
                current_resolution -= 1
            }
            resize = true
        }

        if debug {
            DrawText(TextFormat("%i, %.2f", ctx.ents_count, ctx.wind), 
                font_size, font_size, font_size, GRAY)
        }

        update(&ctx);
        draw(ctx);
        EndDrawing();

        if resize {
            mon := GetCurrentMonitor()
            screen := Vector2 {
                auto_cast GetMonitorWidth(mon),
                auto_cast GetMonitorHeight(mon)
            }
            if borderless_fullscreen {
                SetWindowSize(auto_cast screen.x, auto_cast screen.y)
                SetWindowPosition(0,0)
            } else {
                resolution = resolutions[current_resolution]
                SetWindowSize(auto_cast resolution.x, auto_cast resolution.y)
                
                SetWindowPosition(
                    auto_cast (screen.x - resolution.x)/2, 
                    auto_cast (screen.y - resolution.y)/2
                )
            }
        }     
    }
    CloseWindow();
}
