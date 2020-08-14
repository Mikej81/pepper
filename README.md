# pepper

Working location for Hardened Container based NGINX Proxy

Option to select opensource or plus deployment at build.

```bash
--build-arg PLATFORM=oss/plus
```

Ensure that option for build is sent during runtime as well.

```bash
--env PLATFORM=oss/plus
```

NGINX OSS comes with with ModSec(OWASP CRS), GeoIP.

NGINX+ comes with App Protect.
