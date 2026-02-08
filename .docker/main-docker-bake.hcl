# Main Docker Bake file, for details refer to:
#   - https://docs.docker.com/build/bake/reference/

## Functions ###########################################################################################################

## Variables ###########################################################################################################

## Targets #############################################################################################################
target "dev-container-vscode" {
    inherits = ["dev-container-vscode-base"]
    dockerfile = "./.docker/dev-container-vscode.Dockerfile"
}

## Groups ##############################################################################################################
group "dev-container" {
    targets = [
        "dev-container-vscode"
    ]
}

group "image-base" {
    targets = [
        "image-base-debian-13-usv",
        "image-base-debian-12-usv",
        "image-base-debian-13-svr",
        "image-base-debian-12-svr"
    ]
}

group "dev-container-base" {
    targets = [
        "dev-container-base-debian-13-cli",
        "dev-container-base-debian-12-cli",
        "dev-container-base-debian-13-gui",
        "dev-container-base-debian-12-gui"
    ]
}

group "other" {
    targets = [
        "image-tools"
    ]
}
