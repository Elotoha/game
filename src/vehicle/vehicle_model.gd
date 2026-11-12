class_name VehicleModel
extends RefCounted
## Pure fixed-step simulation, independent from rendering, input and track geometry.
var config := VehicleConfig.new()
var position := Vector2.ZERO
var velocity := Vector2.ZERO
var heading := 0.0
var yaw_rate := 0.0
var steering := 0.0
var front_slip := 0.0
var rear_slip := 0.0
var front_usage := 0.0
var rear_usage := 0.0
var acceleration := 0.0

func reset(at: Vector2, angle: float) -> void:
	position = at
	heading = angle
	velocity = Vector2.ZERO
	yaw_rate = 0.0
	steering = 0.0
	acceleration = 0.0
	front_slip = 0.0
	rear_slip = 0.0
	front_usage = 0.0
	rear_usage = 0.0

func tire_force(slip: float, stiffness: float, load: float, grip: float) -> float:
	var limit := maxf(1.0, load * grip)
	# Smooth peak then sliding plateau, so a saturated axle can lose stability.
	var ratio := stiffness * slip / limit
	return -limit * tanh(ratio) * (1.0 - 0.20 * smoothstep(1.0, 4.0, absf(ratio)))

func step(dt: float, command: Vector3, handbrake: bool, surface_grip: float) -> void:
	var c := config
	var forward := Vector2.from_angle(heading)
	var right := -forward.orthogonal()
	var longitudinal := velocity.dot(forward)
	var lateral := velocity.dot(right)
	var speed := velocity.length()
	var wheelbase := c.front_length + c.rear_length
	var steer_limit := c.max_steer / (1.0 + absf(longitudinal) / 36.0)
	steering = move_toward(steering, command.x * steer_limit, c.steering_rate * dt)
	var front_load := clampf(c.mass * 9.81 * c.rear_length / wheelbase - c.mass * acceleration * c.cg_height / wheelbase, c.mass * 9.81 * 0.15, c.mass * 9.81 * 0.85)
	var rear_load := c.mass * 9.81 - front_load
	var grip := c.friction * surface_grip
	var drive := command.y * c.engine_force / (1.0 + maxf(longitudinal, 0.0) / 28.0)
	var brake := minf(command.z * c.brake_force, absf(longitudinal) * c.mass / dt)
	var resistance := 0.44 * longitudinal * absf(longitudinal) + longitudinal * 18.0
	var front_x := -signf(longitudinal) * brake * 0.66
	var rear_x := drive - signf(longitudinal) * brake * 0.34
	if handbrake:
		rear_x -= signf(longitudinal) * minf(4400.0, absf(longitudinal) * c.mass / dt)
	front_x = clampf(front_x, -front_load * grip, front_load * grip)
	rear_x = clampf(rear_x, -rear_load * grip, rear_load * grip)
	front_slip = atan2(lateral + c.front_length * yaw_rate, maxf(absf(longitudinal), 2.0)) - steering * smoothstep(0.0, 3.0, longitudinal)
	rear_slip = atan2(lateral - c.rear_length * yaw_rate, maxf(absf(longitudinal), 2.0))
	var front_capacity := sqrt(maxf(0.0, 1.0 - pow(front_x / maxf(front_load * grip, 1.0), 2)))
	var rear_capacity := sqrt(maxf(0.0, 1.0 - pow(rear_x / maxf(rear_load * grip, 1.0), 2)))
	var front_y := tire_force(front_slip, c.front_stiffness, front_load, grip) * front_capacity
	var rear_y := tire_force(rear_slip, c.rear_stiffness, rear_load, grip) * rear_capacity * (0.23 if handbrake else 1.0)
	front_usage = absf(front_slip) * c.front_stiffness / maxf(front_load * grip, 1.0)
	rear_usage = absf(rear_slip) * c.rear_stiffness / maxf(rear_load * grip, 1.0)
	var force_x := front_x * cos(steering) - front_y * sin(steering) + rear_x - resistance
	var force_y := front_y * cos(steering) + front_x * sin(steering) + rear_y
	acceleration = force_x / c.mass
	velocity += (forward * force_x + right * force_y) / c.mass * dt
	yaw_rate += ((front_y * cos(steering) + front_x * sin(steering)) * c.front_length - rear_y * c.rear_length - yaw_rate * 180.0) / c.inertia * dt
	if speed < 0.5 and command.y == 0.0:
		velocity *= exp(-8.0 * dt)
		yaw_rate *= exp(-8.0 * dt)
	heading = wrapf(heading + yaw_rate * dt, -PI, PI)
	position += velocity * dt
