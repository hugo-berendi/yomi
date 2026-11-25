# yomi options

Generated from the modules by `just docs`; do not edit by hand.
NixOS options first, then the ones only Home Manager has.

# NixOS

## yomi\.acme\.enable

Whether to enable yomi’s ACME integration\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/acme\.nix](../modules/nixos/acme.nix)

## yomi\.acme\.email

ACME account contact address\.

*Type:*
string

*Declared by:*
 - [modules/nixos/acme\.nix](../modules/nixos/acme.nix)

## yomi\.acme\.sopsFile

Encrypted file containing cloudflare_dns_api_token\.

*Type:*
absolute path

*Declared by:*
 - [modules/nixos/acme\.nix](../modules/nixos/acme.nix)

## yomi\.alerting\.retireLegacyChannels

Remove the notification paths that duplicate the alert router: Grafana’s
Discord and mail receivers, Gatus’ per-endpoint mail and the n8n
execution monitor’s own direct ntfy fallback (the watchdog owns that
now)\. Leave this off until the router and the outside heartbeat have
been checked on the running system\.

*Type:*
boolean

*Default:*

```nix
false
```

*Declared by:*
 - [hosts/nixos/inari/services/alerting](../hosts/nixos/inari/services/alerting)

## yomi\.anubis\.enable

Whether to enable yomi’s anubis integration\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [profiles/services/anubis\.nix](../profiles/services/anubis.nix)

## yomi\.beszel-agent\.enable

Whether to enable yomi’s beszel agent\.

*Type:*
boolean

*Default:*

```nix
true
```

*Example:*

```nix
true
```

*Declared by:*
 - [profiles/services/beszel-agent\.nix](../profiles/services/beszel-agent.nix)

## yomi\.containers\.enable

Whether to enable yomi’s OCI containers integration\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [profiles/services/oci\.nix](../profiles/services/oci.nix)

## yomi\.diabetes\.enable

Whether to enable private diabetes reports\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [hosts/nixos/inari/services/diabetes](../hosts/nixos/inari/services/diabetes)

## yomi\.diabetes\.dexcomCredentialFile

Runtime JSON file with Dexcom Share username/password; provision with sops, never a Nix store path\.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*
 - [hosts/nixos/inari/services/diabetes](../hosts/nixos/inari/services/diabetes)

## yomi\.diabetes\.weeklyEmailEnable

Whether to enable weekly email submission through the private n8n endpoint\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [hosts/nixos/inari/services/diabetes](../hosts/nixos/inari/services/diabetes)

## yomi\.diabetes\.weeklyMailCredentialFile

Runtime JSON with confirmed recipient and optional SMTP settings\. Defaults reuse the existing Migadu no-reply account through LoadCredential\. Use a runtime private file or sops secret path, never a store path\.

*Type:*
null or string

*Default:*

```nix
"/var/lib/diabetes/weekly-mail.json"
```

*Declared by:*
 - [hosts/nixos/inari/services/diabetes](../hosts/nixos/inari/services/diabetes)

## yomi\.dns\.domain

Default zone to include records in

*Type:*
string

*Declared by:*
 - [dns/implementation/nixos-module\.nix](../dns/implementation/nixos-module.nix)

## yomi\.dns\.records

List of records to create

*Type:*
list of (submodule)

*Default:*

```nix
[ ]
```

*Declared by:*
 - [dns/implementation/nixos-module\.nix](../dns/implementation/nixos-module.nix)

## yomi\.dns\.records\.\*\.enableCloudflareProxy

Whether to enable proxying using cloudflare\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [dns/implementation/nixos-module\.nix](../dns/implementation/nixos-module.nix)

## yomi\.dns\.records\.\*\.at

Record name relative to its zone; empty or null denotes the apex\.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*
 - [dns/implementation/nixos-module\.nix](../dns/implementation/nixos-module.nix)

## yomi\.dns\.records\.\*\.to

Shorthand for CNAME-ing to a subdomain of the given zone

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*
 - [dns/implementation/nixos-module\.nix](../dns/implementation/nixos-module.nix)

## yomi\.dns\.records\.\*\.ttl

The TTL assigned to the record

*Type:*
integer between 1 and 2147483647 (both inclusive)

*Default:*

```nix
300
```

*Declared by:*
 - [dns/implementation/nixos-module\.nix](../dns/implementation/nixos-module.nix)

## yomi\.dns\.records\.\*\.type

The type of the DNS record\. ALIAS is only valid at the zone apex, where it stands in for the CNAME the DNS standard forbids there; Cloudflare publishes it as a flattened root CNAME\.

*Type:*
one of “A”, “AAAA”, “TXT”, “CNAME”, “ALIAS”, “MX”

*Declared by:*
 - [dns/implementation/nixos-module\.nix](../dns/implementation/nixos-module.nix)

## yomi\.dns\.records\.\*\.value

The value assigned to the record, in octodns format

*Type:*
YAML 1\.1 value

*Default:*

```nix
null
```

*Declared by:*
 - [dns/implementation/nixos-module\.nix](../dns/implementation/nixos-module.nix)

## yomi\.dns\.records\.\*\.zone

Zone this record is a part of

*Type:*
string

*Default:*

```nix
"hugo-berendi.de"
```

*Declared by:*
 - [dns/implementation/nixos-module\.nix](../dns/implementation/nixos-module.nix)

## yomi\.expose\.enable

Whether to enable the Pangolin site connector (Newt)\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/expose](../modules/nixos/expose)

## yomi\.expose\.allowedCountries

Default country allowlist for public HTTP resources\. Empty means unrestricted geography\. Passing countries still authenticate\.

*Type:*
list of string matching the pattern \[A-Z]{2}

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/expose](../modules/nixos/expose)

## yomi\.expose\.at

Public HTTP(S) tunnels, declared alongside their backend services\.

*Type:*
attribute set of (submodule)

*Default:*

```nix
{ }
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.enable

Whether to publish this endpoint and its DNS and monitoring records\.

*Type:*
boolean

*Default:*

```nix
true
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.enableAnubis

Whether to enable Anubis browser bot challenges before this Web application\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.additionalTargets

Additional backend targets for load balancing; incompatible with the single-backend Anubis wrapper\.

*Type:*
list of (submodule)

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.additionalTargets\.\*\.hostname

Address as seen from Newt\.

*Type:*
string

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.additionalTargets\.\*\.method

Backend protocol\.

*Type:*
one of “http”, “https”

*Default:*

```nix
"http"
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.additionalTargets\.\*\.port

Backend port\.

*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.allowAuthBypass

Explicitly permit allow rules, which bypass all Pangolin authentication\.

*Type:*
boolean

*Default:*

```nix
false
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.allowedCountries

Country allowlist; permitted countries pass to authentication, all other and unknown countries are denied\.

*Type:*
list of string matching the pattern \[A-Z]{2}

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.anubis\.metricsPort

Loopback Anubis metrics listener\.

*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)

*Default:*
derived from the other settings of the entry

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.anubis\.port

Loopback Anubis listener; override if it conflicts with another port\.

*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)

*Default:*
derived from the other settings of the entry

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.blockedASNs

Deny these autonomous system numbers before any custom allow/pass rules\. Requires GeoIP and ASN data\.

*Type:*
list of (positive integer, meaning >0)

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.blockedCountries

Deny these ISO country codes before any custom allow/pass rules\. Requires GeoIP on the gateway\.

*Type:*
list of string matching the pattern \[A-Z]{2}

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.dns\.enable

Manage a DNS record; disable for externally managed hostnames\.

*Type:*
boolean

*Default:*

```nix
true
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.dns\.name

Record name relative to dns\.zone; empty means the apex\.

*Type:*
string

*Default:*

```nix
"‹name›"
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.dns\.zone

Managed DNS zone\.

*Type:*
string

*Default:*

```nix
"hugo-berendi.de"
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.healthCheck\.enable

Whether to enable backend HTTP health checks, independently of SSO and Anubis\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.healthCheck\.interval

Probe interval in seconds\.

*Type:*
positive integer, meaning >0

*Default:*

```nix
30
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.healthCheck\.path

Backend health path\.

*Type:*
string matching the pattern /\.\*

*Default:*

```nix
"/"
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.healthCheck\.status

Expected health response code\.

*Type:*
integer between 100 and 599 (both inclusive)

*Default:*

```nix
200
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.healthCheck\.timeout

Probe timeout in seconds\.

*Type:*
positive integer, meaning >0

*Default:*

```nix
5
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.host

Hostname served by this endpoint\.

*Type:*
string

*Default:*

```nix
"‹name›.hugo-berendi.de"
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.hostHeader

Override the backend Host header for applications with a canonical internal URL\.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.labels

Resource labels for filtering in Pangolin\.

*Type:*
list of string

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.monitor\.enable

Whether to enable a Gatus health check for this endpoint\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.monitor\.conditions

Expected Gatus responses; configure authentication and redirects explicitly\.

*Type:*
list of string

*Default:*

```nix
[
  "[STATUS] == 200"
  "[RESPONSE_TIME] < 2000"
]
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.monitor\.group

Health check group\.

*Type:*
string

*Default:*

```nix
"Services"
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.monitor\.interval

Gatus check interval\.

*Type:*
string

*Default:*

```nix
"1m"
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.monitor\.name

Health check display name\.

*Type:*
string

*Default:*

```nix
"‹name›"
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.monitor\.path

Health check path appended to the public URL\.

*Type:*
string matching the pattern (/\.\*)?

*Default:*

```nix
""
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.port

Upstream HTTP service port\.

*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.protocol

Protocol spoken by the upstream HTTP application\.

*Type:*
one of “http”, “https”

*Default:*

```nix
"http"
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.proxyAddress

Upstream address, with brackets around an IPv6 literal\.

*Type:*
string

*Default:*

```nix
"localhost"
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.roles

Pangolin roles permitted to access the resource; Admin is implicit and must not be listed\.

*Type:*
list of string

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.rules

Ordered resource access rules\. Allow bypasses authentication and requires allowAuthBypass\.

*Type:*
list of (submodule)

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.rules\.\*\.action

Block, continue to authentication, or bypass authentication\.

*Type:*
one of “deny”, “pass”, “allow”

*Default:*

```nix
"deny"
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.rules\.\*\.match

Rule matcher\. Country and ASN matchers require gateway GeoIP databases\.

*Type:*
one of “ip”, “cidr”, “path”, “method”, “country”, “country_is_not”, “asn”

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.rules\.\*\.value

Matcher value\.

*Type:*
string

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.sso

Require Pangolin SSO; false explicitly publishes a service using its own authentication\.

*Type:*
boolean

*Default:*

```nix
true
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.subdomain

Default DNS name within the provider’s domain; empty means the zone apex\.

*Type:*
string

*Default:*

```nix
"‹name›"
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.url

Derived public HTTPS URL\.

*Type:*
string *(read only)*

*Default:*

