class OpenfortivpnKeepalive < Formula
  desc "Open Fortinet client for PPP+TLS VPN tunnel services"
  homepage "https://github.com/adrienverge/openfortivpn"
  url "https://github.com/adrienverge/openfortivpn/archive/refs/tags/v1.23.1.tar.gz"
  sha256 "ecacfc7f18d87f4ff503198177e51a83316b59b4646f31caa8140fdbfaa40389"
  license "GPL-3.0-or-later" => { with: "openvpn-openssl-exception" }
  head "https://github.com/adrienverge/openfortivpn.git", branch: "master"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "pkgconf" => :build
  depends_on "openssl@3"

  # awaiting formula creation
  # uses_from_macos "pppd"

  stable do
    patch :DATA
  end

  def install
    system "./autogen.sh"
    system "./configure", "--disable-silent-rules",
                          "--enable-legacy-pppd", # only for pppd < 2.5.0
                          "--sysconfdir=#{etc}/openfortivpn",
                          *std_configure_args
    system "make", "install"
  end

  service do
    run [opt_bin/"openfortivpn", "-c", etc/"openfortivpn/openfortivpn/config"]
    keep_alive true
    require_root true
    log_path var/"log/openfortivpn.log"
    error_log_path var/"log/openfortivpn.log"
  end

  test do
    system bin/"openfortivpn", "--version"
  end
end

__END__
diff --git a/src/config.c b/src/config.c
index d1e33ad..ddf2644 100644
--- a/src/config.c
+++ b/src/config.c
@@ -68,6 +68,7 @@ const struct vpn_config invalid_cfg = {
 	.pppd_log = NULL,
 	.pppd_plugin = NULL,
 	.pppd_ipparam = NULL,
+	.pppd_keepalive = NULL,
 	.pppd_ifname = NULL,
 	.pppd_call = NULL,
 	.pppd_accept_remote = -1,
@@ -352,6 +353,9 @@ int load_config(struct vpn_config *cfg, const char *filename)
 		} else if (strcmp(key, "pppd-ipparam") == 0) {
 			free(cfg->pppd_ipparam);
 			cfg->pppd_ipparam = strdup(val);
+		} else if (strcmp(key, "pppd-keepalive") == 0) {
+			free(cfg->pppd_keepalive);
+			cfg->pppd_keepalive = strdup(val);
 		} else if (strcmp(key, "pppd-ifname") == 0) {
 			free(cfg->pppd_ifname);
 			cfg->pppd_ifname = strdup(val);
@@ -501,6 +505,7 @@ void destroy_vpn_config(struct vpn_config *cfg)
 	free(cfg->pppd_log);
 	free(cfg->pppd_plugin);
 	free(cfg->pppd_ipparam);
+	free(cfg->pppd_keepalive);
 	free(cfg->pppd_ifname);
 	free(cfg->pppd_call);
 #endif
@@ -585,6 +590,10 @@ void merge_config(struct vpn_config *dst, struct vpn_config *src)
 		free(dst->pppd_ipparam);
 		dst->pppd_ipparam = src->pppd_ipparam;
 	}
