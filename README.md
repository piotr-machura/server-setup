# Personal server setup using Docker
Host operating system (only matters for the installation of docker): [CentOS 8 Stream](https://www.centos.org/centos-stream/) running in a rented VPS
with a custom domain. All of the standard security measures in place (SSL certificates from LetsEncrypt, firewall, SSH only via trusted key etc.).
Software running in containers using [Docker](https://docker.com/).

**Software**:

- [Web server](https://nginx.org/en/) hosting a static website, modified to automatically obtain and renew SSL certificates using [certbot](https://certbot.eff.org/).
- Full stack [email server](https://github.com/docker-mailserver/docker-mailserver).
- [Roundcube](https://roundcube.net/) webmail client located in  domain.com/mail
- [CardDAV](https://radicale.org/3.0.html) server for Roundcube's address book

Full setup documentation in English for future reference. Deployment with a single version controlled shell script (or a set of scripts if necessary).
