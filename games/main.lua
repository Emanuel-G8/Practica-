isomap = require ("isomap")
function love.load()
	--Variables
	x = 0
	y = 0
	zoomL = 1
	zoom = 1

	--Set background to deep blue
	love.graphics.setBackgroundColor(0, 0, 69)
	love.graphics.setDefaultFilter("linear", "linear", 8)

	debugCollisions = false

	--Decode map file (now a plain Lua table, no JSON library needed)
	isomap.decodeJson("Map.lua")

	--Generate map from JSON file (loads assets and creates tables)
	isomap.generatePlayField()

   playerImages = {
    n  = love.graphics.newImage("props/player_n.png"),
    s  = love.graphics.newImage("props/player_s.png"),
    e  = love.graphics.newImage("props/player_e.png"),
    w  = love.graphics.newImage("props/player_w.png"),
    ne = love.graphics.newImage("props/player_ne.png"),
    nw = love.graphics.newImage("props/player_nw.png"),
    se = love.graphics.newImage("props/player_se.png"),
    sw = love.graphics.newImage("props/player_sw.png"),
    }

	playerDirection = "s" 

    -- Starting tile position (row, col) -- pick an open grass tile on your map
    playerRow, playerCol = 5, 5
    playerSpeed = 4 -- tiles per second

	playerColliderRX = 0.20
    playerColliderRY = 0.12

    -- Anchor point inside the sprite: bottom-center = the character's "feet".
    -- This is what actually gets lined up with the ground tile.
    local pw, ph = playerImages.s:getWidth(), playerImages.s:getHeight()
    playerOffX = pw / 2
    playerOffY = ph - 4

    -- Register the player as a DYNAMIC object in isomap's z-buffer.
    -- Quirk: insertNewObject(isoX, isoY) stores them swapped internally
    -- (entry.x = isoY, entry.y = isoX) to match how props are stored
    -- elsewhere (x = column, y = row). So pass (row, col) here.
    isomap.insertNewObject(playerImages[playerDirection], playerRow, playerCol, playerOffX, playerOffY)

    -- Grab a live reference to that entry so we can move it every frame
    -- instead of inserting a new duplicate object each time.
    playerEntry = mapPropsfield[#mapPropsfield]

end

function love.update(dt)

	 local dx, dy = 0, 0
    if love.keyboard.isDown("left") then dx = dx - 1 end
	if love.keyboard.isDown("right") then dx = dx + 1 end
	if love.keyboard.isDown("up") then dy = dy - 1 end
	if love.keyboard.isDown("down") then dy = dy + 1 end

	if dx ~= 0 or dy ~= 0 then
    local dirKey = ""
    if dy < 0 then dirKey = dirKey .. "n"
    elseif dy > 0 then dirKey = dirKey .. "s" end
    if dx < 0 then dirKey = dirKey .. "w"
    elseif dx > 0 then dirKey = dirKey .. "e" end

    playerDirection = dirKey
    playerEntry.texture = playerImages[playerDirection]

    local len = math.sqrt(dx*dx + dy*dy)
    local newCol = playerCol + (dx/len) * playerSpeed * dt
    local newRow = playerRow + (dy/len) * playerSpeed * dt

    if not isomap.collidesWithTrees(newCol, newRow, playerColliderRX, playerColliderRY) then
        playerCol = newCol
        playerRow = newRow
    else
        if not isomap.collidesWithTrees(newCol, playerRow, playerColliderRX, playerColliderRY) then
            playerCol = newCol
        end
        if not isomap.collidesWithTrees(playerCol, newRow, playerColliderRX, playerColliderRY) then
            playerRow = newRow
        end
    end

    playerCol = math.max(1, math.min(isomap.getPlayfieldHeight(), playerCol))
    playerRow = math.max(1, math.min(isomap.getPlayfieldWidth(), playerRow))
end

    -- Push the updated position into the same table isomap re-sorts every
    -- frame. The +0.001 breaks ties in favor of the player over static props.
    playerEntry.x = playerCol
    playerEntry.y = playerRow + 0.001

    -- Camera follows the player
    local tileWidth = isomap.getGroundTileWidth()
    local px = playerCol * (tileWidth * zoomL)
    local py = playerRow * (tileWidth * zoomL)
    local screenX, screenY = isomap.toIso(px, py)
    x = love.graphics.getWidth()/2 - screenX
    y = love.graphics.getHeight()/2 - screenY

    zoomL = lerp(zoomL, zoom, 0.05*(dt*300))


end
function love.draw()
	isomap.drawGround(x, y, zoomL)
	isomap.drawObjects(x, y, zoomL)

	if debugCollisions then
		local tileWidth = isomap.getGroundTileWidth()

		love.graphics.setColor(255, 60, 60, 180)
		for _, t in ipairs(isomap.getTreeColliders()) do
			local sx, sy = isomap.toIso(t.x * tileWidth * zoomL, t.y * tileWidth * zoomL)
			love.graphics.ellipse("line", sx + x, sy + y, t.rx * tileWidth * zoomL, t.ry * tileWidth * zoomL)
		end

		love.graphics.setColor(60, 255, 60, 200)
		local psx, psy = isomap.toIso(playerCol * tileWidth * zoomL, playerRow * tileWidth * zoomL)
		love.graphics.ellipse("line", psx + x, psy + y, playerColliderRX * tileWidth * zoomL, playerColliderRY * tileWidth * zoomL)

		love.graphics.setColor(255, 255, 255, 255)
	end

	info = love.graphics.getStats()
	love.graphics.print("FPS: "..love.timer.getFPS())
	love.graphics.print("Draw calls: "..info.drawcalls, 0, 12)
	love.graphics.print("Texture memory: "..((info.texturememory/1024)/1024).."mb", 0, 24)
	love.graphics.print("Zoom level: "..zoom, 0, 36)
	love.graphics.print("X: "..math.floor(x).." Y: "..math.floor(y), 0, 48)
end

function love.wheelmoved(x, y)
    if y > 0 then
      zoom = zoom + 0.1
    elseif y < 0 then
      zoom = zoom - 0.1
    end

	if zoom < 0.1 then zoom = 0.1 end
end

function lerp(a, b, rate) --EMPLOYEE OF THE MONTH
	local result = (1-rate)*a + rate*b
	return result
end
