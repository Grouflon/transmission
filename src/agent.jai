HIPS_HEIGHT :: 8;
SHOULDER_HEIGHT :: 10;
SHOULDERS :: Vector2.{0, HIPS_HEIGHT + SHOULDER_HEIGHT/2};
ARM_ANCHOR :: Vector2.{3,-1};

Agent :: struct
{
    position: Vector3;
    velocity: Smoother(Vector2);
    velocity_record: [10]Vector2;
    velocity_record_index: int;
    is_facing_left: bool;

    is_following_target: bool;
    has_faced_following_target: bool;
    following_target: Vector2;

    hair_color: Color;
    skin_color: Color;
    top_color: Color;
    bottom_color: Color;

    left_arm: Rope;
    right_arm: Rope;

    time: float;
}

agent_go_to_target :: (agent: *Agent, target: Vector2)
{
    agent.is_following_target = true;
    agent.has_faced_following_target = false;
    agent.following_target = target;
}

agent_init :: (agent: *Agent, position: Vector2)
{
    agent.position = xyz(position, 0);
    agent.hair_color = random_get_array_item(s.hair_tones, BLACK);
    agent.skin_color = random_get_array_item(s.skin_tones, BLACK);
    agent.top_color = random_get_array_item(s.clothes_tones, BLACK);
    agent.bottom_color = random_get_array_item(s.clothes_tones, BLACK);


    agent.left_arm.segment_count = s.arm_segments;
    agent.left_arm.segment_length = s.arm_length / s.arm_segments.(float);
    agent.left_arm.mode = .PHYSICS;
    rope_init(*agent.left_arm, agent.position.xy + SHOULDERS + ARM_ANCHOR);

    agent.right_arm.segment_count = s.arm_segments;
    agent.right_arm.segment_length = s.arm_length / s.arm_segments.(float);
    agent.right_arm.mode = .PHYSICS;
    rope_init(*agent.right_arm, agent.position.xy + SHOULDERS + ARM_ANCHOR * Vector2.{-1,1});
}

agent_update :: (using agent: *Agent, dt: float)
{
    time += dt;

    // sync settings
    velocity.time_to_90 = s.agent_velocity_time_to_90;

    agent.left_arm.gravity = .{0, s.gravity};
    agent.left_arm.drag = s.drag;
    agent.left_arm.smoothed_target.time_to_90 = s.arm_target_time_to_90;

    agent.right_arm.gravity = .{0, s.gravity};
    agent.right_arm.drag = s.drag;
    agent.right_arm.smoothed_target.time_to_90 = s.arm_target_time_to_90;

    // move
    if is_following_target
    {
        agent_to_target: = (following_target - position.xy);
        d: = dot_product(agent_to_target, velocity.value);
        if !has_faced_following_target && d >= 0
        {
            has_faced_following_target = true;
        }

        if has_faced_following_target && dot_product(agent_to_target, velocity.value) < 0
        {
            is_following_target = false;
            smoother_reset(*velocity, .{});
        }
        else
        {
            distance_to_target: = length(agent_to_target);
            t: = clamp01(distance_to_target / s.velocity_decay_distance);

            ideal_velocity: = agent_to_target / dt;
            target_velocity: = max_length(ideal_velocity, s.max_velocity * 1.2 * t);

            smoother_update(*velocity, target_velocity, dt);

            movement: = xyz(velocity.value, 0) * dt;
            position += movement;
        }
    }

    if length(agent.velocity.value) > 0.1
    {
        agent.is_facing_left = velocity.value.x < 0;
    }

    // left arm
    left_arm.segment_positions[0] = agent.position.xy + SHOULDERS + ARM_ANCHOR;
    for i: 0..left_arm.segment_count-1
    {
        v: = ifx is_facing_left then velocity.value else velocity_record[positive_mod(velocity_record_index-1, velocity_record.count)];
        left_arm.segment_velocities[i] -= v * 0.5;
    }
    rope_update(*left_arm, dt);

    // right arm
    right_arm.segment_positions[0] = agent.position.xy + SHOULDERS + ARM_ANCHOR * Vector2.{-1,1};
    for i: 0..right_arm.segment_count-1
    {
        v: = ifx !is_facing_left then velocity.value else velocity_record[positive_mod(velocity_record_index-1, velocity_record.count)];
        right_arm.segment_velocities[i] -= v * 0.5;
    }
    rope_update(*right_arm, dt);

    velocity_record_index = (velocity_record_index + 1) % agent.velocity_record.count;
    agent.velocity_record[velocity_record_index] = velocity.value;

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
    rope_draw(*agent.left_arm, sign*-0.2, 1.0, agent.top_color);
    draw_circle(xyz(agent.left_arm.segment_positions[agent.left_arm.segment_count-1], sign*-0.2 + 0.01), 1.5, agent.skin_color);

    rope_draw(*agent.right_arm, sign*0.2, 1.0, agent.top_color);
    draw_circle(xyz(agent.right_arm.segment_positions[agent.right_arm.segment_count-1], sign*0.2 + 0.01), 1.5, agent.skin_color);

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
    if s.debug_left_arm { rope_draw_debug(*agent.left_arm); }
    if s.debug_right_arm { rope_draw_debug(*agent.right_arm); }
    
    // draw_line(position, position + xyz(velocity.value, 0), 1.0, RED);
} @draw_group("debug")
