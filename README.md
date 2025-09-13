# debian-scripts

A collection of local scripts to manage Debian environments

This is a collection of scripts to help manage Debian 12 and 13 environments
outside of the traditional tools or infrastructure used elsewhere.  Whether a
local bare metal install, a new spin up of a virtual machine, or a development
instance for project use - these scripts will add useful tools and configure
Debian's base installation.

* **`setup.sh`**: This script will setup basic packages with some interactive
prompting as well as install common tools useful for server-side development.

* **`update.sh`**: This script will update the Debian environment with the
latest packages and security updates using the `apt` package manager as well as
display information on system health, active services, and storage details.

* **`secure.sh`**: This script will assist with securing the local Debian
environment, especially for instances with non-local connections.

* **`prompt.sh`**: This script will setup useful shell prompt enhancements for
a local user.

* **`upgrade.sh`**: This script will assist upgrading between the major Debian
versions 12 "Bookworm" to 13 "Trixie".

## License

[Apache License 2.0](https://choosealicense.com/licenses/apache-2.0/)
