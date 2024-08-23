package rodintron

// robotron type game

import "core:math"
import rl "vendor:raylib"
import "core:c"
//import "core:fmt"
//import "core:math/rand"

PLAYER_HEIGHT       :: 45.0
PLAYER_WIDTH	    :: 20.0
PLAYER_SPEED		:: 3.0

SHOTS_MAX			:: 4
SHOTS_LIFE_SPAN		:: 180
SHOTS_SPEED			:: 5


ROB_BRUTE_WIDTH     :: 30
ROB_BRUTE_HEIGHT    :: 50
ROB_BRUTE_SPEED		:: 2

screenWidth			:i32: 1600
screenHeight		:i32: 1200
render_screen_width     :i32 = screenWidth
render_screen_height    :i32 = screenHeight


MAX_ENTITIES        ::100
MAX_LEVEL			:: 600
STARTING_ENTITIES	:: 5

level				:int = 1
entities			:[MAX_ENTITIES]Entity
active_entities		:int
destroyed_entities	:int
score				:int


render_target       :rl.RenderTexture
gameOver			:bool
pause				:bool
victory				:bool

player		:Player
shot		:[SHOTS_MAX]Player_Shot

snd_lazer1		:rl.Sound
snd_explosion1	:rl.Sound
snd_thrust		:rl.Sound

Player :: struct {
	position	:rl.Vector2,
	speed		:rl.Vector2,
	acceleration:f32,
	rotation	:f32,
	collider	:rl.Vector3,
	color		:rl.Color,
}

Player_Shot :: struct {
	position	:rl.Vector2,
	speed		:rl.Vector2,
	radius		:f32,
	rotation	:f32,
	life_span	:c.int,
	color		:rl.Color,
	active		:bool,
}

Entity :: struct {
    position    :rl.Vector2,
    speed       :rl.Vector2,
	collider	:rl.Rectangle,	// temporary collider + drawing shape
	radius		:f32,			// temp
    color       :rl.Color,		// temp for shape. will be replaced by sprite colors.
    active      :bool,
}

main :: proc() {

	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(screenWidth, screenHeight, "Rodintron")
	rl.SetWindowMinSize(screenWidth, screenHeight)
	render_target = rl.LoadRenderTexture(render_screen_width, render_screen_height)
	rl.SetTextureFilter(render_target.texture, .BILINEAR)
	rl.SetTargetFPS(60)
	rl.InitAudioDevice()

	snd_lazer1 = rl.LoadSound("resources/lazer1.wav")
	defer rl.UnloadSound(snd_lazer1)
	snd_explosion1 = rl.LoadSound("resources/explosion1.wav")
	defer rl.UnloadSound(snd_explosion1)
	snd_thrust = rl.LoadSound("resources/thrust.wav")
	defer rl.UnloadSound(snd_thrust)

	InitGame()

    for !rl.WindowShouldClose()    // Detect window close button or ESC key
	{
        UpdateGame()
		RenderFrame()
		DrawFrame()
	}
	
	rl.UnloadRenderTexture(render_target)
	rl.CloseAudioDevice()
	rl.CloseWindow()	// Close window and OpenGL context

	return
	
}

