# S3 AWS Console protocol handler

This Linux helper opens `s3://bucket/path` URIs in the AWS S3 web console.
It installs only for the current user and does not require root access.

## Install

```bash
chmod +x install.sh
./install.sh install
```

The default AWS region is `eu-west-1`. To select another region:

```bash
./install.sh install --region eu-central-1
```

After installation, enter an URI such as this in Firefox:

```text
s3://my-bucket/images/test.png
```

Firefox may ask for confirmation the first time it opens the external
protocol. Select **S3 AWS Console** and optionally remember the choice.

The installer creates:

- `~/.local/bin/s3-console`
- `${XDG_DATA_HOME:-~/.local/share}/applications/s3-console-handler.desktop`

## Uninstall

Run the uninstaller from this directory:

```bash
./install.sh uninstall
```

It removes both installed files and the corresponding per-user MIME
association. The files in this project directory are not removed.