```nix
"https://‹name›.hugo-berendi.de"
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.at\.\<name>\.users

Pangolin users explicitly permitted to access the resource\.

*Type:*
list of string

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.blueprint

Generated site blueprint, also available before activating the connector\.

*Type:*
YAML 1\.1 value *(read only)*

*Default:*

```nix
{
  private-resources = { };
  public-resources = { };
}
```

*Declared by:*
 - [modules/nixos/expose](../modules/nixos/expose)

## yomi\.expose\.domain

Default domain for public Web resources\.

*Type:*
string

*Default:*

```nix
"hugo-berendi.de"
```

*Declared by:*
 - [modules/nixos/expose](../modules/nixos/expose)

## yomi\.expose\.endpoint

Pangolin control server URL\.

*Type:*
string

*Default:*

```nix
"https://pangolin.hugo-berendi.de"
```

*Declared by:*
 - [modules/nixos/expose](../modules/nixos/expose)

## yomi\.expose\.environmentFile

Runtime file with NEWT_ID and NEWT_SECRET; never put credentials in Nix expressions\.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*
 - [modules/nixos/expose](../modules/nixos/expose)

## yomi\.expose\.listeners

Public gateway listeners required by this site’s raw resources\.

*Type:*
list of (attribute set) *(read only)*

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/expose](../modules/nixos/expose)

## yomi\.expose\.private

Client-only resources; no public listener is created\.

*Type:*
attribute set of (submodule)

*Default:*

```nix
{ }
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.private\.\<name>\.enable

Whether to enable this private resource\.

*Type:*
boolean

*Default:*

```nix
true
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.private\.\<name>\.aiBudgets

Token or cost budgets on an inference resource\.

*Type:*
list of (submodule)

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.private\.\<name>\.aiBudgets\.\*\.enable

Whether to enable this AI budget\.

*Type:*
boolean

*Default:*

```nix
true
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.private\.\<name>\.aiBudgets\.\*\.amount

Maximum usage in the configured unit and period\.

*Type:*
signed integer or floating point number

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.private\.\<name>\.aiBudgets\.\*\.enforcement

Block requests over budget or record overruns\.

*Type:*
one of “hard”, “soft”

*Default:*

```nix
"hard"
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.private\.\<name>\.aiBudgets\.\*\.period

Window for accumulating usage\.

*Type:*
one of “hourly”, “daily”, “weekly”, “monthly”, “yearly”, “lifetime”

*Default:*

```nix
"monthly"
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.private\.\<name>\.aiBudgets\.\*\.unit

Budget unit\.

*Type:*
one of “usd”, “tokens”

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.private\.\<name>\.aiProviders

Existing organization AI providers attached to an inference resource\. Use provider identifiers rather than API keys\.

*Type:*
list of (submodule)

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.private\.\<name>\.aiProviders\.\*\.enable

Whether to enable this AI provider attachment\.

*Type:*
boolean

*Default:*

```nix
true
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.private\.\<name>\.aiProviders\.\*\.accessMode

Inherit available models or limit the provider to selected models\.

*Type:*
one of “inherit”, “select”

*Default:*

```nix
"inherit"
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.private\.\<name>\.aiProviders\.\*\.models

Model identifiers for select mode\.

*Type:*
list of non-empty string

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.private\.\<name>\.aiProviders\.\*\.provider

Provider identifier in Pangolin\.

*Type:*
non-empty string

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.private\.\<name>\.alias

Private client DNS alias for a host or SSH resource\.

*Type:*
null or non-empty string

*Default:*

```nix
null
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.private\.\<name>\.allowICMP

Whether to enable ICMP to this private host or network\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.private\.\<name>\.authDaemon

Private SSH authentication and auth daemon placement\.

*Type:*
submodule

*Default:*

```nix
{ }
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.private\.\<name>\.authDaemon\.mode

Use an existing SSH server, a remote auth daemon, or Pangolin’s native SSH on the site\.

*Type:*
one of “site”, “remote”, “native”

*Default:*

```nix
"site"
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.private\.\<name>\.authDaemon\.pam

Use the backend’s existing credentials or provision accounts through Pangolin\.

*Type:*
one of “passthrough”, “push”

*Default:*

```nix
"passthrough"
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.private\.\<name>\.authDaemon\.port

Auth daemon port\. Required for a remote auth daemon\.

*Type:*
null or 16 bit unsigned integer; between 0 and 65535 (both inclusive)

*Default:*

```nix
null
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.private\.\<name>\.destination

Backend address, hostname or CIDR as seen by the site\.

*Type:*
null or non-empty string

*Default:*

```nix
null
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.private\.\<name>\.destinationPort

Backend port for private HTTP or an existing SSH server\. SSH defaults to 22\.

*Type:*
null or 16 bit unsigned integer; between 0 and 65535 (both inclusive)

*Default:*

```nix
null
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.private\.\<name>\.fullDomain

Hostname on a domain managed by the Pangolin organization, used by private HTTP and AI Gateway resources\. Configure the DNS required for Pangolin certificates separately\.

*Type:*
null or string matching the pattern \[a-zA-Z0-9-]+(\\\.\[a-zA-Z0-9-]+)+

*Default:*

```nix
null
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.private\.\<name>\.labels

Pangolin resource labels\.

*Type:*
list of non-empty string

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.private\.\<name>\.machines

Identifiers of Pangolin machine clients explicitly granted access\.

*Type:*
list of non-empty string

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.private\.\<name>\.mode

Private Pangolin resource type\. Use inference for an AI Gateway\.

*Type:*
one of “host”, “cidr”, “http”, “ssh”, “inference”, “exit-node”

*Default:*

```nix
"host"
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.private\.\<name>\.roles

Pangolin roles permitted to access the resource; Admin is implicit and must not be listed\.

*Type:*
list of string

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.private\.\<name>\.scheme

Scheme used by Newt to connect to a private HTTP backend\. Defaults to HTTP\.

*Type:*
null or one of “http”, “https”

*Default:*

```nix
null
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.private\.\<name>\.sites

Pangolin site identifiers\. An empty list uses the site applying the blueprint\.

*Type:*
list of non-empty string

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.private\.\<name>\.ssl

Use TLS on the client-facing private HTTP or AI Gateway resource\. Defaults to true\.

*Type:*
null or boolean

*Default:*

```nix
null
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.private\.\<name>\.tcpPorts

Allowed TCP ports for host, network or SSH resources\. SSH defaults to its backend port; host and network resources default to none\.

*Type:*
list of 16 bit unsigned integer; between 0 and 65535 (both inclusive)

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.private\.\<name>\.udpPorts

Allowed UDP ports for host or network resources\. Defaults to none\.

*Type:*
list of 16 bit unsigned integer; between 0 and 65535 (both inclusive)

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.private\.\<name>\.users

Pangolin users explicitly permitted to access the resource\.

*Type:*
list of string

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.publicHost

Unproxied DNS hostname of the public Pangolin gateway\.

*Type:*
string

*Default:*

```nix
"ebisu.hugo-berendi.de"
```

*Declared by:*
 - [modules/nixos/expose](../modules/nixos/expose)

## yomi\.expose\.server\.enable

Whether to enable the public Pangolin gateway\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/expose/server\.nix](../modules/nixos/expose/server.nix)

## yomi\.expose\.server\.accessLog\.enable

Whether to enable local bounded HTTP access logs for security and geographic analysis\.

*Type:*
boolean

*Default:*

```nix
true
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/expose/access-log\.nix](../modules/nixos/expose/access-log.nix)

## yomi\.expose\.server\.backup\.enable

Whether to enable encrypted off-host Restic backups of Pangolin, certificates, keys and server credentials\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/expose/backup\.nix](../modules/nixos/expose/backup.nix)

## yomi\.expose\.server\.backup\.environmentFile

Optional runtime storage access credentials\.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*
 - [modules/nixos/expose/backup\.nix](../modules/nixos/expose/backup.nix)

## yomi\.expose\.server\.backup\.passwordFile

Runtime Restic encryption password file\.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*
 - [modules/nixos/expose/backup\.nix](../modules/nixos/expose/backup.nix)

## yomi\.expose\.server\.backup\.repositoryFile

Runtime file with the URL of an already initialized off-host Restic repository\.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*
 - [modules/nixos/expose/backup\.nix](../modules/nixos/expose/backup.nix)

## yomi\.expose\.server\.dashboardSessionHours

Maximum dashboard session lifetime in hours\.

*Type:*
positive integer, meaning >0

*Default:*

```nix
12
```

*Declared by:*
 - [modules/nixos/expose/server\.nix](../modules/nixos/expose/server.nix)

## yomi\.expose\.server\.edition

Pangolin edition\. Enterprise requires a valid license activated in the running instance\.

*Type:*
one of “oss”, “enterprise”

*Default:*

```nix
"oss"
```

*Declared by:*
 - [modules/nixos/expose/server\.nix](../modules/nixos/expose/server.nix)

## yomi\.expose\.server\.environmentFile

Runtime SERVER_SECRET environment file for Pangolin\.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*
 - [modules/nixos/expose/server\.nix](../modules/nixos/expose/server.nix)

## yomi\.expose\.server\.geoip\.enable

Whether to enable local IP geolocation and ASN lookups for blocking and Pangolin analytics\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/expose/geoip\.nix](../modules/nixos/expose/geoip.nix)

## yomi\.expose\.server\.geoip\.databaseDirectory

Directory containing GeoLite2-City\.mmdb and GeoLite2-ASN\.mmdb\.

*Type:*
string

*Default:*

```nix
"/var/lib/GeoIP"
```

*Declared by:*
 - [modules/nixos/expose/geoip\.nix](../modules/nixos/expose/geoip.nix)

## yomi\.expose\.server\.geoip\.update\.enable

Whether to enable weekly GeoLite2 downloads directly from MaxMind\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/expose/geoip\.nix](../modules/nixos/expose/geoip.nix)

## yomi\.expose\.server\.geoip\.update\.accountId

MaxMind account ID\.

*Type:*
null or (positive integer, meaning >0)

*Default:*

```nix
null
```

*Declared by:*
 - [modules/nixos/expose/geoip\.nix](../modules/nixos/expose/geoip.nix)

## yomi\.expose\.server\.geoip\.update\.licenseKeyFile

Runtime MaxMind license key file outside the Nix store\.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*
 - [modules/nixos/expose/geoip\.nix](../modules/nixos/expose/geoip.nix)

## yomi\.expose\.server\.listeners

Aggregated public TCP/UDP listeners, including staged sites\.

*Type:*
list of (attribute set) *(read only)*

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/expose/server\.nix](../modules/nixos/expose/server.nix)

## yomi\.expose\.server\.protection\.enable

Whether to enable HTTP flood limits on the gateway, in addition to the provider’s network DDoS filter\.

*Type:*
boolean

*Default:*

```nix
true
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/expose/protection\.nix](../modules/nixos/expose/protection.nix)

## yomi\.expose\.server\.protection\.burst

Maximum HTTP request burst per source IP\.

*Type:*
positive integer, meaning >0

*Default:*

```nix
100
```

*Declared by:*
 - [modules/nixos/expose/protection\.nix](../modules/nixos/expose/protection.nix)

## yomi\.expose\.server\.protection\.concurrentPerHost

Concurrent HTTP requests per hostname, including long-lived streams\.

*Type:*
positive integer, meaning >0

*Default:*

```nix
128
```

*Declared by:*
 - [modules/nixos/expose/protection\.nix](../modules/nixos/expose/protection.nix)

## yomi\.expose\.server\.protection\.concurrentPerIP

Concurrent HTTP requests per source IP, including long-lived streams\.

*Type:*
positive integer, meaning >0

*Default:*

```nix
32
```

*Declared by:*
 - [modules/nixos/expose/protection\.nix](../modules/nixos/expose/protection.nix)

## yomi\.expose\.server\.protection\.requestsPerSecond

Sustained HTTP requests per second per source IP (IPv6 /64)\.

*Type:*
positive integer, meaning >0

*Default:*

```nix
50
```

*Declared by:*
 - [modules/nixos/expose/protection\.nix](../modules/nixos/expose/protection.nix)

## yomi\.expose\.server\.resourceSessionHours

Maximum resource session lifetime in hours\.

*Type:*
positive integer, meaning >0

*Default:*

```nix
24
```

*Declared by:*
 - [modules/nixos/expose/server\.nix](../modules/nixos/expose/server.nix)

## yomi\.expose\.server\.sourceHosts

Yomi hosts whose resource definitions determine public listeners\.

*Type:*
list of string

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/expose/server\.nix](../modules/nixos/expose/server.nix)

## yomi\.expose\.tcp

Unauthenticated public TCP port forwards through the site connector\.

*Type:*
attribute set of (submodule)

*Default:*

```nix
{ }
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.tcp\.\<name>\.enable

