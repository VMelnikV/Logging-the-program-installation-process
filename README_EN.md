**Description and Features**
--------------------

## **Purpose**

The script is designed to **monitor file system changes** when installing applications in various ways on Linux (Debian/Ubuntu/Mint and derivatives).\
It helps to track:

which files were **created**,

which files were **modified**,

and, for text files, shows **diff before/after**.

The script is useful for auditing, debugging, or controlling the installation of new packages.

* * * * *

## **Main Features**

**Support for various installation methods**

`--deb package.deb` --- install a local `.deb` file via `dpkg`.

`--apt package-name` --- install a package from the repositories via `apt-get`.

`--flatpak flatpak-app-id` --- install a package via Flatpak.

`--snap snap-name` --- install package via Snap.

`--gui` --- monitor installation via graphical installer (Software Manager).

**Monitor file system changes**

The script uses `fatrace` to log all file system events (`created`, `written`, `deleted`).

The change log is saved to a temporary file `$LOG`.

**Diff for text files**

For text files, specify `file`.

If a file is changed (`W`), the script saves its before/after state and generates a `diff`.

**Report changes**

After the installation is complete, the script generates a report in `$FILES_REPORT`, which includes:

a list of new and changed files,

diff for text files,

the full `fatrace` log,

additional information about the user and monitoring.

**Environment Check**

The script checks whether the required tools are installed:

`fatrace` --- for monitoring changes,

`file` --- for identifying text files,

`diff` --- for building a diff of changes.

If any tool is missing, a message is displayed that it needs to be installed.

**Root rights check**

The script requires running as root (`sudo`) to monitor system files.

**User support**

The script determines the actual user (`$SUDO_USER`) and can run GUI programs on its behalf.

* * * * *

## **Benefits**

Support for **all major installation methods**: deb, apt, flatpak, snap, GUI.

Full audit of file system changes.

Simple and convenient report with new and changed files.

Does not interfere with the system, only reads file events via `fatrace`.

## **Usage example**

### Installing a local deb package

sudo ./deb-watch-unified.sh --deb gimp.deb

### Installing a package via apt

sudo ./deb-watch-unified.sh --apt gimp

### Installing Flatpak

sudo ./deb-watch-unified.sh --flatpak org.gimp.GIMP

### Installing Snap

sudo ./deb-watch-unified.sh --snap vlc

### Monitoring the installation via GUI

sudo ./deb-watch-unified.sh --gui

**Use the script at your own risk, the script is not guaranteed to work**
