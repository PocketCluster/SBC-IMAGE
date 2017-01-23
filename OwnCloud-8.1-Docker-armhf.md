### Install & run mysql Docker container
```
docker run --restart=always -d --name oc-mysql -e MYSQL_ROOT_PASSWORD=secret -e MYSQL_DATABASE=oc -e MYSQL_USER=oc -e MYSQL_PASSWORD=oc armv7/armhf-mysql:5.5
```

### Install & run OwnCloud Docker container
```
docker run --restart=always -d --link oc-mysql:mysql -p 80:80 --name oc armv7/armhf-owncloud:8.1
```
### Run OC in browser, set admin account name and pw then stop OwnCloud Container
```
docker stop oc
```

### switch to mysql database 

Start a volatile OwnCloud Container for maintenance
```
docker run -ti --volumes-from oc --link oc-mysql:mysql --rm armv7/armhf-owncloud:8.1 bash
```
Inside of the container install `sudo`:
```
<<<>>> apt-get update && apt-get -y install sudo
````
Switch to mysql in the OwnCloud Configuration, see [here](https://doc.owncloud.org/server/8.1/admin_manual/configuration_database/db_conversion.html) for more information.
```
<<<>>> sudo -u www-data php occ db:convert-type --all-apps --password="oc" mysql "$MYSQL_ENV_MYSQL_USER" "oc-mysql" "$MYSQL_ENV_MYSQL_DATABASE"
<<<>>> exit
```

### Restart OwnCloud container
```
docker restart oc
```

### Finalize OwnCloud admin settings

- Run OwnCloud in your browser, enable encryption and external storage apps, enable calendar and contacts apps

- Activate server encryption in [admin settings] (https://doc.owncloud.org/server/8.1/admin_manual/configuration_files/encryption_configuration.html)

- Log off and log on again to OwnCloud (takes some time until user encryption keys are generated)

- Set a recovery key in Owncloud admin settings

- External storage via SMB/CIFS requires smbclient package (and SMBFS support in linux kernel)
```
docker exec -ti oc bash -c "apt-get update && apt-get -y install smbclient && rm -rf /var/lib/apt/lists/*"
```

docker exec -ti oc bash -c "a2enmod headers"