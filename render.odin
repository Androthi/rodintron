package rodintron

// not necessary to split out the files, it just makes it easier for me to
// navigate the sources on a laptop

import rl "vendor:raylib"
import "core:c"
import "core:math/rand"

RenderFrame:: proc() {
	
	rl.BeginTextureMode(render_target)
  
	rl.ClearBackground(rl.BLACK)
	
	if !gameOver
	{
		// Draw spaceship

		//v1 :rl.Vector2 = { player.position.x + math.sin_f32(player.rotation*rl.DEG2RAD)*(shipHeight), player.position.y - math.cos_f32(player.rotation*rl.DEG2RAD)*(shipHeight) }
		//v2 :rl.Vector2 = { player.position.x - math.cos_f32(player.rotation*rl.DEG2RAD)*(PLAYER_WIDTH/2), player.position.y - math.sin_f32(player.rotation*rl.DEG2RAD)*(PLAYER_WIDTH/2) }
		//v3 :rl.Vector2 = { player.position.x + math.cos_f32(player.rotation*rl.DEG2RAD)*(PLAYER_WIDTH/2), player.position.y + math.sin_f32(player.rotation*rl.DEG2RAD)*(PLAYER_WIDTH/2) }
		
		//rl.DrawTriangle(v1, v2, v3, rl.MAROON)
        rl.DrawRectangle( c.int(player.position.x), c.int(player.position.y), PLAYER_WIDTH, PLAYER_HEIGHT, rl.MAROON)

		// Draw meteors
		for i:= 0; i < level*MAX_BIG_METEORS; i+=1
		{
			if bigMeteor[i].active do rl.DrawCircleV(bigMeteor[i].position, bigMeteor[i].radius, rl.DARKGRAY)
		}
		for i:= 0; i < level*MAX_MEDIUM_METEORS; i+=1
		{
			if mediumMeteor[i].active do rl.DrawCircleV(mediumMeteor[i].position, mediumMeteor[i].radius, rl.GRAY)
		}
			
		for i:= 0; i < level*MAX_SMALL_METEORS; i+=1
		{
			if smallMeteor[i].active do rl.DrawCircleV(smallMeteor[i].position, smallMeteor[i].radius, rl.GRAY)
		}
			
			
		// Draw shoot
		for i:= 0; i < PLAYER_MAX_SHOOTS; i+=1
		{
			if shoot[i].active do rl.DrawCircleV(shoot[i].position, shoot[i].radius, shoot[i].color)
		}

		if victory do rl.DrawText("VICTORY", screenWidth/2 - rl.MeasureText("VICTORY", 20)/2, screenHeight/2, 20, rl.LIGHTGRAY)

		if pause do rl.DrawText("GAME PAUSED", screenWidth/2 - rl.MeasureText("GAME PAUSED", 40)/2, screenHeight/2 - 40, 40, rl.GRAY)


		rl.DrawText( rl.TextFormat("Score %v", score), 10, 10, 20, rl.WHITE)

	} else { rl.DrawText("PRESS [ENTER] TO PLAY AGAIN", screenWidth/2 - rl.MeasureText("PRESS [ENTER] TO PLAY AGAIN", 20)/2, screenHeight/2, 20, rl.GRAY) }

	rl.EndTextureMode()
}

DrawFrame :: proc() {
	
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)
	rl.DrawTexturePro(
		render_target.texture,
		(rl.Rectangle){
			0.0, 0.0, f32(render_target.texture.width),f32(-render_target.texture.height) 
		},
		(rl.Rectangle){ 0.0, 0.0, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())},
		rl.Vector2({ 0.0, 0.0 }), 0.0, rl.WHITE)

	rl.EndDrawing()
}


draw_level_entry :: proc() {
    width := rl.GetScreenWidth()
    height := rl.GetScreenHeight()

    
    w_pos, h_pos:c.int
    for  {
        
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        w_pos +=20; if w_pos > width do w_pos = width
        h_pos +=20; if h_pos > height do h_pos = height
        if w_pos == width && h_pos == height do break
        rl.DrawRectangleLinesEx( {f32(width/2 - w_pos/2), f32(height/2 - h_pos/2), f32(w_pos), f32(h_pos)},
                                    40.0,
                                    transmute(rl.Color)rand.uint32()
                                )
        rl.EndDrawing()
    }
}