Whether to enable publishing this raw public port\.

*Type:*
boolean

*Default:*

```nix
true
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.tcp\.\<name>\.port

Backend port reached by the site connector\.

*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.tcp\.\<name>\.proxyAddress

Backend address as seen from the site connector\.

*Type:*
string

*Default:*

```nix
"127.0.0.1"
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.tcp\.\<name>\.publicPort

Public gateway port; raw traffic has no Pangolin authentication\.

*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)

*Default:*
derived from the other settings of the entry

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.udp

Unauthenticated public UDP port forwards, for example game and query ports\.

*Type:*
attribute set of (submodule)

*Default:*

```nix
{ }
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.udp\.\<name>\.enable

Whether to enable publishing this raw public port\.

*Type:*
boolean

*Default:*

```nix
true
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.udp\.\<name>\.port

Backend port reached by the site connector\.

*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.udp\.\<name>\.proxyAddress

Backend address as seen from the site connector\.

*Type:*
string

*Default:*

```nix
"127.0.0.1"
```

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.expose\.udp\.\<name>\.publicPort

Public gateway port; raw traffic has no Pangolin authentication\.

*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)

*Default:*
derived from the other settings of the entry

*Declared by:*
 - [modules/nixos/expose/endpoints\.nix](../modules/nixos/expose/endpoints.nix)

## yomi\.externalHeartbeat\.enable

Whether to enable an independent Healthchecks instance with SMTP alert delivery\.
Provision ` secret-key ` and ` smtp-password ` under /var/lib/yomi/external-heartbeat, readable
by the healthchecks group, before enabling it
\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [hosts/nixos/ebisu/heartbeat\.nix](../hosts/nixos/ebisu/heartbeat.nix)

## yomi\.filesystems\.btrfs\.enable

Whether to enable BTRFS rollback and autoScrub\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/filesystems\.nix](../modules/nixos/filesystems.nix)

## yomi\.filesystems\.btrfs\.device

Decrypted device path for BTRFS rollback

*Type:*
string

*Default:*

```nix
"/dev/mapper/crypted"
```

*Declared by:*
 - [modules/nixos/filesystems\.nix](../modules/nixos/filesystems.nix)

## yomi\.filesystems\.persistPaths

Paths to mark as neededForBoot\. Set to \[] on hosts without the impermanence layout (iso, WSL)\.

*Type:*
list of string

*Default:*

```nix
[
  "/"
  "/nix"
  "/persist/data"
  "/persist/state"
  "/persist/local/cache"
  "/boot"
]
```

*Declared by:*
 - [modules/nixos/filesystems\.nix](../modules/nixos/filesystems.nix)

## yomi\.forgejo\.productionRunner\.enable

Run the Actions runner on inari itself\. Turn this off only after a
dedicated worker (yomi\.forgejoCiWorker on its own machine) has picked up
jobs for the ` native ` label\. Off removes the runner unit, its sops
secrets and templates, its persisted state directory and its nix trust
from the evaluated system\. It does not delete the runner’s registration
in Forgejo, nor the old state under /persist/state/var/lib/gitea-runner\.

*Type:*
boolean

*Default:*

```nix
true
```

*Declared by:*
 - [hosts/nixos/inari/services/forgejo/service\.nix](../hosts/nixos/inari/services/forgejo/service.nix)

## yomi\.forgejoCiWorker\.enable

Whether to enable a dedicated, untrusted Forgejo Actions worker\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/forgejo-ci-worker\.nix](../modules/nixos/forgejo-ci-worker.nix)

## yomi\.forgejoCiWorker\.environmentFiles

Extra environment files for the runner, read as root\. The usual one
sets ` NIX_CONFIG=access-tokens = github.com=<token> ` to lift the
anonymous GitHub API rate limit on flake input resolution\.

*Type:*
list of string

*Default:*

```nix
[ ]
```

*Example:*

```nix
[
  "/run/secrets/forgejo-ci-worker-nix.env"
]
```

*Declared by:*
 - [modules/nixos/forgejo-ci-worker\.nix](../modules/nixos/forgejo-ci-worker.nix)

## yomi\.forgejoCiWorker\.gitSshKeyFile

Private key for ssh:// flake inputs (the read-only deploy key of the
` skills ` input)\. Passed through LoadCredential, so only this unit’s
dynamic user can read its copy\. Issue a key for this worker alone\.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*
 - [modules/nixos/forgejo-ci-worker\.nix](../modules/nixos/forgejo-ci-worker.nix)

## yomi\.forgejoCiWorker\.hostPackages

Packages on the PATH of ` host ` jobs\.

*Type:*
list of package

*Default:*
the production runner’s tool set

*Declared by:*
 - [modules/nixos/forgejo-ci-worker\.nix](../modules/nixos/forgejo-ci-worker.nix)

## yomi\.forgejoCiWorker\.labels

Runner labels\. ` native:host ` matches ` runs-on: native ` in the existing workflows\.

*Type:*
list of string

*Default:*

```nix
[
  "native:host"
]
```

*Declared by:*
 - [modules/nixos/forgejo-ci-worker\.nix](../modules/nixos/forgejo-ci-worker.nix)

## yomi\.forgejoCiWorker\.name

Runner name registered in Forgejo\. Use a name distinct from the production runner’s\.

*Type:*
string

*Default:*

```nix
"${config.networking.hostName}-ci"
```

*Declared by:*
 - [modules/nixos/forgejo-ci-worker\.nix](../modules/nixos/forgejo-ci-worker.nix)

## yomi\.forgejoCiWorker\.requiredSubstituters

Caches that root’s nix\.conf must already list\. An untrusted runner
cannot accept the flake’s own nixConfig, so a cache missing here is
silently not used\.

*Type:*
list of string

*Default:*

```nix
(import common/caches.nix).substituters
```

*Declared by:*
 - [modules/nixos/forgejo-ci-worker\.nix](../modules/nixos/forgejo-ci-worker.nix)

## yomi\.forgejoCiWorker\.requiredTrustedPublicKeys

Signing keys that root’s nix\.conf must already trust\.

*Type:*
list of string

*Default:*

```nix
(import common/caches.nix).trustedPublicKeys
```

*Declared by:*
 - [modules/nixos/forgejo-ci-worker\.nix](../modules/nixos/forgejo-ci-worker.nix)

## yomi\.forgejoCiWorker\.resources\.cores

nix ` cores ` per build; 0 means every core\.

*Type:*
unsigned integer, meaning >=0

*Default:*

```nix
2
```

*Declared by:*
 - [modules/nixos/forgejo-ci-worker\.nix](../modules/nixos/forgejo-ci-worker.nix)

## yomi\.forgejoCiWorker\.resources\.cpuQuota

Optional CPUQuota of the slice\. Unset leaves the machine’s CPUs to the worker\.

*Type:*
null or string

*Default:*

```nix
null
```

*Example:*

```nix
"300%"
```

*Declared by:*
 - [modules/nixos/forgejo-ci-worker\.nix](../modules/nixos/forgejo-ci-worker.nix)

## yomi\.forgejoCiWorker\.resources\.maxJobs

nix ` max-jobs ` on the worker: concurrent derivation builds\.

*Type:*
positive integer, meaning >0

*Default:*

```nix
1
```

*Declared by:*
 - [modules/nixos/forgejo-ci-worker\.nix](../modules/nixos/forgejo-ci-worker.nix)

## yomi\.forgejoCiWorker\.resources\.memoryHigh

MemoryHigh of the slice holding the runner and the nix-daemon\.

*Type:*
string

*Default:*

```nix
"6G"
```

*Declared by:*
 - [modules/nixos/forgejo-ci-worker\.nix](../modules/nixos/forgejo-ci-worker.nix)

## yomi\.forgejoCiWorker\.resources\.memoryMax

MemoryMax of the slice holding the runner and the nix-daemon\.

*Type:*
string

*Default:*

```nix
"8G"
```

*Declared by:*
 - [modules/nixos/forgejo-ci-worker\.nix](../modules/nixos/forgejo-ci-worker.nix)

## yomi\.forgejoCiWorker\.resources\.memorySwapMax

MemorySwapMax of the slice\.

*Type:*
string

*Default:*

```nix
"1G"
```

*Declared by:*
 - [modules/nixos/forgejo-ci-worker\.nix](../modules/nixos/forgejo-ci-worker.nix)

## yomi\.forgejoCiWorker\.resources\.tasksMax

TasksMax of the slice, against fork bombs in job steps\.

*Type:*
positive integer, meaning >0

*Default:*

```nix
4096
```

*Declared by:*
 - [modules/nixos/forgejo-ci-worker\.nix](../modules/nixos/forgejo-ci-worker.nix)

## yomi\.forgejoCiWorker\.tokenFile

Environment file holding ` TOKEN=<registration token> `, read by the
service manager as root\. Use a token issued for this worker alone, so
it can be revoked without touching the production runner\.

*Type:*
string

*Example:*

```nix
"/run/secrets/forgejo-ci-worker-token.env"
```

*Declared by:*
 - [modules/nixos/forgejo-ci-worker\.nix](../modules/nixos/forgejo-ci-worker.nix)

## yomi\.forgejoCiWorker\.url

Forgejo instance the worker registers with and polls for jobs\.

*Type:*
string

*Example:*

```nix
"https://git.example.org"
```

*Declared by:*
 - [modules/nixos/forgejo-ci-worker\.nix](../modules/nixos/forgejo-ci-worker.nix)

## yomi\.inari\.lanIPv4

Static IPv4 address used by Inari’s home network\.

*Type:*
string

*Default:*

```nix
"192.168.178.200"
```

*Declared by:*
 - [hosts/nixos/inari/networking/networkd\.nix](../hosts/nixos/inari/networking/networkd.nix)

## yomi\.inari\.lanInterface

Physical LAN interface enslaved to br0 on the installed server\.

*Type:*
string

*Default:*

```nix
"eno1"
```

*Declared by:*
 - [hosts/nixos/inari/networking/networkd\.nix](../hosts/nixos/inari/networking/networkd.nix)

## yomi\.inari\.releaseUpgrade\.enable

Whether to enable applying CI-signed release manifests instead of building main locally\.
It replaces system\.autoUpgrade; cut over only after a manual
` yomi-release run ` succeeded on this host\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [hosts/nixos/inari/auto-upgrade\.nix](../hosts/nixos/inari/auto-upgrade.nix)

## yomi\.inari\.releaseUpgrade\.allowedSigners

ssh-keygen allowed_signers line(s) for principal ` yomi-release `, restricted
with ` namespaces="yomi-release" `\. This key is the whole trust root\.

*Type:*
strings concatenated with “\\n”

*Default:*

```nix
""
```

*Declared by:*
 - [hosts/nixos/inari/auto-upgrade\.nix](../hosts/nixos/inari/auto-upgrade.nix)

## yomi\.inari\.releaseUpgrade\.dates

systemd OnCalendar expression for release checks\.

*Type:*
string

*Default:*

