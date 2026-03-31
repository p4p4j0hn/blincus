write_defaults() {


	# default container engine
	config_set "default_cloud-init" "debian"
	config_set "default_container_image" "images:ubuntu/noble/cloud"
	config_set "default_container_profiles" "container,idmap"
	config_set "default_scripts" "ubuntu"
	config_set "default_home-mounts" "none"
	config_set "default_vm_image" "images:ubuntu/noble/cloud"
	config_set "default_vm_profiles" "idmap"

	# ubuntu defaults
	config_set "ubuntu.image" "images:ubuntu/noble/cloud"
	config_set "ubuntu.scripts" "ubuntu"
	config_set "ubuntu.description" "Ubuntu Noble + cloud-init"

	config_set "ubuntuw.image" "images:ubuntu/noble/cloud"
	config_set "ubuntuw.scripts" "ubuntu"
	config_set "ubuntuw.description" "Ubuntu Noble cloud-init + wayland"
	config_set "ubuntuw.profiles" "container,idmap,waylanddevs"
	config_set "ubuntuw.cloud-init" "ubuntuwayland"

	config_set "ubuntux.image" "images:ubuntu/noble/cloud"
	config_set "ubuntux.scripts" "ubuntu"
	config_set "ubuntux.description" "Ubuntu Noble cloud-init + x"
	config_set "ubuntux.profiles" "container,idmap,xdevs"
	config_set "ubuntux.cloud-init" "debianx"
	
	# debian defaults
	config_set "debian.image" "images:debian/trixie/cloud"
	config_set "debian.scripts" "debian"
	config_set "debian.description" "Debian Trixie + cloud-init"
	
	config_set "debianw.image" "images:debian/trixie/cloud"
	config_set "debianw.scripts" "debian"
	config_set "debianw.description" "Debian Trixie cloud-init + wayland"
	config_set "debianw.profiles" "container,idmap,waylanddevs"
	config_set "debianw.cloud-init" "debianwayland"

	config_set "debianx.image" "images:debian/trixie/cloud"
	config_set "debianx.scripts" "debian"
	config_set "debianx.description" "Debian Trixie cloud-init + x"
	config_set "debianx.profiles" "container,idmap,xdevs"
	config_set "debianx.cloud-init" "debianx"

	#fedora defaults
	config_set "fedora.image" "images:fedora/43/cloud"
	config_set "fedora.scripts" "fedora"
	config_set "fedora.description" "Fedora 43 + cloud-init"
	config_set "fedora.cloud-init" "fedora"

	config_set "fedoraw.image" "images:fedora/43/cloud"
	config_set "fedoraw.scripts" "fedora"
	config_set "fedoraw.description" "Fedora 43 cloud-init + wayland"
	config_set "fedoraw.profiles" "container,idmap,waylanddevs"
	config_set "fedoraw.cloud-init" "fedorawayland"

	config_set "fedorax.image" "images:fedora/43/cloud"
	config_set "fedorax.scripts" "fedora"
	config_set "fedorax.description" "Fedora 43 cloud-init + x"
	config_set "fedorax.profiles" "container,idmap,xdevs"
	config_set "fedorax.cloud-init" "fedorax"
	
	# nix defaults

	config_set "nix.image" "images:ubuntu/noble/cloud"
	config_set "nix.description" "Ubuntu cloud-init + Nix"
	config_set "nix.scripts" "nix"
	# todo: flag or JIT set this
	# xhost +
}
