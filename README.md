# mke-msr-migration

1. Create .env file with the following
   ```
   export SOURCE_MKE=
   export SOURCE_MKE_USER=
   export SOURCE_MKE_PASSWORD=

   export DEST_MKE=
   export DEST_MKE_USER=
   export DEST_MKE_PASSWORD=

   export DEST_CREATE=false

   export SOURCE_MSR=
   export SOURCE_MSR_USER=
   export SOURCE_MSR_PASSWORD=

   export DEST_MSR=
   export DEST_MSR_USER=
   export DEST_MSR_PASSWORD=

   ```

2. Execute the script
   ```
   ./mke_users.sh <env-file>
   ```
