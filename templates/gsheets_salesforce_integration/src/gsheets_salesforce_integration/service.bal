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

import ballerina/config;
import ballerina/http;
import wso2/gsheets4;
import wso2/sfdc46;

// Spreadsheet configuration.
gsheets4:SpreadsheetConfiguration spreadsheetConfig = {
    clientConfig: {
        accessToken: config:getAsString("GSHEETS_ACCESS_TOKEN"),
        refreshConfig: {
            clientId: config:getAsString("GSHEETS_CLIENT_ID"),
            clientSecret: config:getAsString("GSHEETS_CLIENT_SECRET"),
            refreshUrl: config:getAsString("GSHEETS_REFRESH_URL"),
            refreshToken: config:getAsString("GSHEETS_REFRESH_TOKEN")
        }
    }
};

// Salesforce configuration.
sfdc46:SalesforceConfiguration sfConfig = {
    baseUrl: config:getAsString("SF_BASE_URL"),
    clientConfig: {
        accessToken: config:getAsString("SF_ACCESS_TOKEN"),
        refreshConfig: {
            clientId: config:getAsString("SF_CLIENT_ID"),
            clientSecret: config:getAsString("SF_CLIENT_SECRET"),
            refreshToken: config:getAsString("SF_REFRESH_TOKEN"),
            refreshUrl: config:getAsString("SF_REFRESH_URL")
        }
    }
};

// Create gsheets client.
gsheets4:Client spreadsheetClient = new (spreadsheetConfig);
// Create salesforce client.
sfdc46:Client salesforceClient = new (sfConfig);
// Create salesforce bulk client.
sfdc46:SalesforceBulkClient sfBulkClient = salesforceClient->createSalesforceBulkClient();

const GSHEETS_EXTRACTION_ERROR = "Extracting contacts failed";

// Service created to integrate gsheets and salesforce APIs.
@http:ServiceConfig {
    basePath: "/salesforce"
}
service salesforceService on new http:Listener(config:getAsInt("LISTENER_PORT")) {
    // Add salesforce contact.
    @http:ResourceConfig {
        methods: ["POST"],
        path: "/account"
    }
    resource function addAccount(http:Caller caller, http:Request request) {
        json|error jsonPayload = request.getJsonPayload();

        if (jsonPayload is json) {
            string|sfdc46:SalesforceConnectorError accountId = salesforceClient->createAccount(<@untainted>jsonPayload);

            if (accountId is string) {
                json account = {
                    id: accountId,
                    'type: "Account"
                };
                respondAndHandleError(caller, http:STATUS_OK, <@untainted> account);
            } else {
                logAndRespondError(caller, "Error occurred while creating account", accountId, 
                    http:STATUS_INTERNAL_SERVER_ERROR);
            }

        } else {
            logAndRespondError(caller, "Invalid request payload", jsonPayload, http:STATUS_BAD_REQUEST);
        }
    }

    // Add salesforce contacts.
    @http:ResourceConfig {
        methods: ["POST"],
        path: "/contacts/{accountId}"
    }
    resource function addContacts(http:Caller caller, http:Request request, string accountId) {
        json|error jsonPayload = request.getJsonPayload();

        if (jsonPayload is json) {
            string spreadsheetId = jsonPayload.spreadsheetId.toString();
            string sheetName = jsonPayload.sheetName.toString();
            int noOfRows = <int> jsonPayload.noOfRows;

            string contactsCsv = 
                extractContactsFromSpreadsheet(accountId, <@untainted> spreadsheetId, <@untainted> sheetName, noOfRows);

            if (contactsCsv == GSHEETS_EXTRACTION_ERROR) {
                logAndRespondError(caller, contactsCsv, (), http:STATUS_INTERNAL_SERVER_ERROR);
            } else {
                if (insertContactsToSalesforce(<@untainted> contactsCsv)) {
                    json payload = {
                        status: "success"
                    };
                    respondAndHandleError(caller, http:STATUS_OK, <@untainted> payload);
                } else {
                    logAndRespondError(caller, "inserting contacts to Salesforce failed", (), 
                        http:STATUS_INTERNAL_SERVER_ERROR);
                }
            }

        } else {
            logAndRespondError(caller, "Invalid request payload", jsonPayload, http:STATUS_BAD_REQUEST);
        }
    }

    // Delete salesforce contacts.
    @http:ResourceConfig {
        methods: ["DELETE"],
        path: "/contacts/{accountId}"
    }
    resource function deleteContacts(http:Caller caller, http:Request request, string accountId) {
        json[]|sfdc46:SalesforceError contacts = getContactsFromSalesforce(accountId);

        if (contacts is json[]) {

            sfdc46:Result[]|sfdc46:SalesforceError results = 
                deleteContactsFromSalesforce(createDeleteJson( <@untainted> contacts));

            if (results is sfdc46:Result[]) {

                if (checkBatchResults(results)) {
                    json payload = {
                        status: "success"
                    };
                    respondAndHandleError(caller, http:STATUS_OK, <@untainted> payload);
                } else {
                    logAndRespondError(caller, "Error occurred while deleting contacts", (), 
                        http:STATUS_INTERNAL_SERVER_ERROR);
                }

            } else {
                logAndRespondError(caller, "Error occurred while deleting contacts" , results, 
                    http:STATUS_INTERNAL_SERVER_ERROR);
            }

        } else {
            logAndRespondError(caller, "Error occurred while getting contacts to be deleted", contacts, 
                http:STATUS_INTERNAL_SERVER_ERROR);
        }
    }
}
