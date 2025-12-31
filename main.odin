package main;
import "core:fmt"
import "core:math"
import "vendor:raylib"

print :: fmt.print;
cos   :: math.cos;

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

Color :: raylib.Color;
Vector2 :: raylib.Vector2;
Rectangle :: raylib.Rectangle;
SNOWFLAKE_MAX_COUNT :: 256;

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
    winds:      [WIND_COUNT]Vector2,
    bounds:     Rectangle
}

DrawLineEx :: raylib.DrawLineEx;
SetTargetFPS :: raylib.SetTargetFPS;
Vector2Add :: raylib.Vector2Add;
Vector2Rotate :: raylib.Vector2Rotate;
WHITE :: Color {255,255,255,255};
DEG2RAD :: raylib.DEG2RAD;

SNOWFLAKE_THICKNESS_DECAY :: 1.5
SNOWFLAKE_SIZE_DECAY      :: 2

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

SNOWFLAKE_MAX_ALIVE_COUNT :: SNOWFLAKE_MAX_COUNT / 2

SNOWFLAKE_SPAWN_CHANCE :: 10
GetRandomValue :: raylib.GetRandomValue

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

    if  0.5 > abs(snowflake.angular_velocity) {
        snowflake.angular_velocity = 1
    }

    for &ent in ctx.ents {
        if !ent.used {
            ent = snowflake
            break
        }
    }
}

SNOWFLAKE_GRAVITY_VELOCITY :: 4

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

update :: proc(ctx: ^Context) {
    ctx.ents_count = 0;
    ctx.bounds = get_bounds()

    spawn_random_snowflake(ctx)

    for &ent in ctx.ents {
        if !ent.used { continue }
        if !CheckCollisionPointRec(ent.pos, ctx.bounds) {
            snowflake_despawn(&ent)
        }

        ent.time_alive += GetFrameTime()
        ent.rotation   += ent.angular_velocity
        ctx.ents_count += 1
        ent.pos = Vector2Add(ent.pos, Vector2 { cos(ent.time_alive), SNOWFLAKE_GRAVITY_VELOCITY})
    }
}

draw :: proc(ctx: Context) {
    for ent in ctx.ents {
        if !ent.used { continue }
        draw_snowflake(ent);
    }
}

main :: proc() {

    SetTargetFPS(60);
    InitWindow(800,600, "Snowflakes");

    ctx := Context {
        bounds = get_bounds()
    };

    for !WindowShouldClose() {
        BeginDrawing();
        ClearBackground(Color { 20,20,20,255 });
        DrawText(TextFormat("%i", ctx.ents_count), 10, 10, 14, WHITE )
        update(&ctx);
        draw(ctx);
        EndDrawing();
    }
    CloseWindow();
}