```nix
"04:00"
```

*Declared by:*
 - [hosts/nixos/inari/auto-upgrade\.nix](../hosts/nixos/inari/auto-upgrade.nix)

## yomi\.inari\.releaseUpgrade\.manifestUrl

HTTPS URL of this host’s release\.json; the signature is fetched from ` <url>.sig `\.

*Type:*
string

*Default:*

```nix
""
```

*Declared by:*
 - [hosts/nixos/inari/auto-upgrade\.nix](../hosts/nixos/inari/auto-upgrade.nix)

## yomi\.inari\.releaseUpgrade\.substituter

Extra binary cache holding release closures; its key must already be in nix\.settings\.trusted-public-keys\.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*
 - [hosts/nixos/inari/auto-upgrade\.nix](../hosts/nixos/inari/auto-upgrade.nix)

## yomi\.inari\.rootDataset

Encryption root and dataset prefix, including raw ZFS recovery beneath a fresh pool\.

*Type:*
one of “zroot”, “zroot/recovered”

*Default:*

```nix
"zroot"
```

*Declared by:*
 - [hosts/nixos/inari/filesystems/zfs\.nix](../hosts/nixos/inari/filesystems/zfs.nix)

## yomi\.inari\.tpmUnlock

Unlock the encryption root with a key sealed to this machine’s TPM\.

*Type:*
boolean

*Default:*

```nix
true
```

*Declared by:*
 - [hosts/nixos/inari/services/zfs](../hosts/nixos/inari/services/zfs)

## yomi\.iocaine\.enable

Whether to enable iocaine AI crawler trap\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/iocaine\.nix](../modules/nixos/iocaine.nix)

## yomi\.iocaine\.package

The iocaine package to use\.

*Type:*
package

*Default:*

```nix
pkgs.iocaine
```

*Declared by:*
 - [modules/nixos/iocaine\.nix](../modules/nixos/iocaine.nix)

## yomi\.iocaine\.ipRanges

IP ranges to redirect to iocaine poison pages

*Type:*
list of string

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/iocaine\.nix](../modules/nixos/iocaine.nix)

## yomi\.iocaine\.nginxExtraConfig

Nginx extra config to include in virtual hosts for iocaine redirection

*Type:*
strings concatenated with “\\n” *(read only)*

*Default:*

```nix
''
  if ($iocaine_redirect) { rewrite ^ /.well-known/@iocaine$request_uri last; }
''
```

*Declared by:*
 - [modules/nixos/iocaine\.nix](../modules/nixos/iocaine.nix)

## yomi\.iocaine\.port

Port for iocaine to listen on

*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)

*Default:*

```nix
8420
```

*Declared by:*
 - [modules/nixos/iocaine\.nix](../modules/nixos/iocaine.nix)

## yomi\.iocaine\.settings

Iocaine configuration options

*Type:*
open submodule of (TOML value)

*Default:*

```nix
{ }
```

*Declared by:*
 - [modules/nixos/iocaine\.nix](../modules/nixos/iocaine.nix)

## yomi\.iocaine\.settings\.server\.bind

Address and port for iocaine to bind to

*Type:*
string

*Default:*

```nix
"127.0.0.1:8420"
```

*Declared by:*
 - [modules/nixos/iocaine\.nix](../modules/nixos/iocaine.nix)

## yomi\.iocaine\.settings\.sources\.markov

List of paths to markov chain training data

*Type:*
list of (string or absolute path)

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/iocaine\.nix](../modules/nixos/iocaine.nix)

## yomi\.iocaine\.settings\.sources\.words

Path to word list for content generation

*Type:*
string or absolute path

*Default:*

```nix
"${pkgs.miscfiles}/share/web2"
```

*Declared by:*
 - [modules/nixos/iocaine\.nix](../modules/nixos/iocaine.nix)

## yomi\.iocaine\.userAgents

User agents to redirect to iocaine poison pages

*Type:*
list of string

*Default:*

```nix
[
  "Amazonbot"
  "anthropic-ai"
  "Applebot-Extended"
  "Bytespider"
  "CCBot"
  "ChatGPT-User"
  "ClaudeBot"
  "cohere-ai"
  "Diffbot"
  "DuckAssistBot"
  "FacebookBot"
  "FriendlyCrawler"
  "Google-Extended"
  "GoogleOther"
  "GPTBot"
  "ImagesiftBot"
  "img2dataset"
  "Meta-ExternalAgent"
  "OAI-SearchBot"
  "omgili"
  "PerplexityBot"
  "PetalBot"
  "Scrapy"
  "Timpibot"
  "VelenPublicWebCrawler"
  "YouBot"
]
```

*Declared by:*
 - [modules/nixos/iocaine\.nix](../modules/nixos/iocaine.nix)

## yomi\.location\.latitude

Latitude for location-based services

*Type:*
string

*Default:*

```nix
"51.23"
```

*Declared by:*
 - [modules/common/pilot\.nix](../modules/common/pilot.nix)

## yomi\.location\.longitude

Longitude for location-based services

*Type:*
string

*Default:*

```nix
"14.83"
```

*Declared by:*
 - [modules/common/pilot\.nix](../modules/common/pilot.nix)

## yomi\.machine\.audio

Enable PipeWire audio independently of the desktop\.

*Type:*
boolean

*Default:*

```nix
true
```

*Declared by:*
 - [modules/nixos/machine\.nix](../modules/nixos/machine.nix)

## yomi\.machine\.bluetooth

Enable Bluetooth independently of the desktop\.

*Type:*
boolean

*Default:*

```nix
true
```

*Declared by:*
 - [modules/nixos/machine\.nix](../modules/nixos/machine.nix)

## yomi\.machine\.gaming

```
    Whether this machine will be used to play games.
```

*Type:*
boolean

*Default:*

```nix
false
```

*Declared by:*
 - [modules/nixos/machine\.nix](../modules/nixos/machine.nix)

## yomi\.machine\.graphical

Whether this host runs a graphical desktop\.

*Type:*
boolean

*Default:*

```nix
false
```

*Declared by:*
 - [modules/nixos/machine\.nix](../modules/nixos/machine.nix)

## yomi\.machine\.interactible

Whether this machine is physically interactible with\. Enables things
like specific keyboard layouts\.

This differs from the “graphical” flag, since machines like my home
server(s) need to some times be manually typed on, even though they
do not offer any visuals besides the stock tty\.

*Type:*
boolean

*Default:*

```nix
true
```

*Declared by:*
 - [modules/nixos/machine\.nix](../modules/nixos/machine.nix)

## yomi\.matrix\.bridges\.enable

Run the mautrix WhatsApp, Signal and Discord bridges and register them with
Tuwunel\. Turning this off stops the services and drops their Tuwunel
appservice entries and secret declarations\. It keeps the persisted
databases, their backup entries and the encrypted tokens in secrets\.yaml,
so turning it back on resumes the existing bridge sessions\.

*Type:*
boolean

*Default:*

```nix
false
```

*Declared by:*
 - [hosts/nixos/inari/services/matrix/bridges\.nix](../hosts/nixos/inari/services/matrix/bridges.nix)

## yomi\.meilisearch\.enable

Whether to enable yomi’s meilisearch integration\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/meilisearch\.nix](../modules/nixos/meilisearch.nix)

## yomi\.meilisearch\.environment

Meilisearch environment mode

*Type:*
one of “production”, “development”

*Default:*

```nix
"development"
```

*Declared by:*
 - [modules/nixos/meilisearch\.nix](../modules/nixos/meilisearch.nix)

## yomi\.meilisearch\.sopsFile

Sops file containing the meilisearch_env secret\. Must be set when enable is true\.

*Type:*
null or absolute path

*Default:*

```nix
null
```

*Declared by:*
 - [modules/nixos/meilisearch\.nix](../modules/nixos/meilisearch.nix)

## yomi\.n8n\.workflows

Workflows to load into n8n at startup, keyed by a name used for the
systemd unit and the seed stamp\.

Export the current state with ` just n8n-export ` after editing in the web
ui, so the repository stays the source of truth\.

*Type:*
attribute set of (submodule)

*Default:*

```nix
{ }
```

*Declared by:*
 - [hosts/nixos/inari/services/n8n/workflows\.nix](../hosts/nixos/inari/services/n8n/workflows.nix)

## yomi\.n8n\.workflows\.\<name>\.enforce

Re-import on every start, so this file wins and edits made in the
web ui are replaced\. Set false to only seed the workflow once and
let the web ui own it afterwards – useful while building one out\.

*Type:*
boolean

*Default:*

```nix
true
```

*Declared by:*
 - [hosts/nixos/inari/services/n8n/workflows\.nix](../hosts/nixos/inari/services/n8n/workflows.nix)

## yomi\.n8n\.workflows\.\<name>\.source

Workflow JSON as exported by n8n\. Must carry its ` id `\.

*Type:*
absolute path

*Declared by:*
 - [hosts/nixos/inari/services/n8n/workflows\.nix](../hosts/nixos/inari/services/n8n/workflows.nix)

## yomi\.network\.exposure

Explicit service reachability grants\. A firewall backend must consume the requested scope and interface\.

*Type:*
attribute set of (submodule)

*Default:*

```nix
{ }
```

*Declared by:*
 - [modules/nixos/network-exposure\.nix](../modules/nixos/network-exposure.nix)

## yomi\.network\.exposure\.\<name>\.interface

Ingress interface on which this grant applies\.

*Type:*
string

*Declared by:*
 - [modules/nixos/network-exposure\.nix](../modules/nixos/network-exposure.nix)

## yomi\.network\.exposure\.\<name>\.port

Port to expose; defaults to the matching registry entry\.

*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)

*Default:*

```nix
config.yomi.ports.<name>
```

*Declared by:*
 - [modules/nixos/network-exposure\.nix](../modules/nixos/network-exposure.nix)

## yomi\.network\.exposure\.\<name>\.protocols

Transport protocols allowed by this grant\.

*Type:*
list of (one of “tcp”, “udp”)

*Default:*

```nix
[
  "tcp"
]
```

*Declared by:*
 - [modules/nixos/network-exposure\.nix](../modules/nixos/network-exposure.nix)

## yomi\.network\.exposure\.\<name>\.scope

Trust boundary receiving access; never inferred from upstream openFirewall\.

*Type:*
one of “lan”, “vpn”, “wan”

*Default:*

```nix
"lan"
```

*Declared by:*
 - [modules/nixos/network-exposure\.nix](../modules/nixos/network-exposure.nix)

## yomi\.network\.exposure\.\<name>\.service

Service owning the listener, for review and inventory\.

*Type:*
string

*Default:*

```nix
"‹name›"
```

*Declared by:*
 - [modules/nixos/network-exposure\.nix](../modules/nixos/network-exposure.nix)

## yomi\.nginx\.enable

Whether to enable yomi’s nginx integration\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/nginx\.nix](../modules/nixos/nginx.nix)

## yomi\.nginx\.at

Per-subdomain nginx configuration, written by yomi\.web\.at; set directly only for static files\.

*Type:*
attribute set of (submodule)

*Default:*

```nix
{ }
```

*Declared by:*
 - [modules/nixos/nginx\.nix](../modules/nixos/nginx.nix)

## yomi\.nginx\.at\.\<name>\.enable

Whether to publish this endpoint and its DNS and monitoring records\.

*Type:*
boolean

*Default:*

```nix
true
```

*Declared by:*
 - [modules/nixos/nginx\.nix](../modules/nixos/nginx.nix)

## yomi\.nginx\.at\.\<name>\.clientMaxBodySize

