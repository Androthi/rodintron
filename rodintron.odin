package rodintron

// robotron type game

import "core:fmt"
import "core:math"
import rl "vendor:raylib"
import "core:c"
import "core:math/rand"

GOD_MODE			:: false

PLAYER_HEIGHT       :: 45.0
PLAYER_WIDTH	    :: 20.0
PLAYER_SPEED		:: 3.0

SHOTS_MAX			:: 4
SHOTS_SPEED			:: 5

ROB_BRUTE_WIDTH     :: 30
ROB_BRUTE_HEIGHT    :: 50
ROB_BRUTE_SPEED		:: 2

ROB_PATROL_WIDTH	:: 40
ROB_PATROL_HEIGHT	:: 40
ROB_PATROL_SPEED	:: 1

ROB_SENTRY_WIDTH	:: 30
ROB_SENTRY_HEIGHT	:: 30
ROB_SENTRY_SPEED	:: 0

screenWidth				:i32: 1200
screenHeight			:i32: 800
render_screen_width     :i32 = screenWidth
render_screen_height    :i32 = screenHeight

MAX_WAVE			:: 50		//assuming +1 entity/wave
STARTING_ENTITIES	:: 5
NUM_CIVILIANS		:: 5
MAX_ENTITIES        :: MAX_WAVE + STARTING_ENTITIES + NUM_CIVILIANS
entities			:[MAX_ENTITIES]Entity

wave				:int = 1

active_entities		:int
destroyed_entities	:int
destroyed_civs		:int
score				:int

render_target       :rl.RenderTexture
gameOver			:bool
pause				:bool
victory				:bool

player				:Player
shot				:[500]Projectile

snd_lazer1			:rl.Sound
snd_lazer2			:rl.Sound
snd_explosion1		:rl.Sound
snd_thrust			:rl.Sound
snd_wilhelm			:rl.Sound
sprite_texture		:rl.Texture

frame_update_time	:f32 = 0.2
frame_current_time	:f32

Player :: struct {
	position	:rl.Vector2,
	rotation	:f32,
	collider	:rl.Rectangle,
	source		:rl.Rectangle,
	frame		:int,
	facing		:Facing_Direction,
	color		:rl.Color,
}

Projectile :: struct {
	type		:Entity_Type,	// the entity type that fired this projectile
	position	:rl.Vector2,
	speed		:rl.Vector2,
	radius		:f32,
	rotation	:f32,
	color		:rl.Color,
	active		:bool,
}

Entity :: struct {
    type		:Entity_Type,
	position    :rl.Vector2, 	//? we can get rid of this and just use the collider.x and collider.y positions
    speed       :rl.Vector2,
	direction	:rl.Vector2,		// use this for movement directions for robots that don't follow player format [+/-1, +/-1]
	shape		:rl.Vector2,
	source		:rl.Rectangle,
	frame		:int,
	facing		:Facing_Direction,
	collider	:rl.Rectangle,	// temporary collider + drawing shape
    color       :rl.Color,		// temp for shape. will be replaced by sprite colors.
	hits		:u8,
    active      :bool,
}

Entity_Type :: enum {
	CIVILIAN, BRUTE, PATROL, SENTRY,
}
Entity_Speeds		:[]f32 = { PLAYER_SPEED, ROB_BRUTE_SPEED, ROB_PATROL_SPEED, ROB_SENTRY_SPEED }

Facing_Direction :: enum {
	UP, DOWN, LEFT, RIGHT
}
directions			:[4][2]f32 = { { 0.0, -1.0 }, { 0.0, 1.0 }, { -1.0, 0.0 }, { 1.0, 0.0 } }

GameState			::enum { TITLE, GAMEPLAY, VICTORY, DEFEAT }
current_state		:GameState


