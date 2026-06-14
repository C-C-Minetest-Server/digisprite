# Digisprite

Digiline display that shows plain textures. Inpsired by [Digiscreen](https://content.luanti.org/packages/cheapie/digiscreen/).

## Digiline API

```lua
digiline_send("digisprite_channel", {
    texture_front = "", -- Front texture string, default: transparent
    texture_back  = "", -- Back texture string, default: texture_front

    visual_size   = { x = 1, y = 1, z = 1 }, -- Check lua_api.txt
})
```