Maximum allowed size of the client request body for this host

*Type:*
null or string

*Default:*

```nix
null
```

*Example:*

```nix
"50000M"
```

*Declared by:*
 - [modules/nixos/nginx\.nix](../modules/nixos/nginx.nix)

## yomi\.nginx\.at\.\<name>\.dns\.enable

Manage a DNS record; disable for externally managed hostnames\.

*Type:*
boolean

*Default:*

```nix
true
```

*Declared by:*
 - [modules/nixos/nginx\.nix](../modules/nixos/nginx.nix)

## yomi\.nginx\.at\.\<name>\.dns\.name

Record name relative to dns\.zone; empty means the apex\.

*Type:*
string

*Default:*

```nix
"‹name›"
```

*Declared by:*
 - [modules/nixos/nginx\.nix](../modules/nixos/nginx.nix)

## yomi\.nginx\.at\.\<name>\.dns\.zone

Managed DNS zone\.

*Type:*
string

*Default:*

```nix
"hugo-berendi.de"
```

*Declared by:*
 - [modules/nixos/nginx\.nix](../modules/nixos/nginx.nix)

## yomi\.nginx\.at\.\<name>\.files

Path to serve files from

*Type:*
null or absolute path

*Default:*

```nix
null
```

*Declared by:*
 - [modules/nixos/nginx\.nix](../modules/nixos/nginx.nix)

## yomi\.nginx\.at\.\<name>\.host

Hostname served by this endpoint\.

*Type:*
string

*Default:*

```nix
"‹name›.hugo-berendi.de"
```

*Declared by:*
 - [modules/nixos/nginx\.nix](../modules/nixos/nginx.nix)

## yomi\.nginx\.at\.\<name>\.monitor\.enable

Whether to enable a Gatus health check for this endpoint\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/nginx\.nix](../modules/nixos/nginx.nix)

## yomi\.nginx\.at\.\<name>\.monitor\.conditions

Expected Gatus responses; configure authentication and redirects explicitly\.

*Type:*
list of string

*Default:*

```nix
[
  "[STATUS] == 200"
  "[RESPONSE_TIME] < 2000"
]
```

*Declared by:*
 - [modules/nixos/nginx\.nix](../modules/nixos/nginx.nix)

## yomi\.nginx\.at\.\<name>\.monitor\.group

Health check group\.

*Type:*
string

*Default:*

```nix
"Services"
```

*Declared by:*
 - [modules/nixos/nginx\.nix](../modules/nixos/nginx.nix)

## yomi\.nginx\.at\.\<name>\.monitor\.interval

Gatus check interval\.

*Type:*
string

*Default:*

```nix
"1m"
```

*Declared by:*
 - [modules/nixos/nginx\.nix](../modules/nixos/nginx.nix)

## yomi\.nginx\.at\.\<name>\.monitor\.name

Health check display name\.

*Type:*
string

*Default:*

```nix
"‹name›"
```

*Declared by:*
 - [modules/nixos/nginx\.nix](../modules/nixos/nginx.nix)

## yomi\.nginx\.at\.\<name>\.monitor\.path

Health check path appended to the public URL\.

*Type:*
string matching the pattern (/\.\*)?

*Default:*

```nix
""
```

*Declared by:*
 - [modules/nixos/nginx\.nix](../modules/nixos/nginx.nix)

## yomi\.nginx\.at\.\<name>\.port

Port to proxy requests to

*Type:*
null or 16 bit unsigned integer; between 0 and 65535 (both inclusive)

*Default:*

```nix
null
```

*Declared by:*
 - [modules/nixos/nginx\.nix](../modules/nixos/nginx.nix)

## yomi\.nginx\.at\.\<name>\.protocol

Protocol spoken by the upstream HTTP application\.

*Type:*
one of “http”, “https”

*Default:*

```nix
"http"
```

*Declared by:*
 - [modules/nixos/nginx\.nix](../modules/nixos/nginx.nix)

## yomi\.nginx\.at\.\<name>\.proxyAddress

Upstream address, with brackets around an IPv6 literal\.

*Type:*
string

*Default:*

```nix
"localhost"
```

*Declared by:*
 - [modules/nixos/nginx\.nix](../modules/nixos/nginx.nix)

## yomi\.nginx\.at\.\<name>\.subdomain

Default DNS name within the provider’s domain; empty means the zone apex\.

*Type:*
string

*Default:*

```nix
"‹name›"
```

*Declared by:*
 - [modules/nixos/nginx\.nix](../modules/nixos/nginx.nix)

## yomi\.nginx\.at\.\<name>\.url

Derived public HTTPS URL\.

*Type:*
string *(read only)*

*Default:*

```nix
"https://‹name›.hugo-berendi.de"
```

*Declared by:*
 - [modules/nixos/nginx\.nix](../modules/nixos/nginx.nix)

## yomi\.nginx\.domain

Root domain to use as a default for configurations\.

*Type:*
string

*Default:*

```nix
"hugo-berendi.de"
```

*Declared by:*
 - [modules/nixos/nginx\.nix](../modules/nixos/nginx.nix)

## yomi\.persistence\.enable

Whether to enable system persistence\.

*Type:*
boolean

*Default:*

