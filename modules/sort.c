#pragma comment(lib, "lua54.lib")
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

static int l_pixelSort(lua_State *L) {
    int a = 1;
    lua_pushnumber(L, a);
    return 1;
}

__declspec(dllexport) int luaopen_sort(lua_State *L) {
    luaL_Reg funcs[] = {
        {"pixelSort", l_pixelSort},
        {NULL, NULL}
    };
    luaL_newlib(L, funcs);
    return 1;
}