main :: proc() {

	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(screenWidth, screenHeight, "Rodintron")
	rl.SetWindowMinSize(screenWidth, screenHeight)
	render_target = rl.LoadRenderTexture(render_screen_width, render_screen_height)
	rl.SetTextureFilter(render_target.texture, .BILINEAR)
	rl.SetTargetFPS(60)

	// load resources
	rl.InitAudioDevice()
	snd_lazer1 = rl.LoadSound("resources/lazer1.wav")
	defer rl.UnloadSound(snd_lazer1)
	snd_lazer2 = rl.LoadSound("resources/lazer2.wav")
	defer rl.UnloadSound(snd_lazer2)
	snd_explosion1 = rl.LoadSound("resources/explosion1.wav")
	defer rl.UnloadSound(snd_explosion1)
	snd_thrust = rl.LoadSound("resources/thrust.wav")
	defer rl.UnloadSound(snd_thrust)
	snd_wilhelm = rl.LoadSound("resources/wilhelm.wav")
	defer rl.UnloadSound(snd_wilhelm)

	sprite_texture = rl.LoadTexture("resources/sprites.png")
	defer rl.UnloadTexture(sprite_texture)



	InitWave()
    for !rl.WindowShouldClose()
	{
        switch current_state {
			case .TITLE:
				if rl.IsKeyPressed(.ENTER) || rl.IsMouseButtonPressed(.LEFT) {
					current_state = .GAMEPLAY
					wave = 1
					score = 0
					InitWave()
					gameOver = false
				}

			case .GAMEPLAY:
				UpdateGame()

			case .VICTORY, .DEFEAT:
				if rl.IsKeyPressed(.ENTER) || rl.IsMouseButtonPressed(.LEFT) {
					current_state = .GAMEPLAY
					wave = 1
					score = 0
					InitWave()
					gameOver = false
				}

		}
		RenderFrame()
		DrawFrame()
	}
	
	rl.UnloadRenderTexture(render_target)
	rl.CloseAudioDevice()
	rl.CloseWindow()
	return
}

// random value to get a 'event' activation
random_tick :: proc() -> bool {
	if rand.float32_range(0.0, 1_000_000) < 10_000 do return true
	return false
}

