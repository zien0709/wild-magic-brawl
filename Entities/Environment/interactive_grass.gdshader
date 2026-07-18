shader_type canvas_item;

// 接收 Godot 全域變數
global uniform vec2 player_position;

// 可調整的參數
uniform float push_radius = 60.0; // 草被推開的範圍
uniform float push_strength = 20.0; // 被推開的力度
uniform float wind_speed = 2.0;

void vertex() {
	// 1. 基礎風吹擺動 (只讓草的頂端擺動，底部不動)
	vec2 world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	if (VERTEX.y < 0.0) {
		VERTEX.x += sin(TIME * wind_speed + world_pos.x) * 2.0;
	}
	
	// 2. 玩家踩踏推開計算
	float dist = distance(world_pos, player_position);
	
	if (dist < push_radius && VERTEX.y < 0.0) {
		// 計算推開的方向向量
		vec2 push_dir = normalize(world_pos - player_position);
		
		// 越靠近中心，推力越大 (1.0 代表中心，0.0 代表邊緣)
		float force = 1.0 - (dist / push_radius);
		
		VERTEX.x += push_dir.x * force * push_strength;
		VERTEX.y += push_dir.y * force * push_strength * 0.5; // 稍微往下壓
	}
}