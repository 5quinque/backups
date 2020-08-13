# backups

Bash script to perform backup of web server and upload to S3 compatible storage 

## Requirements

 * AWS Cli
 * AWS Credentials in `~/.aws/credentials`

## Usage

```bash
$ ./backup.sh --help
Usage:
    -h|--help                  Displays this help
    -v|--verbose               Displays verbose output
    -l|--local                 Store backup locally
    -a|--archive               Store backup in a tarball (.tar.gz)
    -r|--remove-old            Remove old locally stored backups
    -d|--directory             Output directory
```

## Database Credentials

```bash
$ cp .backup_credentials .backup_credentials.local
$ sed -i 's/db_user/yourdb_user/' .backup_credentials.local
$ sed -i 's/db_password/yourdb_password/' .backup_credentials.local
```
