# Commons Docker Bake file, for details refer to:
#   - https://docs.docker.com/build/bake/reference/
# Do not edit manually — changes will be overwritten.

## Functions ###########################################################################################################

## Variables ###########################################################################################################
variable "BAKE_PROJECT_NAME" {
    type = string
    description = "Name of the project, must be provided, e.g. 'my-project'."
}

# Force a local registry to be provided by default so all image tags can be fully qualified, for details refer to:
#   - https://github.com/moby/moby/issues/33069
variable BAKE_IMAGE_LOCAL_REGISTRY {
    type = string
    description = "Path to the image registry for images that stay local, must be provided, e.g. 'localhost/localuser'."
}

variable "BAKE_IMAGE_REGISTRY" {
    type = string
    description = "Path to the remote image registry where to push images, e.g. 'docker.io/example-username'."
    default = "${BAKE_IMAGE_LOCAL_REGISTRY}"
}

## Targets #############################################################################################################
# Base target for 'target' items.
target "target-base" {
    platforms = ["linux/amd64"] # Suitable for MacOS, Windows (WSL) and Linux Desktops.
    network = "default" # Use default network, allow access to Internet for packages.
    context = null # Disable default context, do not have any contexts by default.
    # Provide variables as ARG for Dockerfiles, to use them, redeclare ARG <name> in the Dockerfile.
    args = {
        BAKE_PROJECT_NAME = "${BAKE_PROJECT_NAME}"
        BAKE_IMAGE_LOCAL_REGISTRY = "${BAKE_IMAGE_LOCAL_REGISTRY}"
        BAKE_IMAGE_REGISTRY = "${BAKE_IMAGE_REGISTRY}"
    }
    # Provide '.docker' directory of the host as a named context for convenience, only used if referenced.
    contexts = {
        host-docker-dir = "./.docker"
    }
    call = "build" # Make build the default action.
    no-cache = false # Use the cache by default.
    pull = false # Do not attempt to pull referenced images first by default, attempt to build them first if possible.
}

## Groups ##############################################################################################################