// Update game (one frame)
UpdateGame :: proc() {

	
	if !gameOver {

		if rl.IsKeyPressed(.P) do pause = !pause

		if (!pause)
		{ 
			// Player logic: weapon rotation
			if rl.IsKeyDown(.LEFT) do player.rotation -= 5
			if rl.IsKeyDown(.RIGHT) do player.rotation += 5			
			
			//? not strictly necessary
			if player.rotation > 360 do player.rotation = 0
			if player.rotation < 0 do player.rotation = 360
			
			// Player logic: movement direction
            if rl.IsKeyDown(.W) {
				player.position.y -= 2*PLAYER_SPEED
				player.facing = .UP
			}
            if rl.IsKeyDown(.S) {
				player.position.y += 2*PLAYER_SPEED
				player.facing = .DOWN
			}
            if rl.IsKeyDown(.A) {
				player.position.x -= 2*PLAYER_SPEED
				player.facing = .LEFT
			}
            if rl.IsKeyDown(.D) {
				player.position.x += 2*PLAYER_SPEED
				player.facing = .RIGHT
			}

			// update player animaion
			frame_current_time += rl.GetFrameTime()
			if frame_current_time > frame_update_time {
				frame_current_time = 0
				if player.frame == 0 do player.frame = 1
				else do player.frame = 0
			}
			player.source.width = PLAYER_WIDTH
			switch player.facing {
				case .DOWN:
					player.source.x = 2*PLAYER_WIDTH
					if player.frame > 0 do player.source.width = -player.source.width

				case .UP:
					player.source.x = 3*PLAYER_WIDTH
					if player.frame > 0 do player.source.width = -player.source.width							

				case .LEFT:
					if player.frame == 0 do player.source.x = 0
					else do player.source.x = 1*PLAYER_WIDTH
					
				case .RIGHT:
					if player.frame == 0 do player.source.x = 0
					else do player.source.x = 1*PLAYER_WIDTH
					player.source.width = -PLAYER_WIDTH

			}

			// Collision logic: player vs walls
            // walls are invisible, movement limiter. player must stay in the "game world"
			
            if player.position.x + PLAYER_WIDTH > f32(screenWidth) do player.position.x = f32(screenWidth) - PLAYER_WIDTH
			if player.position.x < 0 do player.position.x = 0
            if player.position.y + PLAYER_HEIGHT > f32(screenHeight) do player.position.y = f32(screenHeight) - PLAYER_HEIGHT
            if player.position.y < 0 do player.position.y = 0

			// get mouse position and adjust rotation of 'weapon'
			mpos := rl.GetMousePosition() / rl.Vector2 { cast(f32)rl.GetScreenWidth(), cast(f32)rl.GetScreenHeight() }
			hlen := (rl.Vector2) { mpos.x - player.position.x / cast(f32)screenWidth, player.position.y / cast(f32)screenHeight - mpos.y}
            rot := math.atan2_f32 (hlen.x, hlen.y)
            player.rotation = rot*rl.RAD2DEG
			
			// Player shot logic
			if rl.IsKeyPressed(.SPACE) || rl.IsMouseButtonPressed(.LEFT) {
                for i:= 0; i < SHOTS_MAX; i+=1 {
                    if !shot[i].active {
                        rl.PlaySound(snd_lazer1)
						shot[i].position = { player.position.x + math.sin(player.rotation*rl.DEG2RAD)*(PLAYER_HEIGHT), player.position.y - math.cos(player.rotation*rl.DEG2RAD)*(PLAYER_HEIGHT) }
						shot[i].active = true
						shot[i].speed.x = 2.5*math.sin(player.rotation*rl.DEG2RAD)*SHOTS_SPEED
						shot[i].speed.y = 2.5*math.cos(player.rotation*rl.DEG2RAD)*SHOTS_SPEED
						shot[i].rotation = player.rotation
						break
					}
				}
			}

			// see if robots will shoot
			for i := 0; i < active_entities; i += 1 {
				if entities[i].active {
					if entities[i].type == .SENTRY {
						if random_tick() {
							// this robot will shoot
							for j := SHOTS_MAX; j < len(shot)-SHOTS_MAX; j += 1 {
								if !shot[j].active {
									shot[j].color = rl.ORANGE
									shot[j].position = {entities[i].position.x + entities[i].shape.x/2, entities[i].position.y + entities[i].shape.y/2}
									shot[j].active = true
									shot[j].type = entities[i].type
									hlen := (rl.Vector2) { player.position.x - entities[i].position.x, entities[i].position.y - player.position.y}
									rot := math.atan2_f32 (hlen.x, hlen.y)
									shot[j].rotation = rot*rl.RAD2DEG
									shot[j].speed.x = 2.5*math.sin(shot[j].rotation*rl.DEG2RAD)*SHOTS_SPEED
									shot[j].speed.y = 2.5*math.cos(shot[j].rotation*rl.DEG2RAD)*SHOTS_SPEED
								}
							}
						}
					}
				}
			}


			// Shot logic
			for i:= 0; i < len(shot); i+=1 {
				if shot[i].active {
					
					// Movement
					shot[i].position.x += shot[i].speed.x
					shot[i].position.y -= shot[i].speed.y
					
					// Collision logic: shot vs walls
					if shot[i].position.x > f32(screenWidth) + shot[i].radius {
						shot[i].active = false
					}
					else if shot[i].position.x < 0 - shot[i].radius {
						shot[i].active = false
					}
					if shot[i].position.y > f32(screenHeight) + shot[i].radius {
						shot[i].active = false
					}
					else if shot[i].position.y < 0 - shot[i].radius {
						shot[i].active = false
					}
				}
			}

			// Collision logic: player vs robots
			player.collider = { player.position.x, player.position.y, PLAYER_WIDTH, PLAYER_HEIGHT }

			for a := 0; a < active_entities + NUM_CIVILIANS; a += 1 {
				if rl.CheckCollisionRecs( player.collider, entities[a].collider ) && entities[a].active {
					if entities[a].type == .CIVILIAN {
						rl.PlaySound(snd_thrust)
						score += 1000
						entities[a].active = false
						destroyed_civs += 1
					} else {
						when !GOD_MODE {
							gameOver = true
							current_state = .DEFEAT
						}
					}
				}
			}

			if gameOver do rl.PlaySound(snd_wilhelm)

			// move entities
			for i := 0; i < active_entities + NUM_CIVILIANS; i += 1 {
				
				if entities[i].active {
					if entities[i].type == .BRUTE {
						if entities[i].position.x < player.position.x do entities[i].position.x += entities[i].speed.x
						else do entities[i].position.x -= entities[i].speed.x
						if entities[i].position.y < player.position.y do entities[i].position.y += entities[i].speed.y
						else do entities[i].position.y -= entities[i].speed.y
					} else if entities[i].type == .PATROL || entities[i].type == .CIVILIAN {
						patrol_move(&entities[i])
						entities[i].position.x += entities[i].direction.x*entities[i].speed.x
						entities[i].position.y += entities[i].direction.y*entities[i].speed.y
					}
					entities[i].collider = { entities[i].position.x, entities[i].position.y, entities[i].shape.x, entities[i].shape.y }
				}
			}

			// Collision logic: shots vs robots & civs
			// if the shot originated from a CIV (the player), it can only harm robots
			// if the shot originated from a robot, it can only harm CIVS (player and civs)
			for i := 0; i < len(shot); i += 1 {
				if shot[i].active {
					for a := 0; a < active_entities + NUM_CIVILIANS; a += 1 {
						if entities[a].active && rl.CheckCollisionCircleRec(shot[i].position, shot[i].radius, entities[a].collider ) {
							
							if shot[i].type == .CIVILIAN && entities[a].type != .CIVILIAN {
								entities[a].hits -= 1
								if entities[a].hits == 0 {
									rl.PlaySound(snd_explosion1)
									score += (int(entities[a].type)+1) * 10
									entities[a].active = false
									destroyed_entities +=1
									shot[i].active = false
								}
							} else if shot[i].type > .CIVILIAN && entities[a].type == .CIVILIAN {
								rl.PlaySound(snd_wilhelm)
								destroyed_civs += 1
								score -= 1000
								entities[a].active = false
								shot[i].active = false
							}
						} else {
							
							if shot[i].type > .CIVILIAN && rl.CheckCollisionCircleRec(shot[i].position, shot[i].radius, player.collider ) {
								
								when !GOD_MODE {
									rl.PlaySound(snd_wilhelm)
									gameOver = true
									current_state = .DEFEAT
								}
							}

						}
					}
				}
			}
		 }
		
		if destroyed_entities == active_entities && destroyed_civs == NUM_CIVILIANS {
			wave += 1
			if wave == MAX_WAVE { victory = true }
			else {
                InitWave()
			}
		}

	} 
}

