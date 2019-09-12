FROM centos:latest

MAINTAINER Secure Dimensions <support@secure-dimensions.de>

#ENV DEBIAN_FRONTEND noninteractive
RUN rpm -Uvh http://elgis.argeo.org/repos/6/elgis-release-6-6_0.noarch.rpm
RUN yum install -y centos-release-scl epel-release
RUN yum install -y yum install ansible python27 libtiff libgeotiff libgdata openssl xslt xmlsec1 xmlsec1-openssl

COPY ansible/* /etc/ansible/

COPY mod_authz_geopep/mod_authz_geopep.so /usr/lib/apache2/modules/
COPY mod_authz_geopep/libboost_system.* /usr/lib/
COPY mod_authz_geopep/libboost_locale* /usr/lib/
COPY mod_authz_geopep/libboost_iostreams* /usr/lib/
COPY mod_authz_geopep/libz* /usr/lib/
COPY apache2/html/ /var/www/html/
COPY apache2/config/geopep.conf /etc/apache2/sites-enabled/
RUN ls -r /var/www/html

RUN ansible-playbook -i "localhost," -c local /etc/ansible/site.yml

RUN yum remove -y centos-release-ansible26 python27

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 80

CMD ["apache2-reverse-proxy"]
