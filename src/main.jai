#load "agent.jai";
#load "game.jai";
#load "rope.jai";
#load "settings.jai";

// Boilerplate
main :: ()
{
    register_resources(*resources);

    // Init
    yae_init(800, 600, "transmission");
    game_init();

    // Loop
    yae_loop(game_update, game_draw);
    if OS == .WASM return; // wasm needs to exit immediately. Everything will happen async later

    // Shutdown
    game_shutdown();
    yae_shutdown();
}

// === Loads ===
#if OS == .WASM
{
    // @NOTE(remi): We can remove this with functions that send callbacks as argument to wasm
    #load "../modules/yae/wasm_export.jai";
}

// === Imports ===
#scope_file
#import "Basic"()(MEMORY_DEBUGGER = YAE_DEBUG_MEMORY);
#import,dir "../../yae";

#import "Math";