package net.local.test;

import java.net.URI;
import java.net.URISyntaxException;
import java.security.InvalidKeyException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Set;
import java.util.StringTokenizer;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.CommandLineParser;
import org.apache.commons.cli.DefaultParser;
import org.apache.commons.cli.HelpFormatter;
import org.apache.commons.cli.Option;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.ParseException;
import org.apache.log4j.Logger;

import com.microsoft.azure.storage.CloudStorageAccount;
import com.microsoft.azure.storage.StorageException;
import com.microsoft.azure.storage.blob.BlockEntry;
import com.microsoft.azure.storage.blob.CloudAppendBlob;
import com.microsoft.azure.storage.blob.CloudBlob;
import com.microsoft.azure.storage.blob.CloudBlobClient;
import com.microsoft.azure.storage.blob.CloudBlobContainer;
import com.microsoft.azure.storage.blob.CloudBlockBlob;
import com.microsoft.azure.storage.blob.CloudPageBlob;
import com.microsoft.azure.storage.blob.ListBlobItem;
import com.microsoft.azure.storage.blob.PageRange;

class AzureBlobStorage {
	String name;
	long capacity;
	long size;
	AzureBlobStorage() {
		capacity = size = 0;
	}
}

public class AccessStorage {
	final static Logger logger = Logger.getLogger(AccessStorage.class);
	static String gOnBlobUri = null;
	
	private static String humanReadableByteCount(long bytes, boolean si) {
	    int unit = si ? 1000 : 1024;
	    if (bytes < unit) return bytes + " B";
	    int exp = (int) (Math.log(bytes) / Math.log(unit));
	    String pre = (si ? "kMGTPE" : "KMGTPE").charAt(exp-1) + (si ? "" : "i");
	    return String.format("%.1f %sB", bytes / Math.pow(unit, exp), pre);
	}
	
	public static String convertByte2HumanReadable(long number) {
		return humanReadableByteCount(number, false);
		//return FileUtils.byteCountToDisplaySize(number);
	}
	
	public static AzureBlobStorage getBlobUsage(ListBlobItem listBlobItem, String expecteBlob) {
		final String systemInUseError = "SystemInUse";
		final String snapRateExceeded = "SnaphotOperationRateExceeded";
		boolean needSnapshot = false;
		boolean needWait     = false;
		int waitTrylimit     = 5;
		long blobSize = 0;
		AzureBlobStorage result = new AzureBlobStorage();
		if (listBlobItem instanceof CloudPageBlob) {
			CloudPageBlob cpb = (CloudPageBlob)listBlobItem;
			result.capacity = cpb.getProperties().getLength();
			try {
				result.name = cpb.getName();
			} catch (URISyntaxException e1) {
				// TODO Auto-generated catch block
				e1.printStackTrace();
			}
			
			List<PageRange> pageRangeList = null;
			try {
				pageRangeList = cpb.downloadPageRanges();
				for (PageRange pr : pageRangeList) {
					blobSize += pr.getEndOffset() - pr.getStartOffset() + 12;
				}
			} catch (StorageException se) {
				String exception = se.getErrorCode() + 
						":" + se.getLocalizedMessage();
				logger.info(exception);
				if (systemInUseError.equals(se.getErrorCode())) {
					// if the storage is in use, we need to take snapshot.
					// This is by design.
					needSnapshot = true;
				}
			}
			
			if (needSnapshot) {
				int tryNum = 0;
				do {
					try {
						CloudBlob cbSnap = cpb.createSnapshot();
						CloudPageBlob cpbSnap = (CloudPageBlob)cbSnap;
						
						pageRangeList = cpbSnap.downloadPageRanges();
						for (PageRange pr : pageRangeList) {
							blobSize += pr.getEndOffset() - pr.getStartOffset() + 12;
						}
						needWait = false;
					} catch (StorageException se) {
						String exception = se.getErrorCode() + 
								":" + se.getLocalizedMessage();
						System.out.println(exception);
						logger.info(exception);
						if (snapRateExceeded.equals(se.getErrorCode())) {
							// handle 'SnaphotOperationRateExceeded'
							//   with error message 'The rate of snapshot blob calls is exceeded'
							//   Azure does not allow to snapshot frequently.
							//   For premium storage, the rate of snapshot is ~2min.
							needWait = true;
						}
					}
					if (needWait) {
						try {
							logger.info("Wait for next snapshot");
							Thread.currentThread().sleep(60 * 1000); // wait for 1min
						} catch (InterruptedException e) {
							// TODO Auto-generated catch block
							e.printStackTrace();
						}
					}
					tryNum++;
				} while (tryNum < waitTrylimit && needWait);
			}
			result.size = blobSize;
		} else if (listBlobItem instanceof CloudBlockBlob) {
			CloudBlockBlob cbb = (CloudBlockBlob)listBlobItem;
			try {
				result.name = cbb.getName();
			} catch (URISyntaxException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			}
			try {
				ArrayList<BlockEntry> blockEntryList = cbb.downloadBlockList();
				for (BlockEntry be : blockEntryList) {
					blobSize += be.getSize();
				}
			} catch (StorageException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			}
			result.size = blobSize;
		} else if (listBlobItem instanceof CloudAppendBlob) {
			//TODO
			CloudAppendBlob cab = (CloudAppendBlob)listBlobItem;
			try {
				result.name = cab.getName();
			} catch (URISyntaxException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			}
			logger.info("CloudAppendBlob");
		}
		return result;
	}
	
