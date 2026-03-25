module snake;
import raylib55;
import std::math;

const int TARGET_FPS        = 60;
const int SQUARE_SIZE       = 32;
const float MOVE_SPEED      = 0.15f;
const float MAX_FRAME_DELTA = 0.1f;
const int SCORE_PER_FRUIT   = 100;
const int SCREEN_WIDTH      = 800;
const int SCREEN_HEIGHT     = 450;
const int SCREEN_COLS       = SCREEN_WIDTH / SQUARE_SIZE;
const int SCREEN_ROWS       = SCREEN_HEIGHT / SQUARE_SIZE;
const int SNAKE_LENGTH      = SCREEN_COLS * SCREEN_ROWS;
const int INPUT_QUEUE_SIZE  = 2;

GameState g;

struct GameState @align(64)
{
	Vec2[SNAKE_LENGTH] snake_pos;
	Direction[INPUT_QUEUE_SIZE] input_queue;
	Direction current_dir;
	Vec2 fruit_pos;
	Vec2 screen_remainder;
	int head_idx;
	int tail_count;
	int queue_count;
	float move_timer;
	bool fruit_active;
	bool game_over;
	bool paused;
	bool[SCREEN_COLS * SCREEN_ROWS] grid_occupied;
	rl::RLRenderTexture2D target;
}

enum Direction : (Vec2 dir)
{
	UP    { { 0, -SQUARE_SIZE } },
	DOWN  { { 0, SQUARE_SIZE } },
	LEFT  { { -SQUARE_SIZE, 0 } },
	RIGHT { { SQUARE_SIZE, 0 } }
}

fn bool Direction.is_opposite(self, Direction other)
{
	return (self.dir + other.dir) == (Vec2)0.0f;
}

fn void init_game()
{
	g.head_idx = 0;
	g.tail_count = 1;
	g.current_dir = RIGHT;
	g.queue_count = 0;
	g.game_over = false;
	g.paused = false;
	g.move_timer = 0;
	g.grid_occupied = { };

	g.screen_remainder = { SCREEN_WIDTH % SQUARE_SIZE, SCREEN_HEIGHT % SQUARE_SIZE };

	Vec2 center = {
		(SCREEN_WIDTH / (2 * SQUARE_SIZE)) * SQUARE_SIZE,
		(SCREEN_HEIGHT / (2 * SQUARE_SIZE)) * SQUARE_SIZE
	};
	g.snake_pos[0] = g.screen_remainder / 2.0f + center;
	g.fruit_active = false;

	int row = (int)(center.y / SQUARE_SIZE);
	int col = (int)(center.x / SQUARE_SIZE);
	g.grid_occupied[row * SCREEN_COLS + col] = true;
	spawn_fruit();
}

fn void spawn_fruit()
{
	int[SCREEN_COLS * SCREEN_ROWS] empty_cells;
	int count = 0;
	for (int i = 0; i < SCREEN_COLS * SCREEN_ROWS; i++)
	{
		if (!g.grid_occupied[i]) empty_cells[count++] = i;
	}

	if (count > 0)
	{
		int rand_grid_idx = empty_cells[rl::get_random_value(0, count - 1)];
		int row = rand_grid_idx / SCREEN_COLS;
		int col = rand_grid_idx % SCREEN_COLS;
		g.fruit_pos = g.screen_remainder / 2.0f + (Vec2) { col, row } * SQUARE_SIZE;
		g.fruit_active = true;
	}
}

fn void queue_move(Direction d)
{
	Direction last = g.queue_count > 0 ? g.input_queue[g.queue_count - 1] : g.current_dir;
	if (d == last || d.is_opposite(last)) return;
	if (g.queue_count < g.input_queue.len) g.input_queue[g.queue_count++] = d;
}

fn void update_game()
{
	if (g.game_over)
	{
		if (rl::get_key_pressed() != 0) init_game();
		return;
	}

	if (!rl::is_window_focused()) g.paused = true;
	if (rl::is_key_pressed(P)) g.paused = !g.paused;
	if (rl::is_key_pressed(F)) rl::toggle_fullscreen();
	if (g.paused) return;

	if (rl::is_key_pressed(UP)    || rl::is_key_pressed(W)) queue_move(UP);
	if (rl::is_key_pressed(DOWN)  || rl::is_key_pressed(S)) queue_move(DOWN);
	if (rl::is_key_pressed(LEFT)  || rl::is_key_pressed(A)) queue_move(LEFT);
	if (rl::is_key_pressed(RIGHT) || rl::is_key_pressed(D)) queue_move(RIGHT);

	g.move_timer += math::min(rl::get_frame_time(), MAX_FRAME_DELTA);

	if (g.move_timer >= MOVE_SPEED)
	{
		g.move_timer -= MOVE_SPEED;

		if (g.queue_count > 0)
		{
			g.current_dir = g.input_queue[0];
			g.input_queue[0] = g.input_queue[1];
			g.queue_count--;
		}

		Vec2 old_head = g.snake_pos[g.head_idx];
		Vec2 new_head = old_head + g.current_dir.dir;

		Vec2 min_bounds = g.screen_remainder / 2.0f;
		Vec2 max_bounds = { SCREEN_WIDTH, SCREEN_HEIGHT } - min_bounds;
		if (new_head.comp_lt(min_bounds).or() || new_head.comp_ge(max_bounds).or())
		{
			g.game_over = true;
			return;
		}

		int new_row = (int)((new_head.y - min_bounds.y) / SQUARE_SIZE);
		int new_col = (int)((new_head.x - min_bounds.x) / SQUARE_SIZE);
		int bit_idx = new_row * SCREEN_COLS + new_col;

		int next_idx = (g.head_idx + 1) % SNAKE_LENGTH;

		bool is_fruit = (new_head == g.fruit_pos);

		if (!is_fruit)
		{
			int tail_ring_idx = (g.head_idx - (g.tail_count - 1) + SNAKE_LENGTH) % SNAKE_LENGTH;
			Vec2 tail_pos = g.snake_pos[tail_ring_idx];
			int t_row = (int)((tail_pos.y - min_bounds.y) / SQUARE_SIZE);
			int t_col = (int)((tail_pos.x - min_bounds.x) / SQUARE_SIZE);
			g.grid_occupied[t_row * SCREEN_COLS + t_col] = false;
		}

		if (g.grid_occupied[bit_idx])
		{
			g.game_over = true;
			return;
		}

		if (is_fruit)
		{
			g.tail_count = math::min(g.tail_count + 1, SNAKE_LENGTH);
			g.fruit_active = false;
		}


		g.head_idx = next_idx;
		g.snake_pos[g.head_idx] = new_head;
		g.grid_occupied[bit_idx] = true;
	}

	if (!g.fruit_active) spawn_fruit();
}

