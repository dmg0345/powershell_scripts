# Image Tools Docker Bake file, for details refer to:
#   - https://docs.docker.com/build/bake/reference/

## Functions ###########################################################################################################

## Variables ###########################################################################################################
variable "IMAGE_TOOLS_VERSION" {
    type = string
    description = "Version tag of 'image-tools' image, e.g. '1.0.0'."
    default = "1.0.0"
}

## Targets #############################################################################################################
target "image-tools" {
    inherits = ["target-base"]
    dockerfile = "./.docker/image-tools/image-tools.Dockerfile"
    description = "Image with generic tools and scripts to provision dependencies in other images."
    contexts = {
        host-image-tools-dir = "./.docker/image-tools"
    }
    tags = [
        "${BAKE_IMAGE_REGISTRY}/image-tools:${IMAGE_TOOLS_VERSION}",
        "${BAKE_IMAGE_REGISTRY}/image-tools:latest"
    ]
}

## Groups ##############################################################################################################