// Update game (one frame)
UpdateGame :: proc() {

	change_entity_direction :: proc(entity: ^Entity){
		
		velx, vely :c.int
		for {
			velx = rl.GetRandomValue(-ROB_BRUTE_SPEED, ROB_BRUTE_SPEED)
			vely = rl.GetRandomValue(-ROB_BRUTE_SPEED, ROB_BRUTE_SPEED)
			if velx == 0 && vely == 0 do continue
			break
		}

		entity.speed = { f32(velx), f32(vely) }
	}
	
	if !gameOver {

		if rl.IsKeyPressed(.P) do pause = !pause

		if (!pause)
		{ 

			// Player logic: weapon rotation
			// to get radian? math.sin(player.rotation*rl.DEG2RAD)*PLAYER_SPEED;
			if rl.IsKeyDown(.LEFT) do player.rotation -= 5
			if rl.IsKeyDown(.RIGHT) do player.rotation += 5
			
			// not strictly necessary
			if player.rotation > 360 do player.rotation = 0
			if player.rotation < 0 do player.rotation = 360

			// Player logic: velocity
            if rl.IsKeyDown(.W) do player.position.y -= 2*PLAYER_SPEED
            if rl.IsKeyDown(.S) do player.position.y += 2*PLAYER_SPEED
            if rl.IsKeyDown(.A) do player.position.x -= 2*PLAYER_SPEED
            if rl.IsKeyDown(.D) do player.position.x += 2*PLAYER_SPEED

			// Collision logic: player vs walls
            // walls are invisible, movement limiter. player must stay in the "game world"

            if player.position.x + PLAYER_WIDTH > f32(screenWidth) do player.position.x = f32(screenWidth) - PLAYER_WIDTH
			if player.position.x < 0 do player.position.x = 0
            if player.position.y + PLAYER_HEIGHT > f32(screenHeight) do player.position.y = f32(screenHeight) - PLAYER_HEIGHT
            if player.position.y < 0 do player.position.y = 0

			// Player shot logic
			if rl.IsKeyPressed(.SPACE)
			{
                for i:= 0; i < SHOTS_MAX; i+=1
				{
                    if !shot[i].active
					{
                        rl.PlaySound(snd_lazer1)
						shot[i].position = (rl.Vector2){ player.position.x + math.sin(player.rotation*rl.DEG2RAD)*(PLAYER_HEIGHT), player.position.y - math.cos(player.rotation*rl.DEG2RAD)*(PLAYER_HEIGHT) }
						shot[i].active = true
						shot[i].speed.x = 1.5*math.sin(player.rotation*rl.DEG2RAD)*SHOTS_SPEED
						shot[i].speed.y = 1.5*math.cos(player.rotation*rl.DEG2RAD)*SHOTS_SPEED
						shot[i].rotation = player.rotation
						break
					}
				}
			}
			
			// shot life timer
			for i:= 0; i < SHOTS_MAX; i+=1 {
				if shot[i].active do shot[i].life_span+=1
			}
				
				
			// Shot logic
			for i:= 0; i < SHOTS_MAX; i+=1 {
				if shot[i].active {
					
					// Movement
					shot[i].position.x += shot[i].speed.x
					shot[i].position.y -= shot[i].speed.y

					// Collision logic: shot vs walls
					if shot[i].position.x > f32(screenWidth) + shot[i].radius {
						shot[i].active = false
						shot[i].life_span = 0
					}
					else if shot[i].position.x < 0 - shot[i].radius {
						shot[i].active = false
						shot[i].life_span = 0
					}
					if shot[i].position.y > f32(screenHeight) + shot[i].radius {
						shot[i].active = false
						shot[i].life_span = 0
					}
					else if shot[i].position.y < 0 - shot[i].radius {
						shot[i].active = false
						shot[i].life_span = 0
					}

					// Life of shot
					if shot[i].life_span >= SHOTS_LIFE_SPAN {
						shot[i].position = (rl.Vector2){0, 0}
						shot[i].speed = (rl.Vector2){0, 0}
						shot[i].life_span = 0
						shot[i].active = false
					}
				}
			}

			// Collision logic: player vs robots
			player.collider = (rl.Vector3){ player.position.x + PLAYER_WIDTH/2, player.position.y + PLAYER_HEIGHT/2, PLAYER_WIDTH/2 }

			for a := 0; a < active_entities; a += 1 {
				if rl.CheckCollisionPointRec( { player.collider.x, player.collider.y }, { entities[a].position.x, entities[a].position.y, ROB_BRUTE_WIDTH, ROB_BRUTE_HEIGHT}) && entities[a].active do gameOver = true
			}

			if gameOver do rl.PlaySound(snd_explosion1)

			for i := 0; i < active_entities; i += 1 {
				
				// move entities
				if entities[i].active {
					entities[i].position.x += entities[i].speed.x
					entities[i].position.y += entities[i].speed.y
				}

				// check entity collision with game boundaries
				// just bounce for now, we want these to be chancing the player down .. note some entities can escape with this code.
				// but it's a tempt thing.
				if entities[i].position.x + ROB_BRUTE_WIDTH > f32(screenWidth) do change_entity_direction(&entities[i])
				if entities[i].position.x < 0 do change_entity_direction(&entities[i])
				if entities[i].position.y + ROB_BRUTE_HEIGHT > f32(screenHeight) do change_entity_direction(&entities[i])
				if entities[i].position.y < 0 do change_entity_direction(&entities[i])
				
			}

			// Collision logic: player-shots vs robots
			for i := 0; i < SHOTS_MAX; i += 1 {
				if shot[i].active {
					for a := 0; a < active_entities; a += 1 {
						//if entities[a].active && rl.CheckCollisionCircles(shot[i].position, shot[i].radius, entities[a].position, entities[a].radius)
						if entities[a].active && rl.CheckCollisionCircleRec(shot[i].position, shot[i].radius, { entities[a].position.x, entities[a].position.y, ROB_BRUTE_WIDTH, ROB_BRUTE_HEIGHT} ) {
							rl.PlaySound(snd_explosion1)
							score += 10
							shot[i].active = false
							shot[i].life_span = 0
							entities[a].active = false
							destroyed_entities +=1
						}
					}
				}
			}
		 }
		
		if destroyed_entities == active_entities {
			level += 1
			if level == MAX_LEVEL { victory = true }
			else {
                InitGame()
			}
		}

	} else {
		if rl.IsKeyPressed(.ENTER)
		{
			InitGame()
			gameOver = false
			score = 0
		}
	}
}