fn void draw_game()
{
	rl::clear_background({ 15, 15, 20, 255 });

	if (g.game_over)
	{
		rl::draw_text(
			"GAME OVER",
			SCREEN_WIDTH / 2 - rl::measure_text("GAME OVER", 40) / 2,
			SCREEN_HEIGHT / 2 - 60,
			40,
			rl::MAROON
		);
		rl::draw_text(
			"PRESS ANY KEY TO RESTART",
			SCREEN_WIDTH / 2 - rl::measure_text("PRESS ANY KEY TO RESTART", 20) / 2,
			SCREEN_HEIGHT / 2 + 10,
			20,
			rl::RAYWHITE
		);
		return;
	}

	for (int i = 0; i <= SCREEN_COLS; i++)
	{
		float x = g.screen_remainder.x / 2.0f + (float)i * SQUARE_SIZE;
		rl::draw_line_v(
			{ x, g.screen_remainder.y / 2.0f },
			{ x, SCREEN_HEIGHT - g.screen_remainder.y / 2.0f },
			{ 40, 40, 50, 255 }
		);
	}
	for (int i = 0; i <= SCREEN_ROWS; i++)
	{
		float y = g.screen_remainder.y / 2.0f + (float)i * SQUARE_SIZE;
		rl::draw_line_v(
			{ g.screen_remainder.x / 2.0f, y },
			{ SCREEN_WIDTH - g.screen_remainder.x / 2.0f, y },
			{ 40, 40, 50, 255 }
		);
	}

	if (g.fruit_active) rl::draw_rectangle_v(g.fruit_pos, { SQUARE_SIZE, SQUARE_SIZE }, rl::PINK);

	for (int i = 0; i < g.tail_count; i++)
	{
		int idx = (g.head_idx - i + SNAKE_LENGTH) % SNAKE_LENGTH;
		Vec2 pos = g.snake_pos[idx];
		float t = (float)i / g.tail_count;
		RLColor color = rl::LIME;
		if (i == 0)
		{
			color = rl::SKYBLUE;
		}
		else
		{
			float[<3>] start_c = { 0.0f, 255.0f, 255.0f };
			float[<3>] end_c = { 0.0f, 80.0f, 150.0f };
			color.rgb = (char[<3>])start_c.lerp(end_c, t);
		}

		rl::draw_rectangle_v(pos, { SQUARE_SIZE, SQUARE_SIZE }, color);
		rl::draw_rectangle_lines_ex({ pos.x, pos.y, SQUARE_SIZE, SQUARE_SIZE }, 1.0, { 0, 0, 0, 150 });
	}

	if (g.paused) rl::draw_text("PAUSED", SCREEN_WIDTH / 2 - 50, SCREEN_HEIGHT / 2 - 15, 30, rl::GRAY);
	rl::draw_text(rl::text_format("SCORE: %d", (g.tail_count - 1) * SCORE_PER_FRUIT), 20, 20, 20, rl::GOLD);
}

fn void update_draw_frame()
{
	update_game();

	rl::begin_texture_mode(g.target);
	draw_game();
	rl::end_texture_mode();

	rl::begin_drawing();
	defer rl::end_drawing();
	rl::clear_background(rl::BLACK);

	float screen_w = rl::get_render_width();
	float screen_h = rl::get_render_height();
	float scale = math::min(screen_w / SCREEN_WIDTH, screen_h / SCREEN_HEIGHT);

	rl::draw_texture_pro(
		g.target.texture,
		{ 0.0f, 0.0f, SCREEN_WIDTH, -SCREEN_HEIGHT },
		{
			(screen_w - SCREEN_WIDTH * scale) / 2.0f,
			(screen_h - SCREEN_HEIGHT * scale) / 2.0f,
			SCREEN_WIDTH * scale,
			SCREEN_HEIGHT * scale
		},
		{ 0.0f, 0.0f },
		0.0f,
		rl::WHITE
	);
}

fn void main()
{
	$if !env::WASM:
		rl::set_config_flags(WINDOW_RESIZABLE);
	$endif
	rl::init_window(SCREEN_WIDTH, SCREEN_HEIGHT, "C3 Snake");
	init_game();

	g.target = rl::load_render_texture(SCREEN_WIDTH, SCREEN_HEIGHT);
	g.target.texture.set_filter(POINT);

	$if env::WASM:
		emscripten_set_main_loop(&update_draw_frame, 0, 1);
	$else
		rl::set_target_fps(TARGET_FPS);
		while (!rl::window_should_close())
		{
			update_draw_frame();
		}
		rl::unload_render_texture(g.target);
		rl::close_window();
	$endif
}

alias Em_callback_func = fn void();
extern fn void emscripten_set_main_loop(Em_callback_func func, int fps, int simulate_infinite_loop);
