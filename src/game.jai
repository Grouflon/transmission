resources : struct
{
    settings: GameSettings = .{ path = "data://settings.res" };
};

s : *GameSettings = #run *resources.settings;

// Rendering
GAME_WIDTH :: 320;
GAME_HEIGHT :: 200;
game_render_texture: RenderTexture;

agents: [..]*AgentComponent;
is_following: bool;

emitter: ParticleEmitter;

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

pick_random_position :: () -> Vector2
{
    MARGIN : float : 20.0;
    return .{
        random_range(MARGIN, GAME_WIDTH - MARGIN),
        random_range(MARGIN, GAME_HEIGHT - MARGIN)
    };
}

game_start :: ()
{
    for i: 0..s.agent_count-1
    {
        array_add(*agents, make_agent(pick_random_position()));
    }
}

game_stop :: ()
{
    for agent: agents
    {
        remove_entity(agent.entity);
    }
    array_clear(*agents);
}

game_restart :: ()
{
    game_stop();
    game_start();
}

game_update :: (dt: float)
{
    settings: = resources.settings;

    normalized_mouse_position: = get_mouse_position() / get_viewport_size();
    game_mouse_position : = .{normalized_mouse_position.x, 1.0 - normalized_mouse_position.y} * Vector2.{GAME_WIDTH, GAME_HEIGHT};

    if is_pressed(#char "r")
    {
        game_restart();
    }

    update_group(dt);

    emitter.settings = s.emitter_settings;
    particle_emitter_update(*emitter, xyz(game_mouse_position, 0), dt);

    make_everyone_follow :: (force: bool)
    {
        for i: 1..agents.count-1
        {
            if !force && !agents[i].is_following_target continue;

            to_next_agent: = agents[i-1].transform.position.xy - agents[i].transform.position.xy;
            target: = agents[i-1].transform.position.xy - normalize(to_next_agent) * s.agent_interval;
            agent_go_to_target(agents[i], target);
        }
    }

    if is_down(.MOUSE_BUTTON_LEFT)
    {
        is_following = true;
        agent_go_to_target(agents[0], game_mouse_position);

        make_everyone_follow(true);
    }

    if is_pressed(.MOUSE_BUTTON_MIDDLE)
    {
        is_following = false;
        for agent: agents
        {
            agent_go_to_target(agent, pick_random_position());
        }
    }

    if is_following
    {
        make_everyone_follow(false);
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
                near = -10000.0,
                far = 10000.0
            }
        });
        defer end_camera();

        clear_background(resources.settings.background_color);
        draw_circle_outline(.{160,100, -0.1}, 50.0, 1.0);
        
        draw_all_commands();
        clear_depth_buffer();

        draw_group("shadow");
        clear_depth_buffer();

        draw_group();

        clear_depth_buffer();

        particle_emitter_draw(*emitter);

        draw_group("debug");
    }

    // COMPOSITING
    {
        clear_background(.{0,0,0,255});

        draw_sprite(.{}, game_render_texture.texture, draw_rect = .{.{0,0}, .{1,1}}, flip_y = true); // we flip y cause opengl naturally draws textures upside down
    }
}

#import "Random";