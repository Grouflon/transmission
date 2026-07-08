ShadowComponent :: struct
{
    #as using base: EntityComponent;

    size: Vector2 = .{6.0, 2.0};
    base_height: float;

    transform: *IsoTransformComponent;
}

initialize :: (shadow: *ShadowComponent)
{
    shadow.transform = get_component(shadow, IsoTransformComponent);
}

draw :: (shadow: *ShadowComponent)
{

    height: = shadow.base_height + shadow.transform.position.z;
    horizontal_offset: = 0.0;
    if abs(height) > EPSILON
    {
        horizontal_offset = tan(D2R * s.light_angle) * height;
    }

    draw_ellipse(get_ground_position(shadow.transform) + .{horizontal_offset, 0,0}, shadow.size, .{0,0,0,70});
} @draw_group("shadow")