HIPS_HEIGHT :: 8;
SHOULDER_HEIGHT :: 10;
SHOULDERS :: Vector2.{0, HIPS_HEIGHT + SHOULDER_HEIGHT/2};

Agent :: struct
{
    position: Vector3;
    velocity: Smoother(Vector2);
    is_facing_left: bool;

    follow_target: bool;
    has_aligned_once: bool;
    target: Vector2;

    hair_color: Color;
    skin_color: Color;
    top_color: Color;
    bottom_color: Color;

    left_arm: AgentArm;
    right_arm: AgentArm;
}

agent_go_to_target :: (agent: *Agent, target: Vector2)
{
    agent.follow_target = true;
    agent.has_aligned_once = false;
    agent.target = target;
}

agent_init :: (agent: *Agent, position: Vector2)
{
    agent.position = xyz(position, 0);
    agent.hair_color = random_get_array_item(resources.settings.hair_tones, BLACK);
    agent.skin_color = random_get_array_item(resources.settings.skin_tones, BLACK);
    agent.top_color = random_get_array_item(resources.settings.clothes_tones, BLACK);
    agent.bottom_color = random_get_array_item(resources.settings.clothes_tones, BLACK);

    arm_init(*agent.left_arm, agent, SHOULDERS + .{-3,-1});
    arm_init(*agent.right_arm, agent, SHOULDERS + .{3,-1});
}

agent_update :: (using agent: *Agent, dt: float)
{
    velocity.time_to_90 = resources.settings.agent_velocity_time_to_90;

    if follow_target
    {
        agent_to_target: = (target - position.xy);
        d: = dot_product(agent_to_target, velocity.value);
        if !has_aligned_once && d >= 0
        {
            has_aligned_once = true;
        }

        if has_aligned_once && dot_product(agent_to_target, velocity.value) < 0
        {
            follow_target = false;
            smoother_reset(*velocity, .{});
        }
        else
        {
            distance_to_target: = length(agent_to_target);
            t: = clamp01(distance_to_target / resources.settings.velocity_decay_distance);

            ideal_velocity: = agent_to_target / dt;
            target_velocity: = max_length(ideal_velocity, resources.settings.max_velocity * 1.2 * t);

            smoother_update(*velocity, target_velocity, dt);

            movement: = xyz(velocity.value, 0) * dt;
            position += movement;
            // left_arm_target.value -= movement;
            // right_arm_target.value -= movement;
        }
    }

    if length(agent.velocity.value) > 0.1
    {
        agent.is_facing_left = velocity.value.x < 0;
    }

    arm_update(*left_arm, agent, dt);
    arm_update(*right_arm, agent, dt);

} @update_group()

agent_draw :: (agent: *Agent)
{
    W :: 6;

    sign: float = ifx agent.is_facing_left then -1.0 else 1.0;

    // bottom
    hips: = agent.position + .{0,HIPS_HEIGHT,0};
    draw_ellipse(hips, .{W/2, 2.0}, agent.bottom_color);
    // legs
    draw_line(hips + .{-(W/2 - 1),0,0}, agent.position + .{-(W/2 - 1),0,0}, 2, agent.bottom_color);
    draw_line(hips + .{(W/2 - 1),0,0}, agent.position + .{(W/2 - 1),0,0}, 2, agent.bottom_color);

    // top
    shoulders: = hips + .{0, SHOULDER_HEIGHT/2,0};
    draw_ellipse(hips + .{0,1,0.1}, .{W/2+1, 2.0}, agent.top_color);
    draw_ellipse(shoulders + .{0,0,0.1}, .{W/2, SHOULDER_HEIGHT/2-1}, agent.top_color);

    // arms
    arm_draw(*agent.left_arm, sign*0.2, agent.top_color, agent.skin_color);
    arm_draw(*agent.right_arm, sign*-0.2, agent.top_color, agent.skin_color);

    // head
    draw_ellipse(shoulders + .{0,1,0.3}, .{3,2.5}, agent.skin_color);
    draw_ellipse(shoulders + .{sign * 1,3,0.4}, .{3,2}, agent.hair_color);

} @draw_group()

