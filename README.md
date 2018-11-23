# geopep-apache2-reverse-proxy
Dockerized apache2 reverse proxy service including 'mod_authz_geopep'.

## Description
This project enables you to build a docker container that acts as an Apache2 reverse proxy
that includes the access control module 'mod_authz_geopep' (geoPEP) available from [Secure Dimensions](https://www.secure-dimensions.de).

Once you've created and launched the 'geopep-apache2-reverse-proxy' container, it intercepts all HTTP (or HTTPS) based on the
Apache2 reverse proxy configuration that you configure (details below) and applies standardized authorization decisions received 
from the 'geoPDP' module based on a GeoXACML policy. How to build and run a docker container for the 'geoPDP' is described [here](todo).

## Build the docker image
**Make sure you have 'ansible' installed!**

Change directory to where you like to clone this repository. For the ease of description, let's assume that this is '/opt'.

Now, clone this repository with
```
git clone https://github.com/securedimensions/geopep-apache2-reverse-proxy.git
```

Next go into the directory 'ansible' ('cd /opt/geopep-apache2-reverse-proxy/ansible') and 
get the content of ansible directory by running:
```
git clone https://github.com/jmferrer/ansible-apache2-reverse-proxy.git
```

Then, 'cd ..' and build the docker image with (you should be in directory '/opt/geopep-apache2-reverse-proxy'):
```
docker build -t apache2-reverse-proxy:debian8 .
```

## Creating the 'geopep' container to listen on HTTP
After creating your Apache2 virtualhosts configuration file in '/opt/geopep-apache2-reverse-proxy/apache2/config' create the docker container with:
```
docker create --name geopep --hostname apache2-reverse-proxy -p 80:80 -v /opt/geopep-apache2-reverse-proxy/apache2/config:/etc/apache2/sites-enabled apache2-reverse-proxy:debian8
```
The above command exposes the HTTP port 80. You can change the listen port of your machine via the first number. So for example -p88:80 exposes the geopep on port 88.

## Creating the 'geopep' container to listen on HTTPS
To setup an Apache2 that is able to listen to HTTP (typically on port 443) you need to configure SSL options in you virtualhosts configuration file.
For the ease of the setup, you can put the required files into this directory '/opt/geopep-apache2-reverse-proxy/apache2/certs' and map the directory when creating the docker container:
```
docker create --name geopep --hostname apache2-reverse-proxy -p 443:443 -v /opt/geopep-apache2-reverse-proxy/apache2/config:/etc/apache2/sites-enabled /opt/geopep-apache2-reverse-proxy/apache2/certs:/etc/apache2/certs apache2-reverse-proxy:debian8
```

## Linking directories
Please use these linking as requird:
### logs
**-v /opt/geopep-apache2-reverse-proxy/apache2/logs:/var/log/apache2**
### ssl certificates
**-v /opt/geopep-apache2-reverse-proxy/apache2/certs:/etc/apache2/certs**

### virtualhosts
**-v /opt/geopep-apache2-reverse-proxy/apache2/config:/etc/apache2/sites-enabled**

## Start/stop the Apache2 reverse proxy
You can simply start the geopep with:
````
docker container start geopep
````
You can determine a successful startup using the 'netstat' command.

You can simply stop the geopep with:
````
docker container stop geopep
````

## Virtualhosts configuration example
The following configuration example exposes the geopep on and HTTP port and use as a backend 
a default [geoserver](http://http://geoserver.org/) deployment on a Secure Dimension server:
'http://demo.secure-dimensions.de/geoserver'

```
<VirtualHost *:80>
    ServerName <put the full qualified hostname here>

    <Location /geoserver>
	Require all granted

        GeoPEP.WMS      on
        GeoPDP.Host     <put the IP address of the machine that runs the geoPDP here>
        GeoPDP.Port     8080 #don't change this if you are using the geoPDP default configuration
        GeoPDP.Path     /authzforce-ce/domains/A0bdIbmGEeWhFwcKrC9gSQ/pdp #don't change this
        GeoPDP.Scheme   http #don't change this if you are using the geoPDP default configuration

        ProxyPass http://sp.landsense.secure-dimensions.de:8080/geoserver #You can change this to map your backend WMS
        ProxyPassReverse http://sp.landsense.secure-dimensions.de:8080/geoserver #You can change this to map your backend WMS
    </Location>


	LogLevel error
        ErrorLog /var/log/apache2/geopep-error.log
        CustomLog /var/log/apache2/geopep-access.log combined

</VirtualHost>
```

## Test the geoPEP
You can test the geoPEP deployment **after you have the geoPDP running** using the following example URLs. Using the example configuration for the Apache2 reverse proxy, these requests will be served by the Geoserver on http://demo.secure-dimensions.de

This WMS request will cause the geoPEP **not** to process the image (see uloaded image 1):
````
http://<THE IP OF YOUR MACHINE>/geoserver/topp/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&FORMAT=image%2Fpng&TRANSPARENT=true&LAYERS=topp%3Astates&TILED=true&access_token=200fcaad3e27d4387172ea93daea8686c706f0c9&WIDTH=320&HEIGHT=320&CRS=EPSG%3A3857&STYLES=&FORMAT_OPTIONS=dpi%3A113&BBOX=-7514065.628545966%2C5009377.085697312%2C-5009377.08569731%2C7514065.628545968
````
This WMS request will cause the geoPEP to **redact** the image (see uploaded image 2):
````
http://<THE IP OF YOUR MACHINE>/geoserver/topp/wms?service=WMS&version=1.1.0&request=GetMap&layers=topp:states&styles=&bbox=-124.73142200000001,24.955967,-66.969849,49.371735&width=768&height=330&srs=EPSG:4326&format=image%2Fpng
````

## Viewer example
You can use the OpenLayers based simple viewer to see the geoPEP working by opening your Web Browser using 
''''
http://<THE IP OF YOUR MACHINE>:<THE PORT THE geoPEP IS EXPOSED>/index.html
````
	
## More information
This example project uses a precompiled 'mod_authz_geopep' module for Debian Jessie (8.11).
If you are interested in other deployment options or a build for another platform, please contact us at [support](mailto:support@secure-dimensions.de)
