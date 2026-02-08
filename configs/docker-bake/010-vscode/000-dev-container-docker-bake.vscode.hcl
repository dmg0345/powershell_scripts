# Visual Studio Code Dev Container Docker Bake file, for details refer to:
#   - https://docs.docker.com/build/bake/reference/
# Do not edit manually — changes will be overwritten.

## Functions ###########################################################################################################

## Variables ###########################################################################################################

## Targets #############################################################################################################
# Base target for Visual Studio Code development container.
target "dev-container-vscode-base" {
    inherits = ["target-base"]
    description = "Visual Studio Code Dev Container local image for '{BAKE_PROJECT_NAME}' project."
    tags = [
        "${BAKE_IMAGE_LOCAL_REGISTRY}/${BAKE_PROJECT_NAME}-dev-container-vscode:latest"
    ]
}

## Groups ##############################################################################################################
