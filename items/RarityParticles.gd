extends Node2D

@export var rarity: String = "common"

func _ready():
	setup_particles()

func setup_particles():
	var particles = GPUParticles2D.new()
	particles.one_shot = false
	particles.explosiveness = 0.0

	match rarity:
		"common":
			particles.emitting = false
			add_child(particles)
			return

		"rare":
			particles.amount = 24
			particles.lifetime = 2.0
			particles.emitting = true
			var mat = ParticleProcessMaterial.new()
			mat.color = Palette.RARITY_RARE
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			mat.emission_sphere_radius = 60.0
			mat.initial_velocity_min = 20.0
			mat.initial_velocity_max = 50.0
			mat.scale_min = 2.0
			mat.scale_max = 5.0
			particles.process_material = mat

		"epic":
			particles.amount = 40
			particles.lifetime = 1.5
			particles.emitting = true
			var mat = ParticleProcessMaterial.new()
			mat.color = Palette.RARITY_EPIC
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			mat.emission_ring_radius = 80.0
			mat.emission_ring_inner_radius = 60.0
			mat.initial_velocity_min = 60.0
			mat.initial_velocity_max = 100.0
			mat.scale_min = 3.0
			mat.scale_max = 7.0
			particles.process_material = mat

		"legendary":
			particles.amount = 60
			particles.lifetime = 3.0
			particles.emitting = true
			var mat = ParticleProcessMaterial.new()
			mat.color_ramp = _make_legendary_gradient()
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			mat.emission_sphere_radius = 100.0
			mat.initial_velocity_min = 40.0
			mat.initial_velocity_max = 120.0
			mat.scale_min = 4.0
			mat.scale_max = 10.0
			particles.process_material = mat

	add_child(particles)

func _make_legendary_gradient() -> Gradient:
	var g = Gradient.new()
	g.colors = PackedColorArray([Palette.RARITY_LEG_A, Palette.RARITY_LEG_B, Palette.RARITY_LEG_A])
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	return g
