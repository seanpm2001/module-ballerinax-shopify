import ballerina/auth;
import ballerina/http;
import ballerina/io;
import ballerina/lang.'float;
import ballerina/lang.'int;
import ballerina/stringutils;

import ballerina/time;
import ballerina/encoding;

string message = "Not implemented";

function createHttpClient(string url) returns http:Client {
    http:Client httpClient = new (url);
    return httpClient;
}

function getAuthHandler(BasicAuthConfiguration config) returns http:BasicAuthHandler {
    auth:OutboundBasicAuthProvider outboundBasicAuthProvider = new ({
        username: config.username,
        password: config.password
    });
    return new (outboundBasicAuthProvider);
}

function getRequestWithBasicAuth(Store store) returns http:Request {
    return new http:Request();
}

function getRequestWithOAuth(Store store) returns http:Request {
    http:Request request = new;
    request.addHeader(OAUTH_HEADER_KEY, store.accessToken);
    return request;
}

function createError(string message, error? e = ()) returns Error {
    Error shopifyError;
    if (e is error) {
        shopifyError = error(ERROR_REASON, message = message, cause = e);
    } else {
        shopifyError = error(ERROR_REASON, message = message);
    }
    return shopifyError;
}

function creatRecordArrayFromJsonArray(map<json> jsonValue, string 'field) returns json[] {
    if (jsonValue['field] is json[]) {
        return <json[]>jsonValue['field];
    } else {
        return [null];
    }
}

function checkResponse(http:Response response) returns Error? {
    int statusCode = response.statusCode;
    if (statusCode == http:STATUS_OK || statusCode == http:STATUS_CREATED || statusCode == http:STATUS_ACCEPTED) {
        return;
    } else {
        var payload = response.getJsonPayload();
        if (payload is json) {
            map<json> payloadMap = <@untainted map<json>>payload;
            string errorMessage = "";
            var errorRecord = payloadMap[ERRORS_FIELD];
            if (errorRecord is map<json>) {
                errorMessage = createErrorMessageFromJson(<map<json>>errorRecord);
            } else {
                errorMessage = errorRecord.toString();
            }
            
            return createError(errorMessage);
        }
        return createError("Invalid response received.");
    }
}

function createErrorMessageFromJson(map<json> jsonMap) returns string {
    string result = "";
    foreach string key in jsonMap.keys() {
        result += key + " " + jsonMap[key].toString() + "; ";
    }
    return result;
}

function convertJsonKeysToRecordKeys(json jsonValue) returns json {
    if (jsonValue is json[]) {
        json[] resultJsonArray = [];
        foreach json value in jsonValue {
            resultJsonArray.push(convertJsonKeysToRecordKeys(value));
        }
        return resultJsonArray;
    } else if (jsonValue is map<json>) {
        map<json> resultJson = {};
        foreach string key in jsonValue.keys() {
            string newKey = convertToCamelCase(key);
            json value = jsonValue[key];
            if (value is json[]) {
                resultJson[newKey] = convertJsonKeysToRecordKeys(value);
            } else {
                resultJson[newKey] = convertJsonKeysToRecordKeys(jsonValue[key]);
            }
        }
        return resultJson;
    } else {
        return jsonValue;
    }
}

function convertToCamelCase(string key) returns string {
    string recordKey = "";
    string[] words = stringutils:split(key, "_");

    int i = 0;
    foreach string word in words {
        if (i == 0) {
            recordKey = word;
        } else {
            recordKey = recordKey + word.substring(0, 1).toUpperAscii() + word.substring(1, word.length());
        }
        i += 1;
    }
    return recordKey;
}

function convertRecordKeysToJsonKeys(json jsonValue) returns json {
    if (jsonValue is json[]) {
        json[] resultJsonArray = [];
        foreach json value in jsonValue {
            resultJsonArray.push(convertRecordKeysToJsonKeys(value));
        }
        return resultJsonArray;
    } else if (jsonValue is map<json>) {
        map<json> resultJson = {};
        foreach string key in jsonValue.keys() {
            string newKey = convertToUnderscoreCase(key);
            json value = jsonValue[key];
            if (value is json[]) {
                resultJson[newKey] = convertRecordKeysToJsonKeys(value);
            } else {
                resultJson[newKey] = convertRecordKeysToJsonKeys(jsonValue[key]);
            }
        }
        return resultJson;
    } else {
        return jsonValue;
    }
}

function convertToUnderscoreCase(string value) returns string {
    string result = stringutils:replaceAll(value, "[A-Z]", "_$0");
    return result.toLowerAscii();
}

function getTimeRecordFromTimeString(string? time) returns time:Time|Error? {
    if (time is ()) {
        return;
    } else {
        var parsedTime = time:parse(time, DATE_FORMAT);
        if (parsedTime is time:Error) {
            return createError("Error occurred while converting the time string", parsedTime);
        } else {
            return parsedTime;
        }
    }
}

function getTimeStringTimeFromFilter(DateFilter filter, string filterType) returns string? {
    time:Time? date = filter[filterType];
    if (date is time:Time) {
        return getTimeStringFromTimeRecord(date);
    }
}

function getTimeStringFromTimeRecord(time:Time time) returns string {
    return time:toString(time);
}

function getValueFromJson(string key, map<json> jsonMap) returns string? {
    if (jsonMap.hasKey(key)) {
        var result = jsonMap.remove(key);
        return result.toString();
    }
}

function getFloatValueFromJson(string key, map<json> jsonMap) returns float|Error? {
    string errorMessage = "Error occurred while converting to the float value.";
    if (jsonMap.hasKey(key)) {
        var jsonValue = jsonMap.remove(key);
        var result = 'float:fromString(jsonValue.toString());
        if (result is error) {
            return createError(errorMessage, result);
        }
        return <float>result;
    }
}

function getIntValueFromJson(string key, map<json> jsonMap) returns int|Error {
    string errorMessage = "Error occurred while converting to the float value.";
    var jsonValue = jsonMap.remove(key);
    if (jsonValue is ()) {
        return createError(errorMessage + " Field " + key + " does not exist.", jsonValue);
    }
    var result = 'int:fromString(jsonValue.toString());
    if (result is error) {
        return createError(errorMessage, result);
    }
    return <int>result;
}

function getJsonPayload(http:Response response) returns @tainted json|Error {
    json|error payload = response.getJsonPayload();
    if (payload is error) {
        return createError("Invalid payload received", payload);
    } else {
        return payload;
    }
}

function buildCommaSeparatedListFromArray(any[] array) returns string {
    string result = "";
    int i = 0;
    foreach var item in array {
        if (i == 0) {
            result += item.toString();
        } else {
            result += "," + item.toString();
        }
        i += 1;
    }
    return result;
}

function buildFieldsCommaSeparatedList(string[] array) returns string {
    string result = "";
    int i = 0;
    foreach string item in array {
        string fieldName = convertToUnderscoreCase(item);
        if (i == 0) {
            result += fieldName;
        } else {
            result += "," + fieldName;
        }
        i += 1;
    }
    return result;
}

function getLinkFromHeader(http:Response response) returns string|Error? {
    if (!response.hasHeader(LINK_HEADER)) {
        return;
    }

    string? link = check retrieveLinkHeaderValues(response.getHeader(LINK_HEADER));
    if (link is ()) {
        return link;
    }
    string linkString = <string>link;
    var result = encoding:decodeUriComponent(linkString, UTF8);
    if (result is error) {
        return createError("Error occurred while retaining the link to the next page.", result);
    } else {
        return stringutils:split(result, API_PATH)[1];
    }
}

// Ignore the previous value since we do not use it here, because
function retrieveLinkHeaderValues(string linkHeaderValue) returns string|Error? {
    string[] pages = stringutils:split(linkHeaderValue, ",");
    foreach string page in pages {
        string link = stringutils:replaceAll(stringutils:split(page, ">")[0], " ", "");
        link = link.substring(1, link.length());
        string pageName = stringutils:split(page, "rel=")[1];
        pageName = stringutils:replaceAll(pageName, "\"", "");
        if (pageName == "next") {
            return link;
        }
    }
}

function notImplemented() returns Error {
    io:println("Not implemented");
    return error(ERROR_REASON, message = message);
}
