extends Node

# Mod entry point. Follows the working Brotato example mod pattern:
# install script extensions from _init(), spawn the BotRunner autoload via
# ModLoaderMod helpers.

const LOG_NAME := "BlackTriangle:FullAutoBot"

const _BOT_RUNNER_SCRIPT := preload("res://mods-unpacked/BlackTriangle-FullAutoBot/bot/bot_runner.gd")


func _init():
	ModLoaderLog.info("Init", LOG_NAME)
	ModLoaderMod.install_script_extension(
		"res://mods-unpacked/BlackTriangle-FullAutoBot/extensions/ui/menus/run/difficulty_selection/difficulty_selection.gd"
	)
	ModLoaderMod.install_script_extension(
		"res://mods-unpacked/BlackTriangle-FullAutoBot/extensions/entities/units/movement_behaviors/player_movement_behavior.gd"
	)


func _ready():
	ModLoaderLog.info("Ready", LOG_NAME)
	# Spawn the bot driver as a long-lived child of this autoload — its
	# _physics_process drives movement / shop / level-up decisions.
	var runner = _BOT_RUNNER_SCRIPT.new()
	runner.name = "BotRunner"
	add_child(runner)