+	if (src->pppd_keepalive) {
+		free(dst->pppd_keepalive);
+		dst->pppd_keepalive = src->pppd_keepalive;
+	}
 	if (src->pppd_ifname) {
 		free(dst->pppd_ifname);
 		dst->pppd_ifname = src->pppd_ifname;
diff --git a/src/config.h b/src/config.h
index 8eecddc..1b22507 100644
--- a/src/config.h
+++ b/src/config.h
@@ -117,6 +117,7 @@ struct vpn_config {
 	char			*pppd_log;
 	char			*pppd_plugin;
 	char			*pppd_ipparam;
+	char			*pppd_keepalive;
 	char			*pppd_ifname;
 	char			*pppd_call;
 	int                     pppd_accept_remote;
diff --git a/src/main.c b/src/main.c
index bff329d..7117cc5 100644
--- a/src/main.c
+++ b/src/main.c
@@ -38,24 +38,27 @@
 "                    [--pppd-use-peerdns=<0|1>] [--pppd-log=<file>]\n" \
 "                    [--pppd-ifname=<string>] [--pppd-ipparam=<string>]\n" \
 "                    [--pppd-call=<name>] [--pppd-plugin=<file>]\n" \
-"                    [--pppd-accept-remote=<0|1>]\n"
+"                    [--pppd-accept-remote=<0|1>]\n" \
+"                    [--pppd-keepalive=<interval>]\n"
 #define PPPD_HELP \
 "  --pppd-use-peerdns=[01]       Whether to ask peer ppp server for DNS server\n" \
 "                                addresses and make pppd rewrite /etc/resolv.conf.\n" \
 "  --pppd-no-peerdns             Same as --pppd-use-peerdns=0. pppd will not\n" \
 "                                modify DNS resolution then.\n" \
 "  --pppd-log=<file>             Set pppd in debug mode and save its logs into\n" \
 "                                <file>.\n" \
 "  --pppd-plugin=<file>          Use specified pppd plugin instead of configuring\n" \
 "                                resolver and routes directly.\n" \
 "  --pppd-ifname=<string>        Set the pppd interface name, if supported by pppd.\n" \
 "  --pppd-ipparam=<string>       Provides an extra parameter to the ip-up, ip-pre-up\n" \
 "                                and ip-down scripts. See man (8) pppd.\n" \
 "  --pppd-call=<name>            Move most pppd options from pppd cmdline to\n" \
 "                                /etc/ppp/peers/<name> and invoke pppd with\n" \
 "                                'call <name>'.\n" \
 "  --pppd-accept-remote=[01]     Whether to invoke pppd with 'ipcp-accept-remote'.\n" \
-"                                Disable for pppd < 2.5.0.\n"
+"                                Disable for pppd < 2.5.0.\n" \
+"  --pppd-keepalive=<interval>   Keep connection alive usinc LCP echo-request frames\n" \
+"                                sent by pppd every <interval> seconds.\n"
 #elif HAVE_USR_SBIN_PPP
 #define PPPD_USAGE \
 "                    [--ppp-system=<system>]\n"
@@ -250,6 +253,7 @@ int main(int argc, char *argv[])
 		.pppd_log = NULL,
 		.pppd_plugin = NULL,
 		.pppd_ipparam = NULL,
+		.pppd_keepalive = NULL,
 		.pppd_ifname = NULL,
 		.pppd_call = NULL,
 #if LEGACY_PPPD
@@ -319,6 +323,7 @@ int main(int argc, char *argv[])
 		{"pppd-log",             required_argument, NULL, 0},
 		{"pppd-plugin",          required_argument, NULL, 0},
 		{"pppd-ipparam",         required_argument, NULL, 0},
+		{"pppd-keepalive",       required_argument, NULL, 0},
 		{"pppd-ifname",          required_argument, NULL, 0},
 		{"pppd-call",            required_argument, NULL, 0},
 		{"pppd-accept-remote",   optional_argument, NULL, 0},
@@ -396,6 +401,12 @@ int main(int argc, char *argv[])
 				cli_cfg.pppd_ipparam = strdup(optarg);
 				break;
 			}
+			if (strcmp(long_options[option_index].name,
+			           "pppd-keepalive") == 0) {
+				free(cli_cfg.pppd_ipparam);
+				cli_cfg.pppd_keepalive = strdup(optarg);
+				break;
+			}
 			if (strcmp(long_options[option_index].name,
 			           "pppd-call") == 0) {
 				free(cli_cfg.pppd_call);
diff --git a/src/tunnel.c b/src/tunnel.c
index 667410e..d3345b3 100644
--- a/src/tunnel.c
+++ b/src/tunnel.c
@@ -364,6 +364,16 @@ static int pppd_run(struct tunnel *tunnel)
 				return 1;
 			}
 		}
+		if (tunnel->config->pppd_keepalive) {
+			if (ofv_append_varr(&pppd_args, "lcp-echo-interval")) {
+				free(pppd_args.data);
+				return 1;
+			}
+			if (ofv_append_varr(&pppd_args, tunnel->config->pppd_keepalive)) {
+				free(pppd_args.data);
+				return 1;
+			}
+		}
 		if (tunnel->config->pppd_ifname) {
 			if (ofv_append_varr(&pppd_args, "ifname")) {
 				free(pppd_args.data);
