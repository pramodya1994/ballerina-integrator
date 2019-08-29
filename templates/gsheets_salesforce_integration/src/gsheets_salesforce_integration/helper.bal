// Copyright (c) 2018 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http;
import ballerina/log;
import wso2/sfdc46;

//==================== Gsheets operations ==========================================

function extractContactsFromSpreadsheet(string accountId, string spreadsheetId, string sheetName, int noOfRows) 
    returns string {
    int rowNum = 1;
    string csv = "";

    while (rowNum <= noOfRows) {
        string[]|error row = spreadsheetClient->getRowData(<@untainted> spreadsheetId, <@untainted> sheetName, rowNum);
        if (row is string[]) {
            // Header row
            if (rowNum == 1) {
                csv = csv + createCsvRow(row, "accountId");
            }
            // Check whether salesforce contact.
            if (row[0] == "Salesforce contact") {
                csv = csv + createCsvRow(row, accountId);
            } 
        } else {
            log:printError("Error occurred while retrieving rows from gsheet", err = row);
            return GSHEETS_EXTRACTION_ERROR;
        }
        rowNum = rowNum + 1;
    }
    return csv;
}

//==================== Salesforce operations ==========================================

function insertContactsToSalesforce(string csvContent) returns boolean {
    // Create csv insert operator.
    sfdc46:CsvInsertOperator|sfdc46:SalesforceError csvInserter = sfBulkClient->createCsvInsertOperator("Contact");

    if (csvInserter is sfdc46:CsvInsertOperator) {
        // Upload the csv contacts.
        sfdc46:Batch|sfdc46:SalesforceError batch = csvInserter->insert(csvContent);

        if (batch is sfdc46:Batch) {
            sfdc46:Result[]|sfdc46:SalesforceError batchResult = csvInserter->getBatchResults(batch.id, 15);

            if (batchResult is sfdc46:Result[]) {
                return checkBatchResults(batchResult);
            } else {
                log:printError("Error occurred while getting insert batch result, batchResult:" 
                    + batchResult.message.toString(), err = ());
                return false;
            }

        } else {
            log:printError("Error occurred while uploading the csv content, batch:" + batch.message.toString(), 
                err = ());
            return false;
        }

    } else {
        log:printError("Error occurred while creating salesforce bulk insert operator, csvInserter:" 
            + csvInserter.message.toString(), err = ());
        return false;
    }
}

function getContactsFromSalesforce(string accountId) returns @tainted json[]|sfdc46:SalesforceError {
    // Create JSON query operator.
    sfdc46:JsonQueryOperator|sfdc46:SalesforceError jsonQueryOp = sfBulkClient->createJsonQueryOperator("Contact");
    // Query string
    string queryStr = "SELECT Id, Name FROM Contact where Account.Id = '" + accountId + "'";

    if (jsonQueryOp is sfdc46:JsonQueryOperator) {
        // Create json query batch.
        sfdc46:Batch|sfdc46:SalesforceError batch = jsonQueryOp->query(queryStr);

        if (batch is sfdc46:Batch) {

            // Get query results list.
            sfdc46:ResultList|sfdc46:SalesforceError resultList = jsonQueryOp->getResultList(batch.id, 25);
            if (resultList is sfdc46:ResultList) {
                // Get query result.
                json[]|sfdc46:SalesforceError result = getQueryResultsFromResultList(jsonQueryOp, resultList.result, 
                    batch.id);
                if (result is json[]) {
                    return result;
                } else {
                    log:printInfo("Error occurred while getting query results, err=" + result.toString());
                    return result;
                }
            } else {
                log:printInfo("Error occurred while getting query result list, err=" + resultList.toString());
                return resultList;
            }
        } else {
            return batch;
        }
    } else {
        return jsonQueryOp;
    }
}

function deleteContactsFromSalesforce(json contacts) returns @tainted sfdc46:Result[]|sfdc46:SalesforceError {
    // Create a json delete operator.
    sfdc46:JsonDeleteOperator|sfdc46:SalesforceError jsonDeleteOp = sfBulkClient->createJsonDeleteOperator("Contact");

    if (jsonDeleteOp is sfdc46:JsonDeleteOperator) {
        // Upload the batch should be deleted.
        sfdc46:Batch|sfdc46:SalesforceError batch = jsonDeleteOp->delete(contacts);

        if (batch is sfdc46:Batch) {
            // Get delete results
            sfdc46:Result[]|sfdc46:SalesforceError batchResult = jsonDeleteOp->getBatchResults(batch.id, 25);
            return batchResult;
        } else {
            return batch;
        }
    } else {
        return jsonDeleteOp;
    }
}

//==================== Helper functions ==========================================

// Get results for all IDs in resultList as a single json array. 
function getQueryResultsFromResultList(sfdc46:JsonQueryOperator jsonQueryOperator, string[] resultList, string batchId)
    returns @tainted json[]|sfdc46:SalesforceError {
    json[] finalResultArr = [];
    foreach string resultId in resultList {
        json|sfdc46:SalesforceError result = jsonQueryOperator->getResult(batchId, resultId);
        if (result is json) {
            json[] resArr = <json[]> result;
            foreach json elem in resArr {
                finalResultArr[finalResultArr.length()] = elem; 
            }
        } else {
            return result;
        }
    }
    return finalResultArr;
}

// Log and respond error.
function logAndRespondError(http:Caller caller, string errMsg, 
    error?|sfdc46:SalesforceError|sfdc46:SalesforceConnectorError err, int statusCode) {
    if (err is error) {
        log:printError(errMsg, err = err);
    } else {
        log:printError(errMsg + ", SalesforceErr=" + err.toString(), err = ());
    }
    respondAndHandleError(caller, statusCode, errMsg);
}

// Send the response back to the client and handle responding errors.
function respondAndHandleError(http:Caller caller, int resCode, json|xml|string payload) {
    http:Response res = new;
    res.statusCode = resCode;
    res.setPayload(payload);
    var respond = caller->respond(res);
    if (respond is error) {
        log:printError("Error occurred while responding", err = respond);
    }
}

// Check whether batch results are successful or not.
function checkBatchResults(sfdc46:Result[] results) returns boolean {
    foreach sfdc46:Result res in results {
        if (!res.success) {
            log:printError("Failed result, res=" + res.toString(), err = ());
            return false;
        }
    }
    return true;
}
