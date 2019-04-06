{
    "$schema": "https://raw.githubusercontent.com/F5Networks/f5-appsvcs-extension/master/schema/latest/as3-schema-3.9.0-3.json",
    "class": "AS3",
    "action": "deploy",
    "persist": true,
    "declaration": {
        "class": "ADC",
        "schemaVersion": "3.9.0",
        "id": "example-declaration-01",
        "label": "Sample 1",
        "remark": "Simple HTTP application with round robin pool",
        "Sample_01": {
            "class": "Tenant",
            "defaultRouteDomain": 0,
            "Application_1": {
                "class": "Application",
                "template": "https",
                "serviceMain": {
                    "class": "Service_HTTPS",
                    "virtualAddresses": [
                        "${public_ip}"
                    ],
                    "pool": "web_pool",
                    "serverTLS": "webtls"
                },
                "web_pool": {
                    "class": "Pool",
                    "monitors": [
                        "http"
                    ],
                    "members": [{
                        "servicePort": 80,
                        "addressDiscovery": "fqdn",
                        "autoPopulate": true,
                        "hostname": "f5-demo.f5demos.local"
                    }]
                },
                "webtls": {
                    "class": "TLS_Server",
                    "certificates": [{
                        "certificate": "webcert"
                    }],
                    "authenticationTrustCA": "LetsEncryptCA"
                },
                "webcert": {
                    "class": "Certificate",
                    "remark": "in practice we recommend using a passphrase",
                    "certificate": ${cert},
                    "privateKey": ${key}
                },
                "LetsEncryptCA": {
                    "class": "CA_Bundle",
                    "bundle": ${ca}
                }
            }
        }
    }
}