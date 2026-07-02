GameSettings :: struct
{
    #as using _resource: Resource;
    type = type_info(GameSettings);

    agent_count: int = 1; @min(1) @serialize
    agent_interval: float = 10.0; @serialize @drag

    background_color: Color; @serialize
    segment_count: int = 1; @serialize @range(1,64)
    segment_length: float = 5.0; @serialize @step(1)
    gravity: float = -9.8; @serialize
    drag: float = 0.1; @serialize
    smooth_time: float = 0.3; @serialize
    iterations: int = 1; @serialize
    constraint_angle: float = 180; @serialize @drag @range(0,180) @step(1)

    agent_max_velocity: float = 1.0; @serialize @drag
    agent_velocity_time_to_90: float = 1.0; @serialize @drag
    velocity_decay_distance: float = 10.0; @serialize @drag

    arm_segments: int = 6; @serialize
    arm_target_time_to_90: float = 1.0; @serialize @drag

    leg_movement: Vector2; @serialize
    leg_target_offset: Vector2; @serialize
    leg_movement_phase: float; @serialize
    leg_target_time_to_90: float; @serialize
    debug_left_leg: bool; @serialize
    debug_right_leg: bool; @serialize

    leg_length_range: RangeFloat = .{1,1}; @serialize @min(1)
    arm_length_range: RangeFloat = .{1,1}; @serialize @min(1)
    chest_height_range: RangeFloat = .{1,1}; @serialize @min(1)
    chest_lower_ratio_range: RangeFloat = .{0.6,0.6}; @serialize @min(1)
    lower_body_width_range: RangeFloat = .{1,1}; @serialize @min(1)
    upper_body_width_range: RangeFloat = .{1,1}; @serialize @min(1)

    agent_body: AgentBody; @serialize

    skin_tones: [..]Color; @serialize
    hair_tones: [..]Color; @serialize
    clothes_tones: [..]Color; @serialize
}