	public static void storageUsage(final String storageConnectionString, String expectedBlob) 
			throws InvalidKeyException, URISyntaxException, StorageException {
		long blobCapacity = 0;
		long blobUsage = 0;
		boolean matched = false;
		String expectedContainer = null, expectedBlobName = null;
		if (expectedBlob != null) {
			URI uri = new URI(expectedBlob);
			StringTokenizer st = new StringTokenizer(uri.getPath(), "/");
			expectedContainer = st.nextToken();
			expectedBlobName = st.nextToken();
		}
		CloudStorageAccount storageAccount = CloudStorageAccount.parse(storageConnectionString);
		CloudBlobClient cbc = storageAccount.createCloudBlobClient();
		Iterable<CloudBlobContainer> cIter = cbc.listContainers();
		Iterator<CloudBlobContainer> iter = cIter.iterator();
		while (iter.hasNext()) {
			CloudBlobContainer container = iter.next();
			String name = container.getName();
			if (expectedContainer != null && !expectedContainer.equals(name)) {
				continue;
			}
			/*
			 * Blob Containers: The following is how to estimate the amount
			 * of storage consumed per blob container:
			 *  48 bytes + Len(ContainerName) * 2 bytes + 
			 *  For-Each Metadata[3 bytes + Len(MetadataName) + Len(Value)] + 
			 *  For-Each Signed Identifier[512 bytes] 
			 *  
			 *  The following is the breakdown:
			 *  1) 48 bytes of overhead for each container includes the Last
			 *   Modified Time, Permissions, Public Settings, and some system metadata.
			 *  2) the container name is stored as Unicode so take the
			 *   number of characters and multiply by 2.
			 *  3) or each blob container metadata stored, we store the
			 *   length of the name (stored as ASCII), plus the length of the string value.
			 *  4) the 512 bytes per Signed Identifier includes signed identifier name,
			 *   start time, expiry time and permissions.
			 */
			long containerSize = 48 + name.length() * 2;
			
			long metaSize = 0;
			HashMap<String, String> metaData = container.getMetadata();
			Set<String> keys = metaData.keySet();
			for (Iterator<String> kIter = keys.iterator(); kIter.hasNext();) {
				String key = kIter.next();
				metaSize += 3 + key.length() + metaData.get(key).length();
			}
			
			long blobSize = 0;
			Iterable<ListBlobItem> blobList = container.listBlobs();
			Iterator<ListBlobItem> blobIter = blobList.iterator();
			while (blobIter.hasNext()) {
				ListBlobItem lbi = blobIter.next();
				if (expectedBlobName != null) {
					boolean find = false;
					if (lbi instanceof CloudPageBlob) {
						if (((CloudPageBlob)lbi).getName().equals(expectedBlobName)) {
							find = true;
						}
					} else if (lbi instanceof CloudBlockBlob) {
						if (((CloudBlockBlob)lbi).getName().equals(expectedBlobName)) {
							find = true;
						}
					}
					if (!find) {
						continue;
					} else {
						AzureBlobStorage as = getBlobUsage(lbi, expectedBlob);
						blobCapacity = as.capacity;
						blobUsage = as.size;
						matched = true;
					}
				} else {
					AzureBlobStorage as = getBlobUsage(lbi, expectedBlob);
					blobSize += as.size;
					if (expectedBlob == null) {
						String result = "container '" + name + "' blob '" + as.name + 
								"' capacity is " + convertByte2HumanReadable(as.capacity) +
								" (" + as.capacity + ")" +
								", used size is " + convertByte2HumanReadable(as.size) +
								" (" + as.size + ")";
						logger.info(result);
					}
				}
			}
			
			containerSize += metaSize + blobSize;
			if (expectedBlob == null) {
				String containerUsedSize = "container '" + name + "' size is " +
						convertByte2HumanReadable(containerSize) +
						" (" + containerSize + ")";
				logger.info(containerUsedSize);
			} else if (matched) {
				String result = "Processing " + expectedBlob;
				logger.info(result);
				result = "Size: " + convertByte2HumanReadable(blobCapacity) + " (" + blobCapacity + ")";
				logger.info(result);
				result = "BillingSize: " + convertByte2HumanReadable(blobUsage) + " (" + blobUsage + ")";
				logger.info(result);
				break;
			}
		}
	}
	
