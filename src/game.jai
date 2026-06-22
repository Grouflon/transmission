resources : struct
{
    settings: GameSettings = .{ path = "data://settings.res" };
};

s : *GameSettings = #run *resources.settings;

// Rendering
GAME_WIDTH :: 320;
GAME_HEIGHT :: 200;
game_render_texture: RenderTexture;

agent: *Agent;

rope: Rope;

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
    settings: = resources.settings;

    agent = pool_add(Agent);
    agent_init(agent, .{30, 30});

    rope.segment_count = settings.segment_count;
    rope.segment_length = settings.segment_length;
    rope.smoothed_target.time_to_90 = settings.smooth_time;
    rope.gravity = .{0, settings.gravity};
    rope.drag = settings.drag;

    rope_init(*rope, .{GAME_WIDTH/2, GAME_HEIGHT/2});
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

    if is_pressed(#char "r") && is_down(.CTRL)
    {
        game_restart();
    }


    update_group(dt);

    normalized_mouse_position: = get_mouse_position() / get_viewport_size();
    game_mouse_position : = .{normalized_mouse_position.x, 1.0 - normalized_mouse_position.y} * Vector2.{GAME_WIDTH, GAME_HEIGHT};

    rope.segment_count = settings.segment_count;
    rope.segment_length = settings.segment_length;
    rope.smoothed_target.time_to_90 = settings.smooth_time;
    rope.gravity = .{0, settings.gravity};
    rope.drag = settings.drag;
    if is_pressed(.MOUSE_BUTTON_MIDDLE)
    {
        rope.mode = ifx rope.mode == .PHYSICS then .FOLLOW_TARGET else .PHYSICS;
    }
    rope.target = game_mouse_position;
    rope_update(*rope, dt);

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
        // rope_draw(*rope, 0.0, 5.0);

        clear_depth_buffer();

        draw_group("debug");
        // rope_draw_debug(*rope);
    }

    // COMPOSITING
    {
        clear_background(.{0,0,0,255});

        draw_sprite(.{}, game_render_texture.texture, draw_rect = .{.{0,0}, .{1,1}}, flip_y = true); // we flip y cause opengl naturally draws textures upside down
    }
}

#import "Random";