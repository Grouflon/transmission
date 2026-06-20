resources : struct
{
    settings: GameSettings = .{ path = "data://settings.res" };
};

GameSettings :: struct
{
    #as using _resource: Resource;
    type = type_info(GameSettings);

    background_color: Color; @serialize
    segment_count: int = 1; @serialize @min(1) @max(64)
    segment_length: float = 5.0; @serialize @step(1)
    iterations: int = 1; @serialize
    constraint_angle: float = 180; @serialize @drag @min(0) @max(180) @step(1)

    max_velocity: float = 1.0; @serialize @drag
    agent_velocity_time_to_90: float = 1.0; @serialize @drag
    velocity_decay_distance: float = 10.0; @serialize @drag

    arm_segments: int = 6; @serialize
    arm_length: float = 6.0; @serialize @drag
    arm_target_time_to_90: float = 1.0; @serialize @drag
    arm_target_max_velocity: float = 1.0; @serialize @drag

    skin_tones: [..]Color; @serialize
    hair_tones: [..]Color; @serialize
    clothes_tones: [..]Color; @serialize

    debug_left_arm: bool; @serialize
    debug_right_arm: bool; @serialize
}

// Rendering
GAME_WIDTH :: 320;
GAME_HEIGHT :: 200;
game_render_texture: RenderTexture;

segments_root: Vector2;
segments: [64]Vector2;

agent: *Agent;

// agent_target: Vector2;
// is_agent_moving: bool;
// pid: PIDController(Vector2);

game_init :: ()
{
    t: = get_current_appolo_time();
    random_seed(Some_Big_Time_Value.{t.low, t.high});

    load_all_resources();

    game_render_texture = load_render_texture(GAME_WIDTH, GAME_HEIGHT);
    set_texture_parameters(game_render_texture.texture, TextureParameters.{
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
    });

    game_start();
}

game_shutdown :: ()
{
    game_stop();

    unload_render_texture(game_render_texture);
    unload_all_resources();
}

game_start :: ()
{
    segments_root = .{GAME_WIDTH/2, GAME_HEIGHT/2};
    for i: 0..resources.settings.segment_count-1
    {
        segments[i] = segments_root + .{resources.settings.segment_length, 0.0} * i.(float);
    }

    agent = pool_add(Agent);
    agent_init(agent, .{30, 30});
}

game_stop :: ()
{
    pool_remove(agent);
    agent = null;
}

game_restart :: ()
{
    game_stop();
    game_start();
}

game_update :: (dt: float)
{
    settings: = resources.settings;

    update_group(dt);

    normalized_mouse_position: = get_mouse_position() / get_viewport_size();
    game_mouse_position : = .{normalized_mouse_position.x, 1.0 - normalized_mouse_position.y} * Vector2.{GAME_WIDTH, GAME_HEIGHT};

    fabr_ik(segments.data, settings.segment_count, game_mouse_position, settings.segment_length, settings.iterations, settings.constraint_angle);

    // if is_agent_moving
    // {
    //     pid.p = settings.p;
    //     pid.i = settings.i;
    //     pid.d = settings.d;

    //     agent_position: Vector2 = agent.position.xy;
    //     result: = process_pid_controller(*pid, agent_position, agent_target, dt);
    //     acc: = max_length(result, settings.max_acceleration);
    //     agent.velocity += acc * dt;
    //     agent.velocity = max_length(agent.velocity, settings.max_velocity);
    //     agent.position += xyz(agent.velocity * dt, 0);
    // }

    if is_pressed(.MOUSE_BUTTON_LEFT)
    {
        agent_go_to_target(agent, game_mouse_position);
    }

    if is_pressed(#char "r") && is_down(.CTRL)
    {
        game_restart();
    }

    if is_pressed(.ESCAPE)
    {
        yae_request_close();
    }
}

game_draw :: ()
{
    // GAME
    {
        begin_render_texture(game_render_texture);
        defer end_render_texture();

        begin_camera(.{
            type=.ORTHOGRAPHIC,
            orthographic = .{
                top = GAME_HEIGHT,
                left = 0.0,
                right = GAME_WIDTH,
                bottom = 0.0,
                near = -1.0,
                far = 1.0
            }
        });
        defer end_camera();

        clear_background(resources.settings.background_color);
        draw_circle_outline(.{160,100, -0.1}, 50.0, 1.0);

        draw_group("shadow");
        clear_depth_buffer();


        // for i: 0..resources.settings.segment_count-2
        // {
        //     draw_line(xyz(segments[i], 0.0), xyz(segments[i+1], 0.0), 2.0, RED);
        // }
        // for i: 0..resources.settings.segment_count-1
        // {
        //     draw_circle(xyz(segments[i], 0.1), 3.0, BLACK);
        // }

        draw_group();
        clear_depth_buffer();

        draw_group("debug");
    }

    // COMPOSITING
    {
        clear_background(.{0,0,0,255});

        draw_sprite(.{}, game_render_texture.texture, draw_rect = .{.{0,0}, .{1,1}}, flip_y = true); // we flip y cause opengl naturally draws textures upside down
    }
}

fabr_ik :: (segments: *Vector2, segment_count: int, target: Vector2, segment_length: float, iterations: int = 1, constraint_angle: float = 180.0)
{
    if segments == null || segment_count == 0 return;

    // Set the tip to the target
    root: = segments[0];
    segments[segment_count-1] = target;

    for iteration: 0..iterations-1
    {
        // Backwards tension
        previous_direction: Vector2 = .{};
        for < i: 0..segment_count-2
        {
            direction: = normalize(segments[i] - segments[i+1]);
            if previous_direction != .{}
            {
                a: = signed_angle_between(direction, previous_direction);
                if abs(a) * R2D > constraint_angle
                {
                    direction = rotate(previous_direction, sign(a) * constraint_angle * D2R);
                }
            }

            segments[i] = segments[i+1] + direction * segment_length;
            previous_direction = direction;
        }

        segments[0] = root;
        // Forward tension
        previous_direction = .{};
        for i: 1..segment_count-1
        {
            direction: = normalize(segments[i] - segments[i-1]);
            if previous_direction != .{}
            {
                a: = signed_angle_between(direction, previous_direction);
                if abs(a) * R2D > constraint_angle
                {
                    direction = rotate(previous_direction, sign(a) * constraint_angle * D2R);
                }
            }

            segments[i] = segments[i-1] + direction * segment_length;
            previous_direction = direction;
        }
    }
}

#import "Random";