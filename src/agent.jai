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

    left_leg: Rope;
    right_leg: Rope;

    body: AgentBody;

    time: float;
}

AgentBody :: struct
{
    leg_length: float = 6.0; @serialize @drag @min(0)
    chest_height: float = 6.0; @serialize @drag @min(0)
    chest_lower_ratio: float = 0.5; @serialize @drag @range(0,1)
    chest_overlapping_ratio: float = 0.1; @serialize @drag @range(0,1)
    hips_width: float = 6.0; @serialize @drag @min(0)
    lower_body_width: float = 6.0; @serialize @drag @min(0)
    upper_body_width: float = 6.0; @serialize @drag @min(0)
    arm_length: float = 6.0; @serialize @drag @min(0)
}

agent_go_to_target :: (agent: *Agent, target: Vector2)
{
    agent.is_following_target = true;
    agent.has_faced_following_target = false;
    agent.following_target = target;
}

agent_init :: (agent: *Agent, position: Vector2)
{
    agent.body = s.agent_body;

    agent.position = xyz(position, 0);
    agent.hair_color = random_get_array_item(s.hair_tones, BLACK);
    agent.skin_color = random_get_array_item(s.skin_tones, BLACK);
    agent.top_color = random_get_array_item(s.clothes_tones, BLACK);
    agent.bottom_color = random_get_array_item(s.clothes_tones, BLACK);

    agent.left_arm.segment_count = s.arm_segments;
    agent.left_arm.segment_length = agent.body.arm_length / s.arm_segments.(float);
    agent.left_arm.mode = .PHYSICS;
    rope_init(*agent.left_arm, get_shoulders_position(agent, true).xy);

    agent.right_arm.segment_count = s.arm_segments;
    agent.right_arm.segment_length = agent.body.arm_length / s.arm_segments.(float);
    agent.right_arm.mode = .PHYSICS;
    rope_init(*agent.right_arm, get_shoulders_position(agent, false).xy);

    agent.left_leg.segment_count = 2;
    agent.left_leg.segment_length = agent.body.leg_length / agent.left_leg.segment_count;
    agent.left_leg.mode = .FOLLOW_TARGET;
    rope_init(*agent.left_leg, agent.position.xy + .{0, agent.body.leg_length} + .{-agent.body.hips_width/2,0});

    agent.right_leg.segment_count = 2;
    agent.right_leg.segment_length = agent.body.leg_length / agent.left_leg.segment_count;
    agent.right_leg.mode = .FOLLOW_TARGET;
    rope_init(*agent.right_leg, agent.position.xy + .{0, agent.body.leg_length} + .{agent.body.hips_width/2,0});
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

    agent.body = s.agent_body;

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
            target_velocity: = max_length(ideal_velocity, s.agent_max_velocity * 1.2 * t);

            smoother_update(*velocity, target_velocity, dt);

            movement: = xyz(velocity.value, 0) * dt;
            position += movement;
        }
    }

    // facing
    if length(agent.velocity.value) > 0.1
    {
        agent.is_facing_left = velocity.value.x < 0;
    }

    // arms
    update_arm :: (agent: *Agent, arm: *Rope, dt: float, is_left: bool)
    {
        arm.segment_count = s.arm_segments;
        arm.segment_length = agent.body.arm_length / arm.segment_count;

        shoulders: = get_shoulders_position(agent, is_left).xy;
        rope_set_first_node(arm, shoulders);
        {
            v: = ifx agent.is_facing_left then agent.velocity.value else agent.velocity_record[positive_mod(agent.velocity_record_index-1, agent.velocity_record.count)];
            rope_add_velocity(arm, -v * 0.5);
        }
        rope_update(arm, dt);
    }
    update_arm(agent, *left_arm, dt, true);
    update_arm(agent, *right_arm, dt, false);

    // legs
    update_leg :: (agent: *Agent, leg: *Rope, dt: float, is_left: bool)
    {
        facing_sign: float = ifx agent.is_facing_left then -1.0 else 1.0;
        velocity_ratio: = length(agent.velocity.value) / s.agent_max_velocity;
        if velocity_ratio < 0.1 velocity_ratio = 0.0;
        anchor_offset: = .{agent.body.hips_width/2,0} * Vector2.{ifx is_left then -1.0 else 1.0,1.0};

        rope_set_first_node(leg, agent.position.xy + .{0, agent.body.leg_length} + anchor_offset);

        time: = agent.time + ifx is_left then s.leg_movement_phase*0.5 else 0.0;
        t: = (-time * facing_sign) * TAU / s.leg_movement_phase;
        moving_target: = leg.node_positions[0] + .{0, -agent.body.leg_length} + s.leg_target_offset*.{-facing_sign, 0} + .{cos(t), sin(t)} * s.leg_movement;
        idle_target: = agent.position.xy + anchor_offset;
        leg.target = lerp(idle_target, moving_target, velocity_ratio);

        leg.smoothed_target.time_to_90 = lerp(0.0, s.leg_target_time_to_90, velocity_ratio);
        leg_segment_length: float = agent.body.leg_length / leg.segment_count;
        leg.segment_length = lerp(leg_segment_length, leg_segment_length * 1.1, velocity_ratio);
        rope_update(leg, dt);
    }
    update_leg(agent, *agent.left_leg, dt, true);
    update_leg(agent, *agent.right_leg, dt, false);

    position.z = -position.y;

    // record velocity
    velocity_record_index = (velocity_record_index + 1) % agent.velocity_record.count;
    agent.velocity_record[velocity_record_index] = velocity.value;

} @update_group()

