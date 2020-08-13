scriptOutput()
{
    green="$(tput setaf 2 2> /dev/null || true)"
    end="$(tput sgr0 2> /dev/null || true)"

    if [[ -n ${verbose-} ]]; then
        printf '%b%s%b\n' "$green" "$1" "$end"
    fi
}

backup()
{
    scriptOutput "Creating directories"
    createDirs

    scriptOutput "Dumping databases"
    dumpDbs

    scriptOutput "Copying files from /var/www"
    copyWebFiles

    scriptOutput "Copying configuration files"
    phpConfig
    apacheConfig

    if [[ -n ${archive-} ]]; then
        scriptOutput "Archiving backup"
        archive
    fi
    if [[ ! -n ${local-} ]]; then
        scriptOutput "Uploading to S3 bucket"
        moveToBucket
    fi

}

createDirs()
{
    mkdir -p "${BACKUP_DIR}/db"
    mkdir -p "${BACKUP_DIR}/docroot"
}

dumpDbs()
{
    local PASSWORD_ARG=""

    if [[ -n ${MYSQL_PASSWORD-} ]]; then
        PASSWORD_ARG="-p${MYSQL_PASSWORD}"
    fi

    databases=`${MYSQL} --user=${MYSQL_USER} ${PASSWORD_ARG} -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema)"`
 
    for db in $databases; do
        $MYSQLDUMP --force --opt --user=$MYSQL_USER --databases $db > "${BACKUP_DIR}/db/${db}.sql"
    done

    mygrants > "${BACKUP_DIR}/db/grants.sql"
}

mygrants()
{
    mysql -B -N $@ -e "SELECT DISTINCT CONCAT(
        'SHOW GRANTS FOR \'', user, '\'@\'', host, '\';'
        ) AS query FROM mysql.user" | \
    mysql $@ | \
    sed 's/\(GRANT .*\)/\1;/;s/^\(Grants for .*\)/## \1 ##/;/##/{x;p;x;}'
}

copyWebFiles()
{
    $RSYNC -r /var/www/* "${BACKUP_DIR}/docroot/"
}

# Firewalld
firewalldConfig()
{
    mkdir -p "${BACKUP_DIR}/configs/firewalld"
    $RSYNC /etc/firewalld/zones/public.xml "${BACKUP_DIR}/configs/firewalld/"
}

# php-fpm
phpConfig()
{
    mkdir -p "${BACKUP_DIR}/configs/php"
    $RSYNC -r /etc/php "${BACKUP_DIR}/configs/php/"
}

# apache
apacheConfig()
{
    mkdir -p "${BACKUP_DIR}/configs/httpd"
    $RSYNC -r /etc/apache2 "${BACKUP_DIR}/configs/httpd/"
}

# Archive
archive()
{
    /usr/bin/tar -cvzf "${BACKUP_DIR}.tar.gz" $BACKUP_DIR > /dev/null 2>&1
    removeLocalBackup
}

# Move to S3 bucket
moveToBucket()
{
    if [[ -n ${archive-} ]]; then
        $AWS s3 mv "$BACKUP_DIR.tar.gz" s3://$S3_BUCKET/server/ --endpoint=$S3_ENDPOINT
    else
        $AWS s3 mv $BACKUP_DIR s3://$S3_BUCKET/server/ --endpoint=$S3_ENDPOINT
    fi

}

removeLocalBackup()
{
    # Just double check, we don't want to `rm` our whole filesystem
    if [[ -n ${directory-} ]]; then
        [[ $BACKUP_DIR =~ ^"${directory}" ]] && rm -rf $BACKUP_DIR
    else
        [[ $BACKUP_DIR =~ ^"${scriptDir}" ]] && rm -rf $BACKUP_DIR
    fi
}

# Remove old backups
removeOldBackups()
{
    # [TODO] only search for directories that match YEARMONTHDAY
    $FIND $BACKUP_DIR -maxdepth 1 -type d -mtime +4 -exec rm -rf {} \;
}