```nix
true
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/persistence\.nix](../modules/nixos/persistence.nix)

## yomi\.persistence\.at

System persistence locations grouped by application; backup selection is explicit\.

*Type:*
attribute set of (submodule)

*Default:*

```nix
{ }
```

*Declared by:*
 - [modules/nixos/persistence\.nix](../modules/nixos/persistence.nix)

## yomi\.persistence\.at\.\<name>\.apps

Application persistence declarations\.

*Type:*
attribute set of (submodule)

*Default:*

```nix
{ }
```

*Declared by:*
 - [modules/nixos/persistence\.nix](../modules/nixos/persistence.nix)

## yomi\.persistence\.at\.\<name>\.apps\.\<name>\.backupSets

Named yomi\.restic\.sets explicitly receiving these live paths\.

*Type:*
list of string

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/persistence\.nix](../modules/nixos/persistence.nix)

## yomi\.persistence\.at\.\<name>\.apps\.\<name>\.directories

Directories and their ownership\.

*Type:*
list of (submodule)

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/persistence\.nix](../modules/nixos/persistence.nix)

## yomi\.persistence\.at\.\<name>\.apps\.\<name>\.directories\.\*\.directory

Absolute live directory path\.

*Type:*
string

*Declared by:*
 - [modules/nixos/persistence\.nix](../modules/nixos/persistence.nix)

## yomi\.persistence\.at\.\<name>\.apps\.\<name>\.directories\.\*\.group

Directory group\.

*Type:*
string

*Default:*

```nix
"root"
```

*Declared by:*
 - [modules/nixos/persistence\.nix](../modules/nixos/persistence.nix)

## yomi\.persistence\.at\.\<name>\.apps\.\<name>\.directories\.\*\.mode

Directory permissions\.

*Type:*
string

*Default:*

```nix
"0755"
```

*Declared by:*
 - [modules/nixos/persistence\.nix](../modules/nixos/persistence.nix)

## yomi\.persistence\.at\.\<name>\.apps\.\<name>\.directories\.\*\.user

Directory owner\.

*Type:*
string

*Default:*

```nix
"root"
```

*Declared by:*
 - [modules/nixos/persistence\.nix](../modules/nixos/persistence.nix)

## yomi\.persistence\.at\.\<name>\.apps\.\<name>\.files

Absolute live file paths\.

*Type:*
list of string

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/persistence\.nix](../modules/nixos/persistence.nix)

## yomi\.persistence\.at\.\<name>\.path

Absolute backing storage mount\.

*Type:*
string

*Declared by:*
 - [modules/nixos/persistence\.nix](../modules/nixos/persistence.nix)

## yomi\.persistence\.inventory

Evaluated application paths, ownership and explicit backup assignments\.

*Type:*
list of (attribute set) *(read only)*

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/persistence\.nix](../modules/nixos/persistence.nix)

## yomi\.pilot\.email

Primary email address for the pilot user

*Type:*
string

*Default:*

```nix
"personal@hugo-berendi.de"
```

*Declared by:*
 - [modules/common/pilot\.nix](../modules/common/pilot.nix)

## yomi\.pilot\.gitEmail

Address git commits and tags are made with\. It is the one verified on
the GitHub and Forgejo accounts, so the forges attribute commits to
them only with this, and GitHub marks signatures verified only when a
key’s user ID carries it\.

*Type:*
string

*Default:*

```nix
"git@hugo-berendi.de"
```

*Declared by:*
 - [modules/common/pilot\.nix](../modules/common/pilot.nix)

## yomi\.pilot\.githubUser

GitHub username for git and gh CLI

*Type:*
string

*Default:*

```nix
"hugo-berendi"
```

*Declared by:*
 - [modules/common/pilot\.nix](../modules/common/pilot.nix)

## yomi\.pilot\.gpgKey

Fingerprint of the pilot’s OpenPGP key, which git and mail sign with\.
Its primary key is offline on kagutsuchi; the signing, encryption and
authentication subkeys live only on the YubiKey (serial 30636315), so
signing works only where that card is plugged in\. The public key is
home/features/cli/pilot\.asc\.

It replaces 67D63C5F40CC55DA (rsa4096, 2024), revoked on 2026-09-26\.
That ID sat here as “gpgKeygrip”, though it was a key ID\.

*Type:*
string

*Default:*

```nix
"0E0F00D0D176B857A972E4D8ABC3ACDB6348CD34"
```

*Declared by:*
 - [modules/common/pilot\.nix](../modules/common/pilot.nix)

## yomi\.pilot\.name

The name of the main user for this machine

*Type:*
string

*Default:*

```nix
"hugob"
```

*Declared by:*
 - [modules/common/pilot\.nix](../modules/common/pilot.nix)

## yomi\.pilot\.sshIdentity

SSH identity files, tried in order\. Missing files are skipped by ssh,
so a fallback can stay listed while a key is being rolled over\.

*Type:*
(list of string) or string convertible to it

*Default:*

```nix
[
  "~/.ssh/id_ed25519"
]
```

*Declared by:*
 - [modules/common/pilot\.nix](../modules/common/pilot.nix)

## yomi\.playit\.enable

Whether to enable the playit\.gg tunneling service\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/playit\.nix](../modules/nixos/playit.nix)

## yomi\.playit\.secretPath

Path to the playit secret file

*Type:*
absolute path

*Declared by:*
 - [modules/nixos/playit\.nix](../modules/nixos/playit.nix)

## yomi\.ports

Fixed port allocation for Yomi services\. Each service sets its own entries next to its definition\.

*Type:*
lazy attribute set of 16 bit unsigned integer; between 0 and 65535 (both inclusive)

*Default:*

```nix
{ }
```

*Declared by:*
 - [modules/nixos/ports\.nix](../modules/nixos/ports.nix)

## yomi\.postgres\.enable

Whether to enable yomi’s postgres integration\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/postgres\.nix](../modules/nixos/postgres.nix)

## yomi\.protonMailSorter\.enable

Whether to enable automatic Proton sorting scheduled through n8n\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [hosts/nixos/inari/services/proton-mail-sorter](../hosts/nixos/inari/services/proton-mail-sorter)

## yomi\.protonMailSorter\.apiTokenRef

op:// reference to a random worker API token of at least 32 characters\.

*Type:*
string

*Default:*

```nix
""
```

*Declared by:*
 - [hosts/nixos/inari/services/proton-mail-sorter](../hosts/nixos/inari/services/proton-mail-sorter)

## yomi\.protonMailSorter\.apply

Apply private plans automatically\. False leaves mail and flags untouched\.

*Type:*
boolean

*Default:*

```nix
false
```

*Declared by:*
 - [hosts/nixos/inari/services/proton-mail-sorter](../hosts/nixos/inari/services/proton-mail-sorter)

## yomi\.protonMailSorter\.bridgeCertificateFile

Pinned public PEM of this Bridge instance; its SHA256 replaces bridgeCertificateSha256\.

*Type:*
null or absolute path

*Default:*

```nix
null
```

*Declared by:*
 - [hosts/nixos/inari/services/proton-mail-sorter](../hosts/nixos/inari/services/proton-mail-sorter)

## yomi\.protonMailSorter\.bridgeCertificateSha256

Verified SHA256 fingerprint of this Bridge instance’s TLS certificate\.

*Type:*
string

*Default:*

```nix
""
```

*Declared by:*
 - [hosts/nixos/inari/services/proton-mail-sorter](../hosts/nixos/inari/services/proton-mail-sorter)

## yomi\.protonMailSorter\.bridgeHost

Private address of an already authenticated Proton Mail Bridge\.

*Type:*
string

*Default:*

```nix
"127.0.0.1"
```

*Declared by:*
 - [hosts/nixos/inari/services/proton-mail-sorter](../hosts/nixos/inari/services/proton-mail-sorter)

## yomi\.protonMailSorter\.bridgePort

Bridge STARTTLS IMAP port, not the public Proton API\.

*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)

*Default:*

```nix
1143
```

*Declared by:*
 - [hosts/nixos/inari/services/proton-mail-sorter](../hosts/nixos/inari/services/proton-mail-sorter)

## yomi\.protonMailSorter\.keepFolders

Folder names under Folders/ never deleted when empty\. Every other empty folder outside the categories is removed\.

*Type:*
list of string matching the pattern \[^/]+

*Default:*

```nix
[ ]
```

*Example:*

```nix
[
  "Projekte"
]
```

*Declared by:*
 - [hosts/nixos/inari/services/proton-mail-sorter](../hosts/nixos/inari/services/proton-mail-sorter)

## yomi\.protonMailSorter\.labelExisting

Label mail already in category folders (Action, Steuer \<year>, Alias), once each, while there is nothing new to sort\.

*Type:*
boolean

*Default:*

```nix
true
```

*Declared by:*
 - [hosts/nixos/inari/services/proton-mail-sorter](../hosts/nixos/inari/services/proton-mail-sorter)

## yomi\.protonMailSorter\.markExistingRead

Also process categorized unread mail after each scheduled sorting job, leaving mail labelled Action unread\.

*Type:*
boolean

*Default:*

```nix
true
```

*Declared by:*
 - [hosts/nixos/inari/services/proton-mail-sorter](../hosts/nixos/inari/services/proton-mail-sorter)

## yomi\.protonMailSorter\.maxLabelMessages

Maximum already filed messages to label per job; most need one model call\.

*Type:*
integer between 1 and 1000 (both inclusive)

*Default:*

```nix
50
```

*Declared by:*
 - [hosts/nixos/inari/services/proton-mail-sorter](../hosts/nixos/inari/services/proton-mail-sorter)

## yomi\.protonMailSorter\.maxMessages

Maximum messages per background job; unchanged dry-run verdicts are cached\.

*Type:*
integer between 1 and 1000 (both inclusive)

*Default:*

```nix
50
```

*Declared by:*
 - [hosts/nixos/inari/services/proton-mail-sorter](../hosts/nixos/inari/services/proton-mail-sorter)

## yomi\.protonMailSorter\.maxReadMessages

Maximum already categorized unread messages to mark read per job, without AI\.

*Type:*
integer between 1 and 100000 (both inclusive)

*Default:*

```nix
1000
```

*Declared by:*
 - [hosts/nixos/inari/services/proton-mail-sorter](../hosts/nixos/inari/services/proton-mail-sorter)

## yomi\.protonMailSorter\.modelUrl

Base URL of the local llama\.cpp server running Qwen3\.5-9B; no automatic model substitution\.

*Type:*
string

*Default:*

```nix
"http://127.0.0.1:8496"
```

*Declared by:*
 - [hosts/nixos/inari/services/proton-mail-sorter](../hosts/nixos/inari/services/proton-mail-sorter)

## yomi\.protonMailSorter\.passwordRef

op:// reference to the Bridge password, not the Proton account password\.

*Type:*
string

*Default:*

```nix
""
```

*Declared by:*
 - [hosts/nixos/inari/services/proton-mail-sorter](../hosts/nixos/inari/services/proton-mail-sorter)

## yomi\.protonMailSorter\.serviceAccountTokenFile

Runtime 1Password service-account token, provisioned through sops; never a Nix store path\.

*Type:*
string

*Default:*

```nix
"/run/secrets/proton-mail-sorter-op-token"
```

*Declared by:*
 - [hosts/nixos/inari/services/proton-mail-sorter](../hosts/nixos/inari/services/proton-mail-sorter)

## yomi\.protonMailSorter\.usernameRef

op:// reference to the Bridge username in an automation-accessible vault\.

*Type:*
string

*Default:*

```nix
""
```

*Declared by:*
 - [hosts/nixos/inari/services/proton-mail-sorter](../hosts/nixos/inari/services/proton-mail-sorter)

## yomi\.releases\.enable

Whether to enable the public static release manifest endpoint on this gateway\.
Enable only after the DNS record resolves to the gateway and the
manifests are provisioned under ` directory `\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [hosts/nixos/ebisu/releases\.nix](../hosts/nixos/ebisu/releases.nix)

## yomi\.releases\.directory

Root-owned directory holding ` <host>/release.json ` and
` <host>/release.json.sig `, copied in by hand or by a root-run job\.
It must never be a path under /nix/store\.

*Type:*
string matching the pattern /\[^
]\*

*Default:*

```nix
"/var/lib/yomi-releases"
```

*Declared by:*
 - [hosts/nixos/ebisu/releases\.nix](../hosts/nixos/ebisu/releases.nix)

## yomi\.releases\.domain

Zone that holds the release endpoint\.

*Type:*
string

*Default:*

```nix
"hugo-berendi.de"
```

*Declared by:*
 - [hosts/nixos/ebisu/releases\.nix](../hosts/nixos/ebisu/releases.nix)

## yomi\.releases\.hosts

Yomi hosts whose ` release.json ` and ` release.json.sig ` are published at ` /<host>/ `\.

*Type:*
list of string matching the pattern \[a-z0-9](\[a-z0-9-]\*\[a-z0-9])?

*Default:*

```nix
[
  "inari"
]
```

*Declared by:*
 - [hosts/nixos/ebisu/releases\.nix](../hosts/nixos/ebisu/releases.nix)

## yomi\.releases\.port

Loopback port for the static responder, behind Traefik\. Not in
yomi\.ports, because that registry is consumed by the home fleet;
8522 is unused there and Ebisu’s public ports are 80, 443, 21820
and 51820\.

*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)

*Default:*

```nix
8522
```

*Declared by:*
 - [hosts/nixos/ebisu/releases\.nix](../hosts/nixos/ebisu/releases.nix)

## yomi\.releases\.subdomain

Label under ` domain ` that serves the manifests\.

*Type:*
string matching the pattern \[a-z0-9](\[a-z0-9-]\*\[a-z0-9])?

*Default:*

```nix
"releases"
```

*Declared by:*
 - [hosts/nixos/ebisu/releases\.nix](../hosts/nixos/ebisu/releases.nix)

## yomi\.restic\.enable

Whether to enable yomi’s restic backup integration\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/restic\.nix](../modules/nixos/restic.nix)

## yomi\.restic\.extraOptions

Extra restic options, e\.g\. the ssh key for an sftp repository\.

*Type:*
list of string

*Default:*

```nix
[ ]
```

*Example:*

```nix
[
  "sftp.args='-i /home/user/.ssh/id_ed25519'"
]
```

*Declared by:*
 - [modules/nixos/restic\.nix](../modules/nixos/restic.nix)

## yomi\.restic\.offsite\.enable

Whether to enable a second restic repository on storage that does not share a failure
domain with this machine\.

The repositories above live on a pool inside the same box, which
covers losing a disk but not losing the box
\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/restic\.nix](../modules/nixos/restic.nix)

## yomi\.restic\.offsite\.exclude

Extra exclude patterns for the off-site set\.

*Type:*
list of string

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/restic\.nix](../modules/nixos/restic.nix)

## yomi\.restic\.offsite\.paths

Paths to send off-site\. Deliberately separate from the local sets:
this is metered storage, so it should hold what cannot be
reacquired, not everything\.

*Type:*
list of string

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/restic\.nix](../modules/nixos/restic.nix)

## yomi\.restic\.offsite\.pruneOpts

Retention for the off-site set\. Longer than the local sets by
design: this is the copy that survives the house\.

*Type:*
list of string

*Default:*

```nix
[
  "--keep-daily 7"
  "--keep-weekly 4"
  "--keep-monthly 12"
  "--keep-yearly 3"
]
```

*Declared by:*
 - [modules/nixos/restic\.nix](../modules/nixos/restic.nix)

## yomi\.restic\.offsite\.sopsFile

Secrets file providing b2_bucket, b2_account_id and b2_account_key\.

This module lives in common/, so a relative path here would resolve
against common/ and miss the per-host file the credentials actually
belong in\. backup_password stays in common/secrets\.yaml because it is
genuinely shared\.

*Type:*
absolute path

*Example:*

```nix
./secrets.yaml
```

*Declared by:*
 - [modules/nixos/restic\.nix](../modules/nixos/restic.nix)

## yomi\.restic\.repository

Base restic repository\. Each backup set appends its own name, so a
local path and an sftp target both work\.

*Type:*
null or string

*Default:*

```nix
null
```

*Example:*

```nix
"sftp:user@host:backups"
```

*Declared by:*
 - [modules/nixos/restic\.nix](../modules/nixos/restic.nix)

## yomi\.restic\.sets

Named backup and check jobs\. Paths, credentials, retention and prerequisite units belong to each set\.

*Type:*
attribute set of (submodule)

*Default:*

```nix
{ }
```

*Declared by:*
 - [modules/nixos/restic\.nix](../modules/nixos/restic.nix)

## yomi\.restic\.sets\.\<name>\.enable

Enable this backup job\.

*Type:*
boolean

*Default:*

```nix
true
```

*Declared by:*
 - [modules/nixos/restic\.nix](../modules/nixos/restic.nix)

## yomi\.restic\.sets\.\<name>\.checkOpts

Integrity check arguments\.

*Type:*
list of string

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/restic\.nix](../modules/nixos/restic.nix)

## yomi\.restic\.sets\.\<name>\.environmentFile

Runtime environment file providing backend credentials\.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*
 - [modules/nixos/restic\.nix](../modules/nixos/restic.nix)

## yomi\.restic\.sets\.\<name>\.exclude

Restic exclusion patterns\.

*Type:*
list of string

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/restic\.nix](../modules/nixos/restic.nix)

## yomi\.restic\.sets\.\<name>\.extraBackupArgs

Additional backup arguments\.

*Type:*
list of string

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/restic\.nix](../modules/nixos/restic.nix)

## yomi\.restic\.sets\.\<name>\.extraOptions

Restic backend options\.

*Type:*
list of string

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/restic\.nix](../modules/nixos/restic.nix)

## yomi\.restic\.sets\.\<name>\.initialize

Initialize the repository when missing\.

*Type:*
boolean

*Default:*

```nix
false
```

*Declared by:*
 - [modules/nixos/restic\.nix](../modules/nixos/restic.nix)

## yomi\.restic\.sets\.\<name>\.passwordFile

Runtime repository password file\.

*Type:*
string

*Default:*

```nix
"/run/secrets/backup_password"
```

*Declared by:*
 - [modules/nixos/restic\.nix](../modules/nixos/restic.nix)

## yomi\.restic\.sets\.\<name>\.paths

Explicit paths to back up; an empty set can run checks only\.

*Type:*
list of string

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/restic\.nix](../modules/nixos/restic.nix)

## yomi\.restic\.sets\.\<name>\.pruneOpts

Retention and prune arguments\.

*Type:*
list of string

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/restic\.nix](../modules/nixos/restic.nix)

## yomi\.restic\.sets\.\<name>\.repository

Restic repository, mutually exclusive with repositoryFile\.

*Type:*
null or string

*Default:*

```nix
"sftp:restic-amaterasu@inari-restic:/data/‹name›"
```

*Declared by:*
 - [modules/nixos/restic\.nix](../modules/nixos/restic.nix)

## yomi\.restic\.sets\.\<name>\.repositoryFile

Runtime file containing the repository URL\.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*
 - [modules/nixos/restic\.nix](../modules/nixos/restic.nix)

## yomi\.restic\.sets\.\<name>\.requires

Units required to complete before backup, such as database dumps\.

*Type:*
list of string

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/restic\.nix](../modules/nixos/restic.nix)

## yomi\.restic\.sets\.\<name>\.timerConfig

Native systemd timer settings\.

*Type:*
attribute set of anything

*Default:*

```nix
{
  OnCalendar = "daily";
  Persistent = true;
}
```

*Declared by:*
 - [modules/nixos/restic\.nix](../modules/nixos/restic.nix)

## yomi\.restic\.sopsFile

Encrypted file providing the shared backup_password secret\.

*Type:*
absolute path

*Declared by:*
 - [modules/nixos/restic\.nix](../modules/nixos/restic.nix)

## yomi\.shellTheme\.css

Returns a shell palette color suitable for CSS

*Type:*
function that evaluates to a(n) string

*Declared by:*
 - [modules/common/theming/shell\.nix](../modules/common/theming/shell.nix)

## yomi\.shellTheme\.opacity\.elevated

Opacity used by elevated shell surfaces

*Type:*
floating point number

*Declared by:*
 - [modules/common/theming/shell\.nix](../modules/common/theming/shell.nix)

## yomi\.shellTheme\.opacity\.muted

Opacity used by subdued shell elements

*Type:*
floating point number

*Declared by:*
 - [modules/common/theming/shell\.nix](../modules/common/theming/shell.nix)

## yomi\.shellTheme\.opacity\.panel

Opacity used by shell panels

*Type:*
floating point number

*Declared by:*
 - [modules/common/theming/shell\.nix](../modules/common/theming/shell.nix)

## yomi\.shellTheme\.palette

Semantic shell colors derived from the active Stylix scheme

*Type:*
attribute set of string

*Default:*

```nix
{ }
```

*Declared by:*
 - [modules/common/theming/shell\.nix](../modules/common/theming/shell.nix)

## yomi\.shellTheme\.rgba

Returns a shell palette color with the requested CSS alpha value

*Type:*
function that evaluates to a(n) function that evaluates to a(n) string

*Declared by:*
 - [modules/common/theming/shell\.nix](../modules/common/theming/shell.nix)

## yomi\.ssh\.extraHostNames

Additional hostnames that resolve to this machine and are served by its
sshd\. Other hosts pin the names listed for this host in
profiles/inventory\.nix; this must match that entry\.

*Type:*
list of string

*Default:*

```nix
[ ]
```

*Example:*

```nix
[
  "ssh.git.example.com"
]
```

*Declared by:*
 - [profiles/services/openssh\.nix](../profiles/services/openssh.nix)

## yomi\.t3codeVm\.enable

Whether to enable the t3code Ubuntu guest VM\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [hosts/nixos/inari/services/t3code/vm](../hosts/nixos/inari/services/t3code/vm)

## yomi\.t3codeVm\.credentialFiles

Allowlisted pilot credential files copied independently when present\.

*Type:*
list of string

*Default:*

```nix
[
  "~/.codex/auth.json"
  "~/.claude/.credentials.json"
  "~/.local/share/opencode/auth.json"
]
```

*Declared by:*
 - [hosts/nixos/inari/services/t3code/vm/bootstrap\.nix](../hosts/nixos/inari/services/t3code/vm/bootstrap.nix)

## yomi\.t3codeVm\.guestHostKeyFile

Persistent guest host ed25519 private key consumed by the parent seed provisioner\.

*Type:*
absolute path

*Default:*

```nix
"/var/lib/t3code-vm/guest_host_ed25519"
```

*Declared by:*
 - [hosts/nixos/inari/services/t3code/vm/bootstrap\.nix](../hosts/nixos/inari/services/t3code/vm/bootstrap.nix)

## yomi\.t3codeVm\.guestHostPublicKeyFile

Guest host public key consumed by the parent seed provisioner\.

*Type:*
absolute path

*Default:*

```nix
"/var/lib/t3code-vm/guest_host_ed25519.pub"
```

*Declared by:*
 - [hosts/nixos/inari/services/t3code/vm/bootstrap\.nix](../hosts/nixos/inari/services/t3code/vm/bootstrap.nix)

## yomi\.t3codeVm\.guestSetupScript

Optional guest setup script embedded in cloud-init\.

*Type:*
null or absolute path

*Default:*

```nix
null
```

*Declared by:*
 - [hosts/nixos/inari/services/t3code/vm](../hosts/nixos/inari/services/t3code/vm)

## yomi\.t3codeVm\.imageSha256

SHA-256 checksum for imageUrl\.

*Type:*
string

*Default:*

```nix
"6a81c37564db9b1ee84e141922625e1d7c5b389b99bb3c572e0243607d5bb4d2"
```

*Declared by:*
 - [hosts/nixos/inari/services/t3code/vm](../hosts/nixos/inari/services/t3code/vm)

## yomi\.t3codeVm\.imageUrl

Pinned official Ubuntu cloud image URL\.

*Type:*
string

*Default:*

```nix
"https://cloud-images.ubuntu.com/noble/20260926/noble-server-cloudimg-amd64.img"
```

*Declared by:*
 - [hosts/nixos/inari/services/t3code/vm](../hosts/nixos/inari/services/t3code/vm)

## yomi\.t3codeVm\.localUrl

Local T3 server URL used for host-side linking\.

*Type:*
string

*Default:*

```nix
"http://127.0.0.1:8501"
```

*Declared by:*
 - [hosts/nixos/inari/services/t3code/vm/bootstrap\.nix](../hosts/nixos/inari/services/t3code/vm/bootstrap.nix)

## yomi\.t3codeVm\.managementKeyFile

Runtime path to the host management public key\.

*Type:*
absolute path

*Default:*

```nix
"/var/lib/t3code-vm/ssh_key.pub"
```

*Declared by:*
 - [hosts/nixos/inari/services/t3code/vm](../hosts/nixos/inari/services/t3code/vm)

## yomi\.t3codeVm\.pilot

Local pilot account that owns the host T3 link\.

*Type:*
string

*Default:*

```nix
"hugob"
```

*Declared by:*
 - [hosts/nixos/inari/services/t3code/vm/bootstrap\.nix](../hosts/nixos/inari/services/t3code/vm/bootstrap.nix)

## yomi\.t3codeVm\.providerInstances

Verified T3 provider-instance settings applied through server\.updateSettings\.

*Type:*
attribute set of anything

*Default:*

```nix
{ }
```

*Declared by:*
 - [hosts/nixos/inari/services/t3code/vm/bootstrap\.nix](../hosts/nixos/inari/services/t3code/vm/bootstrap.nix)

## yomi\.t3codeVm\.provisionAfter

Additional units ordered before VM provisioning\.

*Type:*
list of string

*Default:*

```nix
[ ]
```

*Declared by:*
 - [hosts/nixos/inari/services/t3code/vm](../hosts/nixos/inari/services/t3code/vm)

## yomi\.t3codeVm\.provisionRequires

Additional units required before VM provisioning\.

*Type:*
list of string

*Default:*

```nix
[ ]
```

*Declared by:*
 - [hosts/nixos/inari/services/t3code/vm](../hosts/nixos/inari/services/t3code/vm)

## yomi\.t3codeVm\.toolingPackage

Optional shared tooling package made available to guest setup\.

*Type:*
null or package

*Default:*

```nix
null
```

*Declared by:*
 - [hosts/nixos/inari/services/t3code/vm](../hosts/nixos/inari/services/t3code/vm)

## yomi\.terminal\.command

Command used to launch the preferred terminal\.

*Type:*
non-empty string

*Declared by:*
 - [modules/common/terminal\.nix](../modules/common/terminal.nix)

## yomi\.terminal\.execCommand

Terminal command prefix used to execute another command\.

*Type:*
non-empty string

*Declared by:*
 - [modules/common/terminal\.nix](../modules/common/terminal.nix)

## yomi\.theming\.blur\.brightness

Brightness multiplier applied to blurred backgrounds

*Type:*
signed integer

*Default:*

```nix
1
```

*Declared by:*
 - [modules/common/theming/options\.nix](../modules/common/theming/options.nix)

## yomi\.theming\.blur\.contrast

Contrast multiplier applied to blurred backgrounds

*Type:*
signed integer

*Default:*

```nix
1
```

*Declared by:*
 - [modules/common/theming/options\.nix](../modules/common/theming/options.nix)

## yomi\.theming\.blur\.passes

Number of blur passes (more passes = smoother blur)

*Type:*
signed integer

*Default:*

```nix
4
```

*Declared by:*
 - [modules/common/theming/options\.nix](../modules/common/theming/options.nix)

## yomi\.theming\.blur\.size

Blur kernel size in pixels

*Type:*
signed integer

*Default:*

```nix
10
```

*Declared by:*
 - [modules/common/theming/options\.nix](../modules/common/theming/options.nix)

## yomi\.theming\.colors\.colorToRgb

Converts a color name (e\.g\., “base08”) to an ` rgb() ` string\.
It extracts the hex value from ` config.lib.stylix.colors.withHashtag ` and converts it to an RGB string\.

*Type:*
function that evaluates to a(n) string

*Declared by:*
 - [modules/common/theming/options\.nix](../modules/common/theming/options.nix)

## yomi\.theming\.colors\.hexToRgb

Converts a hex color (e\.g\., ‘\#FF5733’) to an ` rgb() ` string (e\.g\., ‘rgb(255, 87, 51)’)\.

*Type:*
function that evaluates to a(n) string

*Declared by:*
 - [modules/common/theming/options\.nix](../modules/common/theming/options.nix)

## yomi\.theming\.colors\.hexWithoutHash

remove \# from a hex color

*Type:*
function that evaluates to a(n) string

*Declared by:*
 - [modules/common/theming/options\.nix](../modules/common/theming/options.nix)

## yomi\.theming\.colors\.rgb

Returns comma separated rgb values for a color\. To be used in css files:)

*Type:*
function that evaluates to a(n) string

*Declared by:*
 - [modules/common/theming/options\.nix](../modules/common/theming/options.nix)

## yomi\.theming\.colors\.rgb-attrs

Returns attrset rgb values for a color\.)

*Type:*
function that evaluates to a(n) (attribute set)

*Declared by:*
 - [modules/common/theming/options\.nix](../modules/common/theming/options.nix)

## yomi\.theming\.colors\.rgba

Returns comma separated rgba values for a color\.
The transparency is taken from ` options.yomi.theming.transparency `\.

*Type:*
function that evaluates to a(n) string

*Declared by:*
 - [modules/common/theming/options\.nix](../modules/common/theming/options.nix)

## yomi\.theming\.colors\.rgba-attrs

Returns attrset rgba values for a color\.)

*Type:*
function that evaluates to a(n) (attribute set)

*Declared by:*
 - [modules/common/theming/options\.nix](../modules/common/theming/options.nix)

## yomi\.theming\.gaps\.inner

Inner gaps (padding) in pixels

*Type:*
signed integer

*Default:*

```nix
0
```

*Declared by:*
 - [modules/common/theming/options\.nix](../modules/common/theming/options.nix)

## yomi\.theming\.gaps\.outer

Outer gaps (margins) in pixels

*Type:*
signed integer

*Default:*

```nix
0
```

*Declared by:*
 - [modules/common/theming/options\.nix](../modules/common/theming/options.nix)

## yomi\.theming\.get

Index a theme map by the current theme

*Type:*
function that evaluates to a(n) anything

*Declared by:*
 - [modules/common/theming/options\.nix](../modules/common/theming/options.nix)

## yomi\.theming\.rounding\.radius

Corner radius in pixels

*Type:*
signed integer

*Default:*

```nix
0
```

*Declared by:*
 - [modules/common/theming/options\.nix](../modules/common/theming/options.nix)

## yomi\.theming\.rounding\.size

Rounding size in pixels

*Type:*
signed integer

*Default:*

```nix
0
```

*Declared by:*
 - [modules/common/theming/options\.nix](../modules/common/theming/options.nix)

## yomi\.web\.at

HTTP endpoints with one selected transport and explicit authentication ownership\.

*Type:*
attribute set of (submodule)

*Default:*

```nix
{ }
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.enable