agent_draw :: (agent: *Agent)
{
    sign: float = ifx agent.is_facing_left then -1.0 else 1.0;

    // bottom
    hips: = get_hips_position(agent);
    draw_ellipse(hips, .{agent.body.hips_width/2, 2.0}, agent.bottom_color);

    // legs
    rope_draw(*agent.left_leg, hips.z, 1.0, agent.bottom_color);
    rope_draw(*agent.right_leg, hips.z, 1.0, agent.bottom_color);

    // chest
    chest_base: = get_chest_base_position(agent);
    lower_chest_height: = (agent.body.chest_lower_ratio + agent.body.chest_overlapping_ratio) * agent.body.chest_height;
    draw_ellipse(chest_base + .{0,lower_chest_height * 0.5,0.1}, .{agent.body.lower_body_width/2+1, lower_chest_height * 0.5}, agent.top_color);

    upper_chest_height: = (1.0 - agent.body.chest_lower_ratio + agent.body.chest_overlapping_ratio) * agent.body.chest_height;
    draw_ellipse(chest_base + .{0,agent.body.chest_height - upper_chest_height*0.5,0.1}, .{agent.body.upper_body_width/2, upper_chest_height/2}, agent.top_color);

    // arms
    rope_draw(*agent.left_arm, hips.z + sign*0.2, 1.0, agent.top_color);
    draw_circle(xyz(agent.left_arm.node_positions[agent.left_arm.segment_count], hips.z + sign*0.2 + 0.01), 1.5, agent.skin_color);

    rope_draw(*agent.right_arm, hips.z + sign*-0.2, 1.0, agent.top_color);
    draw_circle(xyz(agent.right_arm.node_positions[agent.right_arm.segment_count], hips.z + sign*-0.2 + 0.01), 1.5, agent.skin_color);

    // head
    neck: = get_neck_position(agent);
    draw_ellipse(neck + .{0,1,0.3}, .{3,2.5}, agent.skin_color);
    draw_ellipse(neck + .{sign * 1,3,0.4}, .{3,2}, agent.hair_color);

} @draw_group()

agent_draw_shadow :: (agent: *Agent)
{
    draw_ellipse(agent.position + .{-2, 0,0}, .{6.0, 2.0}, .{0,0,0,70});
} @draw_group("shadow")

agent_draw_debug :: (using agent: *Agent)
{
    if s.debug_left_leg { draw_circle(left_leg.target, 2.0, RED); }
    if s.debug_right_leg { draw_circle(right_leg.target, 2.0, RED); }
    // draw_line(position, position + xyz(velocity.value, 0), 1.0, RED);
} @draw_group("debug")

get_hips_position :: (agent: *Agent) -> Vector3
{
    return agent.position + .{0,agent.body.leg_length,0};
}

get_chest_base_position :: (agent: *Agent) -> Vector3
{
    return get_hips_position(agent) + .{0,-1, 0};
}

get_neck_position :: (agent: *Agent) -> Vector3
{
    return get_chest_base_position(agent) + .{0, agent.body.chest_height - 3.0, 0};
}

get_shoulders_position :: (agent: *Agent, is_left: bool) -> Vector3
{
    upper_chest_height: = (1.0 - agent.body.chest_lower_ratio + agent.body.chest_overlapping_ratio) * agent.body.chest_height;
    return get_chest_base_position(agent) + .{0,agent.body.chest_height - upper_chest_height*0.5, 0} + .{(ifx is_left then -1.0 else 1.0) * agent.body.upper_body_width*0.5, 0, 0};
}