agent_draw_shadow :: (agent: *Agent)
{
    draw_ellipse(agent.position + .{-2, 0,0}, .{6.0, 2.0}, .{0,0,0,70});
} @draw_group("shadow")

agent_draw_debug :: (using agent: *Agent)
{
    if resources.settings.debug_left_arm { arm_debug(*agent.left_arm, agent); }
    if resources.settings.debug_right_arm { arm_debug(*agent.right_arm, agent); }
    
    // draw_line(position, position + xyz(velocity.value, 0), 1.0, RED);
} @draw_group("debug")


// Arm
MAX_ARM_SEGMENTS :: 32;
AgentArm :: struct
{
    local_anchor: Vector2;
    segments: [MAX_ARM_SEGMENTS] Vector2;
    target: Vector2;
    target_velocity: Smoother(Vector2);
}

arm_init :: (arm: *AgentArm, agent: *Agent, local_anchor: Vector2)
{
    arm.local_anchor = local_anchor;

    smoother_reset(*arm.target_velocity, .{});

    segment_count: = get_arm_segment_count();
    segment_length: = get_arm_segment_length();
    for i: 0..segment_count-1
    {
        arm.segments[i] = agent.position.xy + local_anchor + .{0, -segment_length} * i.(float);
    }
    arm.target = get_arm_ideal_target(arm, agent);
}

arm_update :: (arm: *AgentArm, agent: *Agent, dt: float)
{
    arm.target_velocity.time_to_90 = resources.settings.arm_target_time_to_90;

    arm.segments[0] = agent.position.xy + arm.local_anchor;

    ideal_target: = get_arm_ideal_target(arm, agent);
    target_to_ideal_target: = ideal_target - arm.target;
    t: = clamp01(length(target_to_ideal_target) / resources.settings.velocity_decay_distance);
    ideal_velocity: = max_length(target_to_ideal_target / dt, resources.settings.arm_target_max_velocity * t);
    smoother_update(*arm.target_velocity, ideal_velocity, dt);
    // arm.target_velocity.value = time_independent_lerp_2(arm.target_velocity.value, .{}, resources.settings.arm_velocity_decay_time, dt);

    arm.target += arm.target_velocity.value * dt;

    segment_count: = get_arm_segment_count();
    segment_length: = get_arm_segment_length();
    fabr_ik(arm.segments.data, segment_count, arm.target, segment_length);
}

arm_draw :: (arm: *AgentArm, z: float, sleeve_color: Color, hand_color: Color)
{
    segment_count: = get_arm_segment_count();
    for i: 0..segment_count-2
    {
        draw_line(xyz(arm.segments[i], z), xyz(arm.segments[i+1], z), 1.0, sleeve_color);
    }
    draw_circle(xyz(arm.segments[segment_count-1], z + 0.01), 1.5, hand_color);
}

arm_debug :: (arm: *AgentArm, agent: *Agent)
{
    draw_circle(arm.target, 2.0, BLACK);
    draw_circle(get_arm_ideal_target(arm, agent), 2.0, YELLOW);
    draw_line(arm.target, arm.target + arm.target_velocity.value, 1.0, GREEN);
}

#scope_file
get_arm_ideal_target :: (arm: *AgentArm, agent: *Agent) -> Vector2
{
    agent_velocity_ratio: = length(agent.velocity.value) / resources.settings.max_velocity;
    return agent.position.xy + arm.local_anchor + .{0, -resources.settings.arm_length + agent_velocity_ratio * 12.0};
}

get_arm_segment_count :: () -> int
{
    return min(MAX_ARM_SEGMENTS, resources.settings.arm_segments);
}

get_arm_segment_length :: () -> float
{
    return resources.settings.arm_length / resources.settings.arm_segments.(float);
}