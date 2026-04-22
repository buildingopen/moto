# moto — residential proxy sidecar (tinyproxy).
#
# We use tinyproxy because its `upstream` directive is short, obvious, and
# works as documented. (3proxy's `parent` was silently ignored across 3
# versions in the same config scenarios.)
#
# The image only offers an HTTP forward proxy listener on :8118. Chrome
# and every agent HTTP client in moto speak HTTP proxy, so this is
# sufficient. If you need a SOCKS5 listener locally, run a separate
# tool (e.g. gost or microsocks) — out of scope for v0.1.
FROM vimagick/tinyproxy:latest

COPY tinyproxy.conf /etc/tinyproxy/moto.conf.tmpl
COPY entrypoint.sh /usr/local/bin/moto-proxy-entrypoint.sh
RUN chmod +x /usr/local/bin/moto-proxy-entrypoint.sh

EXPOSE 8118
ENTRYPOINT ["/usr/local/bin/moto-proxy-entrypoint.sh"]
