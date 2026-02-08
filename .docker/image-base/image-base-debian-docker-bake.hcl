# Image base with Debian Docker Bake file, for details refer to:
#   - https://docs.docker.com/build/bake/reference/

## Functions ###########################################################################################################

## Variables ###########################################################################################################
variable "IMAGE_BASE_DEBIAN_13_USV_VERSION" {
    type = string
    description = "Version tag of 'image-base-debian-13-usv' image, e.g. '1.0.0'."
    default = "1.0.0"
}

variable "IMAGE_BASE_DEBIAN_12_USV_VERSION" {
    type = string
    description = "Version tag of 'image-base-debian-12-usv' image, e.g. '1.0.0'."
    default = "1.0.0"
}

variable "IMAGE_BASE_DEBIAN_13_SVR_VERSION" {
    type = string
    description = "Version tag of 'image-base-debian-13-svr' image, e.g. '1.0.0'."
    default = "1.0.0"
}

variable "IMAGE_BASE_DEBIAN_12_SVR_VERSION" {
    type = string
    description = "Version tag of 'image-base-debian-12-svr' image, e.g. '1.0.0'."
    default = "1.0.0"
}

variable "IMAGE_BASE_DEBIAN_13_BASE_IMAGE" {
    type = string
    description = "Debian 13 base image for 'image-base-debian-13-*' images, e.g. 'docker.io/debian:13.3'."
    default = "docker.io/debian:13.3"
}

variable "IMAGE_BASE_DEBIAN_12_BASE_IMAGE" {
    type = string
    description = "Debian 12 base image for 'image-base-debian-12-*' images, e.g. 'docker.io/debian:12.13'."
    default = "docker.io/debian:12.13"
}

variable "IMAGE_BASE_DEBIAN_13_SVR_S6_OVERLAY_VERSION" {
    type = string
    description = "s6-overlay version for 'image-base-debian-13-svr' image, e.g. '3.2.1.0'."
    default = "3.2.2.0"
}

variable "IMAGE_BASE_DEBIAN_12_SVR_S6_OVERLAY_VERSION" {
    type = string
    description = "s6-overlay version for 'image-base-debian-12-svr' image, e.g. '3.2.1.0'."
    default = "3.2.2.0"
}

## Targets #############################################################################################################
target "image-base-debian-13-usv" {
    inherits = ["target-base"]
    dockerfile = "./.devcontainer/200-image-base/image-base-debian.Dockerfile"
    description = "Image base with Debian 13 and no supervisor for ephemeral / one-shot workflows."
    target = "debian-13-usv-image"
    args = {
        BASE_IMAGE = "${IMAGE_BASE_DEBIAN_13_BASE_IMAGE}"
        BASE_USV_STAGE = "debian-13-usv-stage"
    }
    tags = [
        "${BAKE_IMAGE_REGISTRY}/image-base-debian-13-usv:${IMAGE_BASE_DEBIAN_13_USV_VERSION}",
        "${BAKE_IMAGE_REGISTRY}/image-base-debian-13-usv:latest"
    ]
}

target "image-base-debian-12-usv" {
    inherits = ["target-base"]
    dockerfile = "./.devcontainer/200-image-base/image-base-debian.Dockerfile"
    description = "Image base with Debian 12 and no supervisor for ephemeral / one-shot workflows."
    target = "debian-12-usv-image"
    args = {
        BASE_IMAGE = "${IMAGE_BASE_DEBIAN_12_BASE_IMAGE}"
        BASE_USV_STAGE = "debian-12-usv-stage"
    }
    tags = [
        "${BAKE_IMAGE_REGISTRY}/image-base-debian-12-usv:${IMAGE_BASE_DEBIAN_12_USV_VERSION}",
        "${BAKE_IMAGE_REGISTRY}/image-base-debian-12-usv:latest"
    ]
}

target "image-base-debian-13-svr" {
    inherits = ["image-base-debian-13-usv"]
    description = "Image base with Debian 13 and s6-overlay supervisor for service workflows."
    target = "debian-13-svr-image"
    args = {
        BASE_SVR_STAGE = "debian-13-usv-image"
        S6_OVERLAY_VERSION = "${IMAGE_BASE_DEBIAN_13_SVR_S6_OVERLAY_VERSION}"
    }
    tags = [
        "${BAKE_IMAGE_REGISTRY}/image-base-debian-13-svr:${IMAGE_BASE_DEBIAN_13_SVR_VERSION}",
        "${BAKE_IMAGE_REGISTRY}/image-base-debian-13-svr:latest"
    ]
}

target "image-base-debian-12-svr" {
    inherits = ["image-base-debian-12-usv"]
    description = "Image base with Debian 12 and s6-overlay supervisor for service workflows."
    target = "debian-12-svr-image"
    args = {
        BASE_SVR_STAGE = "debian-12-usv-image"
        S6_OVERLAY_VERSION = "${IMAGE_BASE_DEBIAN_12_SVR_S6_OVERLAY_VERSION}"
    }
    tags = [
        "${BAKE_IMAGE_REGISTRY}/image-base-debian-12-svr:${IMAGE_BASE_DEBIAN_12_SVR_VERSION}",
        "${BAKE_IMAGE_REGISTRY}/image-base-debian-12-svr:latest"
    ]
}

## Groups ##############################################################################################################
