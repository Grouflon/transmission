MAX_ROPE_SEGMENTS :: 32;
RopeMode :: enum
{
    PHYSICS;
    FOLLOW_TARGET;
}

Rope :: struct
{
    node_positions: [MAX_ROPE_SEGMENTS] Vector2;
    node_velocities: [MAX_ROPE_SEGMENTS] Vector2;
    segment_count: int; // rope has segment_count+1 nodes
    segment_length: float;

    mode: RopeMode;

    gravity: Vector2 = .{0,-800};
    drag: float = 0.001;

    target: Vector2;
    smoothed_target: Smoother(Vector2);
}

rope_init :: (rope: *Rope, position: Vector2)
{
    assert(rope.segment_count < MAX_ROPE_SEGMENTS);

    if rope.segment_count == 0 return;

    rope.node_positions[0] = position;
    rope.node_velocities[0] = .{};

    step: = normalize(rope.gravity) * rope.segment_length;

    for i: 1..rope.segment_count
    {
        rope.node_positions[i] = rope.node_positions[i-1] + step;
        rope.node_velocities[i] = .{};
    }
}

rope_set_first_node :: (rope: *Rope, position: Vector2)
{
    rope.node_positions[0] = position;
}

rope_add_velocity :: (rope: *Rope, velocity_increment: Vector2)
{
    for i: 0..rope.segment_count
    {
        rope.node_velocities[i] += velocity_increment;
    }
}

rope_update :: (rope: *Rope, dt: float)
{
    previous_positions: = rope.node_positions;

    if rope.mode ==
    {
        case .PHYSICS;
        {
            gravity_step: = rope.gravity * dt;

            for i: 1..rope.segment_count
            {
                // apply drag
                velocity_length: = length(rope.node_velocities[i]);
                rope.node_velocities[i] += -(rope.node_velocities[i] * velocity_length * rope.drag) * dt;

                // move node
                rope.node_positions[i] += (rope.node_velocities[i] + gravity_step) * dt;
            }

        }

        case .FOLLOW_TARGET;
        {
            smoother_update(*rope.smoothed_target, rope.target, dt);
            rope.node_positions[rope.segment_count] = rope.smoothed_target.value;
        }
    }

    fabr_ik(rope.node_positions.data, rope.segment_count, rope.segment_length);

    for i: 0..rope.segment_count
    {
        rope.node_velocities[i] = (rope.node_positions[i] - previous_positions[i]) / dt;
    }

    // force target to follow tip so switching modes is smooth
    if rope.mode == .PHYSICS
    {
        smoother_reset(*rope.smoothed_target, rope.node_positions[rope.segment_count]);
    }
}

rope_draw :: (rope: *Rope, z: float = 0.0, thickness: float = 1.0, color: Color = WHITE)
{
    for i: 0..rope.segment_count-1
    {
        draw_line(xyz(rope.node_positions[i], z), xyz(rope.node_positions[i+1], z), thickness, color);
    }
}

rope_draw_debug :: (rope: *Rope, z: float = 0.0, segment_thickness: float = 1.0, joint_radius: float = 3.0, segment_color: Color = BLUE, joint_color: Color = RED)
{
    for i: 0..rope.segment_count-1
    {
        draw_line(xyz(rope.node_positions[i], z), xyz(rope.node_positions[i+1], z), segment_thickness, segment_color);
    }

    for i: 0..rope.segment_count
    {
        draw_circle(xyz(rope.node_positions[i], z+0.1), joint_radius, joint_color);
    }
}

fabr_ik :: (nodes: *Vector2, segment_count: int, segment_length: float, iterations: int = 1, constraint_angle: float = 180.0)
{
    if nodes == null || segment_count == 0 return;

    root: = nodes[0];
    for iteration: 0..iterations-1
    {
        // Backwards tension
        previous_direction: Vector2 = .{};
        for < i: 0..segment_count-1
        {
            direction: = normalize(nodes[i] - nodes[i+1]);
            if previous_direction != .{}
            {
                a: = signed_angle_between(direction, previous_direction);
                if abs(a) * R2D > constraint_angle
                {
                    direction = rotate(previous_direction, sign(a) * constraint_angle * D2R);
                }
            }

            nodes[i] = nodes[i+1] + direction * segment_length;
            previous_direction = direction;
        }

        nodes[0] = root;
        // Forward tension
        previous_direction = .{};
        for i: 1..segment_count
        {
            direction: = normalize(nodes[i] - nodes[i-1]);
            if previous_direction != .{}
            {
                a: = signed_angle_between(direction, previous_direction);
                if abs(a) * R2D > constraint_angle
                {
                    direction = rotate(previous_direction, sign(a) * constraint_angle * D2R);
                }
            }

            nodes[i] = nodes[i-1] + direction * segment_length;
            previous_direction = direction;
        }
    }
}