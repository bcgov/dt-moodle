# Moodle Apache Kustomize Configuration

This repository contains Kustomize configurations for deploying Moodle with Apache on OpenShift.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Directory Structure](#directory-structure)
- [Setup](#setup)
- [Environment Variables](#environment-variables)
- [Building and Deploying](#building-and-deploying)
- [Backup and Restore](#backup-and-restore)
- [Security Notes](#security-notes)
- [Contributing](#contributing)
- [License](#license)

## Prerequisites

- OpenShift CLI (oc)
- Docker
- kubectl
- Access to an OpenShift cluster
- Access to an OpenShift image registry

## Directory Structure

```
kustomize-source-apache/
├── base/                  # Base Kustomize configuration
│   ├── apache-config.yaml # Apache configuration
│   ├── imagestream.yaml   # ImageStream definition
│   ├── mysql-secret.yaml  # MySQL secrets
│   ├── backup-viewer-pod.yaml # Backup viewer pod definition
│   └── ...               # Other base resources
├── overlays/             # Environment-specific overlays
│   ├── dev/             # Development environment
│   ├── test/            # Test environment
│   └── prod/            # Production environment
├── .env.example         # Example environment variables
└── README.md           # This file
```

## Setup

1. Clone this repository:
   ```bash
   git clone <repository-url>
   cd kustomize-source-apache
   ```

2. Create your environment file:
   ```bash
   cp .env.example .env
   ```

3. Edit the `.env` file with your specific values:
   - Set your OpenShift cluster URL
   - Configure your registry URL
   - Set your namespace
   - Configure MySQL credentials

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| CLUSTER_URL | OpenShift cluster API URL | https://api.example.com:6443 |
| REGISTRY_URL | OpenShift registry URL | image-registry.apps.example.com |
| NAMESPACE | Target namespace | your-namespace |
| MYSQL_ROOT_PASSWORD | MySQL root password | [secure-password] |
| MYSQL_USER | MySQL user | [database-user] |
| MYSQL_PASSWORD | MySQL user password | [secure-password] |

## Building and Deploying

### Building the Apache Image

1. Source your environment variables:
   ```bash
   source .env
   ```

2. Run the build script:
   ```bash
   ./base/build-apache-image.sh
   ```

### Deploying to Different Environments

#### Development Environment
```bash
kubectl apply -k overlays/dev
```

#### Test Environment
```bash
kubectl apply -k overlays/test
```

#### Production Environment
```bash
kubectl apply -k overlays/prod
```

## Backup and Restore

### Backup Configuration

The backup system is configured with:
- Weekly automated backups (every Sunday at 1 AM)
- Retention of the last 2 weeks of backups
- 5Gi storage space allocated for backups
- Pre-restore backup creation
- Verification steps for both backup and restore operations
- Automatic secret backup included in each backup

### Backup Directory Structure

```
/backup/
└── YYYYMMDD/              # Backup date directory (e.g., 20250409)
    ├── moodle-db.sql.gz   # Compressed MySQL database dump
    ├── moodledata.tar.gz  # Compressed Moodle data directory
    └── moodle-secrets.yaml # Backup of Moodle secrets
```

### Managing Backups

#### Viewing Available Backups
```bash
# Create a temporary pod with the backup PVC mounted
oc apply -f base/backup-viewer-pod.yaml

# Wait for the pod to be ready
oc wait --for=condition=Ready pod/backup-viewer

# List available backups
oc exec backup-viewer -- ls -l /backup

# Clean up the temporary pod
oc delete pod backup-viewer
```

#### Restoring from Backup

1. Apply the restore job configuration:
```bash
oc apply -f base/restore-job.yaml -n <namespace>
```

2. Restore from latest backup:
```bash
oc create job restore-latest --from=cronjob/moodle-restore -n <namespace>
```

3. Restore from specific backup date:
```bash
oc create job restore-specific --from=cronjob/moodle-restore -n <namespace> -- /bin/sh -c 'BACKUP_DATE=YYYYMMDD /restore.sh'
```

4. Monitor restore progress:
```bash
oc logs -f job/restore-latest -n <namespace>
```

### Restore Process

1. **Pre-restore Backup**
   - Creates a timestamped backup of current data
   - Stores backup in `/backup/pre-restore-YYYYMMDD-HHMMSS/`

2. **Backup Verification**
   - Verifies backup files exist and are not empty
   - Checks both database and data files

3. **MySQL Restore**
   - Drops and recreates the database
   - Restores from SQL dump
   - Verifies table count (fails if < 10 tables)

4. **Moodle Data Restore**
   - Clears existing data directory
   - Restores from tarball
   - Verifies data directory size

## Security Notes

- Never commit the `.env` file to version control
- Keep your secrets and credentials secure
- Use appropriate RBAC permissions
- Regularly rotate passwords and credentials

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the Apache License 2.0. See the [LICENSE](LICENSE) file for details.

# Moodle Deployment

This repository contains the configuration for deploying Moodle on OpenShift.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Deployment](#deployment)
- [Backup and Restore](#backup-and-restore)
- [Configuration](#configuration)

## Prerequisites

Before deploying Moodle, ensure you have:
- Access to an OpenShift cluster
- Appropriate permissions to create resources in your namespace
- The `oc` CLI tool installed and configured

## Deployment

To deploy Moodle:

1. Clone this repository
2. Navigate to the deployment directory
3. Apply the configuration:
   ```bash
   oc apply -k kustomize-source-apache/overlays/test
   ```

## Backup and Restore

### Backup Configuration

The backup system is configured with:
- Weekly automated backups (every Sunday at 1 AM)
- Retention of the last 2 weeks of backups
- 5Gi storage space allocated for backups
- Pre-restore backup creation
- Verification steps for both backup and restore operations
- Automatic secret backup included in each backup

### Restoring from Backup

#### 1. List Available Backups

To view available backups, create a temporary pod with the backup PVC mounted:
```bash
# Create a temporary pod with the backup PVC mounted
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: backup-viewer
spec:
  containers:
  - name: backup-viewer
    image: bitnami/kubectl:latest
    command: ["sleep", "infinity"]
    volumeMounts:
    - name: backup-volume
      mountPath: /backup
  volumes:
  - name: backup-volume
    persistentVolumeClaim:
      claimName: backup-pvc
EOF

# Wait for the pod to be ready
oc wait --for=condition=Ready pod/backup-viewer

# List available backups
oc exec backup-viewer -- ls -l /backup

# Clean up the temporary pod
oc delete pod backup-viewer
```

#### 2. Restore from Latest Backup

To restore from the most recent backup:

1. First, apply the restore job configuration:
```bash
oc apply -f base/restore-job.yaml -n <namespace>
```

2. Then create and run the restore job:
```bash
oc create job restore-latest --from=cronjob/moodle-restore -n <namespace>
```

#### 3. Restore from Specific Backup

To restore from a specific backup date (e.g., 20250409):

1. First, apply the restore job configuration:
```bash
oc apply -f base/restore-job.yaml -n <namespace>
```

2. Then create and run the restore job with the specific backup date:
```bash
oc create job restore-specific --from=cronjob/moodle-restore -n <namespace> -- /bin/sh -c 'BACKUP_DATE=YYYYMMDD /restore.sh'
```

#### 4. Monitor Restore Progress

To monitor the restore progress:
```bash
oc logs -f job/restore-latest -n <namespace>
```

### Restore Process Details

The restore process includes the following steps:

1. **Pre-restore Backup**
   - Creates a timestamped backup of current data
   - Stores backup in `/backup/pre-restore-YYYYMMDD-HHMMSS/`
   - Includes both MySQL database and Moodle data files

2. **Backup Verification**
   - Verifies backup files exist and are not empty
   - Checks both database and data files

3. **MySQL Restore**
   - Drops and recreates the database
   - Restores from SQL dump
   - Verifies table count (fails if < 10 tables)

4. **Moodle Data Restore**
   - Clears existing data directory
   - Restores from tarball
   - Verifies data directory size

5. **Completion**
   - Reports success/failure
   - Provides location of pre-restore backup

### Important Notes

- The restore process will overwrite existing data
- A pre-restore backup is automatically created before any restore operation
- The restore job will fail if:
  - Backup files are missing or empty
  - Too few MySQL tables are restored
  - Moodle data directory is empty after restore
- Pre-restore backups are not automatically cleaned up - manual cleanup may be required

