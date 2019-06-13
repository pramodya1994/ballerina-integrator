import org.apache.commons.io.IOUtils;
import utils.ServiceException;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.logging.Level;
import java.util.logging.Logger;

import static constants.Constants.BALLERINA_CODE_MD_SYNTAX;
import static constants.Constants.CODE;
import static constants.Constants.CODE_MD_SYNTAX;
import static constants.Constants.COMMENT_END;
import static constants.Constants.COMMENT_START;
import static constants.Constants.EMPTY_STRING;
import static constants.Constants.INCLUDE_CODE_TAG;
import static constants.Constants.JAVA_CODE_MD_SYNTAX;
import static constants.Constants.REPO_EXAMPLES_DIR;
import static constants.Constants.RESOURCES;
import static constants.Constants.RESOURCES_DIR;
import static constants.Constants.TEMP_DIR;
import static constants.Constants._GUIDE_TEMPLATES_DIR;
import static utils.Utils.copyDirectoryContent;
import static utils.Utils.createDirectory;
import static utils.Utils.deleteDirectory;
import static utils.Utils.getCurrentDate;
import static utils.Utils.getCurrentDirectoryName;
import static utils.Utils.moveDirectoryContent;
import static utils.Utils.moveFile;

public class SiteBuilder {
    // Setup logger.
    private static final Logger logger = Logger.getLogger(SiteBuilder.class.getName());

    public static void main(String[] args) {
        try {
            // First delete already created posts.
            deleteDirectory(_GUIDE_TEMPLATES_DIR);
            // Create needed directory structure.
            createDirStructure();
            // get a copy of examples directory.
            copyDirectoryContent(REPO_EXAMPLES_DIR, TEMP_DIR);
            // Process repository to generate guide templates.
            processRepository(TEMP_DIR);
        } catch (ServiceException e) {
            logger.log(Level.SEVERE, e.getMessage(), e);
        } finally {
            deleteDirectory(TEMP_DIR);
        }
    }

    private static void createDirStructure() {
        createDirectory(TEMP_DIR);
        createDirectory(_GUIDE_TEMPLATES_DIR);
        createDirectory(RESOURCES_DIR);
    }

    private static void processRepository(String folderPath) {
        // Go to git directory and get README.md files from folders.
        File folder = new File(folderPath);
        File[] listOfFiles = folder.listFiles();

        if (listOfFiles != null) {
            for (File file : listOfFiles) {
                if (file.isFile() && file.getName().equals("README.md")) { // If a README.md file.
                    processReadmeFile(file);
                    String newName = renameReadmeFile(file);
                    moveFile(new File(newName), _GUIDE_TEMPLATES_DIR);
                } else if (file.isDirectory()) {
                    // If resources folder add its content to _guideTemplates/resources
                    if (file.getName().equals(RESOURCES)) {
                        moveDirectoryContent(file, RESOURCES_DIR);
                    }
                    processRepository(file.getPath());
                }
            }
        }
    }

    private static void processReadmeFile(File file) {
        try {
            String readMeFileContent = IOUtils
                    .toString(new FileInputStream(file), String.valueOf(StandardCharsets.UTF_8));
            BufferedReader reader = new BufferedReader(new FileReader(file));
            String line;

            while ((line = reader.readLine()) != null) {
                if (line.contains(INCLUDE_CODE_TAG)) { // <!-- INCLUDE_CODE: guide/http_message_receiver.bal -->
                    // Replace INCLUDE_CODE line with include code content.
                    readMeFileContent = readMeFileContent.replace(line, getIncludeCode(file.getParent(), line));
                }
            }

            IOUtils.write(readMeFileContent, new FileOutputStream(file), String.valueOf(StandardCharsets.UTF_8));
        } catch (Exception e) {
            throw new ServiceException("Could not find the README.md file: " + file.getPath(), e);
        }

    }

    private static String renameReadmeFile(File file) {
        String mdFileName =  file.getParent() + "/" + getCurrentDate("yyyy-MM-dd") + "-"
                + getCurrentDirectoryName(file.getParent()) + ".md";
        if (file.renameTo(new File(mdFileName))) {
            return mdFileName;
        } else {
            throw new ServiceException("Renaming README.md failed. file:" + file.getPath());
        }
    }

    private static String getIncludeCode(String readMeParentPath, String line) {
        String fullPathOfIncludeCodeFile = readMeParentPath + getIncludeFilePathFromLine(line);
        File includeCodeFile = new File(fullPathOfIncludeCodeFile);
        String code;

        try {
            code = IOUtils.toString(new FileInputStream(includeCodeFile), String.valueOf(StandardCharsets.UTF_8));
        } catch (IOException e) {
            throw new ServiceException(
                    "Error occurred when converting file content to string. file: " + readMeParentPath, e);
        }

        String type = fullPathOfIncludeCodeFile.substring(fullPathOfIncludeCodeFile.lastIndexOf('.') + 1);
        switch (type) {
        case "bal":
            return BALLERINA_CODE_MD_SYNTAX.replace(CODE, code);
        case "java":
            return JAVA_CODE_MD_SYNTAX.replace(CODE, code);
        default:
            return CODE_MD_SYNTAX.replace(CODE, code);
        }

    }

    private static String getIncludeFilePathFromLine(String line) {
        return "/" + line.replace(COMMENT_START, EMPTY_STRING).replace(COMMENT_END, EMPTY_STRING)
                .replace(INCLUDE_CODE_TAG, EMPTY_STRING).trim();
    }
}