InitGame :: proc() {
	
	posx, posy	:c.int
	velx, vely	:c.int

	victory = false
	pause = false
	
			
	// Initialization player
    player.position = (rl.Vector2){ f32(screenWidth/2), f32(screenHeight/2) - PLAYER_HEIGHT/2}
	player.rotation = 0
	player.collider = (rl.Vector3){player.position.x + PLAYER_WIDTH/2, player.position.y + PLAYER_HEIGHT/2, 0}
    player.color = rl.MAROON

    destroyed_entities = 0
	active_entities = STARTING_ENTITIES
	
	// Initialization shot
	for i := 0; i < SHOTS_MAX; i+=1
	{
		shot[i].position = (rl.Vector2){0, 0}
		shot[i].speed = (rl.Vector2){0, 0}
		shot[i].radius = 4
		shot[i].active = false
		shot[i].life_span = 0
		shot[i].color = rl.YELLOW
	}

	for i := 0; i < STARTING_ENTITIES; i += 1 {
		
		// spawn entities, should be at least 150px away from player (who starts in center of screen)
		for {
			posx = rl.GetRandomValue(0, screenWidth)
			if posx > screenWidth/2 - 150 && posx < screenWidth/2 + 150 {
				posx = rl.GetRandomValue(0, screenWidth)
			} else do break
		}
		for {
			posy = rl.GetRandomValue(0, screenHeight)
			if posy > screenHeight/2 - 150 && posy < screenHeight/2 + 150 {
				posy = rl.GetRandomValue(0, screenHeight)
			} else do break
		}

		entities[i].position = { f32(posx), f32(posy) }
		
		// temp, add randomize speed for now
		for {
			velx = rl.GetRandomValue(-ROB_BRUTE_SPEED, ROB_BRUTE_SPEED)
			vely = rl.GetRandomValue(-ROB_BRUTE_SPEED, ROB_BRUTE_SPEED)
			if velx == 0 && vely == 0 {
				velx = rl.GetRandomValue(-ROB_BRUTE_SPEED, ROB_BRUTE_SPEED)
				vely = rl.GetRandomValue(-ROB_BRUTE_SPEED, ROB_BRUTE_SPEED)
			} else do break
		}

		entities[i].speed = { f32(velx), f32(vely) }
		entities[i].radius = 40 // temp
		entities[i].collider = (rl.Rectangle){ f32(posx), f32(posy), ROB_BRUTE_WIDTH, ROB_BRUTE_HEIGHT }
		entities[i].active = true
		entities[i].color = rl.BLUE
	}

    draw_level_entry()

}
