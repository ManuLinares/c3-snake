module snake::audio;
import raylib6;
import std::math::nolibc;

RLSound eat_sound;
RLAudioStream music_stream;
ulong music_timer = 0;
float music_phase = 0.0f;
float bass_phase = 0.0f;
float music_volume = 0.9f;

int last_checked_bar = -1;
bool glitch_enabled_for_bar = false;

fn void audio_callback(void* data, uint frames)
{
	float* output_buffer = (float*)data;
	const float PI = (float)math::PI;
	for (uint i = 0; i < frames; i++)
	{
		const float STEP_TIME   = 0.15f;
		const float BAR_TIME    = STEP_TIME * 16.0f;
		const float SAMPLE_RATE = 44100.0f;

		float global_time = (float)music_timer / SAMPLE_RATE;

		int current_step = (int)(global_time / STEP_TIME);
		int current_bar_index = (int)(global_time / BAR_TIME);
		int bar_in_phrase = current_bar_index % 4;
		int current_phrase_index = current_bar_index / 4;
		int current_step_in_bar = current_step % 16;
		//float current_step_time = nolibc::fmodf(global_time, STEP_TIME);
		float current_step_time = global_time % STEP_TIME;

		if (current_bar_index != last_checked_bar)
		{
			last_checked_bar = current_bar_index;
			glitch_enabled_for_bar = (current_phrase_index >= 2) && (((current_bar_index * 17 + 11) % 10) < 6);
		}

		float[16] melody_notes = {
			110.0f, 0.0f, 110.0f, 0.0f,
			130.81f, 0.0f, 110.0f, 146.83f,
			110.0f, 0.0f, 110.0f, 0.0f,
			130.81f, 123.47f, 110.0f, 0.0f
			};

		float mixed_sample = 0.0f;
		float note_envelope = 1.0f - (current_step_time / STEP_TIME);
		const float ATTACK_DURATION = 0.002f;
		float note_attack_envelope = math::min(1.0f, current_step_time / ATTACK_DURATION);

		float current_frequency = melody_notes[current_step % 16];

		if (current_frequency > 0.0f)
		{
			music_phase += (current_frequency * 2.0f * PI) / SAMPLE_RATE;
			if (music_phase > 2.0f * PI) music_phase -= 2.0f * PI;

			bass_phase += (current_frequency * 0.5f * 2.0f * PI) / SAMPLE_RATE;
			if (bass_phase > 2.0f * PI) bass_phase -= 2.0f * PI;
		}

		if (current_phrase_index >= 1)
		{
			bool is_intense_phase = (current_phrase_index >= 3);

			if (current_step_in_bar == 0 || current_step_in_bar == 8)
			{
				float kick_envelope = math::max(0.0f, 1.0f - current_step_time / 0.12f);
				float kick_frequency = 150.0f * kick_envelope + (is_intense_phase ? 20.0f : 30.0f);
				float kick_phase = current_step_time * kick_frequency * 2.0f * PI;
				mixed_sample += math::sin(kick_phase) * kick_envelope * (is_intense_phase ? 1.4f : 0.8f);
			}

			if (current_step_in_bar == 4 || current_step_in_bar == 12)
			{
				float snare_envelope = math::max(0.0f, 1.0f - current_step_time / 0.1f);
				float snare_noise = (float)(i % 1237) / 1237.0f - 0.5f;
				mixed_sample += snare_noise * snare_envelope * 0.5f;
			}

			if (is_intense_phase && current_step_in_bar == 11)
			{
				float ghost_snare_envelope = math::max(0.0f, 0.4f - current_step_time / 0.08f);
				float ghost_noise = (float)(i % 71) / 71.0f - 0.5f;
				mixed_sample += ghost_noise * ghost_snare_envelope * 0.3f;
			}

			bool should_play_hat = (current_step_in_bar % 4 == 2)
				|| (is_intense_phase && (current_step_in_bar % 2 != 0));
			if (should_play_hat)
			{
				float hat_envelope = math::max(0.0f, 1.0f - current_step_time / 0.04f);
				float hat_noise = (float)(i % 71) / 71.0f - 0.5f;
				mixed_sample += hat_noise * hat_envelope * 0.25f;
			}
		}

		bool is_industrial_bar = (bar_in_phrase == 1 || bar_in_phrase == 3);
		if (is_industrial_bar && glitch_enabled_for_bar)
		{
			float modulation_value = math::sin(global_time * 12.0f);
			float crunch_wave = math::sin(music_phase * (0.6f + 0.15f * modulation_value));
			mixed_sample += crunch_wave * note_envelope * 0.6f;

			float glitch_noise = (float)(i % 500) / 500.0f * 0.05f;
			mixed_sample += glitch_noise * note_envelope;
		}
		else
		{
			if (current_frequency > 0.0f)
			{
				mixed_sample += math::sin(music_phase) * note_envelope * note_attack_envelope * 0.5f;

				if (current_phrase_index >= 1)
				{
					mixed_sample += math::sin(bass_phase) * note_envelope * note_attack_envelope * 0.7f;
				}
			}
		}

		float overdrive_boost = mixed_sample * 2.5f;
		float absolute_value = overdrive_boost > 0 ? overdrive_boost : -overdrive_boost;
		float saturated_sample = overdrive_boost / (1.0f + absolute_value);

		output_buffer[i] = saturated_sample * music_volume;

		music_timer++;
	}
}

fn void init()
{
	rl::init_audio_device();
	music_phase = 0.0f;
	bass_phase = 0.0f;
	music_timer = 0;

	const uint DEFAULT_SAMPLE_RATE = 44100;
	const uint EAT_FRAME_COUNT     = DEFAULT_SAMPLE_RATE / 15;

	float* sound_samples = (float*)rl::mem_alloc(EAT_FRAME_COUNT * float::size);

	const float PI = (float)math::PI;
	for (uint i = 0; i < EAT_FRAME_COUNT; i++)
	{
		float time_value = (float)i / DEFAULT_SAMPLE_RATE;
		float sweep_frequency = 880.0f - ((float)i / EAT_FRAME_COUNT) * 440.0f;
		sound_samples[i] = math::sin(time_value * sweep_frequency * 2.0f * PI) * (1.0f - (float)i / EAT_FRAME_COUNT)
			* 0.2f;
	}

	RLWave eat_wave = {
		.frameCount = EAT_FRAME_COUNT,
		.sample_rate = DEFAULT_SAMPLE_RATE,
		.sample_size = 32,
		.channels = 1,
		.data = sound_samples
	};

	eat_sound = rl::load_sound_from_wave(eat_wave);
	rl::mem_free(sound_samples);

	music_stream = rl::load_audio_stream(DEFAULT_SAMPLE_RATE, 32, 1);
	music_stream.set_callback(&audio_callback);
	rl::play_audio_stream(music_stream);
}

fn void play_eat()
{
	if (rl::is_audio_device_ready()) rl::play_sound(eat_sound);
}

fn void deinit()
{
	rl::unload_sound(eat_sound);
	rl::unload_audio_stream(music_stream);
	rl::close_audio_device();
}
