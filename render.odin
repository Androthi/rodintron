package rodintron

// not necessary to split out the files, it just makes it easier for me to
// navigate the sources on a laptop

import rl "vendor:raylib"
import "core:c"
import "core:math/rand"
import "core:math"

RenderFrame:: proc() {
	
	rl.BeginTextureMode(render_target)
	rl.ClearBackground(rl.BLACK)
	
	switch current_state {
		case .TITLE:
			
			rl.DrawText("Rodintron", screenWidth/2 - rl.MeasureText("Rodintron", 40)/2, screenHeight/2 - 200, 40, rl.LIGHTGRAY)
			rl.DrawText("PRESS [ENTER] OR LEFT MOUSE BUTTON PLAY", screenWidth/2 - rl.MeasureText("PRESS [ENTER] OR LEFT MOUSE BUTTON PLAY", 20)/2, screenHeight/2, 20, rl.LIGHTGRAY)

		case .VICTORY:

			rl.DrawText("You Have Defeated the Robot Menace!", screenWidth/2 - rl.MeasureText("You Have Defeated the Robot Menace!", 40)/2, screenHeight/2 - 200, 40, rl.LIGHTGRAY)
			rl.DrawText( rl.TextFormat("Final Score %v", score), screenWidth/2 - rl.MeasureText(rl.TextFormat("Final Score %v", score), 20)/2, screenHeight/2, 30, rl.LIGHTGRAY)
			rl.DrawText("PRESS [ENTER] OR LEFT MOUSE BUTTON PLAY AGAIN", screenWidth/2 - rl.MeasureText("PRESS [ENTER] OR LEFT MOUSE BUTTON PLAY AGAIN", 20)/2, screenHeight/2 + 80, 20, rl.LIGHTGRAY)

		case .DEFEAT:

			rl.DrawText("Humanity Has Fallen To The Robot Menace!", screenWidth/2 - rl.MeasureText("Humanity Has Fallen To The Robot Menace!", 40)/2, screenHeight/2 - 200, 40, rl.LIGHTGRAY)
			rl.DrawText( rl.TextFormat("Final Score %v", score), screenWidth/2 - rl.MeasureText(rl.TextFormat("Final Score %v", score), 20)/2, screenHeight/2, 30, rl.LIGHTGRAY)
			rl.DrawText("PRESS [ENTER] OR LEFT MOUSE BUTTON PLAY AGAIN", screenWidth/2 - rl.MeasureText("PRESS [ENTER] OR LEFT MOUSE BUTTON PLAY AGAIN", 20)/2, screenHeight/2 + 80, 20, rl.LIGHTGRAY)

		case .GAMEPLAY:
			if !gameOver {
						
				// TODO Draw player
				rl.DrawTexturePro(sprite_texture, player.source, player.collider, 0, 0, rl.WHITE)
				//rl.DrawRectangleRec(player.collider, player.color)

				stick := (rl.Vector2){ (player.position.x + math.sin(player.rotation*rl.DEG2RAD)*(PLAYER_HEIGHT/2)), player.position.y - math.cos(player.rotation*rl.DEG2RAD)*(PLAYER_HEIGHT/2) }
				rl.DrawLineEx( stick, stick+6, 5, rl.BROWN)

				// Draw entities
				for i:= 0; i < active_entities + NUM_CIVILIANS; i+=1
				{
					if entities[i].active {
						rl.DrawRectangleV( { entities[i].position.x, entities[i].position.y }, {entities[i].shape.x, entities[i].shape.y }, entities[i].color)
					}
				}
				
				// Draw shots
				for i:= 0; i < len(shot); i+=1
				{
					if shot[i].active do rl.DrawCircleV(shot[i].position, shot[i].radius, shot[i].color)
				}

				if victory do rl.DrawText("VICTORY", screenWidth/2 - rl.MeasureText("VICTORY", 20)/2, screenHeight/2, 20, rl.LIGHTGRAY)

				if pause do rl.DrawText("GAME PAUSED", screenWidth/2 - rl.MeasureText("GAME PAUSED", 40)/2, screenHeight/2 - 40, 40, rl.GRAY)

				rl.DrawText( rl.TextFormat("Score %v", score), 10, 10, 20, rl.WHITE)
				rl.DrawText( rl.TextFormat("Wave  %v", wave), 10, 40, 20, rl.WHITE)	
			}
	}

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


draw_wave_entry :: proc() {
    width := rl.GetScreenWidth()
    height := rl.GetScreenHeight()

    
    w_pos, h_pos:c.int
    for  {
        
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        w_pos +=40; if w_pos > width do w_pos = width
        h_pos +=40; if h_pos > height do h_pos = height
        if w_pos == width && h_pos == height do break
        rl.DrawRectangleLinesEx( {f32(width/2 - w_pos/2), f32(height/2 - h_pos/2), f32(w_pos), f32(h_pos)},
                                    40.0,
                                    transmute(rl.Color)rand.uint32()
                                )
        rl.EndDrawing()
    }
}