patrol_move :: proc( entity: ^Entity) {
	
	// entity must be active if this proc is called
	
	if entity.position.x <= entity.shape.x do entity.direction = directions[Facing_Direction.RIGHT]
	if entity.position.x >= f32(screenWidth) - entity.shape.x do entity.direction = directions[Facing_Direction.LEFT]
	if entity.position.y <= 0 do entity.direction = directions[Facing_Direction.DOWN]
	if entity.position.y >= f32(screenHeight) - entity.shape.y{
		entity.direction = directions[Facing_Direction.UP]
		entity.position.y = f32(screenHeight) - entity.shape.y
	}

	if random_tick() {
		dir := rand.choice_enum(Facing_Direction)
		entity.direction = directions[dir]
	}
}

InitWave :: proc() {
	
	posx, posy	:c.int
	velx, vely	:c.int

	victory = false
	pause = false
			
	// Initialization player
    player.position = (rl.Vector2){ f32(screenWidth/2), f32(screenHeight/2) - PLAYER_HEIGHT/2}
	player.rotation = 0
	player.collider = { player.position.x, player.position.y, PLAYER_WIDTH, PLAYER_HEIGHT } //(rl.Vector3){player.position.x + PLAYER_WIDTH/2, player.position.y + PLAYER_HEIGHT/2, 0}
    player.frame = 0
	player.facing = .DOWN
	
	// animation frame info that never changes
	player.source.height = PLAYER_HEIGHT


    destroyed_entities = 0
	destroyed_civs = 0
	active_entities = wave + STARTING_ENTITIES -1  // +1 entity/level
	
	// Initialization shot
	for i := 0; i < len(shot); i+=1 {
		shot[i].position = (rl.Vector2){0, 0}
		shot[i].speed = (rl.Vector2){0, 0}
		shot[i].radius = 4
		shot[i].active = false
		shot[i].color = rl.YELLOW
	}

	for i := 0; i < active_entities; i += 1 {
		
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

		entity_type := rand.choice_enum(Entity_Type)
		if entity_type == .CIVILIAN do entity_type += Entity_Type(1)
		entities[i].type = entity_type

		velocity := Entity_Speeds[entity_type]
		entities[i].speed = { velocity, velocity  }

		entity_shape :[2]f32
		#partial switch entity_type {
			case .BRUTE:
				entity_shape.x = ROB_BRUTE_WIDTH
				entity_shape.y = ROB_BRUTE_HEIGHT
				entities[i].hits = 1
				entities[i].color = rl.BLUE
			case .PATROL:
				entity_shape.x = ROB_PATROL_WIDTH
				entity_shape.y = ROB_PATROL_HEIGHT
				entities[i].hits = 2
				entities[i].color = rl.ORANGE
				dir := rand.choice_enum( Facing_Direction)
				entities[i].direction = directions[dir]
			case .SENTRY:
				entity_shape.x = ROB_SENTRY_WIDTH
				entity_shape.y = ROB_SENTRY_HEIGHT
				entities[i].hits = 5
				entities[i].color = rl.PURPLE
		}
		entities[i].shape = entity_shape
		entities[i].collider = (rl.Rectangle){ f32(posx), f32(posy), entity_shape.x, entity_shape.y }
		entities[i].active = true

		// fix position to make sure none of them are off the screen
		if entities[i].position.x <= entities[i].shape.x do entities[i].position.x = 0
		if entities[i].position.x >= f32(screenWidth) + entities[i].shape.x do entities[i].position.x = f32(screenWidth)-entities[i].shape.x
		if entities[i].position.y <= 0 - entities[i].shape.y do entities[i].position.y = 0
		if entities[i].position.y >= f32(screenHeight) - entities[i].shape.y do entities[i].position.y = f32(screenHeight)-entities[i].shape.y
	
	}

	civs := 0
	for {
		posx := rl.GetRandomValue(0, screenWidth - (PLAYER_WIDTH*2))
		posy := rl.GetRandomValue(0, screenHeight - (PLAYER_HEIGHT*2))
		entities[active_entities+civs].position = { f32(posx), f32(posy) }
		entities[active_entities+civs].type = .CIVILIAN
		entities[active_entities+civs].hits = 20
		entities[active_entities+civs].active = true
		entities[active_entities+civs].shape = {PLAYER_WIDTH, PLAYER_HEIGHT}
		entities[active_entities+civs].speed = PLAYER_SPEED - 0.5
		entities[active_entities+civs].color = rl.GREEN
		dir := rand.choice_enum(Facing_Direction)
		entities[active_entities+civs].direction = directions[dir]
		civs +=1
		if civs >= NUM_CIVILIANS do break
	}

	if current_state == .GAMEPLAY do draw_wave_entry()

}
