class_name SecurityManager
extends Node

## Dynamic encryption key management system
## Replaces hardcoded SECRET_KEY with device-based key generation

const KEY_CACHE_FILE: String = "user://security/.key_cache"
const MIN_KEY_LENGTH: int = 32
const MAX_KEY_LENGTH: int = 64

var _key_cache: String = ""


## Initialize and ensure encryption key exists
func _ready() -> void:
	_ensure_security_directory()
	_load_or_generate_key()


## Ensure the security directory exists
func _ensure_security_directory() -> void:
	var security_dir := "user://security"
	if not DirAccess.dir_exists_absolute(security_dir):
		var err := DirAccess.make_dir_absolute(security_dir)
		if err != OK:
			push_error("Failed to create security directory: ", err)


## Get or generate the encryption key
## This method generates a unique key based on the device ID
## Falls back to a derived key if device ID is unavailable
func get_encryption_key() -> String:
	if not _key_cache.is_empty():
		return _key_cache
	
	_load_or_generate_key()
	return _key_cache


## Load cached key or generate a new one
func _load_or_generate_key() -> void:
	# Try to load existing key from cache
	if FileAccess.file_exists(KEY_CACHE_FILE):
		var file := FileAccess.open(KEY_CACHE_FILE, FileAccess.READ)
		if file:
			_key_cache = file.get_as_text().strip_edges()
			file.close()
			
			if _is_valid_key(_key_cache):
				return
			else:
				push_warning("Cached key is invalid, regenerating...")
	
	# Generate new key
	_key_cache = _generate_device_based_key()
	_save_key_to_cache(_key_cache)


## Generate a device-based encryption key
## Uses OS.get_unique_id() as the primary source of entropy
func _generate_device_based_key() -> String:
	var device_id: String = OS.get_unique_id()
	
	if device_id.is_empty():
		push_warning("Device ID unavailable, using fallback key generation")
		device_id = _generate_fallback_id()
	
	# Create a stable hash from device ID
	var key_source: String = "%s_%d" % [device_id, 1]  # Version 1
	var hashed_key: String = key_source.sha256_text()
	
	# Ensure key is within acceptable length
	return hashed_key.substr(0, MAX_KEY_LENGTH)


## Generate a fallback ID when device ID is unavailable
## Uses system time as entropy source (less secure)
func _generate_fallback_id() -> String:
	var timestamp: int = int(Time.get_unix_time_from_system())
	var hostname: String = OS.get_environment("HOSTNAME")
	
	if hostname.is_empty():
		hostname = "unknown"
	
	return "%s_%d" % [hostname, timestamp]


## Validate key format and length
func _is_valid_key(key: String) -> bool:
	return key.length() >= MIN_KEY_LENGTH and key.length() <= MAX_KEY_LENGTH


## Save key to cache file
func _save_key_to_cache(key: String) -> void:
	var file := FileAccess.open(KEY_CACHE_FILE, FileAccess.WRITE)
	if file:
		file.store_string(key)
		file.close()
	else:
		push_error("Failed to cache encryption key")


## Clear cached key (for testing or re-initialization)
func clear_key_cache() -> void:
	_key_cache = ""
	if FileAccess.file_exists(KEY_CACHE_FILE):
		DirAccess.remove_absolute(KEY_CACHE_FILE)


## Rotate the encryption key (for future migrations)
## Note: This requires re-encrypting all existing saves
func rotate_key() -> String:
	clear_key_cache()
	_load_or_generate_key()
	push_warning("Encryption key rotated. Existing saves need re-encryption.")
	return _key_cache
