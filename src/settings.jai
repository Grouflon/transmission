GameSettings :: struct
{
    #as using _resource: Resource;
    type = type_info(GameSettings);

    background_color: Color; @serialize
    segment_count: int = 1; @serialize @min(1) @max(64)
    segment_length: float = 5.0; @serialize @step(1)
    gravity: float = -9.8; @serialize
    drag: float = 0.1; @serialize
    smooth_time: float = 0.3; @serialize
    iterations: int = 1; @serialize
    constraint_angle: float = 180; @serialize @drag @min(0) @max(180) @step(1)

    agent_max_velocity: float = 1.0; @serialize @drag
    agent_velocity_time_to_90: float = 1.0; @serialize @drag
    velocity_decay_distance: float = 10.0; @serialize @drag

    arm_segments: int = 6; @serialize
    arm_length: float = 6.0; @serialize @drag
    arm_target_time_to_90: float = 1.0; @serialize @drag

    leg_movement: Vector2; @serialize
    leg_target_offset: Vector2; @serialize
    leg_movement_phase: float; @serialize
    leg_target_time_to_90: float; @serialize
    debug_left_leg: bool; @serialize
    debug_right_leg: bool; @serialize

    skin_tones: [..]Color; @serialize
    hair_tones: [..]Color; @serialize
    clothes_tones: [..]Color; @serialize
}
