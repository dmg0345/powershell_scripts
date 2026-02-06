PowerShell Scripts
==================

A highly opinionated `PowerShell Core` based framework for building Docker images with `Docker Bake`, composing
services with `Docker Compose`, and developing inside `Dev Containers` using `Visual Studio Code`.

- `Prerequisites <#Prerequisites>`_
    - `Git CLI <#Git CLI>`_
    - `Docker CLI <#Docker CLI>`_
    - `WSL <#WSL>`_
    - `VS Code <#VS Code>`_
- `Usage <#Usage>`_
- `License <#License>`_

Prerequisites
-------------

This section describes the prerequisites that must exist on the host to use the framework.

Git CLI
~~~~~~~

`Git Command Line Interface <https://git-scm.com>`_ can be installed from the `Git Official Website <https://git-scm.com/install/>`_. No GUI client is required.

Verify that `git` is installed:

.. code-block:: powershell

  PS > git --version

Docker CLI
~~~~~~~~~~

`Docker Command Line Interface <https://www.docker.com/products/cli/>`_ is required to build images and run containers. Specific details of the installation and integration are environment specific and beyond the scope of this document. Two different straightforward alternatives are introduced below.

- `Rancher Desktop <https://rancherdesktop.io/>`_
    - Drop-in replacement for Docker Desktop with a `friendly license <https://github.com/rancher-sandbox/rancher-desktop/blob/main/LICENSE>`_.
    - Ensure `dockerd` backend is used.
    - Kubernetes is not required.
- `Docker Desktop <https://www.docker.com/products/docker-desktop/>`_
    - The official Docker product with a more `restrictive license <https://docs.docker.com/subscription/desktop-license/>`_.

Both of the alternatives also provide a GUI along with the CLI utilities.

Verify that `docker`:

.. code-block:: powershell

  PS > docker version
  PS > docker compose version

Windows Subsystem for Linux (WSL)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This section is only applicable for Windows hosts.

`Windows Subsystem for Linux <https://learn.microsoft.com/en-us/windows/wsl/>`_ is necessary on Windows hosts for `Docker`. Its installation and provisioning is usually handled by the `Docker CLI` installer, however install and uninstall scripts based on `Microsoft WSL Installation Guide <https://learn.microsoft.com/en-gb/windows/wsl/install>`_ are provided for convenience.

WSL Installation with default Ubuntu 24.04:

.. code-block:: powershell

  # Install WSL default Ubuntu-24.04 distribution and provision a username.
  wsl --install "Ubuntu-24.04" --name "default-ubuntu";
  # Ensure the default distribution is set.
  wsl --set-default "default-ubuntu";

Uninstall WSL:

.. code-block:: powershell

  # Terminate and unregister all distributions.
  # WARNING: This deletes all the files in the WSL distros.
  $distroNames = & wsl --list --all --quiet | % { $_.Replace("`0", ""); } | ? { -not [string]::IsNullOrWhiteSpace($_); };
  $distroNames | % { wsl --terminate $_; wsl --unregister $_; };
  # Uninstall WSL.
  wsl --uninstall;

VS Code
~~~~~~~

`Visual Studio Code <https://learn.microsoft.com/en-us/windows/wsl/>`_ can be downloaded from the `Visual Studio Code Official Website <https://code.visualstudio.com/download>`_. Additionally, the following extensions are required:

- `Dev Containers Extension <https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers>`_
    - Ensure `VS Code Dev Container CLI <https://containers.dev/supporting#dev-containers-cli>`_ is also installed.

The recommended `User Settings <https://code.visualstudio.com/docs/configure/settings#_user-settingsjson-location>`_ keys-value pairs are described below:

.. code-block::

  {
    // Disable Dev Container extension magic explicitly for reproducibility, for details refer to:
    //   - Dev Container extension panel in VS Code, features -> settings.
    "dev.containers.cacheVolume": false,
    "dev.containers.copyGitConfig": false,
    "dev.containers.defaultExtensions": [],
    "dev.containers.defaultFeatures": [],
    "dev.containers.dockerCredentialHelper": false,
    "dev.containers.forwardWSLServices": false,
    "dev.containers.gitCredentialHelperConfigLocation": "none",
    "dev.containers.githubCLILoginWithToken": false,
    "dev.containers.mountWaylandSocket": false,
    "dev.containers.optimisticallyLaunchDocker": false,
    "remote.defaultExtensionsIfInstalledLocally": [],

    // Disable telemetry explicitly, for details refer to:
    //   - https://code.visualstudio.com/docs/configure/telemetry#_disable-telemetry-reporting
    "telemetry.telemetryLevel": "off",

    // Disable auto-updates and recommendations on Code and extensions for reproducibility, for details refer to:
    //   - https://code.visualstudio.com/docs/supporting/faq#_how-do-i-opt-out-of-vs-code-autoupdates
    "update.mode": "none",
    "extensions.autoUpdate": false,
    "extensions.autoCheckUpdates": false,
    "extensions.ignoreRecommendations": true,
    "workbench.remoteIndicator.showExtensionRecommendations": false,

    // Open blank workspace on startup, do not attempt to restore previous workspaces.
    "workbench.startupEditor": "none",
    "window.restoreWindows": "none"
  }

If encountering issues, delete the existing installation of `Visual Studio Code` and perform a
`clean uninstall <https://code.visualstudio.com/docs/setup/uninstall#_clean-uninstall>`_.
This process will remove all extensions and user settings. Afterwards, install Visual Studio Code from scratch.

Verify that `code` and `devcontainer` are installed:

.. code-block:: powershell

  PS > code --version
  PS > devcontainer --version

Note that framework delegates image building to `Docker Bake` and service orchestration to `Docker Compose`.
In terms of `Dev Containers`, Visual Studio Code simply attaches to an existing provisioned service.
This decoupling allows integrating other IDEs if desired, without changing the build or orchestration workflow.

Usage
-----

TODO

License
-------

TODO
