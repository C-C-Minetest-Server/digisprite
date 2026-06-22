-- digisprite/init.lua
-- Show plain textures via Digilines
-- Copyright (c) 2026 1F616EMO
-- SPDX-License-Identifier: Unlicense

local S = core.get_translator("digisprite")

local CHN_FORMSPEC = "field[channel;" .. core.formspec_escape(core.translate("digilines", "Channel")) .. ";${channel}]"

local function update_display(pos, node)
    local obj

    do
        local objs = core.get_objects_inside_radius(pos, 0.5)
        for _, i in ipairs(objs) do
            if i:get_luaentity() and i:get_luaentity().name == "digisprite:image" then
                if obj then
                    i:remove()
                else
                    obj = i
                end
            end
        end
    end

    if not obj then
        obj = core.add_entity(pos, "digisprite:image")
    end

    local meta = core.get_meta(pos)

    local texture_front = meta:get_string("texture_front")
    if texture_front == "" then
        texture_front = "digisprite_transparent.png"
    end

    local texture_back = meta:get_string("texture_back")
    if texture_back == "" then
        texture_back = texture_front
    end

    local vx = meta:get_float("vx")
    if vx <= 0 then
        vx = 1
    end

    local vy = meta:get_float("vy")
    if vy <= 0 then
        vy = 1
    end

    local vz = meta:get_float("vz")
    if vz <= 0 then
        vz = 1
    end

    local fdir = core.facedir_to_dir(node and node.param2 or core.get_node(pos).param2)
    obj:set_properties({
        visual_size = { x = vx, y = vy, z = vz },
        textures = { texture_front, texture_back },
    })
    obj:set_yaw((fdir.x ~= 0) and math.pi / 2 or 0)
    obj:set_pos(vector.add(pos, vector.multiply(fdir, 0.39)))
end

local function on_construct(pos)
    local meta = core.get_meta(pos)
    meta:set_string("formspec", CHN_FORMSPEC)

    update_display(pos)
end

local function on_destruct(pos)
    local objs = core.get_objects_inside_radius(pos, 0.5)
    for _, i in ipairs(objs) do
        if i:get_luaentity() and i:get_luaentity().name == "digisprite:image" then
            i:remove()
        end
    end
end

local function on_receive_fields(pos, _, fields, sender)
    local name = sender:get_player_name()
    if core.is_protected(pos, name) and not core.check_player_privs(name, { protection_bypass = true }) then
        return
    end
    if fields.channel then
        core.get_meta(pos):set_string("channel", fields.channel)
    end
end

local on_rotate

if core.global_exists("screwdriver") then
    on_rotate = function(pos, _, _, mode, new_param2)
        if mode ~= screwdriver.ROTATE_FACE then
            return false
        end

        update_display(pos, { param2 = new_param2 })
    end
end

local function on_digilines(pos, _, channel, msg)
    local meta = core.get_meta(pos)
    local setchan = meta:get_string("channel")
    if channel ~= setchan then return end

    if type(msg) == "string" then
        msg = {
            texture_front = msg,
        }
    elseif type(msg) ~= "table" then
        return
    end

    local texture_front = ""
    if type(msg.texture_front) == "string" then
        texture_front = msg.texture_front
    end

    local texture_back = ""
    if type(msg.texture_back) == "string" then
        texture_back = msg.texture_back
    end

    local vx, vy, vz = 0, 0, 0
    if type(msg.visual_size) == "table" then
        if type(msg.visual_size.x) == "number" then
            vx = math.max(msg.visual_size.x, 0)
        end
        if type(msg.visual_size.y) == "number" then
            vy = math.max(msg.visual_size.y, 0)
        end
        if type(msg.visual_size.z) == "number" then
            vz = math.max(msg.visual_size.z, 0)
        end
    end

    meta:set_string("texture_front", texture_front)
    meta:set_string("texture_back", texture_back)
    meta:set_float("vx", vx)
    meta:set_float("vy", vy)
    meta:set_float("vz", vz)

    update_display(pos)
end

core.register_entity("digisprite:image", {
    initial_properties = {
        visual = "upright_sprite",
        physical = false,
        collisionbox = { 0, 0, 0, 0, 0, 0, },
        textures = { "digisprite_transparent.png" },
        glow = 14,
        shaded = true,
        static_save = false,
    },

    on_step = function(self, dtime)
        self._dtime = (self._dtime or 0) + dtime
        if self._dtime < 1 then return end
        self._dtime = 0

        local observers = {}
        local pos = self.object:get_pos()
        for _, player in ipairs(core.get_connected_players()) do
            local pname = player:get_player_name()
            local pprop = player:get_properties()
            local vpos = vector.add(
                vector.add(player:get_pos(), player:get_eye_offset()[1]),
                { x = 0, y = pprop.eye_height, z = 0 }
            )
            local distance = vector.distance(pos, vpos)

            if distance < 30 then
                observers[pname] = true
            elseif distance < 100 then
                local rc = core.raycast(vpos, pos, false, false)
                local blocks = false
                for pt in rc do
                    if pt.type == "node" then
                        local npos = pt.under
                        local node = core.get_node(npos)
                        local ndef = core.registered_nodes[node.name]

                        if ndef and not ndef.sunlight_propagates then
                            blocks = true
                            break
                        end
                    end
                end

                if not blocks then
                    observers[pname] = true
                end
            end
        end

        self.object:set_observers(observers)
    end,
})

core.register_node("digisprite:digisprite", {
    description = S("Digilines Texture Display"),
    tiles = { "digisprite_pixel.png", },
    groups = { cracky = 3, digisprite = 1, },
    paramtype = "light",
    paramtype2 = "facedir",
    on_rotate = on_rotate,
    drawtype = "nodebox",
    node_box = {
        type = "fixed",
        fixed = { -0.5, -0.5, 0.4, 0.5, 0.5, 0.5 },
    },
    _digistuff_channelcopier_fieldname = "channel",
    light_source = 10,
    on_construct = on_construct,
    on_destruct = on_destruct,
    on_receive_fields = on_receive_fields,
    digiline = {
        wire = {
            rules = digilines.rules.default,
        },
        effector = {
            action = on_digilines,
        },
    },
})

core.register_lbm({
    name = "digisprite:respawn",
    label = "Respawn/upgrade digisprite entities",
    nodenames = { "group:digisprite", },
    run_at_every_load = true,
    action = update_display,
})
