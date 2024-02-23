BASE_URL := "http://localhost:42800/"
HTTP_METHOD := "GET"

; Sets up the server by allocating a console and hiding it
SetupServer() {
    DllCall("AllocConsole")
    WinHide("ahk_id " DllCall("GetConsoleWindow", "ptr"))
    Run("node `"`"files/dist/index.js`"`"")
}

; Runs the client by sending requests to the server and handling the responses
RunClient() {
    whr := ComObject("WinHttp.WinHttpRequest.5.1")
    allFunctions := GetAvailableFunctions()

    Loop {
        if (!SendRequest(whr, HTTP_METHOD, BASE_URL . "register/" . allFunctions, false)) {
            continue
        }

        if (!SendRequest(whr, HTTP_METHOD, BASE_URL . "subscribe", false)) {
            continue
        }

        command := whr.ResponseText

        if (command == "kill") {
            SendRequest(whr, HTTP_METHOD, BASE_URL . "kill", false)
            Exit()
        } else if (command != "") {
            HandleCommand(command)
        }
    }
}

; Sends an HTTP request using the specified method, URL, and async flag
SendRequest(whr, method, url, async) {
    try {
        whr.Open(method, url, async)
        whr.Send()
        return true
    } catch error {
        return false
    }
}

; Handles a command received from the server
HandleCommand(command) {
    decodedCommand := EncodeDecodeURI(command, false)
    questionMarkPos := InStr(decodedCommand, "?")
    if (questionMarkPos) {
        methodName := SubStr(decodedCommand, 1, questionMarkPos - 1)
        paramString := SubStr(decodedCommand, questionMarkPos + 1)
    } else {
        methodName := decodedCommand
        paramString := ""
    }

    paramsArray := paramString ? ParamSplit(paramString) : []
    totalParameters := paramsArray.Length
    CallCustomFunctionByName(methodName, totalParameters, paramsArray*)
}

; Calls a custom function by its name, passing the specified parameters
CallCustomFunctionByName(methodName, totalParameters, params*) {
    method := GetMethodFromString("CustomFunctions." . methodName)
    if (method)
        method.Call(params*)
}

; Retrieves a method object from a string representation of the method
GetMethodFromString(str) {
    arr := StrSplit(str, '.')
    method := arr.Pop()
    obj := CustomFunctions()
    return ObjBindMethod(obj, method)
}

; Encodes or decodes a URI string
EncodeDecodeURI(str, encode := true, component := true) {
    static Doc, JS
    if !IsSet(Doc) {
        Doc := ComObject("htmlfile")
        Doc.write('<meta http-equiv="X-UA-Compatible" content="IE=9">')
        JS := Doc.parentWindow
        (Doc.documentMode < 9 && JS.execScript())
    }
    return JS.%((encode ? "en" : "de") . "codeURI" . (component ? "Component" : ""))%(str)
}

; Splits a parameter string into an array of individual parameters
; This function can handle both strings and variables
ParamSplit(text) {
    needle := ".*?,(?![^\(\[\{]*[\]\)\}])|.*"
    Params := []
    spo := 1, Len := StrLen(text)
    while (fpo := RegExMatch(text, "" needle, &M, (spo) < 1 ? (spo) - 1 : (spo))) && spo < Len {
        param := Trim(M[0], ", ")

        ; Handle array-like strings
        if (InStr(param, "[") AND InStr(param, "]")) {
            param := StrSplit(StrReplace(StrReplace(StrReplace(param, "[", ""), "]", ""), A_Space, ""), ",")
        }
        ; Handle literal strings
        else if InStr(param, '"') {
            param := StrReplace(param, '"')
        }
        else {
            param := %param%
        }

        Params.Push(param)
        spo := fpo + StrLen(M[0])
    }
    return Params
}

; Retrieves a list of available functions from the CustomFunctions object
GetAvailableFunctions() {
    customFuncs := CustomFunctions()
    baseMembers := ""
    isFirst := true

    for key in customFuncs.Base.OwnProps() {
        if customFuncs.Base.HasMethod(key) {
            note := ""

            baseMembers .= (isFirst ? "" : "`n") . key . "`n" . note
            isFirst := false
        }
    }

    return baseMembers
}