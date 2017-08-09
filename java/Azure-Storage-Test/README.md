#Description
This tool is used to check Azure blob storage usage including capacity and real space usage.

#Required
JDK
maven

#Build
mvn package

#Run
##Usage
```
Missing required options: n, k, c
usage: StorageUsage
 -c,--onMooncake <arg>          true: run on Mooncake (azure china),
                                false: not on Mooncake
 -k,--storagePrimaryKey <arg>   input the storage primary key
 -n,--storageAccount <arg>      input storage account
```
The following are examples with fake account name and key.
##On global Azure
```
java -jar target\azure-storage-usage-1.0-SNAPSHOT.jar net.local.test.AccessStorage -k kNGnHdQ4kBGz8Y2gJnWwlMERx9OeDswswWwP3btoW2VVDEaMsonKS8GuvvtiENZBIdABzXLafGQ7ZiphZwuNYA== -n honzhanhackathon4666 -c false
```
##On Mooncake (Azure China)
```
java -jar target\azure-storage-usage-1.0-SNAPSHOT.jar net.local.test.AccessStorage -k kNGnHdQ4kBGz8Y2gJnWwlMERx9OeDswswWwP3btoW2VVDEaMsonKS8GuvvtiENZBIdABzXLafGQ7ZiphZwuNYA== -n honzhanhackathon4666 -c true
```