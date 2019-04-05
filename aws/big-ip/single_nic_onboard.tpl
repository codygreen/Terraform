{
    "schemaVersion": "1.0.0",
    "class": "Device",
	"async": true,
    "Common": {
    	"class": "Tenant",
        "hostname": "bigip.f5demos.com",
        "myDns": {
            "class": "DNS",
            "nameServers": [
            	"10.0.0.2"
            ],
            "search": [
                "f5demos.com"
            ]
        },
        "myNtp": {
            "class": "NTP",
            "servers": [
            	"169.254.169.123"
            ],
            "timezone": "UTC"
        },
        "myProvisioning": {
        	"class": "Provision",
        	"ltm": "nominal"
        }
    }
}