Whether to publish this endpoint and its DNS and monitoring records\.

*Type:*
boolean

*Default:*

```nix
true
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.enableAnubis

Whether to enable Anubis protection on Pangolin\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.authentication

Who authenticates requests; none deliberately permits anonymous access\.

*Type:*
one of “application”, “gateway”, “none”

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.clientMaxBodySize

Largest request body nginx accepts (nginx transport only); null keeps nginx’s 1M default\.

*Type:*
null or string

*Default:*

```nix
null
```

*Example:*

```nix
"50M"
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.dns\.enable

Manage a DNS record; disable for externally managed hostnames\.

*Type:*
boolean

*Default:*

```nix
true
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.dns\.name

Record name relative to dns\.zone; empty means the apex\.

*Type:*
string

*Default:*

```nix
"‹name›"
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.dns\.zone

Managed DNS zone\.

*Type:*
string

*Default:*

```nix
"hugo-berendi.de"
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.host

Hostname served by this endpoint\.

*Type:*
string

*Default:*

```nix
"‹name›.hugo-berendi.de"
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.monitor\.enable

Whether to enable a Gatus health check for this endpoint\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.monitor\.conditions

Expected Gatus responses; configure authentication and redirects explicitly\.

*Type:*
list of string

*Default:*

```nix
[
  "[STATUS] == 200"
  "[RESPONSE_TIME] < 2000"
]
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.monitor\.group

Health check group\.

*Type:*
string

*Default:*

```nix
"Services"
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.monitor\.interval

