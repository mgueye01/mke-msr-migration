# mke-msr-migration

1. Create .env file with the following
   ```
   SOURCE_MKE=mke-cluster1.example.com
   SOURCE_MKE_USER=admin
   SOURCE_MKE_PASSWORD='securestring'

   DEST_MKE=mke-cluster2.example.com
   DEST_MKE_USER=admin
   DEST_MKE_PASSWORD='securestring'

   DEST_CREATE=false
   ```

2. Execute the script
   ```
   ./mke_users.sh <env-file>
   ```
