# Moodle Apache Kustomize Configuration

This repository contains Kustomize configurations for deploying Moodle with Apache on OpenShift.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Directory Structure](#directory-structure)
- [Setup](#setup)
- [Environment Variables](#environment-variables)
- [Building and Deploying](#building-and-deploying)
- [Backup and Restore](#backup-and-restore)
- [Upgrading Moodle](#upgrading-moodle)
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

#### Triggering a Manual Backup

To trigger a manual backup job immediately, you can create a new Job from the existing `moodle-backup` CronJob template. This is useful if you need a backup outside the scheduled time.

```bash
# Replace <namespace> with your target namespace
oc create job moodle-backup-manual-$(date +%s) --from=cronjob/moodle-backup -n <namespace>
```

This command creates a new Job named `moodle-backup-manual-<timestamp>` (e.g., `moodle-backup-manual-1678886400`). You can monitor its progress like any other Kubernetes Job:

```bash
# Replace <namespace> and the job name accordingly
oc logs -f job/moodle-backup-manual-$(date +%s) -n <namespace>
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

## Upgrading Moodle

Upgrading your Moodle site requires a careful process to ensure data integrity. Follow these steps to upgrade Moodle to a new version.

### Phase 1: Preparation and Backup

1.  **Enable Maintenance Mode**

    Put your Moodle site into maintenance mode to prevent users from making changes during the upgrade. You can do this from the Moodle UI (`Site administration > Server > Maintenance mode`) or by running a command inside your Moodle pod:

    ```bash
    # Get your moodle pod name
    oc get pods -l app=moodle -n <namespace>

    # Exec into the pod and enable maintenance mode
    oc exec <moodle-pod-name> -n <namespace> -- php /var/www/html/admin/cli/maintenance.php --enable
    ```

2.  **Back Up Your Data**

    Before upgrading, perform a full backup of your database and Moodle data directory. Use the manual backup process described in the [Backup and Restore](#backup-and-restore) section.

    ```bash
    # Trigger a manual backup
    oc create job moodle-backup-manual-$(date +%s) --from=cronjob/moodle-backup -n <namespace>

    # Monitor the backup job
    oc logs -f job/moodle-backup-manual-$(date +%s) -n <namespace>
    ```

    Ensure the backup completes successfully before proceeding.

### Phase 2: The Upgrade

1.  **Update Moodle Version in `Dockerfile`**

    In `kustomize-source-apache/base/Dockerfile`, update the Moodle version. Find the download URL for the desired version from the [Moodle downloads page](https://download.moodle.org/releases/latest/).

    Update the `curl` command in the `Dockerfile`. For example, to upgrade to Moodle 4.6:

    ```dockerfile
    # kustomize-source-apache/base/Dockerfile
    # ...
    # Download and extract Moodle
    RUN cd /var/www/html \
        && curl -fsSL https://download.moodle.org/download.php/direct/stable406/moodle-latest-406.tgz -o moodle.tgz \
        && tar -xzf moodle.tgz \
    # ...
    ```

2.  **Build and Push the New Docker Image**

    Build a new Docker image using the provided script and push it to your registry.

    ```bash
    source .env
    ./base/build-apache-image.sh
    ```

3.  **Deploy the New Image**

    Update your `deployment.yaml` (or the corresponding file in your Kustomize overlay) to use the new image tag. Then apply the changes to your cluster.

    ```yaml
    # kustomize-source-apache/overlays/<your-env>/deployment.yaml (or base/deployment.yaml)
    # ...
    spec:
      template:
        spec:
          containers:
          - name: moodle-apache
            image: <your-registry>/<your-namespace>/moodle-apache:<new-version-tag> # <-- Update this line
    # ...
    ```

    Apply the Kustomize configuration:
    ```bash
    kubectl apply -k overlays/<your-env>
    ```

### Phase 3: Finalization

1.  **Trigger Moodle Database Upgrade**

    Once the new pods are running, you must run Moodle's internal database upgrade script.

    ```bash
    # Get the name of a new Moodle pod
    oc get pods -l app=moodle -n <namespace>

    # Exec into the pod and run the upgrade
    oc exec -it <new-moodle-pod-name> -n <namespace> -- php /var/www/html/admin/cli/upgrade.php
    ```

    Follow the prompts in the command-line interface to complete the database upgrade.

2.  **Verify and Disable Maintenance Mode**

    Thoroughly test your Moodle site. Once you are confident that the upgrade was successful, disable maintenance mode.

    ```bash
    oc exec <new-moodle-pod-name> -n <namespace> -- php /var/www/html/admin/cli/maintenance.php --disable
    ```

    It is also recommended to purge all caches from the Moodle UI (`Site administration > Development > Purge all caches`).

### Rollback Plan

If the upgrade fails, you can roll back to the previous state:
1.  **Revert Image:** Change the image tag in your `deployment.yaml` back to the previous version and re-apply the configuration.
2.  **Restore Data:** If the database or files were corrupted, use the `restore-job.yaml` to restore from the backup you created before the upgrade. Refer to the [Restoring from Backup](#restoring-from-backup) section for instructions.

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