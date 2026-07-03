ShadowComponent :: struct
{
    #as using base: EntityComponent;

    transform: *IsoTransformComponent;
}

initialize :: (shadow: *ShadowComponent)
{
    shadow.transform = get_component(shadow, IsoTransformComponent);
}

draw :: (shadow: *ShadowComponent)
{
    LIGHT_ANGLE :: 30.0;

    horizontal_offset: = 0.0;
    if abs(shadow.transform.position.z) > EPSILON
    {
        horizontal_offset = tan(D2R * LIGHT_ANGLE) * shadow.transform.position.z;
    }

    draw_ellipse(get_ground_position(shadow.transform) + .{-2 - horizontal_offset, 0,0}, .{6.0, 2.0}, .{0,0,0,70});
} @draw_group("shadow")