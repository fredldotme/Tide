#ifndef SDL2_API_BINDING_H
#define SDL2_API_BINDING_H

#include <SDL2/SDL.h>
#include <wasm_export.h>
#include <QDebug>
#include <SDL_main.h>

extern "C" {

static int wamr_binding_SDL_Init(wasm_exec_env_t exec_env, Uint32 flags)
{
    qDebug() << "SDL Init flags:" << flags;
    SDL_SetHint(SDL_HINT_OPENGL_ES_DRIVER, "1");
    return SDL_Init(flags);
}

static uint32_t wamr_binding_SDL_CreateWindow(wasm_exec_env_t exec_env, int name, int x, int y, int w, int h, int flags)
{
    auto module_inst = wasm_runtime_get_module_inst(exec_env);
    char* window_name = (char *)wasm_runtime_addr_app_to_native(module_inst, name);
    auto window = SDL_CreateWindow(window_name, x, y, w, h, (Uint32)flags);
    qDebug() << "SDL_CreateWindow:" << window;
    return wasm_runtime_addr_native_to_app(module_inst, (void*)window);
}

static void wamr_binding_SDL_Delay(wasm_exec_env_t exec_env, Uint32 ms)
{
    SDL_Delay(ms);
}

static uint32_t wamr_binding_SDL_GetError(wasm_exec_env_t exec_env)
{
    auto module_inst = wasm_runtime_get_module_inst(exec_env);
    const auto err = SDL_GetError();
    qWarning() << "SDL_GetError:" << err;
    return wasm_runtime_addr_native_to_app(module_inst, (void*)err);
}

static void wamr_binding_SDL_SetMainReady(wasm_exec_env_t exec_env)
{
    SDL_SetMainReady();
}

static SDL_bool wamr_binding_SDL_SetHint(wasm_exec_env_t exec_env, int name, int value)
{
    auto module_inst = wasm_runtime_get_module_inst(exec_env);
    char* hint_name = (char *)wasm_runtime_addr_app_to_native(module_inst, name);
    char* hint_value = (char *)wasm_runtime_addr_app_to_native(module_inst, value);

    qDebug() << "SDL_SetHint:" << hint_name << hint_value;

    return SDL_SetHint(hint_name, hint_value);
}

static void wamr_binding_SDL_ShowWindow(wasm_exec_env_t exec_env, int window)
{
    auto module_inst = wasm_runtime_get_module_inst(exec_env);
    SDL_Window* sdl_window = (SDL_Window *)wasm_runtime_addr_app_to_native(module_inst, window);
    qDebug() << "SDL_ShowWindow:" << sdl_window;
    SDL_ShowWindow(sdl_window);
}

#define ADD_SYMBOL(name, signature) \
    { #name, (void*) wamr_binding_##name, signature, nullptr }

static NativeSymbol sdl2_native_symbols[] = {
    ADD_SYMBOL(SDL_Init, "(i)i"),
    ADD_SYMBOL(SDL_CreateWindow, "(iiiiii)i"),
    ADD_SYMBOL(SDL_Delay, "(i)"),
    ADD_SYMBOL(SDL_GetError, "()i"),
    ADD_SYMBOL(SDL_SetMainReady, "()"),
    ADD_SYMBOL(SDL_SetHint, "(ii)i"),
    ADD_SYMBOL(SDL_ShowWindow, "(i)")
};

void register_wamr_sdl2_bindings() {
    const int n_native_symbols = sizeof(sdl2_native_symbols) / sizeof(NativeSymbol);
    if (!wasm_runtime_register_natives("env", sdl2_native_symbols, n_native_symbols)) {
        qWarning() << "Failed to register SDL2 APIs";
    } else {
        qInfo() << "Successfully registered SDL2 APIs";
    }
}
} // extern "C"

#endif // SDL2_API_BINDING_H
