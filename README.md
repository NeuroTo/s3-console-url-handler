# S3 AWS Console protocol handler

This Linux helper opens `s3://bucket/path` URIs in the AWS S3 web console.
Firefox is supported directly through the Linux protocol handler. Chromium is
supported through an additional address-bar keyword extension. Installation is
per-user and does not require root access.

## Install

### From a cloned repository

```bash
git clone https://github.com/NeuroTo/s3-console-url-handler.git
cd s3-console-url-handler
chmod +x install.sh
./install.sh install
```
The default AWS region is `eu-west-1`. To select another region:

```bash
./install.sh install --region eu-central-1
```

### Without cloning

The installer downloads the required application and Chromium extension files
from this repository:

```bash
curl -fsSL https://raw.githubusercontent.com/NeuroTo/s3-console-url-handler/main/install.sh | bash -s -- install
```

To select another region:

```bash
curl -fsSL https://raw.githubusercontent.com/NeuroTo/s3-console-url-handler/main/install.sh | bash -s -- install --region eu-central-1
```

### Firefox

After installation, enter an URI directly:

```text
s3://my-bucket/images/test.png
```

Firefox may ask for confirmation the first time it opens the external
protocol. Select **S3 AWS Console** and optionally remember the choice.

### Chromium

Chromium requires one manual step because it does not allow scripts to install
unpacked extensions:

1. Open `chrome://extensions`.
2. Enable **Developer mode**.
3. Select **Load unpacked**.
4. Select `~/.local/share/s3-console/chromium-extension` (or the equivalent
   directory below `$XDG_DATA_HOME`).

Then use the `s3` keyword followed by a space:

```text
s3 s3://my-bucket/images/test.png
```

The installer creates:

- `~/.local/bin/s3-console`
- `${XDG_DATA_HOME:-~/.local/share}/applications/s3-console-handler.desktop`
- `${XDG_DATA_HOME:-~/.local/share}/s3-console/chromium-extension/`

## Uninstall

From the cloned repository:

```bash
./install.sh uninstall
```

Without cloning:

```bash
curl -fsSL https://raw.githubusercontent.com/NeuroTo/s3-console-url-handler/main/install.sh | bash -s -- uninstall
```

It removes the installed files and the corresponding per-user MIME
association. Remove the extension from `chrome://extensions` as well if
Chromium still lists it.
