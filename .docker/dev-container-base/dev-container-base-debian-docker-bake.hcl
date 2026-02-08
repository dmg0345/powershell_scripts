# Dev Container image base with Debian Docker Bake file, for details refer to:
#   - https://docs.docker.com/build/bake/reference/

## Functions ###########################################################################################################

## Variables ###########################################################################################################
variable "DEV_CONTAINER_BASE_DEBIAN_13_CLI_VERSION" {
    type = string
    description = "Version tag of 'dev-container-base-debian-13-cli' image, e.g. '1.0.0'."
    default = "1.0.0"
}

variable "DEV_CONTAINER_BASE_DEBIAN_12_CLI_VERSION" {
    type = string
    description = "Version tag of 'dev-container-base-debian-12-cli' image, e.g. '1.0.0'."
    default = "1.0.0"
}

variable "DEV_CONTAINER_BASE_DEBIAN_13_GUI_VERSION" {
    type = string
    description = "Version tag of 'dev-container-base-debian-13-gui' image, e.g. '1.0.0'."
    default = "1.0.0"
}

variable "DEV_CONTAINER_BASE_DEBIAN_12_GUI_VERSION" {
    type = string
    description = "Version tag of 'dev-container-base-debian-12-gui' image, e.g. '1.0.0'."
    default = "1.0.0"
}

variable "DEV_CONTAINER_BASE_DEBIAN_13_BASE_IMAGE" {
    type = string
    description = "Debian 13 SVR base image for 'dev-container-base-debian-13-*' images, e.g. 'image-base-debian-13-svr:1.0.0'."
    default = "${BAKE_IMAGE_REGISTRY}/image-base-debian-13-svr:1.0.0"
}

variable "DEV_CONTAINER_BASE_DEBIAN_12_BASE_IMAGE" {
    type = string
    description = "Debian 12 SVR base image for 'dev-container-base-debian-12-*' images, e.g. 'image-base-debian-12-svr:1.0.0'."
    default = "${BAKE_IMAGE_REGISTRY}/image-base-debian-12-svr:1.0.0"
}

# TODO: https://github.com/PowerShell/PowerShell/issues/25865, replace PWSH_VERSION with official 7.6.0 or 7.5.X with backport
variable "DEV_CONTAINER_BASE_DEBIAN_13_PWSH_VERSION" {
    type = string
    description = "PowerShell Core version for 'dev-container-base-debian-13-*' images, e.g. '7.5.4'."
    default = "7.6.0-preview.6"
}

variable "DEV_CONTAINER_BASE_DEBIAN_12_PWSH_VERSION" {
    type = string
    description = "PowerShell Core version for 'dev-container-base-debian-12-*' images, e.g. '7.5.4'."
    default = "7.5.4"
}

## Targets #############################################################################################################
target "dev-container-base-debian-13-cli" {
    inherits = ["target-base"]
    dockerfile = "./.docker/dev-container-base/dev-container-base-debian.Dockerfile"
    description = "Dev Container base image with Debian 13, PowerShell Core shell and other CLI utilities."
    target = "debian-13-cli-image"
    contexts = {
        host-dev-container-base-dir = "./.docker/dev-container-base"
    }
    args = {
        BASE_IMAGE = "${DEV_CONTAINER_BASE_DEBIAN_13_BASE_IMAGE}"
        BASE_CLI_STAGE = "debian-13-cli-stage"
        PWSH_VERSION = "${DEV_CONTAINER_BASE_DEBIAN_13_PWSH_VERSION}"
    }
    tags = [
        "${BAKE_IMAGE_REGISTRY}/dev-container-base-debian-13-cli:${DEV_CONTAINER_BASE_DEBIAN_13_CLI_VERSION}",
        "${BAKE_IMAGE_REGISTRY}/dev-container-base-debian-13-cli:latest"
    ]
}

target "dev-container-base-debian-12-cli" {
    inherits = ["target-base"]
    dockerfile = "./.docker/dev-container-base/dev-container-base-debian.Dockerfile"
    description = "Dev Container base image with Debian 12, PowerShell Core shell and other CLI utilities."
    target = "debian-12-cli-image"
    contexts = {
        host-dev-container-base-dir = "./.docker/dev-container-base"
    }
    args = {
        BASE_IMAGE = "${DEV_CONTAINER_BASE_DEBIAN_12_BASE_IMAGE}"
        BASE_CLI_STAGE = "debian-12-cli-stage"
        PWSH_VERSION = "${DEV_CONTAINER_BASE_DEBIAN_12_PWSH_VERSION}"
    }
    tags = [
        "${BAKE_IMAGE_REGISTRY}/dev-container-base-debian-12-cli:${DEV_CONTAINER_BASE_DEBIAN_12_CLI_VERSION}",
        "${BAKE_IMAGE_REGISTRY}/dev-container-base-debian-12-cli:latest"
    ]
}

target "dev-container-base-debian-13-gui" {
    inherits = ["dev-container-base-debian-13-cli"]
    description = "Dev Container base image with Debian 13, VNC desktop with window manager and other GUI utilities."
    target = "debian-13-gui-image"
    args = {
        BASE_GUI_STAGE = "debian-13-gui-stage"
    }
    tags = [
        "${BAKE_IMAGE_REGISTRY}/dev-container-base-debian-13-gui:${DEV_CONTAINER_BASE_DEBIAN_13_GUI_VERSION}",
        "${BAKE_IMAGE_REGISTRY}/dev-container-base-debian-13-gui:latest"
    ]
}

target "dev-container-base-debian-12-gui" {
    inherits = ["dev-container-base-debian-12-cli"]
    description = "Dev Container base image with Debian 12, VNC desktop with window manager and other GUI utilities."
    target = "debian-12-gui-image"
    args = {
        BASE_GUI_STAGE = "debian-12-gui-stage"
    }
    tags = [
        "${BAKE_IMAGE_REGISTRY}/dev-container-base-debian-12-gui:${DEV_CONTAINER_BASE_DEBIAN_12_GUI_VERSION}",
        "${BAKE_IMAGE_REGISTRY}/dev-container-base-debian-12-gui:latest"
    ]
}

## Groups ##############################################################################################################
