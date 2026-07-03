IsoTransformComponent :: struct
{
    #as using base: EntityComponent;

    position: Vector3; // x,y is ground position, z is height (having y as height is very inconvenient)
}

get_draw_position :: (transform: *IsoTransformComponent) -> Vector3
{
    return .{transform.position.x, transform.position.y + transform.position.z, -transform.position.y};
}

get_ground_position :: (transform: *IsoTransformComponent) -> Vector3
{
    return .{transform.position.x, transform.position.y, -transform.position.y};
}