Gatus check interval\.

*Type:*
string

*Default:*

```nix
"1m"
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.monitor\.name

Health check display name\.

*Type:*
string

*Default:*

```nix
"‹name›"
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.monitor\.path

Health check path appended to the public URL\.

*Type:*
string matching the pattern (/\.\*)?

*Default:*

```nix
""
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.pangolin

Pangolin-specific access and backend policy\.

*Type:*
submodule

*Default:*

```nix
{ }
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.pangolin\.additionalTargets

Additional backend targets for load balancing; incompatible with the single-backend Anubis wrapper\.

*Type:*
list of (submodule)

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.pangolin\.additionalTargets\.\*\.hostname

Address as seen from Newt\.

*Type:*
string

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.pangolin\.additionalTargets\.\*\.method

Backend protocol\.

*Type:*
one of “http”, “https”

*Default:*

```nix
"http"
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.pangolin\.additionalTargets\.\*\.port

Backend port\.

*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.pangolin\.allowAuthBypass

Explicitly permit allow rules, which bypass all Pangolin authentication\.

*Type:*
boolean

*Default:*

```nix
false
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.pangolin\.allowedCountries

Country allowlist; permitted countries pass to authentication, all other and unknown countries are denied\.

*Type:*
list of string matching the pattern \[A-Z]{2}

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.pangolin\.blockedASNs

Deny these autonomous system numbers before any custom allow/pass rules\. Requires GeoIP and ASN data\.

*Type:*
list of (positive integer, meaning >0)

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.pangolin\.blockedCountries

Deny these ISO country codes before any custom allow/pass rules\. Requires GeoIP on the gateway\.

*Type:*
list of string matching the pattern \[A-Z]{2}

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.pangolin\.healthCheck\.enable

Whether to enable backend HTTP health checks, independently of SSO and Anubis\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.pangolin\.healthCheck\.interval

Probe interval in seconds\.

*Type:*
positive integer, meaning >0

*Default:*

```nix
30
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.pangolin\.healthCheck\.path

Backend health path\.

*Type:*
string matching the pattern /\.\*

*Default:*

```nix
"/"
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.pangolin\.healthCheck\.status

Expected health response code\.

*Type:*
integer between 100 and 599 (both inclusive)

*Default:*

```nix
200
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.pangolin\.healthCheck\.timeout

Probe timeout in seconds\.

*Type:*
positive integer, meaning >0

*Default:*

```nix
5
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.pangolin\.hostHeader

Override the backend Host header for applications with a canonical internal URL\.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.pangolin\.labels

Resource labels for filtering in Pangolin\.

*Type:*
list of string

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.pangolin\.roles

Roles permitted by gateway authentication\.

*Type:*
list of string

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.pangolin\.rules

Ordered resource access rules\. Allow bypasses authentication and requires allowAuthBypass\.

*Type:*
list of (submodule)

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.pangolin\.rules\.\*\.action

Block, continue to authentication, or bypass authentication\.

*Type:*
one of “deny”, “pass”, “allow”

*Default:*

```nix
"deny"
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.pangolin\.rules\.\*\.match

Rule matcher\. Country and ASN matchers require gateway GeoIP databases\.

*Type:*
one of “ip”, “cidr”, “path”, “method”, “country”, “country_is_not”, “asn”

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.pangolin\.rules\.\*\.value

Matcher value\.

*Type:*
string

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.pangolin\.users

Users permitted by gateway authentication\.

*Type:*
list of string

*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.port

HTTP application port; defaults to the registry entry of the same name\.

*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)

*Default:*

```nix
config.yomi.ports.<name>
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.protocol

Protocol spoken by the upstream HTTP application\.

*Type:*
one of “http”, “https”

*Default:*

```nix
"http"
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.proxyAddress

Upstream address, with brackets around an IPv6 literal\.

*Type:*
string

*Default:*

```nix
"localhost"
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.publicReason

Why this endpoint lets anyone on the internet in without a login\.
A Pangolin endpoint with ` authentication = "none" ` draws a warning
until this says why; an nginx endpoint is private (LAN and
Pangolin private resources) and needs no reason\.

*Type:*
null or string

*Default:*

```nix
null
```

*Example:*

```nix
"the personal website"
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.stagePangolin

Whether to enable previewing this endpoint in the blueprint while the connector is disabled\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.subdomain

Default DNS name within the provider’s domain; empty means the zone apex\.

*Type:*
string

*Default:*

```nix
"‹name›"
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.transport

Transport responsible for this endpoint’s publication and DNS\.

*Type:*
one of “nginx”, “pangolin”

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.web\.at\.\<name>\.url

Derived public HTTPS URL\.

*Type:*
string *(read only)*

*Default:*

```nix
"https://‹name›.hugo-berendi.de"
```

*Declared by:*
 - [modules/nixos/web\.nix](../modules/nixos/web.nix)

## yomi\.wireless\.enable

Whether to enable yomi’s WIFI integration\.

*Type:*
boolean

*Default:*

```nix
true
```

*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos/wireless](../modules/nixos/wireless)

## yomi\.wireless\.backend

Determines which backend should be used for WIFI connectivity\.

*Type:*
value “networkmanager” (singular enum)

*Default:*

```nix
"networkmanager"
```

*Declared by:*
 - [modules/nixos/wireless](../modules/nixos/wireless)

## yomi\.wireless\.sopsFile

sops file holding the wireless secret (the PSK environment variables)\.

*Type:*
absolute path

*Declared by:*
 - [modules/nixos/wireless](../modules/nixos/wireless)

# Home Manager

## yomi\.ai\.mcp

Shared MCP server configurations for AI coding assistants

*Type:*
attribute set

*Default:*

```nix
{ }
```

*Declared by:*
 - [home/features/cli/ai/mcp\.nix](../home/features/cli/ai/mcp.nix)

## yomi\.ai\.mcpRemote

Remote MCP server configurations (HTTP-based)

*Type:*
attribute set

*Default:*

```nix
{ }
```

*Declared by:*
 - [home/features/cli/ai/mcp\.nix](../home/features/cli/ai/mcp.nix)

## yomi\.monitors

This option has no description\.

*Type:*
list of (submodule)

*Declared by:*
 - [modules/home-manager/monitors\.nix](../modules/home-manager/monitors.nix)

## yomi\.monitors\.\*\.height

Monitor height in pixels

*Type:*
signed integer

*Example:*

```nix
1080
```

*Declared by:*
 - [modules/home-manager/monitors\.nix](../modules/home-manager/monitors.nix)

## yomi\.monitors\.\*\.name

Monitor identifier (e\.g\. output name)

*Type:*
string

*Example:*

```nix
"DP-1"
```

*Declared by:*
 - [modules/home-manager/monitors\.nix](../modules/home-manager/monitors.nix)

## yomi\.monitors\.\*\.refreshRate

Refresh rate in Hz

*Type:*
signed integer

*Default:*

```nix
60
```

*Declared by:*
 - [modules/home-manager/monitors\.nix](../modules/home-manager/monitors.nix)

## yomi\.monitors\.\*\.width

Monitor width in pixels

*Type:*
signed integer

*Example:*

```nix
1920
```

*Declared by:*
 - [modules/home-manager/monitors\.nix](../modules/home-manager/monitors.nix)

## yomi\.monitors\.\*\.workspace

Workspace to assign to this monitor (null for none)

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*
 - [modules/home-manager/monitors\.nix](../modules/home-manager/monitors.nix)

## yomi\.monitors\.\*\.x

Monitor X position (horizontal offset in pixels)

*Type:*
signed integer

*Default:*

```nix
0
```

*Declared by:*
 - [modules/home-manager/monitors\.nix](../modules/home-manager/monitors.nix)

## yomi\.monitors\.\*\.y

Monitor Y position (vertical offset in pixels)

*Type:*
signed integer

*Default:*

```nix
0
```

*Declared by:*
 - [modules/home-manager/monitors\.nix](../modules/home-manager/monitors.nix)

## yomi\.sessionMenu

Command that toggles the session menu, for keybinds and bar buttons

*Type:*
string *(read only)*

*Declared by:*
 - [home/features/wayland/wlogout\.nix](../home/features/wayland/wlogout.nix)

