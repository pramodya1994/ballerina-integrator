package utils;

import java.io.File;
import java.io.IOException;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.logging.Logger;

import org.apache.commons.io.FileUtils;

import static constants.Constants.RESOURCES;

public class Utils {
    private static final Logger logger = Logger.getLogger(Utils.class.getName());

    public static void createDirectory(String directoryPath) {
        if (!new File(directoryPath).exists()) {
            if (!new File(directoryPath).mkdir()) {
                throw new ServiceException("Error occurred when creating directory: " + directoryPath);
            }
        } else {
            logger.info("Directory already exists: " + directoryPath);
        }
    }

    public static void deleteDirectory(String directory) {
        try {
            FileUtils.deleteDirectory(new File(directory));
        } catch (IOException e) {
            throw new ServiceException("Error occurred while deleting tempDirectory.", e);
        }
    }

    public static void moveFile(File file, String destination) {
        if (!file.renameTo(new File(destination + file.getName()))) {
            throw new ServiceException(
                    "Error occurred while moving file to destination. file: " + file.getPath() + ", dest:" + destination
                            + file.getName());
        }
    }

    public static void moveDirectoryContent(File srcDir, String destDir) {
        File[] listOfFiles = srcDir.listFiles();

        if (listOfFiles != null) {
            for (File file : listOfFiles) {
                if (file.isFile()) {
                    // Check file already exists in the destDir.
                    moveFile(file, destDir);
                } else if (file.isDirectory()) {
                    throw new ServiceException(
                            "Error Cannot create directories inside `" + RESOURCES + "` directory. " + "directory: "
                                    + file.getPath());
                } else {
                    throw new ServiceException(
                            "Invalid content inside `" + RESOURCES + "` directory. " + "invalid content: " + file
                                    .getPath());
                }
            }
        }
    }

    public static void copyDirectoryContent(String src, String dest) {
        try {
            FileUtils.copyDirectory(new File(src), new File(dest));
        } catch (IOException e) {
            throw new ServiceException("Error when copying directory content. src: " + src + ", dest: " + dest, e);
        }
    }

    public static String getCurrentDirectoryName(String path) {
        return path.substring(path.lastIndexOf("/") + 1);
    }

    public static String getCurrentDate(String format) {
        DateFormat dateFormat = new SimpleDateFormat(format);
        Date date = new Date();
        return dateFormat.format(date);
    }
}