	public static String parseConnectString(String args[]) {
		final String storageAccount 	= "storageAccount";
		final String storagePrimaryKey 	= "storagePrimaryKey";
		final String onMooncake         = "onMooncake";
		final String blobUriPara        = "blobUri";
		Options options = new Options();
		Option input = new Option("n", storageAccount, true, "input storage account");
        input.setRequired(true);
        options.addOption(input);

        Option primaryKey = new Option("k", storagePrimaryKey, true, "input the storage primary key");
        primaryKey.setRequired(true);
        options.addOption(primaryKey);

        Option chinacloud = new Option("c", onMooncake, true,
        		"true: run on Mooncake (azure china), false: not on Mooncake");
        chinacloud.setRequired(true);
        options.addOption(chinacloud);
        
        Option blobUri = new Option("u", blobUriPara, true,
        		"Optional: only return the usage for your specified blob URI");
        blobUri.setRequired(false);
        options.addOption(blobUri);
        CommandLineParser parser = new DefaultParser();
        HelpFormatter formatter = new HelpFormatter();
        CommandLine cmd;

        try {
            cmd = parser.parse(options, args);
        } catch (ParseException e) {
            System.out.println(e.getMessage());
            formatter.printHelp("StorageUsage", options);

            System.exit(1);
            return null;
        }
        String storageAccountValue = cmd.getOptionValue(storageAccount);
        String storagePrimaryKeyValue = cmd.getOptionValue(storagePrimaryKey);
        String onMooncakeCloud = cmd.getOptionValue(onMooncake);
        gOnBlobUri = cmd.getOptionValue(blobUriPara);
        StringBuilder sb = new StringBuilder();
        
        if (onMooncakeCloud != null && Boolean.valueOf(onMooncakeCloud)) {
        	// Mooncake can not be accessed through https because
        	// the server CA was not in JDK's CA trust chain
        	sb.append("DefaultEndpointsProtocol=http;")
            .append("AccountName=").append(storageAccountValue)
            .append(";AccountKey=").append(storagePrimaryKeyValue);
        	sb.append(";EndpointSuffix=core.chinacloudapi.cn");
        } else {
        	sb.append("DefaultEndpointsProtocol=https;")
            .append("AccountName=").append(storageAccountValue)
            .append(";AccountKey=").append(storagePrimaryKeyValue);
        }
        String ret = sb.toString();
        logger.info(ret);
        return ret;
	}
	
	public static void main(String args[]) throws InvalidKeyException, URISyntaxException, StorageException {
		String connectStr = parseConnectString(args);
		storageUsage(connectStr, gOnBlobUri);
	}
}
